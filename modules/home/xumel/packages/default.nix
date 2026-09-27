# 用户级软件包入口：纯 import 清单，不夹带任何配置。
#
# 按用途拆成多个文件，避免单文件越堆越长。home-manager 的
# `home.packages` 是可合并 list，每个子模块各自声明自己那部分，
# 最终合并进同一个用户 profile；这个 default.nix 只负责汇总。
{ ... }:

{
  imports = [
    ./cli.nix
    ./desktop-apps.nix
    ./icon-annotated.nix
    ./third-party.nix
    ./browsers.nix
    ./gaming.nix
  ];
}
