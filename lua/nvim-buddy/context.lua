-- nvim-buddy context handling module
local M = {}

-- Store contexts for the current session (paths only, not content)
M.contexts = {}

-- Store additional metadata about contexts
M.context_metadata = {}

-- Parse input text for context triggers (@file or @module.function)
function M.parse_triggers(text)
  local triggers = {}
  -- Basic pattern to match @filename or @module.function
  for trigger in text:gmatch('@([%w%.%/%_%-]+)') do
    table.insert(triggers, trigger)
  end
  return triggers
end

-- Add a context to the internal storage (store path instead of content)
function M.add_context(identifier, file_path)
  M.contexts[identifier] = file_path
  
  -- Add metadata about the file
  M.context_metadata[identifier] = {
    added_at = os.time(),
    file_type = vim.fn.fnamemodify(file_path, ":e"),
    relative_path = vim.fn.fnamemodify(file_path, ":~:."),
  }
  
  return identifier
end

-- Get all stored context paths
function M.get_contexts()
  return M.contexts
end

-- Clear all stored contexts
function M.clear_contexts()
  M.contexts = {}
  M.context_metadata = {}
end

-- Process input text to find context triggers and create a JSON structure for the backend
function M.process_input(visible_text)
    local triggers = M.parse_triggers(visible_text)
    local processed_text = visible_text
    local context_files = {}
    for _, trigger in ipairs(triggers) do
        if M.contexts[trigger] then
            table.insert(context_files, {
                identifier = trigger,
                path = M.contexts[trigger],
                file_type = M.context_metadata[trigger].file_type,
                relative_path = M.context_metadata[trigger].relative_path
            })
            processed_text = processed_text:gsub('@' .. trigger, '[Context: ' .. trigger .. ']')
        end
    end
    local backend_data = {
        message = processed_text,
        contexts = context_files,
        timestamp = os.time(),
        streaming = true -- Enable streaming by default
    }
    return backend_data
end

-- Convert a table to a JSON string
function M.to_json(data)
    -- Use vim's built-in JSON encoding function
    return vim.fn.json_encode(data)
end

return M
