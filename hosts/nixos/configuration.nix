# 主机入口（机器相关）。
# 只负责汇总：本机专属设置 + 通用系统模块 + home-manager 全局设置。
# 用户列表由 blueprint 从 hosts/nixos/users/ 自动生成（见 users/xumel.nix），
# useGlobalPkgs / useUserPackages 也由 blueprint 默认开启。
{ flake, ... }:

{
  imports = [
    ./hardware.nix
    ./settings.nix

    # 通用系统模块：modules/nixos/system/（blueprint 暴露为
    # flake.modules.nixos.system）。
    flake.modules.nixos.system
  ];

  # 激活时遇到已存在的真实文件先备份为 *.hm-backup（例如 DMS 运行时
  # 重写过的 ~/.config/qtengine/config.json），不会直接删除。
  home-manager.backupFileExtension = "hm-backup";
}
