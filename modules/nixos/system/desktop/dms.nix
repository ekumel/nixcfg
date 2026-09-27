# DankMaterialShell（DMS）桌面 shell（系统级安装）。
#
# 包与模块都来自 flake input `dms`（见 flake.nix）。DMS 接管 shell 功能：
# 状态栏、启动器（Spotlight）、通知中心、剪贴板历史、锁屏、电源菜单，
# 以及配色（内置 matugen 动态主题）。
#
# 配色：`enableDynamicTheming` 会安装 matugen 并由 DMS 在壁纸/主题变化时
# 生成 GTK / Qt(qtengine) / kitty / Zen / VSCode 等主题文件。
#
# 启动方式：`systemd.enable` 生成 dms.service，绑定 graphical-session.target；
# 用户会话由 Hyprland 启动的 hyprland-session.target 拉起该目标
# （该 target 由 DMS 写入 ~/.config/systemd/user/，见
# modules/home/xumel/programs/hyprland.nix），无需在合成器配置里再 exec dms。
{ inputs, pkgs, ... }:

{
  imports = [
    inputs.dms.nixosModules.dank-material-shell
  ];

  programs.dank-material-shell = {
    enable = true;
    # 由 systemd 用户服务自动启动（默认关闭，须显式开启）。
    systemd.enable = true;
    # 让 DMS 接管 Material You 配色（安装 matugen 并在运行时生成主题）。
    enableDynamicTheming = true;
  };

  # dsearch：DMS Spotlight 的文件搜索后端。
  programs.dsearch.enable = true;

  environment.systemPackages = with pkgs; [
    ffmpeg
    amdgpu_top
    libinput
    cups-pk-helper
    kdePackages.ocean-sound-theme
    ccal
    ydotool
    ddcutil
    wlr-utils
  ];
}