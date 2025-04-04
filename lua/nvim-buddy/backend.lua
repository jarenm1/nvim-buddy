-- Backend module for nvim-buddy with streamlined API implementation
local M = {}
local Job = require('plenary.job')

-- Configuration with defaults
M.config = {
  provider = "gemini",
  gemini = {
    api_key = os.getenv("GEMINI_API_KEY") or nil,
    model = "gemini-1.5-flash",
    endpoint = "https://generativelanguage.googleapis.com/v1beta/models/",
    max_output_tokens = 1000,
  },
  debug = false,
  streaming = true,
}

-- Setup function to configure the module
function M.setup(opts)
  if opts then
    -- Handle case where opts might be a boolean or unexpected type
    if type(opts) == "table" then
      -- Deep merge config tables
      M.config = vim.tbl_deep_extend("force", M.config, opts)
      
      -- Handle backward compatibility with old config structure
      if opts.provider and type(opts.provider) == "string" then
        M.config.provider = opts.provider
      end
    else
      vim.notify("Invalid configuration format for nvim-buddy backend", vim.log.levels.WARN)
    end
  end
  
  -- Attempt to get API key from environment if not explicitly set
  if not M.config.gemini.api_key then
    M.config.gemini.api_key = vim.env.GEMINI_API_KEY
    
    if not M.config.gemini.api_key or M.config.gemini.api_key == "" then
      vim.notify('Missing Gemini API key. Set config.gemini.api_key or GEMINI_API_KEY env variable', vim.log.levels.WARN)
    end
  end
  
  return M
end

-- Get the base URL for API calls
local function get_api_url()
  local base = M.config.gemini.endpoint
  local model = M.config.gemini.model
  
  -- Remove trailing slash if present
  if base:sub(-1) == "/" then
    base = base:sub(1, -2)
  end
  
  local url = base .. "/" .. model .. ":streamGenerateContent?alt=sse"
  
  -- Add API key to URL
  if M.config.gemini.api_key then
    url = url .. "&key=" .. M.config.gemini.api_key
  end
  
  return url
end

-- Function to get the prompt from the current buffer
local function get_prompt_from_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return table.concat(lines, "\n")
end

-- Function to append text to a buffer
local function append_to_buffer(text, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    vim.notify("Invalid buffer for append operation", vim.log.levels.ERROR)
    return false
  end
  
  -- Make buffer modifiable (but don't restore - keep it modifiable)
  local was_modifiable = vim.api.nvim_buf_get_option(bufnr, 'modifiable')
  if not was_modifiable then
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
  end
  
  -- Get current line count and append text
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  
  -- Split text by newlines and append all lines
  local lines = vim.split(text, "\n")
  vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, lines)
  
  -- Get window that shows the buffer and move cursor to end if possible
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      local new_line_count = vim.api.nvim_buf_line_count(bufnr)
      local last_line = vim.api.nvim_buf_get_lines(bufnr, new_line_count - 1, new_line_count, false)[1] or ""
      vim.api.nvim_win_set_cursor(win, {new_line_count, #last_line})
      break
    end
  end
  
  -- Do NOT restore modifiable state - keep it modifiable
  return true
end

-- Debug logging function
local function log_debug(message)
  if M.config.debug then
    print("[nvim-buddy debug] " .. message)
  end
end

-- Format and send a request to the Gemini API
function M.send_message(message, callback, on_chunk)
  -- Validate API key
  if not M.config.gemini.api_key or M.config.gemini.api_key == "" then
    vim.notify("Missing Gemini API key", vim.log.levels.ERROR)
    if callback then
      callback({ error = "Missing API key" })
    end
    return
  end
  
  -- Prepare request
  local request_body = vim.fn.json_encode({
    contents = {{parts = {{text = message}}}}
  })
  
  log_debug("Sending request to Gemini API")
  
  -- Create the job for streaming
  local url = get_api_url()
  log_debug("API URL: " .. url)
  
  local job = Job:new({
    command = 'curl',
    args = {
      '-s',  -- Silent mode
      '-S',  -- Show error even in silent mode
      '--no-progress-meter', -- Explicitly disable progress meter
      '--no-buffer',  -- Ensures real-time streaming
      url,
      '-H', 'Content-Type: application/json',
      '-d', request_body
    },
    on_stdout = function(_, data)
      -- Handle various data formats safely
      if not data then return end
      
      -- Convert string data to a table if needed
      local lines = data
      if type(data) == "string" then
        lines = {data}
      elseif type(data) ~= "table" then
        log_debug("Unexpected data type in on_stdout: " .. type(data))
        return
      end
      
      -- Process each line
      for _, line in ipairs(lines) do
        if line and type(line) == "string" and line ~= "" then
          log_debug("Received line: " .. vim.inspect(line:sub(1, 50) .. (line:len() > 50 and "..." or "")))
          
          if line:match("^data: ") then
            -- Extract the data portion
            local data_content = line:gsub("^data: ", "")
            
            -- Skip "[DONE]" marker
            if data_content == "[DONE]" then
              log_debug("Streaming completed")
              return
            end
            
            -- Try to parse the JSON
            local ok, decoded = pcall(vim.fn.json_decode, data_content)
            if ok and decoded and decoded.candidates then
              -- Extract text from candidate
              local text = nil
              if decoded.candidates[1] and decoded.candidates[1].content and 
                 decoded.candidates[1].content.parts and decoded.candidates[1].content.parts[1] then
                text = decoded.candidates[1].content.parts[1].text
              end
              
              if text and type(text) == "string" and #text > 0 then
                log_debug("Extracted text: " .. vim.inspect(text:sub(1, 20) .. (text:len() > 20 and "..." or "")))
                
                -- Call the chunk handler callback
                if on_chunk then
                  on_chunk(text)
                end
              end
            else
              -- Fallback direct text extraction (for cases where JSON parsing fails)
              local text = line:match('"text"%s*:%s*"([^"]*)"')
              if text and text ~= "" then
                -- Unescape special characters in the string
                text = text:gsub("\\n", "\n"):gsub("\\t", "\t"):gsub('\\"', '"'):gsub("\\\\", "\\")
                log_debug("Direct text extraction: " .. text:sub(1, 20) .. (text:len() > 20 and "..." or ""))
                
                if on_chunk then
                  on_chunk(text)
                end
              else
                log_debug("Failed to parse JSON: " .. data_content)
              end
            end
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        local error_msg = ""
        
        -- Handle both string and table data formats
        if type(data) == "string" then
          error_msg = data
        elseif type(data) == "table" and #data > 0 then
          error_msg = table.concat(data, "\n")
        end
        
        -- Only process if we have a meaningful error message
        if error_msg ~= "" then
          log_debug("stderr: " .. error_msg)
          
          -- If we have a callback, report the error
          if callback then
            callback({ error = "API error", details = error_msg })
          end
        end
      end
    end,
    on_exit = function(_, code)
      log_debug("Job exited with code: " .. tostring(code))
      
      -- Call the completion callback
      vim.schedule(function()
        if code == 0 then
          if callback then callback({ success = true }) end
        else
          if callback then callback({ error = "Request failed with code " .. tostring(code) }) end
        end
      end)
    end,
  })

  -- Start the job
  job:start()
  
  return job  -- Return job object so caller can control it if needed
end

-- Process a buffer and stream responses directly to it
function M.process_buffer(bufnr, header_bufnr)
  -- Get prompt from specified buffer
  local prompt = get_prompt_from_buffer(bufnr)
  
  -- Track if we've shown the first response yet
  local is_first_response = true
  local timer = nil
  local timer_active = false
  
  -- Set up progress indicator if header buffer is provided
  if header_bufnr and vim.api.nvim_buf_is_valid(header_bufnr) then
    -- Schedule header buffer modifications to the main event loop
    vim.schedule(function()
      -- Find the greeting line and replace with "thinking..."
      local thinking_text = "thinking..."
      local header_lines = vim.api.nvim_buf_get_lines(header_bufnr, 0, -1, false)
      
      -- Look for the greeting line
      local greeting_line_idx = nil
      for i, line in ipairs(header_lines) do
        if line:match("What can I help you with?") then
          greeting_line_idx = i-1
          break
        end
      end
      
      -- Only try to modify if we found the greeting line
      if greeting_line_idx ~= nil then
        -- Safe buffer modification
        if pcall(function()
          vim.api.nvim_buf_set_option(header_bufnr, 'modifiable', true)
          local new_line = header_lines[greeting_line_idx+1]:gsub("What can I help you with%?", thinking_text)
          vim.api.nvim_buf_set_lines(header_bufnr, greeting_line_idx, greeting_line_idx+1, false, {new_line})
          vim.api.nvim_buf_set_option(header_bufnr, 'modifiable', false)
        end) then
          log_debug("Successfully updated header with thinking message")
        else
          log_debug("Failed to update header buffer")
        end
      end
      
      -- Set up spinner animation after a short delay
      vim.defer_fn(function()
        if not vim.api.nvim_buf_is_valid(header_bufnr) then return end
        
        local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
        local spinner_idx = 1
        
        timer = vim.loop.new_timer()
        timer_active = true
        
        timer:start(0, 100, vim.schedule_wrap(function()
          if not timer_active then return end
          
          if vim.api.nvim_buf_is_valid(header_bufnr) then
            pcall(function()
              vim.api.nvim_buf_set_option(header_bufnr, 'modifiable', true)
              local header_lines = vim.api.nvim_buf_get_lines(header_bufnr, 0, -1, false)
              
              for i, line in ipairs(header_lines) do
                -- Look for the line with "thinking..." with or without any spinner
                if line:match("thinking...") then
                  spinner_idx = (spinner_idx % #spinner_frames) + 1
                  
                  -- Replace the entire line with new version - this ensures we don't accumulate symbols
                  local base_line = line:gsub("thinking...%s*%S*", "thinking...")
                  local new_line = base_line .. " " .. spinner_frames[spinner_idx]
                  
                  vim.api.nvim_buf_set_lines(header_bufnr, i-1, i, false, {new_line})
                  break
                end
              end
              vim.api.nvim_buf_set_option(header_bufnr, 'modifiable', false)
            end)
          else
            -- Buffer no longer valid, stop timer safely
            if timer_active then
              timer_active = false
              if timer then 
                pcall(function() timer:stop() end)
              end
            end
          end
        end))
      end, 100) -- Short delay to ensure we're out of the current context
    end)
  end
  
  -- Send the request - with a short delay to ensure we're out of the keymap context
  vim.defer_fn(function()
    M.send_message(
      prompt,
      function(response)
        -- Stop the spinner safely
        if timer_active then
          timer_active = false
          if timer then 
            pcall(function() timer:stop() end)
            pcall(function() timer:close() end)
          end
        end
        
        -- Restore the header greeting if needed
        vim.schedule(function()
          if header_bufnr and vim.api.nvim_buf_is_valid(header_bufnr) then
            pcall(function()
              vim.api.nvim_buf_set_option(header_bufnr, 'modifiable', true)
              local header_lines = vim.api.nvim_buf_get_lines(header_bufnr, 0, -1, false)
              
              for i, line in ipairs(header_lines) do
                -- Look for any line with "thinking..." with or without spinner
                if line:match("thinking...") then
                  -- Use the original greeting text without any modification
                  local new_line = line:gsub("thinking...%s*%S*", "What can I help you with?")
                  vim.api.nvim_buf_set_lines(header_bufnr, i-1, i, false, {new_line})
                  
                  -- Restore greeting highlight if needed
                  local greeting_ns = vim.api.nvim_create_namespace('nvim_buddy_greeting')
                  pcall(function()
                    vim.api.nvim_buf_clear_namespace(header_bufnr, greeting_ns, i-1, i)
                    local greeting_start = new_line:find("What can I help you with?")
                    if greeting_start then
                      vim.api.nvim_buf_add_highlight(header_bufnr, greeting_ns, "Title", 
                                                   i-1, greeting_start-1, greeting_start+#"What can I help you with?")
                    end
                  end)
                  
                  break
                end
              end
              vim.api.nvim_buf_set_option(header_bufnr, 'modifiable', false)
            end)
          end
          
          -- Clear the request in progress flag in the main module
          if package.loaded["nvim-buddy"] then
            local nvim_buddy = package.loaded["nvim-buddy"]
            if nvim_buddy and type(nvim_buddy) == "table" then
              nvim_buddy.is_request_in_progress = false
            end
          end
        end)
        
        -- Handle any response errors
        if response.error then
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(bufnr) then
              pcall(function()
                vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, 
                                      {"Error: " .. response.error})
                if response.details then
                  vim.api.nvim_buf_set_lines(bufnr, 1, 1, false, 
                                          {"Details: " .. response.details})
                end
                -- Do NOT set modifiable to false
              end)
            end
          end)
        end
      end,
      function(chunk)
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(bufnr) then
            pcall(function()
              -- For the first chunk, clear the buffer
              if is_first_response then
                is_first_response = false
                vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
              end
              
              -- Append the chunk to the buffer
              append_to_buffer(chunk, bufnr)
            end)
          end
        end)
      end
    )
  end, 50) -- Short delay to get out of the keymap context
end

return M
