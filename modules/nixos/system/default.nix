# 系统空间入口：纯 import 清单，不夹带任何配置。
# 由 hosts/nixos/configuration.nix 经 flake.modules.nixos.system 引入。
# 用户空间入口在 modules/home/xumel/default.nix，由 blueprint 从
# hosts/nixos/users/xumel.nix 挂到 home-manager。
{ ... }:

{
  imports = [
    ./boot.nix
    ./nix.nix
    ./networking.nix
    ./users.nix
    ./shell.nix
    ./audio.nix
    ./fonts.nix
    ./input-method.nix
    ./virtualisation.nix
    ./gaming.nix
    ./nix-github-auth.nix
    ./desktop
    ./packages.nix
  ];
}
