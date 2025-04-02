-- Minimal lazy.nvim configuration for local development of nvim-buddy
-- Save this to your Neovim config directory

return {
  {
    "nvim-buddy",
    dir = "c:/Users/yourc/projects/nvim-buddy", -- Absolute Windows path to your plugin
    dev = true, -- Enable dev mode for auto-reloading on changes
    lazy = false, -- This ensures the plugin loads immediately at startup
    priority = 1000, -- High priority to load early
    config = function()
      require("nvim-buddy").setup()
    end,
  },
}

-- For minimal configuration with just a keymap override:
--[[
return {
  {
    "nvim-buddy",
    dir = "c:/Users/yourc/projects/nvim-buddy",
    dev = true,
    lazy = false, -- Load immediately
    priority = 1000,
    config = function()
      require("nvim-buddy").setup({
        keymaps = {
          show_input = "<leader>q", -- Just override the keymap
        },
      })
    end,
  },
}
--]]
