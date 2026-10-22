return {
    {
        "folke/todo-comments.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        event = { "BufReadPost", "BufNewFile" },
        cmd = { "TodoTelescope", "TodoQuickFix", "TodoLocList" },
        config = function()
            require("todo-comments").setup()

            vim.keymap.set("n", "]T", function() require("todo-comments").jump_next() end, { desc = "Next TODO" })
            vim.keymap.set("n", "[T", function() require("todo-comments").jump_prev() end, { desc = "Previous TODO" })
            vim.keymap.set("n", "<leader>ft", ":TodoTelescope<CR>", { desc = "Find TODOs" })
        end
    }
}
