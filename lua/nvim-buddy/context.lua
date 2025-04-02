-- nvim-buddy context handling module
local M = {}

-- Store contexts for the current session
M.contexts = {}

-- Parse input text for context triggers (@file or @module.function)
function M.parse_triggers(text)
  local triggers = {}
  -- Basic pattern to match @filename or @module.function
  for trigger in text:gmatch('@([%w%.%/%_%-]+)') do
    table.insert(triggers, trigger)
  end
  return triggers
end

-- Add a context to the internal storage
function M.add_context(identifier, content)
  M.contexts[identifier] = content
  return identifier
end

-- Get all stored contexts
function M.get_contexts()
  return M.contexts
end

-- Clear all stored contexts
function M.clear_contexts()
  M.contexts = {}
end

-- Read the content of a file
function M.read_file_content(file_path)
  local lines = {}
  local file = io.open(file_path, "r")
  if file then
    for line in file:lines() do
      table.insert(lines, line)
    end
    file:close()
    return table.concat(lines, "\n")
  end
  return nil
end

-- Process input text and add contexts as needed
function M.process_input(visible_text)
  local triggers = M.parse_triggers(visible_text)
  local processed_text = visible_text
  local contexts = {}
  
  -- For each trigger, add its context
  for _, trigger in ipairs(triggers) do
    if M.contexts[trigger] then
      -- If we have this context, add it
      table.insert(contexts, {
        identifier = trigger,
        content = M.contexts[trigger]
      })
      -- Replace the trigger in the processed text with a marker
      processed_text = processed_text:gsub('@' .. trigger, '[Context: ' .. trigger .. ']')
    end
  end
  
  return {
    text = processed_text,
    contexts = contexts
  }
end

return M
