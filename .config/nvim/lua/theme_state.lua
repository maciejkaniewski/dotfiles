-- Reads the active theme (family + variant) from ~/.config/theme/current,
-- the same state file install.sh's apply_theme()/configure_theme() write.
-- Shared by any plugin config that needs to react to the active theme
-- picker without a full ColorScheme-integration (theme.lua, alpha.lua, ...).
local M = {}

function M.read()
  local family, variant = "catppuccin", "mocha"
  local f = io.open(vim.fn.expand("~/.config/theme/current"), "r")
  if f then
    local line = f:read("*l")
    f:close()
    if line then
      local fam, var = line:match("^(%S+)%s+(%S+)$")
      if fam and var then family, variant = fam, var end
    end
  end
  return family, variant
end

return M
