# 输入法：fcitx5（中文）。
{ pkgs, ... }:

{
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-gtk
      (fcitx5-rime.override {
        rimeDataPkgs = [ pkgs.rime-ice ];
      })
      qt6Packages.fcitx5-qt
      qt6Packages.fcitx5-chinese-addons
      qt6Packages.fcitx5-configtool
    ];
  };
}
