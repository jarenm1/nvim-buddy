local M = {}

function M.show_help()
    -- Create a buffer
    local buf = vim.api.nvim_create_buf(false, true)
    -- Set some text
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"This is a helpful message.", "Press <esc> to close."})
    -- Configure the floating window
    local opts = {
        relative = 'cursor',  -- Position near the cursor
        width = 30,
        height = 2,
        row = 1,              -- 1 row below cursor
        col = 0,
        style = 'minimal',
        border = 'single',    -- Add a border
    }
    -- Open the window
    local win = vim.api.nvim_open_win(buf, true, opts)
    -- Add a keymap to close it with <esc>
    vim.api.nvim_buf_set_keymap(buf, 'n', '<esc>', '<cmd>lua vim.api.nvim_win_close('..win..', true)<cr>', {noremap = true, silent = true})
end

-- Set a keybinding
vim.api.nvim_set_keymap('n', '<leader>q', '<cmd>lua require("nvim-buddy").show_help()<cr>', {noremap = true, silent = true})

return M