return {
    {
        "folke/flash.nvim",
        event = "VeryLazy",
        opts = {},
        -- `S` is limited to normal/operator modes so it does not clash with
        -- nvim-surround's visual-mode `S` mapping.
        keys = {
            { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end,       desc = "Flash jump" },
            { "S", mode = { "n", "o" },      function() require("flash").treesitter() end, desc = "Flash Treesitter" },
        },
    }
}
