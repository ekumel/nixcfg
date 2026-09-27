# xsettingsd：把 GTK 主题 / 图标 / 光标通过 XSETTINGS 协议广播给
# X11 / XWayland 应用（dconf 只对走 GSettings 的应用生效）。
#
# 主题相关配置分两处：
#   - dconf 默认值由系统层播种（modules/nixos/system/desktop/gtk.nix）；
#   - 本文件（xsettingsd.conf）覆盖纯 X11 / X Toolkit 客户端。
#
# Net/IconThemeName 故意不写死：xsettingsd 会从 dconf 回退读取，
# 由 DMS 的 mode-hook 在浅/深色切换时同步（Colloid ↔ Colloid-dark），
# XWayland 应用因此跟随模式。
{ pkgs, ... }:

let
  xsettingsdConf = pkgs.writeText "xsettingsd.conf" ''
    Net/ThemeName "Darkly"
    # 图标主题不写死：交给 dconf，由 dms-mode-hook 在切深浅色时同步
    # （Colloid ↔ Colloid-dark）。
    Net/EnableEventSounds 0
    Net/EnableInputFeedbackSounds 0

    Gtk/CursorThemeName "Bibata-Modern-Ice"
    Gtk/CursorThemeSize 48
    Gtk/FontName "LXGW WenKai 11"
    Gtk/MonospaceFontName "Maple Mono NF CN 11"
  '';
in
{
  # 守护进程由 programs/hyprland.nix 在会话启动时拉起；装进用户 profile，
  # 保证 Lua 配置里引用的 store 路径始终有效。
  home.packages = [ pkgs.xsettingsd ];

  xdg.configFile."xsettingsd/xsettingsd.conf".source = xsettingsdConf;
}
