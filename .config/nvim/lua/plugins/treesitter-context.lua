return {
    {
        "nvim-treesitter/nvim-treesitter-context",
        -- This plugin's own default branch; it has no `main`. It drives
        -- Neovim's built-in treesitter, so it doesn't track nvim-treesitter's.
        branch = "master",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        event = "BufReadPost",
        opts = {},
    }
}
