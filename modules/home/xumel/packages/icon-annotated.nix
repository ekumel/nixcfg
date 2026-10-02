# 需要套 Colloid 风格背景蒙版图标的小众应用。
#
# 原理与可调参数见 lib/icon-overrides.nix。默认：白底 + 18.75% 圆角 + 75% 缩放。
# 参数可覆盖，例如：
#   iconBadged { pname = "kazumi"; pkg = kazumi; cornerRadius = 256; }      # 圆形
#   iconBadged { pname = "piliplus"; pkg = piliplus; bg = "transparent"; }  # 无背景
#   iconBadged { pname = "x"; pkg = x; scale = 0.6; cornerRadius = 0; }     # 紧凑方块
{
  pkgs,
  lib,
  flake,
  ...
}:

let
  iconBadged =
    {
      pname,
      pkg,
      bg ? null,
      cornerRadius ? null,
      scale ? null,
      viewBox ? null,
    }:
    let
      extra = lib.filterAttrs (_: v: v != null) {
        inherit
          bg
          cornerRadius
          scale
          viewBox
          ;
      };
      base = { inherit pname pkg; };
    in
    # 走 flake.lib 而非相对路径 ../../../../lib/：这样本模块被别的 flake
    # 消费时仍能解析。
    flake.lib.icon-overrides pkgs (base // extra);
in
{
  home.packages = with pkgs; [
    # 终端文件管理器：原包不带 .desktop，覆盖无害
    (iconBadged {
      pname = "yazi";
      pkg = yazi;
      scale = 1.00;
    })
    # Telegram 第三方客户端
    (iconBadged {
      pname = "com.ayugram.desktop";
      pkg = ayugram-desktop;
      bg = "#39314F";
    })
    # 全能播放器
    (iconBadged {
      pname = "SPlayer-Next";
      pkg = splayer-next;
      scale = 0.75;
    })
    # 第三方 B 站客户端
    (iconBadged {
      pname = "piliplus";
      pkg = piliplus;
      scale = 1.00;
    })
  ];
}
