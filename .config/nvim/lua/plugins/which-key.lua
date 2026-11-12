return {
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            spec = {
                { "<leader>f", group = "find" },
                { "<leader>g", group = "git" },
                { "<leader>h", group = "git hunks" },
                { "<leader>x", group = "trouble / diagnostics" },
                { "<leader>c", group = "code" },
                { "<leader>t", group = "tabs" },
                { "<leader>u", group = "toggles (UI)" },
                { "<leader>q", group = "quit / session" },
                { "<leader>w", group = "workspace" },
                { "<leader>b", group = "buffer / disk" },
                { "<leader>d", group = "diagnostics / symbols" },
                { "<leader>r", group = "rename / refactor" },
                { "]", group = "next" },
                { "[", group = "prev" },
            },
        },
    }
}
