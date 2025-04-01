# nvim-buddy

A simple Neovim plugin that provides helpful floating windows.

## Features

- Show a help floating window with `<leader>q` (default)
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
      --   show_help = "<leader>h", -- Change default keymap
      -- },
      -- floating_window = {
      --   width = 40,              -- Customize window width
      --   height = 3,              -- Customize window height
      --   border = "rounded",      -- Border style: 'none', 'single', 'double', 'rounded'
      -- }
    })
  end,
}
```

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
    show_help = "<leader>q", -- Set to false to disable the keymap
  },
  floating_window = {
    width = 30,
    height = 2,
    border = "single", -- Border style: 'none', 'single', 'double', 'rounded'
  },
})
```

## License

MIT
