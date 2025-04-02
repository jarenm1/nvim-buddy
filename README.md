# nvim-buddy

A simple Neovim plugin that provides an interactive floating window with ASCII art.

## Features

- Interactive input window with ASCII art using `<leader>b` (default)
- Customizable keymaps and window settings

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "jarenm1/nvim-buddy",
  config = function()
    require("nvim-buddy").setup()
  end,
}

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

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)
idk if this works i dont use packer, claude cooked this up.

```lua
use {
  "jarenm1/nvim-buddy",
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
    greeting = "What can I help you with? :3",
    colors = {
      art = "String", -- Art color
      greeting = "Title", -- Greeting color: Title (usually bold)
      divider = "NonText", -- Divider color
    },
  },
})
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


## License

MIT
