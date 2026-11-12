return {
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        event = "VeryLazy",
        config = function()
            require('lualine').setup({
                options = {
                    theme = "auto",
                },
                sections = {
                    lualine_b = {
                        'branch',
                        'diff',
                        {
                            'diagnostics',
                            sources = { function()
                                local count = vim.diagnostic.count(0)
                                return {
                                    error = count[vim.diagnostic.severity.ERROR] or 0,
                                    warn = vim.g.warnings_enabled and (count[vim.diagnostic.severity.WARN] or 0) or 0,
                                    info = vim.g.warnings_enabled and (count[vim.diagnostic.severity.INFO] or 0) or 0,
                                    hint = vim.g.warnings_enabled and (count[vim.diagnostic.severity.HINT] or 0) or 0,
                                }
                            end },
                        },
                    },
                },
            })
        end
    }
}