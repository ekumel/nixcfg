# xumel 的用户空间入口（home-manager 模块）。
# 由 blueprint 暴露为 flake.homeModules.xumel，系统侧挂载见
# hosts/nixos/users/xumel.nix；这里只汇总用户侧配置。
{ inputs, ... }:

{
  imports = [
    # nixvim 走 home-manager 模块（编辑器属于用户空间）。
    inputs.nixvim.homeModules.nixvim

    ./packages
    ./programs/dms-mode-hook.nix
    ./programs/fish.nix
    ./programs/hyprland.nix
    ./programs/input-method.nix
    ./programs/matugen.nix
    ./programs/nixvim
    ./programs/qt.nix
    ./programs/xsettingsd.nix

    ./secrets.nix
  ];

  # home-manager 状态版本，与系统 stateVersion 保持一致
  # （见 hosts/nixos/settings.nix）。
  home.stateVersion = "25.11";
}
