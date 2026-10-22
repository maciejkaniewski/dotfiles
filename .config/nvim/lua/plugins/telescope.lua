return {
  {
    -- master (not the 0.1.x stable branch): 0.1.8 predates Neovim 0.11's LSP
    -- API changes and warns about make_position_params / client.supports_method
    -- on nightly. master passes the client offset_encoding and uses the colon form.
    'nvim-telescope/telescope.nvim', branch = 'master',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-ui-select.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
      },
    },
    cmd = "Telescope",
    keys = {
      { '<C-p>',      function() require('telescope.builtin').find_files() end,             desc = "Find files" },
      { '<leader>fg', function() require('telescope.builtin').live_grep() end,              desc = "Live grep" },
      { '<leader>/',  function() require('telescope.builtin').current_buffer_fuzzy_find() end, desc = "Fuzzy find in buffer" },
      { '<leader>fr', function() require('telescope.builtin').oldfiles() end,               desc = "Recent files" },
      { '<leader>fb', function() require('telescope.builtin').buffers() end,                desc = "Open buffers" },
      -- Straight to a grep for the identifier under the cursor: the common case
      -- when clangd has no answer (macros, linker symbols, Kconfig-style defines).
      { '<leader>fw', function() require('telescope.builtin').grep_string() end,            desc = "Grep word under cursor" },
      { '<leader>fw', function() require('telescope.builtin').grep_string() end,            mode = 'v', desc = "Grep selection" },
      { '<leader>fd', function() require('telescope.builtin').diagnostics() end,            desc = "Diagnostics (all buffers)" },
      { '<leader>fh', function() require('telescope.builtin').help_tags() end,              desc = "Help tags" },
      { '<leader>fk', function() require('telescope.builtin').keymaps() end,                desc = "Keymaps" },
      -- Reopens the last picker with its query and cursor position intact --
      -- the escape hatch for closing a grep one result too early.
      { '<leader>fR', function() require('telescope.builtin').resume() end,                 desc = "Resume last picker" },
    },
    config = function()
      require("telescope").setup({
        defaults = {
          file_ignore_patterns = { "^.git/" },
        },
        pickers = {
          find_files = {
            hidden = true,
          },
        },
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown()
          },
          fzf = {},
        }
      })
      require("telescope").load_extension("ui-select")
      require("telescope").load_extension("fzf")
    end
  },
}
