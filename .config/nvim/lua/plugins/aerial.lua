return {
    {
        "stevearc/aerial.nvim",
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "nvim-tree/nvim-web-devicons",
        },
        cmd = { "AerialToggle", "AerialNavToggle" },
        keys = {
            { "<leader>o", "<cmd>AerialToggle<cr>", desc = "Toggle symbol outline (Aerial)" },
        },
        opts = {
            backends = { "lsp", "treesitter", "markdown" },
        },
    }
}
