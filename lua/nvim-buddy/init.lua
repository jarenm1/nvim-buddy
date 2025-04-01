local M = {}

-- Default configuration
M.config = {
  keymaps = {
    show_help = "<leader>q",
  },
  floating_window = {
    width = 30,
    height = 2,
    border = 'single',
  },
}

function M.show_help()
    -- Create a buffer
    local buf = vim.api.nvim_create_buf(false, true)
    -- Set some text
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"This is a helpful message.", "Press <esc> to close."})
    -- Configure the floating window
    local opts = {
        relative = 'cursor',  -- Position near the cursor
        width = M.config.floating_window.width,
        height = M.config.floating_window.height,
        row = 1,              -- 1 row below cursor
        col = 0,
        style = 'minimal',
        border = M.config.floating_window.border,
    }
    -- Open the window
    local win = vim.api.nvim_open_win(buf, true, opts)
    -- Add a keymap to close it with <esc>
    vim.api.nvim_buf_set_keymap(buf, 'n', '<esc>', '<cmd>lua vim.api.nvim_win_close('..win..', true)<cr>', {noremap = true, silent = true})
end

-- Setup function that lazy.nvim will call
function M.setup(opts)
    -- Merge user config with defaults
    if opts then
        M.config = vim.tbl_deep_extend("force", M.config, opts)
    end

    -- Set a keybinding if enabled
    if M.config.keymaps.show_help then
        vim.keymap.set('n', M.config.keymaps.show_help, function() require("nvim-buddy").show_help() end, {noremap = true, silent = true})
    end
end

return M