return {
    {
        "folke/persistence.nvim",
        -- BufReadPre, not VeryLazy: the session has to be recordable before the
        -- first real buffer settles, but loading it any earlier would race the
        -- alpha dashboard.
        event = "BufReadPre",
        keys = {
            -- Under <leader>q rather than <leader>w: a session is written on
            -- quit, and <leader>w is already the LSP workspace prefix
            -- (<leader>ws = workspace symbols, set buffer-locally on LspAttach).
            {
                "<leader>qs",
                function() require("persistence").load() end,
                desc = "Restore session for this directory",
            },
            {
                "<leader>ql",
                function() require("persistence").load({ last = true }) end,
                desc = "Restore last session (any directory)",
            },
            {
                "<leader>qd",
                function() require("persistence").stop() end,
                desc = "Don't save this session on exit",
            },
        },
        opts = {
            -- One session per cwd, so switching between firmware repos restores
            -- that repo's buffers rather than a single global pile.
            --
            -- `options` is what gets persisted. The default set includes
            -- "options", which round-trips global/local option values and will
            -- happily restore a stale 'shiftwidth' or 'foldmethod' over what
            -- vim-options.lua and nvim-ufo just set up. Dropping it keeps the
            -- session to what it is actually wanted for: which files were open,
            -- in which windows and tabs.
            options = { "buffers", "curdir", "tabpages", "winsize", "help" },
            -- Neo-tree, aerial and trouble panels restore as empty, broken
            -- windows because their content is generated, not read from disk.
            -- Close them before the session is written.
            pre_save = function()
                for _, win in ipairs(vim.api.nvim_list_wins()) do
                    local buf = vim.api.nvim_win_get_buf(win)
                    local ft = vim.bo[buf].filetype
                    if ft == "neo-tree" or ft == "aerial" or ft == "trouble" or ft == "alpha" then
                        pcall(vim.api.nvim_win_close, win, true)
                    end
                end
            end,
        },
    },
}
