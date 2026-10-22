return {
    {
        "MeanderingProgrammer/render-markdown.nvim",
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "nvim-tree/nvim-web-devicons",
        },
        ft = { "markdown" },
        opts = {},
        keys = {
            {
                "<leader>um",
                "<cmd>RenderMarkdown toggle<cr>",
                desc = "Toggle markdown rendering",
            },
        },
    },
}
