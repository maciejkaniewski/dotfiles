return {
    {
        "kdheepak/lazygit.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        cmd = { "LazyGit", "LazyGitConfig", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
        keys = {
            { "<leader>lg", "<cmd>LazyGit<CR>", desc = "LazyGit" },
        },
        init = function()
            -- LazyGit runs in a terminal job inside Neovim, so committing/pushing
            -- there fires none of FocusGained/ShellCmdPost/VimResume. Use LazyGit's
            -- own exit hook to refresh Neo-tree's git indicators once it closes.
            vim.g.lazygit_on_exit_callback = function()
                require("utils.neotree").refresh_git()
            end
        end,
    }
}
