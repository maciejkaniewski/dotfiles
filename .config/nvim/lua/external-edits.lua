-- Protects against losing edits that another process (Claude Code, a formatter,
-- `git checkout`) makes to a file that is already open in a buffer.
--
-- Neovim's own guards are not enough here: 'autoread' only compares timestamps
-- when it happens to regain focus, it refuses to reload a buffer with unsaved
-- changes, and auto-save.nvim writes with `silent! write`, which swallows the
-- "file has changed since reading it" warning. So a stale buffer can overwrite
-- someone else's work without a single message. Two halves fix that:
--
--   1. check the disk aggressively, so a buffer never sits on stale content
--   2. expose `stale()` so a writer can refuse to clobber a changed file
--      (wired into the auto-save condition in lua/plugins/autosave.lua)
--
-- The third half lives outside nvim: a Claude Code PostToolUse hook
-- (~/.claude/nvim-checktime.sh) pokes `:checktime` over RPC the moment Claude
-- writes a file, so a reload does not wait on a focus event.

local M = {}

local group = vim.api.nvim_create_augroup("external-edits", { clear = true })

-- Records the mtime the buffer is currently in sync with. Anything newer on
-- disk was written by somebody else.
local function stamp(buf)
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= "" then
        vim.b[buf].disk_mtime = vim.fn.getftime(name)
    end
end

--- True when the file on disk is newer than the content this buffer last agreed
--- with, i.e. another process wrote it behind our back.
--- @param buf number?
--- @return boolean
function M.stale(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].buftype ~= "" then
        return false
    end
    local known = vim.b[buf].disk_mtime
    if known == nil then
        return false
    end
    local name = vim.api.nvim_buf_get_name(buf)
    local on_disk = name ~= "" and vim.fn.getftime(name) or -1
    return on_disk > 0 and on_disk > known
end

-- After a read or our own write, buffer and file agree by definition.
vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
    group = group,
    callback = function(ev) stamp(ev.buf) end,
})

-- Deliberately no FileChangedShell autocmd: defining one replaces the built-in
-- handling and would disable autoread. FileChangedShellPost only observes.
vim.api.nvim_create_autocmd("FileChangedShellPost", {
    group = group,
    callback = function(ev)
        local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ev.buf), ":~:.")
        if vim.bo[ev.buf].modified then
            -- Conflict: the file changed *and* this buffer has unsaved edits, so
            -- nvim could not reload it. Leave the old stamp in place — that is
            -- what keeps stale() true and keeps auto-save from clobbering.
            vim.notify(
                name .. " changed on disk but has unsaved edits — nothing overwritten yet\n"
                    .. "<leader>bd to diff, <leader>br to take the disk version",
                vim.log.levels.ERROR
            )
        else
            stamp(ev.buf)
            vim.notify("reloaded " .. name .. " (changed on disk)", vim.log.levels.WARN)
        end
    end,
})

-- `checktime` is what actually makes autoread fire. Poll it on every plausible
-- moment of attention rather than waiting for a focus event the terminal may
-- never deliver. CursorHold rides on updatetime = 250ms (see vim-options.lua).
vim.api.nvim_create_autocmd({
    "FocusGained", "BufEnter", "CursorHold", "CursorHoldI", "TermLeave", "VimResume",
}, {
    group = group,
    callback = function()
        -- checktime throws inside the command-line window and while a prompt is up
        if vim.fn.getcmdwintype() ~= "" or vim.fn.mode() == "c" then
            return
        end
        vim.cmd("silent! checktime")
    end,
})

-- Manual escape hatches for the conflict case, where picking a winner has to be
-- a decision rather than a reflex.
vim.keymap.set("n", "<leader>br", "<cmd>edit!<CR>", { desc = "Reload file from disk (discard buffer)" })
vim.keymap.set("n", "<leader>bd", function()
    vim.cmd("diffthis")
    vim.cmd("vertical new | set buftype=nofile bufhidden=wipe")
    vim.cmd("read #")
    vim.cmd("0delete _")
    vim.bo.modifiable = false
    vim.cmd("diffthis")
end, { desc = "Diff buffer against file on disk" })

return M
