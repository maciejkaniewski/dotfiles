return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    lazy = true,
    cmd = { "Neotree" },
    keys = {
      { "<leader>e", "<cmd>Neotree toggle position=left<CR>",              desc = "Toggle file explorer (Neo-tree)" },
      { "<leader>gs", "<cmd>Neotree toggle source=git_status position=float<CR>", desc = "Toggle Git status (Neo-tree)" },
      { "<leader>gr", function() require("utils.neotree").refresh_git() end, desc = "Refresh Neo-tree git status" },
    },
    init = function()
      -- Open neo-tree instead of netrw when nvim is called with a directory
      if vim.fn.argc(-1) == 1 then
        local stat = vim.uv.fs_stat(vim.fn.argv(0))
        if stat and stat.type == "directory" then
          require("neo-tree")
        end
      end
    end,
    config = function()
      require("neo-tree").setup({
        components = {
          diagnostics = function(config, node, state)
            local effective_config = vim.tbl_extend("force", config, {
              errors_only = not vim.g.warnings_enabled,
            })
            return require("neo-tree.sources.common.components").diagnostics(effective_config, node, state)
          end,
        },
        filesystem = {
          use_libuv_file_watcher = true,
          follow_current_file = {
            enabled = true,
            leave_dirs_open = true,
          },
          filtered_items = {
            visible = true,
            hide_dotfiles = false,
            hide_gitignored = false,
          },
        },
      })

      -- Refresh git status on the triggers that matter:
      --   FocusGained/ShellCmdPost/VimResume -> commits made in an external
      --     terminal, then returning to Neovim.
      --   TermClose -> commits made in an in-Neovim terminal job (LazyGit uses
      --     one). This fires regardless of the terminal's exit code, so it is
      --     more reliable than LazyGit's own vim.g.lazygit_on_exit_callback
      --     (which is skipped on a non-zero exit).
      vim.api.nvim_create_autocmd({ "FocusGained", "ShellCmdPost", "VimResume", "TermClose" }, {
        callback = function()
          require("utils.neotree").refresh_git()
        end,
      })
    end,
  },
}
