# 图形 / 媒体 / 日常桌面应用（用户 profile）。
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    vscode-fhs # 编辑器（仓库维护 / 日常开发）
    kdePackages.koko
    kdePackages.kdenlive
    kdePackages.kolourpaint
    kdePackages.kalk
    kdePackages.kdeconnect-kde # KDE Connect（手机与电脑互联）
    scrcpy # Android 投屏
    haruna
    fooyin
    gimp-with-plugins
    mpv
    mpvpaper
    kazumi
    vesktop
    bilibili
    thunderbird

    ayugram-desktop # Telegram 第三方客户端
    piliplus # 第三方 B 站客户端
  ];
  # 播放器：splayer-next（全能播放器）已下线，接替者是 third-party.nix 里的
  # perSystem.self.any-listen（私有音乐播放服务桌面端）。
  # 下载器：kget（KDE 单线程下载器）与 qbittorrent 已移除，
  # 由 third-party.nix 里的 fluxdown 统一承担（HTTP/FTP/BT/ED2K/HLS/DASH +
  # 浏览器扩展接管 magnet 链接）。
}
