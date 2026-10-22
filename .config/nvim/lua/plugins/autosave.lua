return {
    {
        "okuuva/auto-save.nvim",
        event = { "InsertLeave", "TextChanged" },
        config = function()
            local external = require("external-edits")

            require("auto-save").setup({
                enabled = true,
                debounce_delay = 1000,
                trigger_events = {
                    immediate_save = { "BufLeave", "FocusLost" },
                    defer_save = { "TextChanged" },
                    cancel_deferred_save = { "InsertEnter" },
                },
                -- auto-save writes with `silent! write`, which suppresses the
                -- "file has changed since reading it" warning — so without this
                -- a stale buffer silently overwrites whatever another process
                -- (Claude Code, a formatter) wrote to the file meanwhile.
                condition = function(buf)
                    if external.stale(buf) then
                        local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":~:.")
                        vim.notify(
                            "auto-save skipped: " .. name .. " changed on disk\n"
                                .. "<leader>bd to diff, <leader>br to reload from disk",
                            vim.log.levels.WARN
                        )
                        return false
                    end
                    return true
                end
            })
        end
    }
}
