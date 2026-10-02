# 声音主题：KDE Plasma 的 Ocean（用户空间）。
#
# 与 GTK / Qt 侧同一分工模式（对照 programs/gtk.nix、programs/qt.nix）：
# 系统层只提供运行环境（PipeWire 等，见 modules/nixos/audio.nix），主题的包
# 与选择全在本文件。
#
# ── 包从哪来 ────────────────────────────────────────────────────────
# nixpkgs 已收录 kdePackages.ocean-sound-theme（版本跟 Plasma 走，本机
# nixos-unstable 为 6.7.5），不需要仓库自建包 + flake input。装进
# home.packages 后落在 ~/.nix-profile/share/sounds/ocean。
#
# ── 主题怎么被找到 ──────────────────────────────────────────────────
# 遵循 freedesktop Sound Theme Specification：主题名 = 目录名 = index.theme
# 所在目录，libcanberra 按 $XDG_DATA_DIRS/sounds/<name>/ 逐个查找。本机会话的
# XDG_DATA_DIRS 含 ~/.nix-profile/share（home-manager 的 useUserPackages
# 默认为 true），所以装进用户 profile 即可被发现，无需 NixOS 模块。
#
# ── 主题怎么被选中 ──────────────────────────────────────────────────
# org.gnome.desktop.sound theme-name。目录名 ocean 即主题名；index.theme 里的
# Name=Ocean 只是显示名，gsettings 要填的是目录名。这个键也是 GNOME「声音」
# 设置面板写的同一个键，GTK3 的 libcanberra-gtk 从它取主题名传给 libcanberra。
#
# 为什么用 home-manager 的 dconf.settings，而不是别的写法：
#   - 系统层 programs.dconf.profiles.user.databases 只在用户 dconf profile 首次
#     被创建时播种默认值，之后不再覆盖——首次登录即失效，不可用。
#   - 直接软链 ~/.config/dconf/user 不行：那是运行时二进制库，DMS 启动 /
#     模式切换都要重写它。
#   - dconf.settings 在每次 home-manager activation 时用 `dconf load` 写用户库，
#     幂等，还负责跨代清理（某个键从配置里删掉时自动 dconf reset），
#     并在 DBUS_SESSION_BUS_ADDRESS 缺失时自己套 dbus-run-session。
#
# 与 programs/dms-mode-hook.nix 的分工：那边用运行时 gsettings 写
# org.gnome.desktop.interface，是因为那些键 DMS 每切一次明暗模式就要重写，
# 声明式托管会打架。声音主题没有任何运行时改写方，属静态项，适合放这里。
{
  pkgs,
  ...
}:

{
  home.packages = [ pkgs.kdePackages.ocean-sound-theme ];

  # 目录名即主题名。值是 GVariant 字符串，home-manager 的 dconf.settings 会负责
  # 加引号（写成 'ocean'），不要自己带引号。
  dconf.settings."org/gnome/desktop/sound".theme-name = "ocean";
}
