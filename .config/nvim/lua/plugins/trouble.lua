return {
    {
        "folke/trouble.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        cmd = "Trouble",
        keys = {
            { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",              desc = "Diagnostics (Trouble)" },
            { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer diagnostics (Trouble)" },
            { "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>",      desc = "Symbols (Trouble)" },
            { "<leader>xq", "<cmd>Trouble qflist toggle<cr>",                   desc = "Quickfix list (Trouble)" },
        },
        -- focus the panel on open so you can navigate immediately;
        -- the symbols keymap below overrides this to stay passive.
        opts = {
            focus = true,
            modes = {
                -- widen the symbols outline so long C/C++ symbol names fit
                symbols = {
                    win = { position = "right", size = 0.4 },
                },
            },
        },
    }
}
