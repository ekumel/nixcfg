# GTK 主题（用户空间）。
#
# 与 Qt 侧保持同一分工模式（对照 modules/nixos/desktop/qt.nix）：
#   - 系统层只提供运行环境（XWayland、dconf 守护进程等）；
#   - 主题相关的包与配置声明全在本文件（用户空间）。
#
# 为什么 GTK 的「键值」不在这里而在 dms-mode-hook.nix：
#   org.gnome.desktop.interface 的这些键最终落在 ~/.config/dconf/user ——
#   一个运行时二进制库。DMS 每次启动 / 模式切换都要重写它（动态配色、
#   明暗模式），所以它不能是 home-manager 管理的 store 软链。静态项由
#   dms-mode-hook.nix 在 onDankHooksStarted 时用 gsettings 写入，动态项在
#   模式切换时写入。
#
#   此前这些键还在系统层 modules/nixos/desktop/gtk.nix 的
#   programs.dconf.profiles.user.databases 里声明了一份，但 NixOS 只在用户
#   dconf profile 尚未被首次登录创建时播种默认值，之后不再覆盖——等于首次
#   登录后就失效的僵尸配置，且与 hook 重复。该模块已移除。
{
  pkgs,
  lib,
  flake,
  ...
}:

let
  # DMS（matugen）在壁纸 / 明暗模式变化时重写
  # ~/.config/gtk-{3,4}.0/dank-colors.css，GTK 主题在运行时 @import 它。
  # 与 modules/nixos/desktop/dms.nix 的 pywalfox 同步脚本保持一致——
  # 两边都写绝对路径（本机单用户 xumel）。
  userHome = "/home/xumel";

  # 主题构建逻辑在 lib/darkly-gtk.nix：编译 sass 主题并把调色板改写成
  # 引用 DMS 语义色。
  darkly-gtk = flake.lib.darkly-gtk pkgs {
    inherit
      lib
      flake
      userHome
      ;
  };

  gsettingsSchemas = pkgs.gsettings-desktop-schemas;
in
{
  home.packages = [ darkly-gtk ];

  # dconf / gsettings 需要能定位 schema 才能解析 org.gnome.desktop.interface。
  # 原先在系统层用 environment.sessionVariables 声明，这里下沉到用户会话。
  home.sessionVariables.GSETTINGS_SCHEMA_DIR = "${gsettingsSchemas}/share/gsettings-schemas/${gsettingsSchemas.name}/glib-2.0/schemas";

  # 主题相关的会话变量。原先由系统层 modules/nixos/desktop/default.nix 的
  # environment.sessionVariables 提供，这里等价下沉到用户会话。
  #
  # GTK_THEME 是兜底：dconf 优先，但 dms-mode-hook 要等 DMS 启动才写
  # dconf，在那之前部分 GTK 应用（如 pwvucontrol）会用默认主题；显式写一遍
  # 确保所有 GTK 进程都用 Darkly。
  #
  # XCURSOR_THEME / XCURSOR_SIZE：光标主题。Hyprland 会话里
  # custom.lua.in 也用 hl.env 设了同样两项（给纯 X11 / X Toolkit 客户端），
  # 两处并存是既有情况，本次下沉未改动 custom.lua.in。
  home.sessionVariables = {
    GTK_THEME = "Darkly";
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "48";
  };
}
