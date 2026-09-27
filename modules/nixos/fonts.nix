# 字体：中文（霞鹜文楷）+ 等宽/图标（Maple Mono NF CN，
# 自带 Nerd Font 图标与中文），另保留 emoji 字体。
{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    lxgw-wenkai
    maple-mono.NF-CN
    wqy_zenhei
    noto-fonts-color-emoji
  ];

  fonts.fontconfig.defaultFonts = {
    serif = [ "LXGW WenKai" ];
    sansSerif = [ "LXGW WenKai" ];
    monospace = [ "Maple Mono NF CN" ];
    emoji = [ "Noto Color Emoji" ];
  };
}
