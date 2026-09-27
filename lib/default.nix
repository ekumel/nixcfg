# 仓库范围的 Nix 辅助函数，blueprint 会把它暴露为 flake.lib。
#
# sources：nvfetcher 生成源的统一入口。packages/ 下的包定义与需要
# sources 的系统模块（desktop/gtk.nix、desktop/icons.nix）都从这里取；
# wrapper 的职责说明见 fetch/sources.nix 头部。
{ ... }:

{
  sources = pkgs: pkgs.callPackage ../fetch/sources.nix { };
}
