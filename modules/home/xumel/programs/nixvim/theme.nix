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
#
# 读取 / 映射逻辑拆到 extraFiles 的 Lua 模块里（各文件头有说明）：
#   lua/dms_colors.lua           调色板读取（归一化 token）
#   lua/dms_ui.lua               插件自定义高亮（neo-tree / bufferline / …）
#   lua/lualine/themes/dms.lua   lualine 主题 "dms"
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

    # DMS 主题辅助模块：放进 runtimepath，运行时用 require 加载。
    extraFiles = {
      "lua/dms_colors.lua".source = ./lua/dms_colors.lua;
      "lua/dms_ui.lua".source = ./lua/dms_ui.lua;
      "lua/lualine/themes/dms.lua".source = ./lua/lualine/themes/dms.lua;
    };

    # 读取 DMS 写的 dms-colors.json，动态应用配色，并在文件变化时重载。
    extraConfigLua = ''
      do
        local dms = require("dms_colors")
        local ui = require("dms_ui")
        local colors_path = dms.path()

        local function apply_colors()
          local p = dms.palette()
          if not p then return false end

          -- 常用 Material You token（归一化由 dms_colors.palette 完成）。
          local primary    = p.primary
          local on_primary = p.on_primary
          local secondary  = p.secondary
          local tertiary   = p.tertiary
          local error_     = p.error
          local bg         = p.bg
          local fg         = p.fg
          local muted      = p.muted

          -- 基底
          vim.api.nvim_set_hl(0, "Normal",     { bg = bg, fg = fg })
          vim.api.nvim_set_hl(0, "NormalNC",   { bg = bg, fg = fg })
          vim.api.nvim_set_hl(0, "SignColumn", { bg = bg, fg = muted })
          vim.api.nvim_set_hl(0, "EndOfBuffer",{ bg = bg, fg = bg })
          vim.api.nvim_set_hl(0, "FoldColumn", { bg = bg, fg = muted })
          vim.api.nvim_set_hl(0, "Folded",     { bg = bg, fg = muted })
          vim.api.nvim_set_hl(0, "LineNr",     { bg = bg, fg = muted })
          vim.api.nvim_set_hl(0, "CursorLineNr", { bg = bg, fg = primary, bold = true })
          vim.api.nvim_set_hl(0, "CursorLine", { bg = p.bg_high })
          vim.api.nvim_set_hl(0, "CursorColumn", { bg = p.bg_high })
          vim.api.nvim_set_hl(0, "Cursor",     { fg = primary })
          vim.api.nvim_set_hl(0, "TermCursor", { fg = primary })
          vim.api.nvim_set_hl(0, "Visual",     { bg = p.primary_container, fg = on_primary })
          vim.api.nvim_set_hl(0, "VisualNOS",  { bg = p.primary_container, fg = on_primary })

          -- 搜索
          vim.api.nvim_set_hl(0, "Search",     { bg = p.tertiary_container, fg = p.on_tertiary_container })
          vim.api.nvim_set_hl(0, "IncSearch",  { bg = p.tertiary_container, fg = p.on_tertiary_container, bold = true })
          vim.api.nvim_set_hl(0, "CurSearch",  { bg = p.tertiary_container, fg = p.on_tertiary_container })
          vim.api.nvim_set_hl(0, "MatchParen", { fg = primary, bold = true })

          -- 状态行 / Tab
          vim.api.nvim_set_hl(0, "StatusLine",    { bg = p.bg_mid,     fg = fg })
          vim.api.nvim_set_hl(0, "StatusLineNC",  { bg = p.bg_alt,     fg = muted })
          vim.api.nvim_set_hl(0, "WinBar",        { bg = bg, fg = fg })
          vim.api.nvim_set_hl(0, "WinBarNC",      { bg = bg, fg = muted })
          vim.api.nvim_set_hl(0, "TabLine",       { bg = p.bg_alt, fg = muted })
          vim.api.nvim_set_hl(0, "TabLineFill",   { bg = p.bg_alt })
          vim.api.nvim_set_hl(0, "TabLineSel",    { bg = bg, fg = primary, bold = true })

          -- 浮窗 / 补全菜单
          vim.api.nvim_set_hl(0, "NormalFloat", { bg = p.bg_mid, fg = fg })
          vim.api.nvim_set_hl(0, "FloatBorder", { bg = p.bg_mid, fg = muted })
          vim.api.nvim_set_hl(0, "FloatTitle",  { bg = p.bg_mid, fg = primary, bold = true })
          vim.api.nvim_set_hl(0, "Pmenu",       { bg = p.bg_mid, fg = fg })
          vim.api.nvim_set_hl(0, "PmenuSel",    { bg = p.primary_container, fg = p.on_primary_container, bold = true })
          vim.api.nvim_set_hl(0, "PmenuSbar",   { bg = p.bg_alt })
          vim.api.nvim_set_hl(0, "PmenuThumb",  { bg = muted })

          -- 消息
          vim.api.nvim_set_hl(0, "Comment",    { fg = muted, italic = true })
          vim.api.nvim_set_hl(0, "ErrorMsg",   { bg = p.error_container, fg = p.on_error_container })
          vim.api.nvim_set_hl(0, "WarningMsg", { fg = tertiary, bold = true })
          vim.api.nvim_set_hl(0, "MoreMsg",    { fg = primary })
          vim.api.nvim_set_hl(0, "Question",   { fg = primary, bold = true })

          -- 诊断（LSP / 内联提示插件会读取这些组）
          vim.api.nvim_set_hl(0, "DiagnosticError", { fg = error_ })
          vim.api.nvim_set_hl(0, "DiagnosticWarn",  { fg = secondary })
          vim.api.nvim_set_hl(0, "DiagnosticInfo",  { fg = primary })
          vim.api.nvim_set_hl(0, "DiagnosticHint",  { fg = tertiary })
          vim.api.nvim_set_hl(0, "DiagnosticVirtualTextError", { fg = error_ })
          vim.api.nvim_set_hl(0, "DiagnosticVirtualTextWarn",  { fg = secondary })
          vim.api.nvim_set_hl(0, "DiagnosticVirtualTextInfo",  { fg = primary })
          vim.api.nvim_set_hl(0, "DiagnosticVirtualTextHint",  { fg = tertiary })
          vim.api.nvim_set_hl(0, "DiagnosticUnderlineError", { sp = error_, undercurl = true })
          vim.api.nvim_set_hl(0, "DiagnosticUnderlineWarn",  { sp = secondary, undercurl = true })
          vim.api.nvim_set_hl(0, "DiagnosticUnderlineInfo",  { sp = primary, undercurl = true })
          vim.api.nvim_set_hl(0, "DiagnosticUnderlineHint",  { sp = tertiary, undercurl = true })

          -- Diff
          vim.api.nvim_set_hl(0, "DiffAdd",    { bg = p.tertiary_container,  fg = p.on_tertiary_container })
          vim.api.nvim_set_hl(0, "DiffChange", { bg = p.secondary_container, fg = p.on_secondary_container })
          vim.api.nvim_set_hl(0, "DiffDelete", { bg = p.error_container,     fg = p.on_error_container })
          vim.api.nvim_set_hl(0, "DiffText",   { bg = p.primary_container,   fg = on_primary, bold = true })

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
          vim.api.nvim_set_hl(0, "Todo",         { bg = p.tertiary_container, fg = p.on_tertiary_container, bold = true })
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

          -- 插件自定义高亮（neo-tree / bufferline / which-key / telescope …）
          ui.apply(p)

          -- lualine 主题名是 "dms"（见 plugins/ui.nix），由
          -- lua/lualine/themes/dms.lua 读取同一份调色板。重跑 setup 让主题
          -- 模块重新 dofile，从而立刻套用新配色。
          if package.loaded["lualine"] then
            pcall(function() require("lualine").setup() end)
          end

          return true
        end

        -- 启动时尝试套一次（DMS 还没写文件时 tokyonight 已在生效）。
        apply_colors()

        -- DMS 在壁纸/明暗模式变化后会原子重写该文件，触发刷新。
        vim.api.nvim_create_autocmd("FileWritePost", {
          pattern = colors_path,
          callback = function() apply_colors() end,
        })

        -- 切换 colorscheme / background 时，插件会先按自己的预设重写高亮；
        -- 本 autocmd 比插件的注册得晚，因此能最后覆盖回 DMS 配色。
        vim.api.nvim_create_autocmd("ColorScheme", {
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
