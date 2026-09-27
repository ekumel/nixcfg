# Qt 应用统一外观：qtengine（平台主题引擎）+ Darkly（应用样式）。
#
# 分工：
#   - 系统层只安装引擎与样式（Darkly 的 Qt6 样式插件），并写出
#     /etc/xdg/qtengine/config.json 作为兜底。
#   - Qt 的样式 / 图标 / 字体 / 杂项配置放在用户层
#     （modules/home/xumel/programs/qt.nix 的 ~/.config/qtengine/config.json）。
#     原因：DMS 的动态主题会重写该用户文件里的 theme.colorScheme /
#     theme.iconTheme（保留其它键），而 ~/.config 优先于 /etc/xdg；
#     只有把 style / 字体放进用户文件，DMS 合并配色时才不会把它们丢掉。
{ inputs, pkgs, ... }:

let
  # Darkly 的 Qt6 样式包（来自 upstream flake）。
  # 只装 Qt6：upstream 仍提供 darkly-qt5，但它依赖已被 nixpkgs 移除的旧 KF5
  # 组件（libsForQt5.kcmutils），无法跟随本仓库的 nixpkgs；本机也没有 Qt5 应用。
  darkly = inputs.darkly.packages.${pkgs.stdenv.hostPlatform.system}.darkly-qt6;
in
{
  imports = [
    inputs.qtengine.nixosModules.default
  ];

  # 样式插件需要进入系统 profile，QT_PLUGIN_PATH（由 qt.enable 设置）才能找到它。
  environment.systemPackages = [
    darkly
  ];

  programs.qtengine.enable = true;
}
