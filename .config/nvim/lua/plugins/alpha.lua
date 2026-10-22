return {
  "goolord/alpha-nvim",
  event = "VimEnter",

  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.startify")

    -- Header color follows the active theme picker (was hardcoded to
    -- Catppuccin Frappé's mauve regardless of the selected theme).
    local header_colors = {
      catppuccin = { frappe = "#ca9ee6", macchiato = "#c6a0f6", mocha = "#cba6f7" },
      gruvbox = { dark = "#d3869b" },
      dracula = { dark = "#bd93f9" },
    }
    local family, variant = require("theme_state").read()
    local header_color = (header_colors[family] or {})[variant] or "#cba6f7"

    vim.api.nvim_set_hl(0, "AlphaHeader", { fg = header_color })
    dashboard.section.header.opts = { hl = "AlphaHeader", position = "center" }

    dashboard.section.header.val = {
      [[                                                                       ]],
      [[                                                                       ]],
      [[                                                                       ]],
      [[                                                                       ]],
      [[                                                                     ]],
      [[       ████ ██████           █████      ██                     ]],
      [[      ███████████             █████                             ]],
      [[      █████████ ███████████████████ ███   ███████████   ]],
      [[     █████████  ███    █████████████ █████ ██████████████   ]],
      [[    █████████ ██████████ █████████ █████ █████ ████ █████   ]],
      [[  ███████████ ███    ███ █████████ █████ █████ ████ █████  ]],
      [[ ██████  █████████████████████ ████ █████ █████ ████ ██████ ]],
      [[                                                                       ]],
      [[                                                                       ]],
      [[                                                                       ]],
    }

    -- Startify's top buttons are just "New file". Add a session entry so the
    -- dashboard is also the way back into the last session for this directory
    -- -- otherwise <leader>qs is the only entry point and the dashboard is the
    -- screen you are actually looking at when you'd want it.
    dashboard.section.top_buttons.val = {
      dashboard.button("e", "  New file", "<cmd>ene<CR>"),
      dashboard.button("s", "  Restore session", "<cmd>lua require('persistence').load()<CR>"),
    }

    alpha.setup(dashboard.opts)
  end,
}