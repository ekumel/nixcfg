# 网络（通用部分；主机名见 hosts/<host>/settings.nix）。
{ ... }:

{
  networking.networkmanager.enable = true;

  networking.firewall.enable = true;
}
