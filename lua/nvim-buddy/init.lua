-- nvim-buddy main module
local M = {}

-- Import our new modules
local context = require('nvim-buddy.context')
local picker = require('nvim-buddy.picker')

-- Initialize backend
M.backend = require("nvim-buddy.backend")

-- Default configuration
M.config = {
  keymaps = {
    show_input = "<leader>q", -- Keymap for input window
  },
  input_window = {
    width = 60,  -- Width to accommodate side-by-side layout
    height = 16,  -- Increased to accommodate more visible lines
    border = 'rounded',
    ascii_art = [[
(\_/)
(o.o) 
 ]],
    greeting = "What can I help you with?",
    colors = {
      art = "String", -- Default highlight group for ASCII art (usually green)
      greeting = "Title", -- Changed to Title for better visibility (usually bold/yellow)
      divider = "NonText", -- Default highlight group for divider
    },
    visible_lines = 12,  -- Show this many lines before scrolling
  },
  backend = {
    provider = "openai",                  -- Provider: "openai" or "gemini"
    openai = {
      api_key = nil,                      -- Your OpenAI API key (or set OPENAI_API_KEY env variable)
      model = "gpt-3.5-turbo",            -- Default model
      endpoint = "https://api.openai.com/v1/chat/completions", -- OpenAI endpoint
      max_tokens = 1000,                  -- Maximum number of tokens to generate
    },
    gemini = {
      api_key = nil,                      -- Your Gemini API key (or set GEMINI_API_KEY env variable)
      model = "gemini-pro",               -- Default model
      endpoint = "https://generativelanguage.googleapis.com/v1beta/models/", -- Base Gemini endpoint
      max_output_tokens = 1000,           -- Maximum number of tokens to generate
    },
    timeout = 30000,                      -- Timeout in milliseconds
    streaming = true,                     -- Enable streaming by default
  }
}

-- Add request state tracking
M.is_request_in_progress = false

-- Plugin setup function
function M.setup(opts)
  opts = opts or {}
  
  -- Merge configuration
  if opts and type(opts) == "table" then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end
  
  -- Make sure backend is loaded
  if not M.backend then
    M.backend = require("nvim-buddy.backend")
  end
  
  -- Initialize the backend
  M.backend.setup(opts)
  
  -- Set keybinding for input window if enabled
  if M.config.keymaps.show_input then
    vim.keymap.set('n', M.config.keymaps.show_input, function() require("nvim-buddy").show_input_window() end, {noremap = true, silent = true})
  end
end

function M.show_input_window()
    -- Use pcall to catch any errors during initialization
    local ok, err = pcall(function()
        -- Create two buffers: one for header (non-editable) and one for content (editable)
        local header_buf = vim.api.nvim_create_buf(false, true)
        local content_buf = vim.api.nvim_create_buf(false, true)
        
        if not header_buf or header_buf == 0 or not content_buf or content_buf == 0 then 
            error("Failed to create buffers")
            return
        end
        
        -- Set buffer options
        for _, buf in ipairs({header_buf, content_buf}) do
            vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
            vim.api.nvim_buf_set_option(buf, 'swapfile', false)
            vim.api.nvim_buf_set_option(buf, 'undolevels', -1)
        end
        
        -- Make header buffer non-modifiable - this ensures it can't be edited
        vim.api.nvim_buf_set_option(header_buf, 'modifiable', false)
        
        -- Split the ASCII art into lines
        local ascii_lines = {}
        for line in string.gmatch(M.config.input_window.ascii_art, "[^\r\n]+") do
            table.insert(ascii_lines, line)
        end
        
        -- Ensure we have 2 lines of ASCII art, pad if needed
        while #ascii_lines < 2 do
            table.insert(ascii_lines, string.rep(" ", 10))
        end
        
        -- Calculate padding for text content
        local text_padding = string.rep(" ", 30)
        
        -- Set consistent window padding for both windows
        local window_padding = 2  -- Consistent padding on all sides
        
        -- Create the header content with left padding to match the window
        local header_lines = {}
        local left_padding = string.rep(" ", window_padding)
        
        -- Header: ASCII art and greeting with consistent padding
        table.insert(header_lines, left_padding .. ascii_lines[1] .. text_padding)
        
        -- Store the greeting position for highlighting (adjusted for left padding)
        local greeting_col = left_padding:len() + #ascii_lines[2]
        
        table.insert(header_lines, left_padding .. ascii_lines[2] .. M.config.input_window.greeting)
        
        -- Divider with consistent length that respects padding
        local divider_width = M.config.input_window.width - window_padding * 2
        table.insert(header_lines, left_padding .. string.rep("─", divider_width))
        
        -- Set the header content
        vim.api.nvim_buf_set_option(header_buf, 'modifiable', true)
        pcall(function()
            vim.api.nvim_buf_set_lines(header_buf, 0, -1, false, header_lines)
        end)
        vim.api.nvim_buf_set_option(header_buf, 'modifiable', false)
        
        -- Set an empty line in the content buffer for initial input
        pcall(function()
            vim.api.nvim_buf_set_lines(content_buf, 0, -1, false, {""})
        end)
        
        -- Header height (where the window will be split)
        local header_height = #header_lines
        
        -- Configure the main floating window with padding
        local main_win_width = M.config.input_window.width -- Store original width
        local main_win_height = M.config.input_window.height -- Store original height
        
        local opts = {
            relative = 'editor',  -- Centered in editor
            width = main_win_width,
            height = main_win_height,
            row = math.floor((vim.o.lines - main_win_height) / 2),
            col = math.floor((vim.o.columns - main_win_width) / 2),
            style = 'minimal',
            border = M.config.input_window.border,
            zindex = 50, -- Ensure it's on top
        }
        
        -- Open the main window with the header buffer
        local main_win = vim.api.nvim_open_win(header_buf, true, opts)
        if not main_win or main_win == 0 then
            error("Failed to create window")
            return
        end
        
        -- Set window options to eliminate default padding
        vim.api.nvim_win_set_option(main_win, 'sidescrolloff', 0)
        vim.api.nvim_win_set_option(main_win, 'scrolloff', 0)
        vim.api.nvim_win_set_option(main_win, 'winfixwidth', true)
        
        -- Create the content window with the same padding
        local content_win_opts = {
            relative = 'win',
            win = main_win,
            width = main_win_width - (window_padding * 2), -- Account for left and right padding
            height = main_win_height - header_height,
            row = header_height,
            col = window_padding, -- Left padding
            style = 'minimal',
            border = 'none',
            zindex = 51,  -- Higher than main window
        }
        
        local content_win = vim.api.nvim_open_win(content_buf, true, content_win_opts)
        if not content_win or content_win == 0 then
            pcall(function() vim.api.nvim_win_close(main_win, true) end)
            error("Failed to create content window")
            return
        end
        
        -- Set consistent options for content window too
        vim.api.nvim_win_set_option(content_win, 'sidescrolloff', 0)
        vim.api.nvim_win_set_option(content_win, 'scrolloff', 0)
        vim.api.nvim_win_set_option(content_win, 'winfixwidth', true)
        
        -- Set up robust text wrapping
        vim.api.nvim_win_set_option(content_win, 'wrap', true)  -- Enable text wrapping
        vim.api.nvim_win_set_option(content_win, 'linebreak', true)  -- Wrap at word boundaries
        vim.api.nvim_win_set_option(content_win, 'breakindent', true)  -- Preserve indentation when wrapping
        
        -- Also set buffer options for better text handling
        vim.api.nvim_buf_set_option(content_buf, 'textwidth', content_win_opts.width - 2)  -- Set text width slightly less than window width
        
        -- Buffer is ready for user input
        vim.api.nvim_buf_set_option(content_buf, 'modifiable', true)
        
        -- Set up @ context trigger using a simpler but more reliable approach
        vim.keymap.set('i', '@', function()
            -- First let's just return @ to insert it normally
            local result = "@"
            
            -- Then show the picker, but only after @ is inserted
            vim.schedule(function()
                -- Get current buffer and cursor position after @ is inserted
                local buf = vim.api.nvim_get_current_buf()
                local win = vim.api.nvim_get_current_win()
                
                picker.pick_file(function(file_path)
                    if file_path then
                        -- Store the file path instead of content
                        local identifier = vim.fn.fnamemodify(file_path, ":t")
                        
                        -- Add the file content to the backend context
                        M.backend.add_file_context(identifier, file_path)
                        
                        -- Simply insert the brackets and filename right at the cursor
                        -- The @ is already in the buffer, we just append to it
                        vim.cmd('normal! a[' .. identifier .. ']')
                        
                        -- Return to insert mode
                        vim.cmd('startinsert!')
                    end
                end)
            end)
            
            return result
        end, {buffer = content_buf, expr = true})
        
        -- Process the message when user presses Enter
        vim.keymap.set('i', '<CR>', function()
            -- Get all text from buffer
            local lines = vim.api.nvim_buf_get_lines(content_buf, 0, -1, false)
            local input_text = table.concat(lines, "\n")
            
            -- Skip if input is empty
            if input_text:gsub("%s", "") == "" then
                return ""
            end
            
            -- Skip if a request is already in progress
            if M.is_request_in_progress then
                vim.notify("A request is already in progress", vim.log.levels.WARN)
                return ""
            end
            
            -- Set the request in progress flag
            M.is_request_in_progress = true
            
            -- Make buffer unmodifiable during request
            vim.api.nvim_buf_set_option(content_buf, 'modifiable', false)
            
            -- Use the backend's process_buffer function to handle streaming
            M.backend.process_buffer(content_buf, header_buf)
            
            -- Return empty string so the Enter key doesn't insert a newline
            return ""
        end, {buffer = content_buf, expr = true})
        
        -- Store both windows in global table for cleanup
        _G.nvim_buddy_windows = _G.nvim_buddy_windows or {}
        _G.nvim_buddy_windows[header_buf] = main_win
        _G.nvim_buddy_windows[content_buf] = content_win
        
        -- Create a single simplified close function
        _G.nvim_buddy_close_all = function()
            -- Close content window first
            if _G.nvim_buddy_window_ids and _G.nvim_buddy_window_ids.content_win and 
               vim.api.nvim_win_is_valid(_G.nvim_buddy_window_ids.content_win) then
                pcall(vim.api.nvim_win_close, _G.nvim_buddy_window_ids.content_win, true)
            end
            
            -- Then close main window
            if _G.nvim_buddy_window_ids and _G.nvim_buddy_window_ids.main_win and 
               vim.api.nvim_win_is_valid(_G.nvim_buddy_window_ids.main_win) then
                pcall(vim.api.nvim_win_close, _G.nvim_buddy_window_ids.main_win, true)
            end
            
            -- Finally clean up resources
            pcall(require('nvim-buddy').cleanup_all_windows)
        end
        
        -- Better tracking for window IDs
        _G.nvim_buddy_window_ids = _G.nvim_buddy_window_ids or {}
        _G.nvim_buddy_window_ids.main_win = main_win
        _G.nvim_buddy_window_ids.content_win = content_win
        
        -- Set window options
        for _, win in ipairs({main_win, content_win}) do
            pcall(function()
                vim.api.nvim_win_set_option(win, 'cursorline', false)
                vim.api.nvim_win_set_option(win, 'number', false)
                vim.api.nvim_win_set_option(win, 'relativenumber', false)
            end)
        end
        
        -- Create highlight namespace
        local ns_id = vim.api.nvim_create_namespace('nvim_buddy_highlights')
        
        -- Apply colors to ASCII art (lines 0-1 now, since there are only 2 lines)
        for i = 0, 1 do
            if i < #ascii_lines then
                pcall(function()
                    vim.api.nvim_buf_add_highlight(header_buf, ns_id, M.config.input_window.colors.art, i, 0, #ascii_lines[i+1] + left_padding:len())
                end)
            end
        end
        
        -- Apply color to greeting (line 1)
        pcall(function()
            vim.api.nvim_buf_add_highlight(header_buf, ns_id, M.config.input_window.colors.greeting, 1, greeting_col, -1)
        end)
        
        -- Apply color to divider (line 2)
        pcall(function()
            vim.api.nvim_buf_add_highlight(header_buf, ns_id, M.config.input_window.colors.divider, 2, 0, -1)
        end)
        
        -- Set up a SINGLE autocommand that doesn't depend on specific window IDs
        vim.cmd([[
          augroup NvimBuddyCleanup
            autocmd!
            autocmd WinClosed * lua if _G.nvim_buddy_window_ids and (vim.v.event.window == ]] .. main_win .. [[ or vim.v.event.window == ]] .. content_win .. [[) then pcall(_G.nvim_buddy_close_all) end
          augroup END
        ]])
        
        -- Add multiple ways to close the windows - all using the same reliable function
        
        -- 1. Make ESC close the windows
        vim.keymap.set('n', '<ESC>', function() 
            pcall(_G.nvim_buddy_close_all)
        end, {buffer = content_buf, noremap = true, silent = true})
        
        -- 2. Make 'q' in normal mode close the windows
        vim.keymap.set('n', 'q', function() 
            pcall(_G.nvim_buddy_close_all)
        end, {buffer = content_buf, noremap = true, silent = true})
        
        -- 3. Make Ctrl+C close the windows from insert mode
        vim.keymap.set('i', '<C-c>', function() 
            pcall(_G.nvim_buddy_close_all)
        end, {buffer = content_buf, noremap = true, silent = true})
        
        -- Also add a mapping for normal mode Ctrl+C
        vim.keymap.set('n', '<C-c>', function() 
            pcall(_G.nvim_buddy_close_all)
        end, {buffer = content_buf, noremap = true, silent = true})
        
        -- Add Ctrl+C mappings to header buffer too
        vim.keymap.set('n', '<C-c>', function() 
            pcall(_G.nvim_buddy_close_all)
        end, {buffer = header_buf, noremap = true, silent = true})
        
        -- Make easier for focus switching between windows
        vim.keymap.set('n', '<Tab>', function()
            if vim.api.nvim_get_current_win() == main_win then
                vim.api.nvim_set_current_win(content_win)
            else
                vim.api.nvim_set_current_win(main_win)
            end
        end, {buffer = content_buf})
        
        vim.keymap.set('n', '<Tab>', function()
            if vim.api.nvim_get_current_win() == main_win then
                vim.api.nvim_set_current_win(content_win)
            else
                vim.api.nvim_set_current_win(main_win)
            end
        end, {buffer = header_buf})
        
        -- Focus the content window and enter insert mode
        vim.api.nvim_set_current_win(content_win)
        vim.cmd('startinsert!')
    end)
    
    if not ok then
        vim.notify("Error in nvim-buddy: " .. tostring(err), vim.log.levels.ERROR)
    end
end

-- Function to clean up all nvim-buddy windows
function M.cleanup_all_windows()
    -- Clear out autocommand group first
    pcall(function()
        vim.cmd("silent! autocmd! NvimBuddyCleanup")
    end)
    
    -- Clean up buffers
    if _G.nvim_buddy_windows then
        for buf, _ in pairs(_G.nvim_buddy_windows) do
            if buf and vim.api.nvim_buf_is_valid(buf) then
                pcall(vim.api.nvim_buf_delete, buf, {force = true})
            end
        end
        _G.nvim_buddy_windows = {}
    end
    
    -- Clear global state after a small delay to ensure all callbacks complete
    vim.defer_fn(function()
        -- Clean up window ids
        _G.nvim_buddy_window_ids = nil
        
        -- Clean up global helper functions
        _G.nvim_buddy_close_all = nil
        
        -- Try to clear any related variables
        collectgarbage("collect")
    end, 100)
end

return M