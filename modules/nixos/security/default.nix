# 系统安全服务聚合入口：当前只有 ClamAV。
{ ... }:

{
  imports = [
    ./clamav.nix
  ];
}
