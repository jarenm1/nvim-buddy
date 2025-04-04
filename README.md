# nvim-buddy

A simple Neovim plugin that provides an interactive floating window with ASCII art.

## Features

- Interactive input window with ASCII art using `<leader>b` (default)
- Customizable keymaps and window settings

## Installation

### Dependencies

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - Required for HTTP requests to LLM APIs

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "jarenm1/nvim-buddy",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("nvim-buddy").setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)
idk if this works i dont use packer, claude cooked this up.

```lua
use {
  "jarenm1/nvim-buddy",
  requires = { "nvim-lua/plenary.nvim" },
  config = function()
    require("nvim-buddy").setup()
  end
}
```

## Configuration

You can customize the plugin by passing options to the setup function:

```lua
require("nvim-buddy").setup({
  keymaps = {
    show_input = "<leader>q", -- Set to keymap you want to use
  },
  input_window = {
    width = 50,
    height = 10,
    border = "rounded", -- Border style: 'none', 'single', 'double', 'rounded'
    ascii_art = [[
 /\_/\  
( o.o ) 
 ]],
    greeting = "What can I help you with?",
    colors = {
      art = "String", -- Art color
      greeting = "Title", -- Greeting color: Title (usually bold)
      divider = "NonText", -- Divider color
    },
  },
  backend = {
    provider = "gemini",                  -- Provider: "openai" or "gemini"
    openai = {
      api_key = nil,                      -- Your OpenAI API key
      model = "gpt-3.5-turbo",            -- Default model
      endpoint = "https://api.openai.com/v1/chat/completions", -- OpenAI endpoint
      max_tokens = 1000,                  -- Maximum token limit
    },
    gemini = {
      api_key = nil,                      -- Your Gemini API key
      model = "gemini-pro",               -- Default Gemini model
      endpoint = "https://generativelanguage.googleapis.com/v1beta/models/", -- Gemini endpoint
      max_output_tokens = 1000,           -- Maximum token limit
    },
    timeout = 30000,                      -- Request timeout in milliseconds
    streaming = true,                     -- Enable streaming responses
  },
})
```

### API Key Configuration

You can configure nvim-buddy to work with either OpenAI or Gemini APIs:

#### OpenAI API
1. Add it to your setup configuration: `backend.openai.api_key = "your-openai-api-key"`
2. Set the `OPENAI_API_KEY` environment variable in your system

#### Gemini API
1. Add it to your setup configuration: `backend.gemini.api_key = "your-gemini-api-key"`
2. Set the `GEMINI_API_KEY` environment variable in your system

Never commit your API keys to public repositories.

### LLM Provider Configuration

The plugin supports two LLM providers:

You can switch providers at runtime using the `backend.set_provider()` function:

```lua
-- Switch to Gemini
require("nvim-buddy.backend").set_provider("gemini")

-- Switch to OpenAI
require("nvim-buddy.backend").set_provider("openai")
```

## Art Colors
Art colors are the colors used for the ASCII art in the input window. Will change colors based on your theme.
- `String`
- `Comment`
- `Special`
- `WarningMsg`
- `Error` (usually highlighted)
- `Todo`
- `Function`
- `Type`
- `Identifier`
- `Title` (usually bold)

## ASCII Art!

You can add your own ASCII art by setting the `ascii_art` option in the configuration.

There may be plans to add some sort of 'active' ascii art that changes based on the context.

### Examples

kitty
```text
 /\_/\  
( o.o )
```
dumb kitty
```text
 /\_/\  
(o . o)
```
bunny
```text
(\_/)
(o.o)
```
cute bunny
```text
(\_/)  
(>.>)
```
 sleepy bunny
```text
(\_/)  
(-.-)
```
 bunny with carrot :O
```text
(\_/)  
(o.o)^
```
## Development

### Local Development with lazy.nvim

For local development with lazy.nvim, you can use the `dir` option to specify the local path and enable `dev` mode:

```lua
{
  "jarenm1/nvim-buddy",
  dir = "~/projects/nvim-buddy", -- Adjust path to your local directory
  dev = true,                    -- Enable dev mode
  config = function()
    require("nvim-buddy").setup({
      -- Your configuration
    })
  end,
}
```

## License

MIT
