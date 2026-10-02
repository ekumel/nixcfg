# hyprland-scroll-overview.nix：用系统正在运行的 Hyprland 构建滚动工作区
# 概览插件（类 niri 的 scroll overview）。
#
# 为什么必须单独构建而不能用 pkgs.hyprlandPlugins 的现成包：
#   Hyprland 插件在加载时做 PLUGIN_INIT 的 API 哈希校验，编译时用的 Hyprland
#   版本与运行中的不一致就会被拒绝加载（配置项 plugin.scrolloverview.* 会
#   一直报 unknown config key）。本机合成器由 programs.hyprland.package 设为
#   inputs.hyprland 的 main 包（见 modules/nixos/desktop/hyprland.nix），
#   所以这里必须传入同一个包。若误用 nixpkgs 自带的 pkgs.hyprland
#   （版本更旧），插件会加载失败。
#
# 构建步骤与上游 flake 的 packages.scrolloverview 相同。
# 调用方：modules/home/xumel/programs/hyprland.nix。
{
  pkgs,
  # lib 只用于 meta 里的 license / platforms，与其它 lib 函数签名一致。
  lib,
  flake,
  # 与系统合成器完全一致的 Hyprland 包，由调用方从
  # inputs.hyprland.packages.<system>.hyprland 传入。
  hyprland,
}:

pkgs.hyprlandPlugins.mkHyprlandPlugin {
  pluginName = "scrolloverview";
  version = "unstable";
  src = flake.inputs.hyprland-scroll-overview;

  inherit hyprland;

  buildInputs = [ pkgs.lua5_4 ];
  dontUseCmakeConfigure = true;

  buildPhase = ''
    runHook preBuild
    export SCROLLOVERVIEW_BUILD_VERSION="unstable"
    make all
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib
    mv scrolloverview.so $out/lib/libscrolloverview.so
    runHook postInstall
  '';

  meta = {
    description = "Scrollable workspace overview plugin for Hyprland";
    homepage = "https://github.com/yayuuu/hyprland-scroll-overview";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
