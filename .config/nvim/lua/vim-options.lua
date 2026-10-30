vim.g.mapleader = " "
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

-- Indentation
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4

-- UI
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.scrolloff = 8
vim.opt.wrap = false

-- Behaviour
vim.opt.modeline = false
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.updatetime = 250       -- faster CursorHold events (default 4000ms)
vim.opt.timeoutlen = 300       -- faster which-key popup
vim.opt.redrawtime = 1500      -- stop syntax highlight on very long lines
vim.opt.synmaxcol = 240        -- don't highlight beyond column 240
vim.opt.lazyredraw = false     -- do not use lazyredraw (breaks noice)
vim.keymap.set("n", "<Esc>", function()
    vim.cmd("nohlsearch")
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        -- Closing one float can take its companions with it (treesitter-context,
        -- noice and dropbar pair windows), so later ids in the list may be gone.
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= "" then
            vim.api.nvim_win_close(win, false)
        end
    end
end, { desc = "Clear search highlight and close floating windows" })

-- Quit all
vim.keymap.set("n", "<leader>qq", ":qa<CR>", { desc = "Quit all" })
vim.keymap.set("n", "<leader>qQ", ":qa!<CR>", { desc = "Force quit all" })

-- Tabs
vim.keymap.set("n", "<leader>tn", ":tabnew<CR>", { desc = "New tab" })
vim.keymap.set("n", "<leader>tc", ":tabclose<CR>", { desc = "Close tab" })
vim.keymap.set("n", "[t", ":tabprev<CR>", { desc = "Previous tab" })
vim.keymap.set("n", "]t", ":tabnext<CR>", { desc = "Next tab" })