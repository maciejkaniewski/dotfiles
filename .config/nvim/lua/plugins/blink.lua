return {
    {
        -- LuaSnip is kept as the snippet engine (blink drives it through its
        -- `luasnip` preset below) because friendly-snippets is in VS Code
        -- format and LuaSnip is what loads it. blink's own snippet support
        -- would not pick those up.
        "L3MON4D3/LuaSnip",
        dependencies = { "rafamadriz/friendly-snippets" },
        event = "InsertEnter",
        config = function()
            -- friendly-snippets ships the actual content; lazy_load pulls in
            -- each filetype on first use rather than all of them at startup.
            require("luasnip.loaders.from_vscode").lazy_load()
        end,
    },
    {
        "saghen/blink.cmp",
        -- Replaces nvim-cmp and its four source plugins (cmp-nvim-lsp,
        -- cmp-buffer, cmp-path, cmp_luasnip). Matching + sorting run in a
        -- prebuilt Rust binary instead of Lua.
        --
        -- Pinned to the 1.x line on upstream's own advice: "V2 is under active
        -- development with many breaking changes. Consider staying on stable by
        -- using branch = 'v1' or version = '1.*'". A release tag also means the
        -- fuzzy matcher is downloaded prebuilt, so no cargo toolchain is needed.
        version = "1.*",
        event = "InsertEnter",
        dependencies = { "L3MON4D3/LuaSnip" },
        opts = {
            snippets = { preset = "luasnip" },

            sources = {
                default = { "lsp", "snippets", "buffer", "path" },
            },

            -- preset = "none" so nothing is inherited implicitly; these are the
            -- same bindings the previous nvim-cmp setup had, in the same order.
            -- Each list falls through to the next entry when one does not apply,
            -- which is how the old `if cmp.visible() ... elseif jumpable()` chain
            -- is expressed here.
            keymap = {
                preset = "none",
                ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
                ["<C-e>"]     = { "hide", "fallback" },
                ["<CR>"]      = { "accept", "fallback" },
                ["<Tab>"]     = { "select_next", "snippet_forward", "fallback" },
                ["<S-Tab>"]   = { "select_prev", "snippet_backward", "fallback" },
            },

            completion = {
                -- Mirrors nvim-cmp's `confirm({ select = false })`: nothing is
                -- selected until you move to it, so <CR> stays a newline unless
                -- an entry was chosen deliberately.
                list = { selection = { preselect = false, auto_insert = false } },
                documentation = { auto_show = true, auto_show_delay_ms = 200 },
                -- Replaces the nvim-autopairs/cmp `confirm_done` integration:
                -- blink appends the call parens itself. nvim-autopairs is still
                -- installed and still handles ordinary typing.
                accept = { auto_brackets = { enabled = true } },
            },

            -- Completion in the `:` cmdline, which the nvim-cmp setup never had
            -- (noice draws the cmdline, but drawing it is not completing it).
            cmdline = { enabled = true },

            fuzzy = { implementation = "prefer_rust_with_warning" },
        },
    },
}
