# xumel 的用户空间入口。
# 共享的用户模块在 modules/home/xumel/，由 blueprint 暴露为
# flake.homeModules.xumel；这里只把它挂到本机。
# （blueprint 还会据此生成独立的 homeConfigurations."xumel@nixos"。）
{ flake, ... }:

{
  imports = [
    flake.homeModules.xumel
  ];
}
