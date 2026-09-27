# Hyprland：合成器本体、XDG portal 与会话运行时工具。
# 系统级只负责“装好并注册会话”，用户级配置（~/.config/hypr 的 Lua 配置、
# 键位、自动启动等）由 modules/home/xumel/programs/hyprland.nix 通过
# home-manager 写入。
#
# 合成器使用上游 Hyprland flake 的 main 包（为了 wobble 等新特性），而不是
# nixpkgs 里的 0.56.2；产物经 hyprland.cachix.org 缓存替换。注意：这里只把
# inputs.hyprland 的包赋给 programs.hyprland.package，pkgs.hyprland 仍是
# nixpkgs 版本。插件要能被加载，必须用同一个包构建（见
# modules/home/xumel/programs/hyprland.nix 的 scrollOverview）。
{ inputs, pkgs, ... }:

{
  programs.hyprland = {
    enable = true;
    # 允许运行 X11 应用（默认开启）。
    xwayland.enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  # 会话中会被 Hyprland 键位 / 自动启动直接调用的工具。
  # 启动器 / 剪贴板 / 通知 / 锁屏 / 电源菜单 / 配色均由 DMS 提供
  # （见 desktop/dms.nix 与 modules/home/xumel/programs/hyprland.nix）。
  environment.systemPackages = with pkgs; [
    grim # 截图
    slurp # 区域选择
    wl-clipboard # wl-copy / wl-paste
    hyprpicker # 取色器
    libnotify # notify-send
    procps # pgrep/pkill（脚本与 shell 组件常用的进程查询）
    glib # gio（部分应用的默认程序解析）
    trash-cli # 回收站
    hyprpolkitagent # polkit 认证代理

    pwvucontrol
  ];

  # Hyprland 由 greetd 直接拉起（未走 UWSM），不会激活 systemd 的
  # graphical-session.target。而 xdg-desktop-portal 1.22 起带了
  # `Requisite=graphical-session.target`，该目标未激活时 portal 的 D-Bus
  # 激活会以 “startup job failed / dependency failed” 告终（Zed 等应用的
  # Portal request 即因此失败）。graphical-session.target 自身
  # `RefuseManualStart=yes`，只能被依赖拉起；DMS 会在会话初始化时写入
  # ~/.config/systemd/user/hyprland-session.target（BindsTo=
  # graphical-session.target），由用户空间配置在 Hyprland 启动时拉起
  # （见 modules/home/xumel/programs/hyprland.nix），这里不需要额外定义。

  # XDG portal：
  #   - 默认实现用 hyprland + gtk（与上游 hyprland-portals.conf 的
  #     `default=hyprland;gtk` 一致：截图/录屏走 hyprland，其余回退 gtk）。
  #   - 文件选择器单独指定为 KDE，使用 KDE 的对话框（支持缩略图 / 网络位置）。
  # programs.hyprland 已负责 xdg.portal.enable 与 hyprland portal 本身，
  # 这里只补充 gtk / kde 后端并覆盖配置。
  xdg.portal = {
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.kdePackages.xdg-desktop-portal-kde
    ];

    config.hyprland = {
      default = [
        "hyprland"
        "gtk"
      ];
      "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
    };
  };
}
