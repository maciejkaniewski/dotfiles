local read_theme = require("theme_state").read

-- catppuccin/nvim ships explicit flash.nvim + notify integrations
-- (auto_integrations = true); the other colorscheme plugins here don't, so
-- FlashLabel/FlashMatch/FlashCurrent/FlashBackdrop fall back to Neovim's
-- generic Substitute/Search/IncSearch highlights (low-contrast, hard to read
-- for jump labels) and NotifyBackground resolves to nil (nvim-notify then
-- hardcodes black with a startup warning). Mirror catppuccin's own flash
-- style (bold, colored foreground, no background) and give Notify a solid,
-- slightly-recessed background, using each theme's own palette.
local function fix_flash_and_notify(colors)
  vim.api.nvim_set_hl(0, "FlashBackdrop", { fg = colors.backdrop })
  vim.api.nvim_set_hl(0, "FlashLabel", { fg = colors.label, bold = true })
  vim.api.nvim_set_hl(0, "FlashMatch", { fg = colors.match })
  vim.api.nvim_set_hl(0, "FlashCurrent", { fg = colors.current })
  vim.api.nvim_set_hl(0, "FlashPrompt", { link = "NormalFloat" })
  vim.api.nvim_set_hl(0, "NotifyBackground", { bg = colors.notify_bg })
end

return {
  {
    "catppuccin/nvim",
    lazy = false,
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        auto_integrations = true,
        transparent_background = true,
      })

      local family, variant = read_theme()
      if family == "catppuccin" then
        vim.cmd.colorscheme("catppuccin-" .. variant)
      end
    end
  },
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("gruvbox").setup({
        transparent_mode = true,
      })

      local family = read_theme()
      if family == "gruvbox" then
        vim.o.background = "dark"
        vim.cmd.colorscheme("gruvbox")

        fix_flash_and_notify({
          backdrop = "#928374",
          label = "#b8bb26",
          match = "#d3869b",
          current = "#fe8019",
          notify_bg = "#1d2021",
        })
      end
    end
  },
  {
    "Mofiqul/dracula.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("dracula").setup({
        transparent_bg = true,
      })

      local family = read_theme()
      if family == "dracula" then
        vim.cmd.colorscheme("dracula")

        -- dracula.nvim's supported-plugins list has neither flash.nvim nor
        -- notify/noice either — same gap as gruvbox.nvim above.
        fix_flash_and_notify({
          backdrop = "#6272a4",
          label = "#50fa7b",
          match = "#ff79c6",
          current = "#ffb86c",
          notify_bg = "#21222c",
        })

        -- dracula.nvim also never defines WinBar/WinBarNC (used by
        -- dropbar.nvim's breadcrumb), so it falls back to Neovim's built-in
        -- default — a near-black bg that clashes with the transparent
        -- editor. catppuccin sets WinBar with no bg (blends with the
        -- transparent background); mirror that here.
        vim.api.nvim_set_hl(0, "WinBar", { fg = "#f8f8f2" })
        vim.api.nvim_set_hl(0, "WinBarNC", { fg = "#6272a4" })
      end
    end
  }
}
