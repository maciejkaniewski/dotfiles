-- Languages to keep parsers + queries installed for.
--
-- Beyond the obvious editing languages, the firmware-specific ones earn their
-- place: `cmake`/`make`/`ninja` for the build system, `linkerscript` for the
-- .ld files, `doxygen` for the comment blocks injected into C/C++, and
-- `gitcommit`/`git_rebase` because .gitconfig sets core.editor = nvim with
-- commit.verbose = true -- every commit message (and the diff below it, via the
-- `diff` parser) is written in this editor.
local LANGUAGES = {
    "lua", "c", "cpp", "python", "rust",
    "vim", "vimdoc", "query", "bash",
    "markdown", "markdown_inline",
    "json", "yaml", "toml", "regex", "diff",
    "cmake", "make", "ninja", "linkerscript", "doxygen",
    "gitcommit", "git_rebase",
}

return {
    {
        "nvim-treesitter/nvim-treesitter",
        -- `main`, not `master`. master is frozen: its last commit (2026-03-23)
        -- capped support at Neovim 0.11, because 0.12 removed the `all` option
        -- to Query:iter_matches() that master's query directives still rely on.
        -- On 0.12+ that makes every markdown buffer throw
        -- "attempt to call method 'range' (a nil value)".
        --
        -- main requires Neovim 0.12+ and tree-sitter-cli >= 0.26.1 (install.sh
        -- installs both). It is a different plugin API, not a version bump --
        -- `nvim-treesitter.configs` does not exist here.
        branch = "main",
        -- Upstream: "This plugin does not support lazy-loading."
        lazy = false,
        build = ":TSUpdate",
        config = function()
            -- install() is a no-op for parsers already present, but it still
            -- walks the whole list on every startup. Diff against what is
            -- actually installed so a normal launch does no work at all.
            local installed = {}
            for _, lang in ipairs(require("nvim-treesitter.config").get_installed("parsers")) do
                installed[lang] = true
            end
            local missing = vim.tbl_filter(function(lang)
                return not installed[lang]
            end, LANGUAGES)
            if #missing > 0 then
                require("nvim-treesitter").install(missing)
            end

            -- On `master` these came from configs.setup({ highlight, indent }).
            -- `main` ships queries only and leaves activation to the user, so
            -- highlighting and indentation have to be turned on per buffer.
            vim.api.nvim_create_autocmd("FileType", {
                group = vim.api.nvim_create_augroup("treesitter-activate", { clear = true }),
                callback = function(ev)
                    local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
                    if not lang then
                        return
                    end
                    -- pcall: a filetype whose parser is not installed (or is
                    -- still downloading on first launch) must not raise on
                    -- every buffer open.
                    if not pcall(vim.treesitter.start, ev.buf, lang) then
                        return
                    end
                    vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                end,
            })
        end
    },
    {
        "nvim-treesitter/nvim-treesitter-textobjects",
        branch = "main",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            require("nvim-treesitter-textobjects").setup({
                select = { lookahead = true },
                move   = { set_jumps = true },
            })

            local select = require("nvim-treesitter-textobjects.select")
            local move   = require("nvim-treesitter-textobjects.move")

            local function s(capture)
                return function() select.select_textobject(capture, "textobjects") end
            end
            local function gns(capture)
                return function() move.goto_next_start(capture, "textobjects") end
            end
            local function gps(capture)
                return function() move.goto_previous_start(capture, "textobjects") end
            end

            -- Select
            vim.keymap.set({ "x", "o" }, "af", s("@function.outer"),    { desc = "Around function" })
            vim.keymap.set({ "x", "o" }, "if", s("@function.inner"),    { desc = "Inside function" })
            vim.keymap.set({ "x", "o" }, "ac", s("@class.outer"),       { desc = "Around class/struct/enum" })
            vim.keymap.set({ "x", "o" }, "ic", s("@class.inner"),       { desc = "Inside class/struct/enum" })
            vim.keymap.set({ "x", "o" }, "aa", s("@parameter.outer"),   { desc = "Around parameter/arg" })
            vim.keymap.set({ "x", "o" }, "ia", s("@parameter.inner"),   { desc = "Inside parameter/arg" })
            vim.keymap.set({ "x", "o" }, "al", s("@loop.outer"),        { desc = "Around loop" })
            vim.keymap.set({ "x", "o" }, "il", s("@loop.inner"),        { desc = "Inside loop body" })
            vim.keymap.set({ "x", "o" }, "a?", s("@conditional.outer"), { desc = "Around conditional" })
            vim.keymap.set({ "x", "o" }, "i?", s("@conditional.inner"), { desc = "Inside conditional body" })
            vim.keymap.set({ "x", "o" }, "am", s("@call.outer"),        { desc = "Around call" })
            vim.keymap.set({ "x", "o" }, "im", s("@call.inner"),        { desc = "Inside call args" })
            vim.keymap.set({ "x", "o" }, "ar", s("@return.outer"),      { desc = "Around return" })
            vim.keymap.set({ "x", "o" }, "ir", s("@return.inner"),      { desc = "Inside return value" })
            vim.keymap.set({ "x", "o" }, "in", s("@number.inner"),      { desc = "Inside number literal" })
            vim.keymap.set({ "x", "o" }, "a=", s("@assignment.outer"),  { desc = "Around assignment" })
            vim.keymap.set({ "x", "o" }, "i=", s("@assignment.inner"),  { desc = "Inside assignment" })
            vim.keymap.set({ "x", "o" }, "aS", s("@shift.outer"),       { desc = "Around bitshift expression" })
            vim.keymap.set({ "x", "o" }, "iS", s("@shift.inner"),       { desc = "Inside bitshift value" })

            -- Move
            vim.keymap.set({ "n", "x", "o" }, "]f", gns("@function.outer"),    { desc = "Next function start" })
            vim.keymap.set({ "n", "x", "o" }, "[f", gps("@function.outer"),    { desc = "Prev function start" })
            vim.keymap.set({ "n", "x", "o" }, "]C", gns("@class.outer"),       { desc = "Next struct/class start" })
            vim.keymap.set({ "n", "x", "o" }, "[C", gps("@class.outer"),       { desc = "Prev struct/class start" })
            vim.keymap.set({ "n", "x", "o" }, "]l", gns("@loop.outer"),        { desc = "Next loop" })
            vim.keymap.set({ "n", "x", "o" }, "[l", gps("@loop.outer"),        { desc = "Prev loop" })
            vim.keymap.set({ "n", "x", "o" }, "]?", gns("@conditional.outer"), { desc = "Next conditional" })
            vim.keymap.set({ "n", "x", "o" }, "[?", gps("@conditional.outer"), { desc = "Prev conditional" })
            vim.keymap.set({ "n", "x", "o" }, "]S", gns("@shift.outer"),       { desc = "Next bitshift" })
            vim.keymap.set({ "n", "x", "o" }, "[S", gps("@shift.outer"),       { desc = "Prev bitshift" })
        end,
    }
}
