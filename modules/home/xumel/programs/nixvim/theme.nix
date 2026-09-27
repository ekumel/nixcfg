# 配色：兜底 tokyonight + DMS（matugen）动态主题。
#
# 主题：DMS（matugen）生成的 $XDG_CACHE_HOME/DankMaterialShell/dms-colors.json。
# 文件结构见上游源码
#   core/internal/matugen/matugen.go:124-129   (ColorsOutput struct)
#   core/cmd/dms/commands_doctor.go:1250-1258  (实际写入路径)
# 即：
#   { "colors": { "dark": { "primary": "#...", ... }, "light": { ... } } }
# 启动时按 vim.o.background 选 dark/light，把 Material You token 映射到
# 常用 Neovim 高亮组；DMS 在壁纸/明暗模式变化后重写该文件，FileWritePost
# autocmd 会即时刷新配色。文件还没生成（DMS 还没跑过）时落回 tokyonight。
{ ... }:

{
  programs.nixvim = {
    # 兜底配色：DMS 还没生成 dms-colors.json 时用 tokyonight。
    colorschemes.tokyonight = {
      enable = true;
      settings = {
        style = "night";
        transparent = false;
      };
    };
    colorscheme = "tokyonight";

    # 读取 DMS 写的 dms-colors.json，动态应用配色，并在文件变化时重载。
    extraConfigLua = ''
      do
        local cache = os.getenv("XDG_CACHE_HOME") or vim.fn.expand("~/.cache")
        local colors_path = cache .. "/DankMaterialShell/dms-colors.json"

        -- "#abc" / "abc" / "#aabbcc" / "aabbcc" -> "#aabbcc"；非法返回 nil。
        local function norm(hex)
          if type(hex) ~= "string" then return nil end
          local h = hex:gsub("^#", "")
          if #h == 3 then h = h:gsub("(.)", "%1%1") end
          if #h ~= 6 or not h:match("^%x+$") then return nil end
          return "#" .. h
        end

        -- 仅接受 "#rrggbb" 的小工具：nil-safe。
        local function n(hex) return norm(hex) or "NONE" end

        local function apply_colors()
          local f = io.open(colors_path, "r")
          if not f then return false end
          local raw = f:read("*a")
          f:close()

          local ok, data = pcall(vim.fn.json_decode, raw)
          if not ok or type(data) ~= "table" or type(data.colors) ~= "table" then
            return false
          end

          local mode = (vim.o.background == "light") and "light" or "dark"
          local pal = data.colors[mode]
          if type(pal) ~= "table" then return false end

          -- 常用 Material You token。
          local primary   = norm(pal.primary)
          local on_primary = norm(pal.on_primary)
          local secondary = norm(pal.secondary)
          local tertiary  = norm(pal.tertiary)
          local error_    = norm(pal.error)
          local bg        = norm(pal.surface_dim) or norm(pal.background) or norm(pal.surface)
          local fg        = norm(pal.on_surface)
          local muted     = norm(pal.outline_variant) or norm(pal.outline)
          if not bg or not fg or not muted then return false end

          -- 基底
          vim.api.nvim_set_hl(0, "Normal",     { bg = bg, fg = fg })
          vim.api.nvim_set_hl(0, "NormalNC",   { bg = bg, fg = fg })
          vim.api.nvim_set_hl(0, "SignColumn", { bg = bg, fg = muted })
          vim.api.nvim_set_hl(0, "EndOfBuffer",{ bg = bg, fg = bg })
          vim.api.nvim_set_hl(0, "FoldColumn", { bg = bg, fg = muted })
          vim.api.nvim_set_hl(0, "Folded",     { bg = bg, fg = muted })
          vim.api.nvim_set_hl(0, "LineNr",     { bg = bg, fg = muted })
          vim.api.nvim_set_hl(0, "CursorLineNr", { bg = bg, fg = primary, bold = true })
          vim.api.nvim_set_hl(0, "CursorLine", { bg = n(pal.surface_container_high) })
          vim.api.nvim_set_hl(0, "CursorColumn", { bg = n(pal.surface_container_high) })
          vim.api.nvim_set_hl(0, "Cursor",     { fg = primary })
          vim.api.nvim_set_hl(0, "TermCursor", { fg = primary })
          vim.api.nvim_set_hl(0, "Visual",     { bg = n(pal.primary_container), fg = on_primary })
          vim.api.nvim_set_hl(0, "VisualNOS",  { bg = n(pal.primary_container), fg = on_primary })

          -- 搜索
          vim.api.nvim_set_hl(0, "Search",     { bg = n(pal.tertiary_container), fg = n(pal.on_tertiary_container) })
          vim.api.nvim_set_hl(0, "IncSearch",  { bg = n(pal.tertiary_container), fg = n(pal.on_tertiary_container), bold = true })
          vim.api.nvim_set_hl(0, "CurSearch",  { bg = n(pal.tertiary_container), fg = n(pal.on_tertiary_container) })
          vim.api.nvim_set_hl(0, "MatchParen", { fg = primary, bold = true })

          -- 状态行 / Tab
          vim.api.nvim_set_hl(0, "StatusLine",    { bg = n(pal.surface_container),     fg = fg })
          vim.api.nvim_set_hl(0, "StatusLineNC",  { bg = n(pal.surface_container_low), fg = muted })
          vim.api.nvim_set_hl(0, "WinBar",        { bg = bg, fg = fg })
          vim.api.nvim_set_hl(0, "WinBarNC",      { bg = bg, fg = muted })
          vim.api.nvim_set_hl(0, "TabLine",       { bg = n(pal.surface_container_low), fg = muted })
          vim.api.nvim_set_hl(0, "TabLineFill",   { bg = n(pal.surface_container_low) })
          vim.api.nvim_set_hl(0, "TabLineSel",    { bg = bg, fg = primary, bold = true })

          -- 消息
          vim.api.nvim_set_hl(0, "Comment",    { fg = muted, italic = true })
          vim.api.nvim_set_hl(0, "ErrorMsg",   { bg = n(pal.error_container), fg = n(pal.on_error_container) })
          vim.api.nvim_set_hl(0, "WarningMsg", { fg = tertiary, bold = true })
          vim.api.nvim_set_hl(0, "MoreMsg",    { fg = primary })
          vim.api.nvim_set_hl(0, "Question",   { fg = primary, bold = true })

          -- Diff
          vim.api.nvim_set_hl(0, "DiffAdd",    { bg = n(pal.tertiary_container),  fg = n(pal.on_tertiary_container) })
          vim.api.nvim_set_hl(0, "DiffChange", { bg = n(pal.secondary_container), fg = n(pal.on_secondary_container) })
          vim.api.nvim_set_hl(0, "DiffDelete", { bg = n(pal.error_container),     fg = n(pal.on_error_container) })
          vim.api.nvim_set_hl(0, "DiffText",   { bg = n(pal.primary_container),   fg = on_primary, bold = true })

          -- 语法
          vim.api.nvim_set_hl(0, "String",       { fg = tertiary })
          vim.api.nvim_set_hl(0, "Character",    { fg = tertiary })
          vim.api.nvim_set_hl(0, "Number",       { fg = tertiary })
          vim.api.nvim_set_hl(0, "Boolean",      { fg = tertiary })
          vim.api.nvim_set_hl(0, "Float",        { fg = tertiary })
          vim.api.nvim_set_hl(0, "Identifier",   { fg = fg })
          vim.api.nvim_set_hl(0, "Function",     { fg = primary })
          vim.api.nvim_set_hl(0, "Statement",    { fg = secondary })
          vim.api.nvim_set_hl(0, "Keyword",      { fg = secondary })
          vim.api.nvim_set_hl(0, "Operator",     { fg = secondary })
          vim.api.nvim_set_hl(0, "PreProc",      { fg = secondary })
          vim.api.nvim_set_hl(0, "Type",         { fg = primary })
          vim.api.nvim_set_hl(0, "StorageClass", { fg = secondary })
          vim.api.nvim_set_hl(0, "Structure",    { fg = primary })
          vim.api.nvim_set_hl(0, "Typedef",      { fg = primary })
          vim.api.nvim_set_hl(0, "Special",      { fg = primary })
          vim.api.nvim_set_hl(0, "SpecialChar",  { fg = tertiary })
          vim.api.nvim_set_hl(0, "Tag",          { fg = primary })
          vim.api.nvim_set_hl(0, "Delimiter",    { fg = muted })
          vim.api.nvim_set_hl(0, "SpecialComment", { fg = muted, bold = true })
          vim.api.nvim_set_hl(0, "Debug",        { fg = error_ })
          vim.api.nvim_set_hl(0, "Underlined",   { fg = primary, underline = true })
          vim.api.nvim_set_hl(0, "Error",        { fg = error_ })
          vim.api.nvim_set_hl(0, "Todo",         { bg = n(pal.tertiary_container), fg = n(pal.on_tertiary_container), bold = true })
          vim.api.nvim_set_hl(0, "Title",        { fg = primary, bold = true })

          -- Treesitter / LSP 兼容别名
          vim.api.nvim_set_hl(0, "@comment",          { fg = muted, italic = true })
          vim.api.nvim_set_hl(0, "@string",           { fg = tertiary })
          vim.api.nvim_set_hl(0, "@string.regexp",    { fg = tertiary })
          vim.api.nvim_set_hl(0, "@string.escape",    { fg = tertiary })
          vim.api.nvim_set_hl(0, "@string.special",   { fg = tertiary })
          vim.api.nvim_set_hl(0, "@number",           { fg = tertiary })
          vim.api.nvim_set_hl(0, "@boolean",          { fg = tertiary })
          vim.api.nvim_set_hl(0, "@function",         { fg = primary })
          vim.api.nvim_set_hl(0, "@function.call",    { fg = primary })
          vim.api.nvim_set_hl(0, "@function.builtin", { fg = secondary })
          vim.api.nvim_set_hl(0, "@keyword",          { fg = secondary })
          vim.api.nvim_set_hl(0, "@keyword.operator", { fg = secondary })
          vim.api.nvim_set_hl(0, "@keyword.return",   { fg = secondary })
          vim.api.nvim_set_hl(0, "@operator",         { fg = secondary })
          vim.api.nvim_set_hl(0, "@type",             { fg = primary })
          vim.api.nvim_set_hl(0, "@type.builtin",     { fg = primary })
          vim.api.nvim_set_hl(0, "@variable",         { fg = fg })
          vim.api.nvim_set_hl(0, "@variable.builtin", { fg = secondary })
          vim.api.nvim_set_hl(0, "@variable.parameter", { fg = fg })
          vim.api.nvim_set_hl(0, "@punctuation",      { fg = muted })
          vim.api.nvim_set_hl(0, "@tag",              { fg = primary })
          vim.api.nvim_set_hl(0, "@tag.attribute",    { fg = tertiary })
          vim.api.nvim_set_hl(0, "@tag.delimiter",    { fg = muted })
          vim.api.nvim_set_hl(0, "@error",            { fg = error_ })
          vim.api.nvim_set_hl(0, "@warning",          { fg = tertiary, bold = true })

          return true
        end

        -- 启动时尝试套一次（DMS 还没写文件时 tokyonight 已在生效）。
        apply_colors()

        -- DMS 在壁纸/明暗模式变化后会原子重写该文件，触发刷新。
        vim.api.nvim_create_autocmd("FileWritePost", {
          pattern = colors_path,
          callback = function() apply_colors() end,
        })

        -- 兜底：用 libuv fs event 监听（无需 nvim 自己打开该文件）。
        local uv = vim.uv or vim.loop
        if uv and uv.new_fs_event then
          local handle = uv.new_fs_event()
          local ok = handle:start(colors_path, {}, function() apply_colors() end)
          if ok then
            vim.api.nvim_create_autocmd("VimLeavePre", {
              callback = function() pcall(function() handle:stop() end) end,
            })
          end
        end
      end
    '';
  };
}