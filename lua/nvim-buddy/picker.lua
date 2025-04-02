-- File picker module for nvim-buddy
local M = {}

local context = require('nvim-buddy.context')

-- Keep track of open windows/buffers
M.state = {
  buf = nil,
  win = nil,
  items = {},
  callback = nil,
  input = ""
}

-- Create a floating window for file selection
function M.create_window()
  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'nvimbuddypicker')
  vim.api.nvim_buf_set_option(buf, 'modifiable', false) -- Make it unmodifiable
  vim.api.nvim_buf_set_option(buf, 'readonly', true)    -- Make it readonly too
  
  -- Get cursor position in the current window
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor_pos[1]
  local cursor_col = cursor_pos[2]
  
  -- Convert cursor position to screen coords
  local screen_row, screen_col
  local current_win = vim.api.nvim_get_current_win()
  
  -- Get window position
  local win_pos = vim.api.nvim_win_get_position(current_win)
  screen_row = win_pos[1] + cursor_row
  screen_col = win_pos[2] + cursor_col
  
  -- Instead of using complex win_info calculations that might have nil fields,
  -- use a simpler approach to position the dropdown
  -- Add a small offset from cursor
  screen_row = screen_row + 1
  
  -- Window size - make it reasonable size that fits on screen
  local width = math.min(60, vim.o.columns - 4)
  local height = math.min(15, vim.o.lines - 4)
  
  -- Ensure the window doesn't go off-screen
  screen_row = math.min(screen_row, vim.o.lines - height - 2)
  screen_col = math.min(screen_col, vim.o.columns - width - 2)
  
  -- Window options
  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = screen_row,
    col = screen_col,
    style = 'minimal',
    border = 'rounded',
    title = " File Context ",
    title_pos = "center",
    zindex = 100  -- Set a high z-index to ensure it's on top
  }
  
  -- Create window
  local win = vim.api.nvim_open_win(buf, true, opts)
  
  -- Set window options
  vim.api.nvim_win_set_option(win, 'cursorline', true) -- Highlight current line
  vim.api.nvim_win_set_option(win, 'winhl', 'CursorLine:PmenuSel') -- Use menu selection highlight
  vim.api.nvim_win_set_option(win, 'wrap', false)
  vim.api.nvim_win_set_option(win, 'number', false)
  
  -- Store in state
  M.state.buf = buf
  M.state.win = win
  
  return buf, win
end

-- Find files in project
function M.find_files()
  local items = {}
  local root = vim.fn.getcwd()
  
  -- Simple paths to always ignore
  local basic_ignore_patterns = {
    "^%.git/",
    "^node_modules/"
  }
  
  -- Fallback to the simplest approach to ensure we show files
  local files = vim.fn.glob(root .. "/**/*.lua", false, true)
  local additional_files = vim.fn.glob(root .. "/**/*.rs", false, true)
  for _, file in ipairs(additional_files) do
    table.insert(files, file)
  end
  
  additional_files = vim.fn.glob(root .. "/**/*.md", false, true)
  for _, file in ipairs(additional_files) do
    table.insert(files, file)
  end
  
  -- Helper function to check if a file should be ignored by basic patterns
  local function is_basic_ignored(file_path)
    local rel_path = vim.fn.fnamemodify(file_path, ":~:.")
    
    -- Skip directories
    if vim.fn.isdirectory(file_path) == 1 then
      return true
    end
    
    -- Check basic ignore patterns
    for _, pattern in ipairs(basic_ignore_patterns) do
      if rel_path:match(pattern) then
        return true
      end
    end
    
    return false
  end
  
  -- Filter files using just basic patterns to ensure we show something
  for _, file in ipairs(files) do
    if not is_basic_ignored(file) then
      local display = vim.fn.fnamemodify(file, ":~:.")
      table.insert(items, {
        value = file,
        display = display,
        filename = vim.fn.fnamemodify(file, ":t")
      })
    end
  end
  
  -- If we still have no items, add all non-hidden files as a fallback
  if #items == 0 then
    local all_files = vim.fn.glob(root .. "/*", false, true)
    for _, file in ipairs(all_files) do
      if vim.fn.isdirectory(file) == 0 and not vim.fn.fnamemodify(file, ":t"):match("^%.") then
        local display = vim.fn.fnamemodify(file, ":~:.")
        table.insert(items, {
          value = file,
          display = display,
          filename = vim.fn.fnamemodify(file, ":t")
        })
      end
    end
  end
  
  -- Add a debug item if we still have no items
  if #items == 0 then
    table.insert(items, {
      value = root .. "/README.md", 
      display = "README.md (debug item)",
      filename = "README.md"
    })
  end
  
  -- Sort by display name
  table.sort(items, function(a, b) return a.display < b.display end)
  
  -- Log for debugging
  print("Found " .. #items .. " files")
  
  return items
end

-- Filter items based on input
function M.filter_items(query)
  if not query or query == "" then
    return M.state.items
  end
  
  local filtered = {}
  local lower_query = string.lower(query)
  
  for _, item in ipairs(M.state.items) do
    if string.lower(item.display):find(lower_query, 1, true) then
      table.insert(filtered, item)
    end
  end
  
  return filtered
end

-- Update the buffer with filtered items
function M.update_buffer(items)
  local lines = {}
  for _, item in ipairs(items) do
    table.insert(lines, item.display)
  end
  
  -- If no items, show message
  if #lines == 0 then
    lines = {"No matching files found"}
  end
  
  -- Set lines in buffer
  vim.api.nvim_buf_set_option(M.state.buf, 'modifiable', true)
  vim.api.nvim_buf_set_option(M.state.buf, 'readonly', false)  -- Temporarily make it writable
  vim.api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.state.buf, 'readonly', true)   -- Make it readonly again
  vim.api.nvim_buf_set_option(M.state.buf, 'modifiable', false) -- Make it unmodifiable again
  
  -- Add custom highlight for each line (alternating colors for better visibility)
  for i, _ in ipairs(lines) do
    local hl_group = (i % 2 == 0) and "NvimBuddyPickerEven" or "NvimBuddyPickerOdd"
    vim.api.nvim_buf_add_highlight(M.state.buf, -1, hl_group, i-1, 0, -1)
  end
end

-- Handle selection of an item
function M.select_item()
  if not M.state.win or not vim.api.nvim_win_is_valid(M.state.win) then
    return
  end
  
  -- Get cursor position
  local cursor = vim.api.nvim_win_get_cursor(M.state.win)
  local idx = cursor[1]
  
  -- Get filtered items
  local filtered = M.filter_items(M.state.input)
  
  -- Check if selection is valid
  if idx > 0 and idx <= #filtered then
    local selected = filtered[idx]
    local file_path = selected.value
    local content = context.read_file_content(file_path)
    
    -- Close window
    M.close()
    
    -- Call callback with selected file
    if M.state.callback then
      M.state.callback(selected.filename, content, file_path)
    end
  end
end

-- Close picker window
function M.close()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_win_close(M.state.win, true)
  end
  
  if M.state.buf and vim.api.nvim_buf_is_valid(M.state.buf) then
    vim.api.nvim_buf_delete(M.state.buf, { force = true })
  end
  
  M.state.win = nil
  M.state.buf = nil
end

-- Set up keymaps for the picker
function M.setup_keymaps()
  local buf = M.state.buf
  
  -- Block insert mode attempts
  vim.keymap.set('n', 'i', function() end, { buffer = buf, noremap = true })
  vim.keymap.set('n', 'I', function() end, { buffer = buf, noremap = true })
  vim.keymap.set('n', 'a', function() end, { buffer = buf, noremap = true })
  vim.keymap.set('n', 'A', function() end, { buffer = buf, noremap = true })
  vim.keymap.set('n', 'o', function() end, { buffer = buf, noremap = true })
  vim.keymap.set('n', 'O', function() end, { buffer = buf, noremap = true })
  
  -- Select item with Enter
  vim.keymap.set('n', '<CR>', function()
    M.select_item()
  end, { buffer = buf, noremap = true })
  
  -- Move up/down with Tab/Shift-Tab
  vim.keymap.set('n', '<Tab>', function()
    local cursor = vim.api.nvim_win_get_cursor(M.state.win)
    local line = cursor[1]
    local filtered = M.filter_items(M.state.input)
    
    -- Move to next item (or wrap to first)
    if line < #filtered then
      vim.api.nvim_win_set_cursor(M.state.win, {line + 1, 0})
    else
      vim.api.nvim_win_set_cursor(M.state.win, {1, 0})
    end
  end, { buffer = buf, noremap = true })
  
  vim.keymap.set('n', '<S-Tab>', function()
    local cursor = vim.api.nvim_win_get_cursor(M.state.win)
    local line = cursor[1]
    local filtered = M.filter_items(M.state.input)
    
    -- Move to previous item (or wrap to last)
    if line > 1 then
      vim.api.nvim_win_set_cursor(M.state.win, {line - 1, 0})
    else
      vim.api.nvim_win_set_cursor(M.state.win, {#filtered, 0})
    end
  end, { buffer = buf, noremap = true })
  
  -- Add j/k navigation for familiarity
  vim.keymap.set('n', 'j', function()
    local cursor = vim.api.nvim_win_get_cursor(M.state.win)
    local line = cursor[1]
    local filtered = M.filter_items(M.state.input)
    
    if line < #filtered then
      vim.api.nvim_win_set_cursor(M.state.win, {line + 1, 0})
    end
  end, { buffer = buf, noremap = true })
  
  vim.keymap.set('n', 'k', function()
    local cursor = vim.api.nvim_win_get_cursor(M.state.win)
    local line = cursor[1]
    
    if line > 1 then
      vim.api.nvim_win_set_cursor(M.state.win, {line - 1, 0})
    end
  end, { buffer = buf, noremap = true })
  
  -- Close with Escape
  vim.keymap.set('n', '<Esc>', function()
    M.close()
  end, { buffer = buf, noremap = true })
  
  -- Also close with q
  vim.keymap.set('n', 'q', function()
    M.close()
  end, { buffer = buf, noremap = true })
  
  -- Filter as you type (simplified version of Telescope's behavior)
  vim.keymap.set('n', '/', function()
    -- Create a small prompt at the bottom
    local new_input = vim.fn.input("Filter: ", M.state.input)
    M.state.input = new_input
    
    -- Update display with filtered items
    local filtered = M.filter_items(new_input)
    M.update_buffer(filtered)
  end, { buffer = buf, noremap = true })
end

-- Show the file picker
function M.pick_file(callback)
  -- Set up highlight groups if they don't exist
  vim.cmd([[
    highlight default link NvimBuddyPickerOdd Normal
    highlight default link NvimBuddyPickerEven Comment
    highlight default link NvimBuddyPickerSelected PmenuSel
  ]])

  -- Find all files first
  M.state.items = M.find_files()
  M.state.callback = callback
  M.state.input = ""
  
  -- Create window
  local buf, win = M.create_window()
  
  -- Show initial items
  M.update_buffer(M.state.items)
  
  -- Set up keymaps
  M.setup_keymaps()
  
  -- Block all insert mode attempts
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'readonly', true)
  
  -- Position cursor at first item
  vim.api.nvim_win_set_cursor(win, {1, 0})
  
  -- Ensure we're in normal mode
  vim.cmd('stopinsert')
end

return M
