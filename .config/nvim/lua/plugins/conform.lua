return {
    "stevearc/conform.nvim",
    cmd = { "ConformInfo" },
    keys = {
        {
            "<leader>cf",
            function()
                require("conform").format({ async = true })
            end,
            desc = "Format buffer",
        },
    },
    opts = {
        notify_on_error = false,
        formatters_by_ft = {
            c = { "clang_format" },
            cpp = { "clang_format" },
            python = { "ruff_format" },
            lua = { "stylua" },
        },
        format_on_save = false,
    },
}
