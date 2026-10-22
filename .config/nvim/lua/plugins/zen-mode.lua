-- Centered, distraction-free buffer. Bound to <leader>uz to match Zed's
-- "space u z" -> workspace::ToggleCenteredLayout (see .config/zed/keymap.json).
return {
    {
        "folke/zen-mode.nvim",
        cmd = "ZenMode",
        keys = {
            { "<leader>uz", "<cmd>ZenMode<CR>", desc = "Toggle zen / centered layout" },
        },
        opts = {
            window = {
                width = 100,       -- absolute column count, not a fraction of the window
                options = {
                    number = false,
                    relativenumber = false,
                    signcolumn = "no",
                    cursorline = false,
                },
            },
            plugins = {
                options = {
                    laststatus = 0,  -- hide lualine
                },
                gitsigns = { enabled = false },
            },
        },
    }
}
