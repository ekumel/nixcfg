# qtengine 的用户级配置（Qt 统一外观）。
#
# qtengine 只读取 ~/.config/qtengine/config.json（存在时不再读 /etc/xdg），
# 所以 Qt 的样式 / 图标 / 字体 / 杂项都放在这里。配色（colorScheme）故意
# 不在这里指定：DMS 的动态主题会在运行时把它合并进本文件
# （DMS 只改 theme.colorScheme / theme.iconTheme，其它键原样保留）。
#
# 本文件由 home-manager 软链到只读 store；DMS 首次应用主题时会读取它、
# 合并配色后用真实文件替换该软链。之后每次 rebuild，home-manager 会恢复
# 为下面的种子配置（旧文件备份为 *.hm-backup），DMS 下次应用主题时再补回配色。
{ pkgs, ... }:

let
  qtengineConfig = (pkgs.formats.json { }).generate "qtengine-config.json" {
    theme = {
      # 注意：Qt（QIconLoader）按“目录名”查找图标主题，而不是 index.theme 里的
      # Name 字段；ozone-icons 的目录是 Vector-dark（GTK 里用的显示名才是
      # "Vector (Dark)"）。若填 "Vector (Dark)"，Qt 找不到该主题、只回退到
      # hicolor，导致只在 Vector 里存在的图标（如 input-keyboard-symbolic）
      # 缺失——fcitx5 托盘图标正是用它，所以会变成空白。
      iconTheme = "Colloid";

      # 来自系统模块安装的 Darkly 包（见 modules/nixos/desktop/qt.nix）。
      style = "Darkly";
      colorScheme = "/home/xumel/.local/share/color-schemes/DankMatugen.colors";
      # 与 fonts.nix 安装的字体对应（霞鹜文楷 / Maple Mono NF CN）。
      font = {
        family = "LXGW WenKai";
        size = 11;
        weight = -1;
      };
      fontFixed = {
        family = "Maple Mono NF CN";
        size = 11;
        weight = -1;
      };
    };

    misc = {
      singleClickActivate = false;
      menusHaveIcons = true;
      shortcutsForContextMenus = true;
    };
  };
in
{
  xdg.configFile."qtengine/config.json".source = qtengineConfig;
}
