-- DMS（matugen）运行时调色板读取器。
--
-- DankMaterialShell 在壁纸 / 明暗模式变化时原子重写
-- $XDG_CACHE_HOME/DankMaterialShell/dms-colors.json，结构见上游源码：
--   core/internal/matugen/matugen.go:124-129   (ColorsOutput struct)
--   core/cmd/dms/commands_doctor.go:1250-1258  (实际写入路径)
-- 即 { colors = { dark = { <token> = "#rrggbb", ... }, light = { ... } } }。
--
-- 本模块刻意不做缓存：每次调用都重新读文件，这样 matugen 更新后立刻拿到新值。
-- 由 theme.nix 通过 extraFiles 放进 runtimepath（lua/dms_colors.lua）。
local M = {}

-- dms-colors.json 的绝对路径。
function M.path()
  local cache = os.getenv("XDG_CACHE_HOME")
  if cache == nil or cache == "" then
    cache = vim.fn.expand("~/.cache")
  end
  return cache .. "/DankMaterialShell/dms-colors.json"
end

-- "#abc" / "abc" / "#aabbcc" / "aabbcc" -> "#aabbcc"；非法返回 nil。
function M.norm(hex)
  if type(hex) ~= "string" then
    return nil
  end
  local h = hex:gsub("^#", "")
  if #h == 3 then
    h = h:gsub("(.)", "%1%1")
  end
  if #h ~= 6 or not h:match("^%x+$") then
    return nil
  end
  return "#" .. h
end

-- 当前 vim.o.background 对应的原始 token 表（未归一化）；失败返回 nil。
function M.tokens()
  local f = io.open(M.path(), "r")
  if not f then
    return nil
  end
  local raw = f:read("*a")
  f:close()

  local ok, data = pcall(vim.fn.json_decode, raw)
  if not ok or type(data) ~= "table" or type(data.colors) ~= "table" then
    return nil
  end

  local mode = (vim.o.background == "light") and "light" or "dark"
  local pal = data.colors[mode]
  if type(pal) ~= "table" then
    return nil
  end
  return pal
end

-- 归一化的调色板（含常用别名）。文件缺失 / 关键 token 缺失时返回 nil，
-- 由调用方决定兜底（neovim 侧回退 tokyonight）。
function M.palette()
  local t = M.tokens()
  if not t then
    return nil
  end
  local function n(key)
    return M.norm(t[key])
  end

  local pal = {
    -- Material You 主色 / 强调色
    primary = n("primary"),
    on_primary = n("on_primary"),
    primary_container = n("primary_container"),
    on_primary_container = n("on_primary_container"),
    secondary = n("secondary"),
    on_secondary = n("on_secondary"),
    secondary_container = n("secondary_container"),
    on_secondary_container = n("on_secondary_container"),
    tertiary = n("tertiary"),
    on_tertiary = n("on_tertiary"),
    tertiary_container = n("tertiary_container"),
    on_tertiary_container = n("on_tertiary_container"),
    error = n("error"),
    on_error = n("on_error"),
    error_container = n("error_container"),
    on_error_container = n("on_error_container"),
    -- 前景 / 边框
    fg = n("on_surface"),
    muted = n("outline_variant") or n("outline"),
    outline = n("outline"),
    -- 背景层级（surface_dim 最暗，container 越高越亮）
    bg = n("surface_dim") or n("background") or n("surface"),
    bg_alt = n("surface_container_low"),
    bg_mid = n("surface_container"),
    bg_high = n("surface_container_high"),
    bg_highest = n("surface_container_highest"),
    inverse_surface = n("inverse_surface"),
    on_inverse_surface = n("inverse_on_surface"),
  }

  -- 关键底色缺失时无法安全上色，回退到 tokyonight。
  if not pal.bg or not pal.fg or not pal.muted then
    return nil
  end

  -- 缺 token 时按“背景 ↔ 前景”互补回退，保证对比度。
  local function fill(value, fallback)
    return value or fallback
  end
  pal.on_primary = fill(pal.on_primary, pal.bg)
  pal.on_secondary = fill(pal.on_secondary, pal.bg)
  pal.on_tertiary = fill(pal.on_tertiary, pal.bg)
  pal.on_error = fill(pal.on_error, pal.bg)
  pal.primary_container = fill(pal.primary_container, pal.primary)
  pal.on_primary_container = fill(pal.on_primary_container, pal.on_primary)
  pal.secondary_container = fill(pal.secondary_container, pal.secondary)
  pal.on_secondary_container = fill(pal.on_secondary_container, pal.on_secondary)
  pal.tertiary_container = fill(pal.tertiary_container, pal.tertiary)
  pal.on_tertiary_container = fill(pal.on_tertiary_container, pal.on_tertiary)
  pal.error_container = fill(pal.error_container, pal.error)
  pal.on_error_container = fill(pal.on_error_container, pal.on_error)
  pal.outline = fill(pal.outline, pal.muted)
  pal.bg_alt = fill(pal.bg_alt, pal.bg)
  pal.bg_mid = fill(pal.bg_mid, pal.bg_alt)
  pal.bg_high = fill(pal.bg_high, pal.bg_mid)
  pal.bg_highest = fill(pal.bg_highest, pal.bg_high)
  pal.inverse_surface = fill(pal.inverse_surface, pal.fg)
  pal.on_inverse_surface = fill(pal.on_inverse_surface, pal.bg)

  return pal
end

return M
