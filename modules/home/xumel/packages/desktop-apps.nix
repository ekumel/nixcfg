# 图形 / 媒体 / 日常桌面应用（用户 profile）。
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    vscode-fhs # 编辑器（仓库维护 / 日常开发）
    kdePackages.gwenview
    kdePackages.kdenlive
    kdePackages.kolourpaint
    kdePackages.kget
    amarok
    gimp-with-plugins
    mpv
    mpvpaper
    kazumi
    vesktop
    thunderbird
  ];
}
