# nvim-buddy

A simple Neovim plugin that provides an interactive floating window with ASCII art.

## Features

- Interactive input window with ASCII art using `<leader>b` (default)
- Customizable keymaps and window settings

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourusername/nvim-buddy",
  config = function()
    require("nvim-buddy").setup({
      -- Optional: override default settings
      -- keymaps = {
      --   show_input = "<leader>i", -- Change default keymap
      -- },
      -- input_window = {
      --   width = 60,              -- Customize window width
      --   height = 12,             -- Customize window height
      --   border = "double",       -- Border style: 'none', 'single', 'double', 'rounded'
      --   ascii_art = [[
      --     /\_/\  
      --    ( o.o ) 
      --     > ^ <  
      --   ]],
      --   greeting = "Hello! How can I assist you today?",
      -- }
    })
  end,
}

### Local Development with lazy.nvim

For local development with lazy.nvim, you can use the `dir` option to specify the local path and enable `dev` mode:

```lua
{
  "nvim-buddy",
  dir = "~/projects/nvim-buddy", -- Adjust path to your local directory
  dev = true,                    -- Enable dev mode
  config = function()
    require("nvim-buddy").setup({
      -- Your configuration
    })
  end,
}
```

Add this to your lazy.nvim configuration file (e.g., `~/.config/nvim/lua/plugins.lua`).

For a complete setup, considering adding this to your Neovim configuration:

```lua
-- In your init.lua or similar file
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim with plugins
require("lazy").setup({
  {
    "nvim-buddy",
    dir = vim.fn.expand("~/projects/nvim-buddy"), -- Adjust path to your local directory
    dev = true,
    config = function()
      require("nvim-buddy").setup()
    end,
  },
  -- Your other plugins...
})
```

With this setup, lazy.nvim will:
1. Load your plugin from the local directory
2. Automatically reload the plugin when files change (due to `dev = true`)
3. Apply proper isolation for development

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "yourusername/nvim-buddy",
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
    show_input = "<leader>b", -- Set to false to disable the keymap
  },
  input_window = {
    width = 50,
    height = 10,
    border = "rounded", -- Border style: 'none', 'single', 'double', 'rounded'
    ascii_art = [[
      /\_/\  
     ( o.o ) 
      > ^ <  
    ]],
    greeting = "What can I help you with?",
  },
})
```

## License

MIT
