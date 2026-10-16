# denial：denialwm/denial —— Rust + Smithay + Flutter 的 Wayland 合成器。
#
# 仅启用 programs.denial 模块（模块内部已经处理：
#   - 把 Denial 的 overlay 加到 host 的 pkgs（host native 依赖自动对齐）
#   - .desktop session 条目写进 wayland-sessions 目录
#   - 自带 Settings portal + systemd user unit
#   - xdg-desktop-portal-wlr（截图/录屏）/ Xwayland / polkit /
#     realtime scheduling / CJK fallback 字体
# ），不碰 DM、默认 session、autologin —— 所以 Hyprland + DMS + greetd
# 链路不受影响，denial 只是 greetd 会话菜单里的另一个选项。
#
# inputs.denial 是 flake input（dev 分支，flake.nix 注释里解释了为什么
# 不跟 host 的 nixpkgs），nixosModules.denial 暴露在 flake output 上。
{
  inputs,
  ...
}:
{
  imports = [ inputs.denial.nixosModules.denial ];

  programs.denial.enable = true;
}