# nvfetcher-sources.nix：把 nvfetcher 生成的 _sources/generated.nix 暴露为
# 一个 attrset，供整个仓库的 *.nix 包定义统一消费。
#
# 为什么放 lib/：
#   它是仓库范围内的"基础设施"——系统模块、用户模块与 packages/ 都要引用。
#   blueprint 只把 lib/default.nix 暴露为 flake.lib，本文件作为其内部
#   wrapper 与 default.nix 放在一起；生成的 _sources/ 与 nvfetcher.toml
#   放在仓库根，与 flake.nix 平级。
#
# 为什么多一层 wrapper：
#   _sources/generated.nix 是一个返回 attrset 的函数（接收 fetchgit /
#   fetchurl / fetchFromGitHub / dockerTools 作为参数），里面只放了
#   nvfetcher 跟踪的 src。如果每个消费者自己 callPackage 这个函数、
#   再选自己需要的 key，会重复 import + 暴露逻辑。
#
#   所以这里统一调一次 `callPackage ./nvfetcher-sources.nix { }`，得到一个已经
#   "扁平化"的 attrset：
#     sources = {
#       kelivo        = { pname, version, src };
#       genoffice     = { pname, version, src };
#       zedg          = { pname, version, src };
#       wechat        = { pname, version, src };
#       whisker-shell = { pname, version, src };
#       whisker-cli   = { pname, version, src };
#       outfit-fonts  = { pname, version, src };
#     }
#
#   消费者统一用 `flake.lib.sources pkgs`（见 lib/default.nix）拿到
#   sources，再注入具体包定义。
#
# 这文件是 generated 文件的人工包装，手动维护——结构稳定后基本不需要改。
# 跑 `nvfetcher -c ./nvfetcher.toml` 会重写 _sources/generated.nix
# （src / sha256），但本文件不需要改。
{
  fetchgit,
  fetchurl,
  fetchFromGitHub,
  dockerTools,
}:
import ../_sources/generated.nix {
  inherit
    fetchgit
    fetchurl
    fetchFromGitHub
    dockerTools
    ;
}
