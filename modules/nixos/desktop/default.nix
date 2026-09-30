# 桌面环境：Hyprland 合成器 + DankMaterialShell（含动态配色）
# + greetd/DankGreeter 图形登录器。
{ pkgs, ... }:

{
  imports = [
    ./hyprland.nix
    ./niri.nix
    ./dms.nix
    ./icons.nix
    ./gtk.nix
    ./qt.nix
    ./greeter.nix
    ./dolphin.nix
  ];

  # 显卡与触控板支持。
  hardware.graphics.enable = true;
  services.libinput.enable = true;

  # Wayland 下常见应用（Electron / Firefox）的原生 Wayland 提示，
  # 以及会话光标主题（含 X11 / GTK / Qt 客户端）。
  # 光标：Bibata-Modern-Ice（XCursor；上游未发 hyprcursor 版本，Hyprland
  # 在 enable_hyprcursor=true 时找不到主题会自动回退到 XCursor）。
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "48";
    # GTK_THEME：兜底。dconf 优先，但 dms-mode-hook 在 DMS 启动前还没写
    # 时，部分 GTK 应用（如 pwvucontrol）会用默认主题；显式写一遍确保
    # 所有 GTK 进程都用 Darkly。
    GTK_THEME = "Darkly";
  };

  # 桌面会话依赖的服务：电源/亮度信息、性能配置、蓝牙（无 shell 时也保留，
  # 供设置面板与硬件按键使用）。
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  # udisks2 守护进程 + udisksctl CLI，给 yazi 等应用挂载/卸载 U 盘、外设块设备。
  services.udisks2.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Secret Service（D-Bus org.freedesktop.secrets），给 Zed / Chromium / VS Code
  # 等通过 libsecret 读写密钥的应用使用。
  # kdePackages.kwallet 提供两个守护进程：
  #   - ksecretd：org.freedesktop.secrets 实现（libsecret 客户端的入口），
  #     顺带承担 xdg-desktop-portal-kwallet 与旧版 kwallet API 兼容；
  #   - kwalletd6：新的 org.kde.kwalletd6 服务，给走 KF6 Wallet 的应用。
  # 二进制与对应的 .service 文件一起被安装，D-Bus session 也会按需激活；
  # 在 Hyprland 会话启动时由 modules/home/xumel/programs/hyprland.nix 显式
  # 拉起，避免 libsecret 在首请求时被阻塞。
  environment.systemPackages = [ pkgs.kdePackages.kwallet ];

  # 默认应用关联（xdg-open、文件管理器双击时使用）：
  # 目录 → Dolphin，图片 → Gwenview，视频 → mpv。
  # 写入 /etc/xdg/mimeapps.list 作为系统级默认，用户可在
  # ~/.config/mimeapps.list 中覆盖。
  xdg.mime.defaultApplications = {
    "inode/directory" = "org.kde.dolphin.desktop";
    "image/*" = "org.kde.gwenview.desktop";
    "video/*" = "mpv.desktop";
  };
}
