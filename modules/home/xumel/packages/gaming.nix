# 游戏相关用户级配置：Bottles + 把 dwproton 注册为它的 Proton runner。
{ pkgs, perSystem, ... }:

let
  # 与 modules/nixos/system/gaming.nix 给 Steam 用的是同一个包
  # （packages/dwproton.nix，blueprint 暴露为 perSystem.self.dwproton）。
  dwproton = perSystem.self.dwproton;
in
{
  # Bottles：Wine 前缀管理器（跑 Windows 应用 / 游戏）。removeWarningPopup
  # 关掉“当前发行版不受支持”的启动弹窗（NixOS 不在官方支持列表内）。
  # 32 位运行库由 programs.steam 打开的 hardware.graphics.enable32Bit 提供。
  home.packages = [
    (pkgs.bottles.override { removeWarningPopup = true; })
  ];

  # 把 dwproton 作为自定义 Proton runner 暴露给 Bottles。
  # Bottles 启动时扫描 ~/.local/share/bottles/runners/*/，逐个用
  # toolmanifest.vdf 判定是否为 Proton runner（dwproton 的 toolmanifest
  # 带 compatmanager_layer_name=proton），因此直接把工具根软链进去即可。
  # runner 目录名必须带 "-"（Bottles 排序回退逻辑会按 "-" 切分版本号，
  # 无 "-" 的名字会 IndexError），所以用版本号 + 架构命名。
  # 软链目标在 /nix/store；Bottles 的 buildFHSEnv 沙箱已 `--bind /nix /nix`，
  # 沙箱内可正常读取（包括 Wine 启动时读 proton 的 files/）。
  xdg.dataFile."bottles/runners/${dwproton.version}-x86_64".source = dwproton.steamcompattool;
}
