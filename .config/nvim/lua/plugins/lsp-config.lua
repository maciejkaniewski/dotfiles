return {
    {
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup()
        end
    },
    {
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        dependencies = { "williamboman/mason.nvim" },
        config = function()
            require("mason-tool-installer").setup({
                -- Only what install.sh doesn't provide. clangd, ruff,
                -- basedpyright and stylua come from install.sh on PATH: Mason
                -- puts its bin dir first on nvim's PATH, so a Mason copy of any
                -- of them would beat the one Zed and the CLI use, and nvim
                -- would ignore the --llvm pin and run different versions.
                -- install.sh removes older Mason copies.
                ensure_installed = { "lua-language-server" },
            })
        end
    },
    {
        "neovim/nvim-lspconfig",
        dependencies = { "saghen/blink.cmp" },
        config = function()
            -- blink.cmp replaced cmp-nvim-lsp here. get_lsp_capabilities()
            -- already folds in Neovim's own make_client_capabilities(), so this
            -- is the whole set rather than an overlay on it.
            local capabilities = require("blink.cmp").get_lsp_capabilities()
            -- nvim-ufo: advertise line-based folding range support
            capabilities.textDocument.foldingRange = {
                dynamicRegistration = false,
                lineFoldingOnly = true,
            }
            vim.lsp.config("*", { capabilities = capabilities })

            vim.lsp.config("basedpyright", {
                settings = {
                    basedpyright = {
                        analysis = {
                            typeCheckingMode = "standard",
                        },
                    },
                },
            })

            -- ruff handles linting/formatting; let basedpyright own hover to avoid duplicates.
            vim.lsp.config("ruff", {
                on_attach = function(client)
                    client.server_capabilities.hoverProvider = false
                end,
            })

            -- clangd: run clang-tidy inline, index in the background, richer completion.
            vim.lsp.config("clangd", {
                cmd = {
                    "clangd",
                    "--clang-tidy",
                    "--background-index",
                    "--completion-style=detailed",
                    "--header-insertion=iwyu",
                    -- Allow clangd to run the ARM cross-compiler to extract its
                    -- built-in system headers (newlib). Off-snap, so it survives
                    -- VS Code updates. Glob covers gcc/g++/ar/etc.
                    "--query-driver=/opt/arm-gcc/bin/arm-none-eabi-*",
                },
            })

            vim.lsp.enable({ "lua_ls", "clangd", "basedpyright", "ruff" })

            vim.g.warnings_enabled = true
            vim.diagnostic.config({
                signs = true,
                virtual_text = true,
                underline = true,
            })

            vim.keymap.set("n", "<leader>uw", function()
                vim.g.warnings_enabled = not vim.g.warnings_enabled
                if vim.g.warnings_enabled then
                    vim.diagnostic.config({
                        signs = true,
                        virtual_text = true,
                        underline = true,
                    })
                else
                    local errors_only = { severity = { min = vim.diagnostic.severity.ERROR } }
                    vim.diagnostic.config({
                        signs = errors_only,
                        virtual_text = errors_only,
                        underline = errors_only,
                    })
                end
                require("lualine").refresh()
                vim.api.nvim_exec_autocmds("DiagnosticChanged", { modeline = false })
            end, { desc = "Toggle Warnings" })

            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(event)
                    local client = vim.lsp.get_client_by_id(event.data.client_id)
                    local map = function(keys, func, desc, opts)
                        opts = vim.tbl_extend("force", { buffer = event.buf, desc = "LSP: " .. desc }, opts or {})
                        vim.keymap.set("n", keys, func, opts)
                    end

                    -- Inlay hints (param names, inferred types) — on by default, toggle with <leader>uh
                    if client and client:supports_method("textDocument/inlayHint") then
                        vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
                        map("<leader>uh", function()
                            vim.lsp.inlay_hint.enable(
                                not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }),
                                { bufnr = event.buf }
                            )
                        end, "Toggle Inlay Hints")
                    end

                    -- clangd: jump between .c/.cpp and its header
                    if client and client.name == "clangd" then
                        map("<leader>ch", function()
                            client:request("textDocument/switchSourceHeader",
                                { uri = vim.uri_from_bufnr(event.buf) },
                                function(err, result)
                                    if err or not result then
                                        vim.notify("No corresponding source/header file", vim.log.levels.WARN)
                                        return
                                    end
                                    vim.cmd.edit(vim.uri_to_fname(result))
                                end, event.buf)
                        end, "Switch Source/Header")
                    end

                    -- K, [d and ]d are not mapped here: Neovim ships them as
                    -- defaults (hover, previous/next diagnostic).
                    map("gd", vim.lsp.buf.definition, "Go to Definition")
                    -- nowait: Neovim's built-in grr/grn/gra/gri/grt/grx all
                    -- start with gr, so without it every gr paused for
                    -- timeoutlen waiting for a third key. Those defaults are
                    -- unreachable in LSP buffers as a result; rename and code
                    -- action live on <leader>rn / <leader>ca below.
                    map("gr", function()
                        require("telescope.builtin").lsp_references(
                            require("telescope.themes").get_cursor({ layout_config = { width = 0.6, height = 0.4 } })
                        )
                    end, "Go to References", { nowait = true })
                    map("<leader>rn", vim.lsp.buf.rename, "Rename")
                    map("<leader>ca", vim.lsp.buf.code_action, "Code Action")
                    map("<leader>d", vim.diagnostic.open_float, "Show Diagnostic")
                    map("<leader>ds", function()
                        require("telescope.builtin").lsp_document_symbols()
                    end, "Document Symbols")
                    map("<leader>ws", function()
                        local supported = vim.tbl_filter(function(client)
                            return client.server_capabilities.workspaceSymbolProvider
                        end, vim.lsp.get_clients({ bufnr = event.buf }))
                        if #supported == 0 then
                            vim.notify("Workspace symbols not supported by any LSP for this buffer", vim.log.levels.WARN)
                            return
                        end
                        require("telescope.builtin").lsp_dynamic_workspace_symbols()
                    end, "Workspace Symbols")
                end,
            })
        end
    }
}
