local M = {}

-- Force Neo-tree to re-run `git status` and redraw all sources (filesystem
-- tree, the git_status float, and the buffers view).
--
-- Why not *just* fire GIT_EVENT (the maintainer-recommended trigger)? Firing
-- GIT_EVENT alone routes through manager.refresh, which only re-runs
-- `git status` for windows that are currently visible on the current tab --
-- otherwise it just marks them dirty. That is why writing a file (which goes
-- through FS_EVENT and calls git.status_async directly) reliably updates the
-- indicators, but a commit made from LazyGit sometimes does not.
--
-- So we do what the file-write path does: explicitly kick git.status_async for
-- every tracked worktree, then fire GIT_EVENT so every source redraws.
-- See https://github.com/nvim-neo-tree/neo-tree.nvim/discussions/1253
function M.refresh_git()
  -- Defer to the next tick so any in-flight git writes (e.g. a LazyGit commit)
  -- have fully settled before we read `git status`.
  vim.schedule(function()
    local ok_git, git = pcall(require, "neo-tree.git")
    if ok_git then
      local cfg = require("neo-tree").ensure_config()
      local roots = {}
      for root in pairs(git.worktrees or {}) do
        roots[root] = true
      end
      -- Fallback: if nothing is registered yet, force a scan of the cwd.
      if next(roots) == nil then
        roots[(vim.uv or vim.loop).cwd()] = true
      end
      for root in pairs(roots) do
        pcall(git.status_async, root, nil, cfg.git_status_async_options)
      end
    end

    local ok_ev, events = pcall(require, "neo-tree.events")
    if ok_ev then
      events.fire_event(events.GIT_EVENT)
    end
  end)
end

return M
