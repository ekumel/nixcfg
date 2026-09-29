{ pkgs, lib, ... }:
{
  # 桌面环境组件（Wayland compositor: niri）
  environment.systemPackages = with pkgs; [
    xwayland-satellite
  ];
  programs.niri.enable = true;

  xdg.portal = {
    extraPortals = [
      pkgs.xdg-desktop-portal-wlr
      pkgs.xdg-desktop-portal-gtk
      pkgs.kdePackages.xdg-desktop-portal-kde
    ];

    config.niri = lib.mkForce {
      default = [
        "wlr"
        "gtk"
      ];
      "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
    };
  };
}
