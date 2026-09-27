-- lualine 主题：直接读取 DMS（matugen）调色板。
--
-- 注册为 lualine 主题名 "dms"（见 ui.nix 的 settings.options.theme）。
-- DMS 重写 dms-colors.json 后，theme.nix 会调用 require("lualine").setup()
-- 重新 dofile 本文件，因此每次都能拿到新配色。
-- 由 theme.nix 通过 extraFiles 放进 runtimepath（lua/lualine/themes/dms.lua）。
local ok, colors = pcall(require, "dms_colors")
local palette = ok and colors.palette() or nil
if not palette then
  -- DMS 还没生成配色：回退到兜底 colorscheme（tokyonight）的主题。
  local ok_fallback, fallback = pcall(require, "lualine.themes.tokyonight")
  if ok_fallback then
    return fallback
  end
  return require("lualine.themes.auto")
end

local p = palette

local function hl(fg, bg, gui)
  return { fg = fg, bg = bg, gui = gui }
end

-- b / c 段在所有模式下共用同一套表面色。
local surface_high = hl(p.fg, p.bg_high)
local surface_mid = hl(p.fg, p.bg_mid)
local inactive = {
  a = hl(p.muted, p.bg_alt),
  b = hl(p.muted, p.bg_alt),
  c = hl(p.muted, p.bg_alt),
}

local function mode(accent, on_accent)
  return {
    a = hl(on_accent, accent, "bold"),
    b = surface_high,
    c = surface_mid,
  }
end

return {
  normal = mode(p.primary, p.on_primary),
  insert = mode(p.tertiary, p.on_tertiary),
  visual = mode(p.secondary, p.on_secondary),
  replace = mode(p.error, p.on_error),
  command = mode(p.primary_container, p.on_primary_container),
  terminal = mode(p.tertiary_container, p.on_tertiary_container),
  inactive = inactive,
}
