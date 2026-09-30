# 图形 / 媒体 / 日常桌面应用（用户 profile）。
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    vscode-fhs # 编辑器（仓库维护 / 日常开发）
    kdePackages.koko
    kdePackages.kdenlive
    kdePackages.kolourpaint
    kdePackages.kalk
    kdePackages.kget
    kdePackages.kdeconnect-kde # KDE Connect（手机与电脑互联）
    scrcpy # Android 投屏
    qtscrcpy # QtScrcpy（带 GUI 的 Android 投屏）
    qbittorrent
    haruna
    fooyin
    gimp-with-plugins
    mpv
    mpvpaper
    kazumi
    vesktop
    bilibili
    thunderbird
    firefox
  ];
}
