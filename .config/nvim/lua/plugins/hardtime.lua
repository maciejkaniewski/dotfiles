return {
    {
        "m4xshen/hardtime.nvim",
        dependencies = { "MunifTanjim/nui.nvim" },
        event = "VeryLazy",
        opts = {
            enabled = true,
            -- hardtime disables the arrow keys outright by default (normal and
            -- insert), which also takes away using them to scroll. Each key needs
            -- an empty mode list: opts are merged with vim.tbl_deep_extend, so
            -- `disabled_keys = {}` would merge to nothing and change no defaults.
            -- hjkl stay rate-limited by max_count (3), so the motion training the
            -- plugin exists for is untouched.
            disabled_keys = {
                ["<Up>"] = {},
                ["<Down>"] = {},
                ["<Left>"] = {},
                ["<Right>"] = {},
            },
            -- Default true, which sets mouse = "" and kills wheel / trackpad
            -- scrolling along with it.
            disable_mouse = false,
        },
    }
}
