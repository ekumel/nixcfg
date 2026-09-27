-- DMS（matugen）插件的运行时高亮组。
--
-- 只负责「插件自定义高亮组」，基础 Neovim 高亮组由 theme.nix 负责。
-- 入参为 dms_colors.palette() 的归一化结果；theme.nix 在每次配色刷新时调用
-- M.apply(p)，并且在插件自身的 ColorScheme 处理之后执行，因此能覆盖插件的
-- 预设配色。由 theme.nix 通过 extraFiles 放进 runtimepath（lua/dms_ui.lua）。
local M = {}

local function h(group, fg, bg, extra)
  local spec = { fg = fg, bg = bg }
  if extra then
    for k, v in pairs(extra) do
      spec[k] = v
    end
  end
  vim.api.nvim_set_hl(0, group, spec)
end

-- neo-tree（右侧文件树）
local function neo_tree(p)
  h("NeoTreeNormal", p.fg, p.bg)
  h("NeoTreeNormalNC", p.fg, p.bg)
  h("NeoTreeSignColumn", p.muted, p.bg)
  h("NeoTreeStatusLine", p.fg, p.bg)
  h("NeoTreeStatusLineNC", p.muted, p.bg)
  h("NeoTreeVertSplit", p.muted, p.bg)
  h("NeoTreeWinSeparator", p.muted, p.bg)
  h("NeoTreeEndOfBuffer", p.bg, p.bg)
  h("NeoTreeCursorLine", nil, p.bg_high)

  h("NeoTreeRootName", p.primary, nil, { bold = true })
  h("NeoTreeDirectoryName", p.fg, nil)
  h("NeoTreeDirectoryIcon", p.primary, nil)
  h("NeoTreeFileName", p.fg, nil)
  h("NeoTreeFileNameOpened", p.fg, nil, { bold = true })
  h("NeoTreeFileIcon", p.muted, nil)
  h("NeoTreeSymbolicLinkTarget", p.secondary, nil)
  h("NeoTreeIndentMarker", p.muted, nil)
  h("NeoTreeExpander", p.muted, nil)
  h("NeoTreeDotfile", p.muted, nil)
  h("NeoTreeHiddenByName", p.muted, nil)
  h("NeoTreeDimText", p.muted, nil)
  h("NeoTreeFadeText", p.muted, nil)
  h("NeoTreeMessage", p.muted, nil)
  h("NeoTreeEvent", p.muted, nil)
  h("NeoTreeWindowsHidden", p.muted, nil)
  h("NeoTreeFilterTerm", p.primary, nil, { bold = true })
  h("NeoTreeBufferNumber", p.muted, nil)
  h("NeoTreeModified", p.secondary, nil)
  h("NeoTreePreview", p.secondary, nil)

  h("NeoTreeTitleBar", p.fg, p.bg_high, { bold = true })
  h("NeoTreeFloatNormal", p.fg, p.bg_mid)
  h("NeoTreeFloatBorder", p.muted, p.bg_mid)
  h("NeoTreeFloatTitle", p.primary, p.bg_mid, { bold = true })

  h("NeoTreeGitAdded", p.tertiary, nil)
  h("NeoTreeGitStaged", p.tertiary, nil)
  h("NeoTreeGitModified", p.secondary, nil)
  h("NeoTreeGitUnstaged", p.secondary, nil)
  h("NeoTreeGitDeleted", p.error, nil)
  h("NeoTreeGitRenamed", p.secondary, nil)
  h("NeoTreeGitUntracked", p.muted, nil)
  h("NeoTreeGitIgnored", p.muted, nil)
  h("NeoTreeGitConflict", p.error, nil)
  h("NeoTreeIgnored", p.muted, nil)

  h("NeoTreeTabActive", p.primary, p.bg_mid, { bold = true })
  h("NeoTreeTabInactive", p.muted, p.bg_alt)
  h("NeoTreeTabSeparatorActive", p.muted, p.bg_mid)
  h("NeoTreeTabSeparatorInactive", p.muted, p.bg_alt)
end

-- bufferline（顶部 tab）
local function bufferline(p)
  local bar = p.bg_alt -- 整体 tabline 背景
  local bar_vis = p.bg_mid -- 未选中但可见的 buffer
  local sel = p.bg_high -- 当前 buffer
  local sep = bar -- 分隔符颜色（= 整体底色，形成 slope 效果）

  h("BufferLineFill", p.muted, bar)
  h("BufferLineBackground", p.muted, bar)
  h("BufferLineBuffer", p.muted, bar)
  h("BufferLineBufferVisible", p.fg, bar_vis)
  h("BufferLineBufferSelected", p.primary, sel, { bold = true })
  h("BufferLineNumbers", p.muted, bar)
  h("BufferLineNumbersVisible", p.fg, bar_vis)
  h("BufferLineNumbersSelected", p.primary, sel, { bold = true })
  h("BufferLineCloseButton", p.muted, bar)
  h("BufferLineCloseButtonVisible", p.fg, bar_vis)
  h("BufferLineCloseButtonSelected", p.fg, sel)
  h("BufferLineModified", p.secondary, bar)
  h("BufferLineModifiedVisible", p.secondary, bar_vis)
  h("BufferLineModifiedSelected", p.secondary, sel)
  h("BufferLineDuplicate", p.muted, bar)
  h("BufferLineDuplicateVisible", p.muted, bar_vis)
  h("BufferLineDuplicateSelected", p.muted, sel)
  h("BufferLineSeparator", sep, bar)
  h("BufferLineSeparatorVisible", sep, bar_vis)
  h("BufferLineSeparatorSelected", sep, sel)
  h("BufferLineTab", p.muted, bar)
  h("BufferLineTabSelected", p.primary, sel, { bold = true })
  h("BufferLineTabClose", p.muted, bar)
  h("BufferLineTabSeparator", sep, bar)
  h("BufferLineTabSeparatorSelected", sep, sel)
  h("BufferLineIndicator", p.primary, bar)
  h("BufferLineIndicatorVisible", p.primary, bar_vis)
  h("BufferLineIndicatorSelected", p.primary, sel)
  h("BufferLinePick", p.error, bar, { bold = true })
  h("BufferLinePickVisible", p.error, bar_vis, { bold = true })
  h("BufferLinePickSelected", p.error, sel, { bold = true })
  h("BufferLineTruncMarker", p.muted, bar)
  h("BufferLineOffsetSeparator", p.muted, bar)
  h("BufferLineGroupSeparator", p.muted, bar)
  h("BufferLineGroupLabel", p.on_primary, p.primary)

  h("BufferLineDiagnostic", p.muted, bar)
  h("BufferLineDiagnosticVisible", p.fg, bar_vis)
  h("BufferLineDiagnosticSelected", p.fg, sel)

  -- 诊断按严重级别上色（sp 用于下划线 / 图标色）。
  local function diagnostic(name, color)
    h("BufferLine" .. name, p.muted, bar, { sp = color })
    h("BufferLine" .. name .. "Visible", p.fg, bar_vis, { sp = color })
    h("BufferLine" .. name .. "Selected", color, sel, { bold = true, sp = color })
    h("BufferLine" .. name .. "Diagnostic", p.muted, bar, { sp = color })
    h("BufferLine" .. name .. "DiagnosticVisible", p.fg, bar_vis, { sp = color })
    h("BufferLine" .. name .. "DiagnosticSelected", color, sel, { bold = true, sp = color })
  end
  diagnostic("Hint", p.tertiary)
  diagnostic("Info", p.primary)
  diagnostic("Warning", p.secondary)
  diagnostic("Error", p.error)
end

-- which-key（键位提示浮窗）
local function which_key(p)
  h("WhichKey", p.primary, nil)
  h("WhichKeyNormal", p.fg, p.bg_mid)
  h("WhichKeyFloat", nil, p.bg_mid)
  h("WhichKeyBorder", p.muted, p.bg_mid)
  h("WhichKeyTitle", p.primary, p.bg_mid, { bold = true })
  h("WhichKeyGroup", p.secondary, nil)
  h("WhichKeyDesc", p.fg, nil)
  h("WhichKeySeparator", p.muted, nil)
  h("WhichKeyValue", p.muted, nil)
  h("WhichKeyIcon", p.primary, nil)
end

-- telescope（模糊查找）
local function telescope(p)
  h("TelescopeNormal", p.fg, p.bg_mid)
  h("TelescopeBorder", p.muted, p.bg_mid)
  h("TelescopeTitle", p.primary, p.bg_mid, { bold = true })
  h("TelescopePromptNormal", p.fg, p.bg_high)
  h("TelescopePromptBorder", p.muted, p.bg_high)
  h("TelescopePromptTitle", p.on_primary, p.primary, { bold = true })
  h("TelescopePromptPrefix", p.primary, p.bg_high)
  h("TelescopePromptCounter", p.muted, p.bg_high)
  h("TelescopeResultsNormal", p.fg, p.bg_mid)
  h("TelescopeResultsBorder", p.muted, p.bg_mid)
  h("TelescopeResultsTitle", p.primary, p.bg_mid, { bold = true })
  h("TelescopePreviewNormal", p.fg, p.bg_mid)
  h("TelescopePreviewBorder", p.muted, p.bg_mid)
  h("TelescopePreviewTitle", p.primary, p.bg_mid, { bold = true })
  h("TelescopeSelection", p.fg, p.bg_high, { bold = true })
  h("TelescopeSelectionCaret", p.primary, p.bg_high)
  h("TelescopeMultiSelection", p.tertiary, nil)
  h("TelescopeMatching", p.primary, nil, { bold = true })
end

-- noice（messages / cmdline / notify 接管）
local function noice(p)
  h("NoiceCmdline", p.fg, p.bg_mid)
  h("NoiceCmdlineIcon", p.primary, nil)
  h("NoiceCmdlinePrompt", p.primary, nil)
  h("NoiceCmdlinePopup", p.fg, p.bg_mid)
  h("NoiceCmdlinePopupBorder", p.muted, p.bg_mid)
  h("NoiceCmdlinePopupTitle", p.primary, p.bg_mid, { bold = true })
  h("NoiceConfirm", p.fg, p.bg_mid)
  h("NoiceConfirmBorder", p.muted, p.bg_mid)
  h("NoiceMini", p.fg, p.bg_mid)
  h("NoicePopup", p.fg, p.bg_mid)
  h("NoicePopupBorder", p.muted, p.bg_mid)
  h("NoicePopupmenu", p.fg, p.bg_high)
  h("NoicePopupmenuBorder", p.muted, p.bg_high)
  h("NoicePopupmenuMatch", p.primary, nil, { bold = true })
  h("NoicePopupmenuSelected", p.fg, p.bg_highest, { bold = true })
  h("NoiceScrollbar", nil, p.bg_high)
  h("NoiceScrollbarThumb", nil, p.muted)
  h("NoiceSplit", p.fg, p.bg_mid)
  h("NoiceSplitBorder", p.muted, p.bg_mid)
  h("NoiceFormatTitle", p.primary, nil, { bold = true })
  h("NoiceFormatDate", p.muted, nil)
  h("NoiceFormatProgressDone", p.on_primary, p.primary)
  h("NoiceFormatProgressTodo", p.muted, p.bg_high)
  h("NoiceLspProgressClient", p.secondary, nil)
  h("NoiceLspProgressSpinner", p.primary, nil)
  h("NoiceLspProgressTitle", p.fg, nil)
end

-- nvim-notify
local function notify(p)
  h("NotifyBackground", p.fg, p.bg_mid)
  local function level(name, color)
    h("Notify" .. name .. "Border", color, p.bg_mid)
    h("Notify" .. name .. "Title", color, p.bg_mid, { bold = true })
    h("Notify" .. name .. "Icon", color, p.bg_mid)
    h("Notify" .. name .. "Body", p.fg, p.bg_mid)
  end
  level("ERROR", p.error)
  level("WARN", p.secondary)
  level("INFO", p.primary)
  level("DEBUG", p.muted)
  level("TRACE", p.muted)
end

-- dashboard（启动页）
local function dashboard(p)
  h("DashboardHeader", p.primary, nil, { bold = true })
  h("DashboardCenter", p.fg, nil)
  h("DashboardShortCut", p.secondary, nil)
  h("DashboardFooter", p.muted, nil, { italic = true })
  h("DashboardKey", p.on_primary, p.primary, { bold = true })
  h("DashboardDesc", p.fg, nil)
  h("DashboardIcon", p.primary, nil)
  h("DashboardProjectTitle", p.primary, nil, { bold = true })
  h("DashboardProjectTitleIcon", p.secondary, nil)
  h("DashboardProjectIcon", p.tertiary, nil)
  h("DashboardFiles", p.secondary, nil)
  h("DashboardMruIcon", p.tertiary, nil)
  h("DashboardMruTitle", p.primary, nil, { bold = true })
  h("DashboardShortCutIcon", p.tertiary, nil)
end

-- nvim-ufo（折叠）
local function ufo(p)
  h("UfoFoldedFg", p.primary, nil)
  h("UfoFoldedBg", nil, p.bg_high)
  h("UfoFoldedEllipsis", p.muted, nil)
  h("UfoCursorFoldedLine", nil, p.bg_high)
  h("UfoPreviewCursorLine", nil, p.bg_high)
  h("UfoPreviewSbar", nil, p.bg_high)
  h("UfoPreviewThumb", nil, p.muted)
end

---@param p table dms_colors.palette() 的返回值
function M.apply(p)
  if type(p) ~= "table" then
    return
  end
  neo_tree(p)
  bufferline(p)
  which_key(p)
  telescope(p)
  noice(p)
  notify(p)
  dashboard(p)
  ufo(p)
end

return M
