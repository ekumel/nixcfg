# 游戏与 Proton 兼容层。
#
# Steam：走 NixOS 官方模块 programs.steam。开启后它会一并处理：
#   - hardware.graphics 的 32 位支持（很多 Windows 游戏需要）；
#   - hardware.steam-hardware（手柄 udev 规则）；
#   - 32 位 pipewire / alsa 支持（若对应服务已启用）。
#
# 注：Steam 主进程 / Big Picture / 游戏 overlay 的光标不走
# XCURSOR_THEME，wrap 二进制会破坏字体加载且改不了光标，故不在此处
# 干预；唯一已知的"半生效"路径是 Steam 启动项里给单个游戏加
# `env XCURSOR_THEME=Bibata-Modern-Ice %command%`。
#
# dwproton：第三方 Proton 分支（Dawn Winery，基于 Proton-CachyOS），
# nixpkgs 不收录。包定义在 packages/dwproton.nix（system / users 共用），
# 版本与 src 由 flake.nix 的 dwproton URL input 跟踪上游 dawn.wine release。
# 用 programs.steam.extraCompatPackages 注入后，Steam 重启
# 即可在「设置 → 兼容性 → 强制使用特定 Steam Play 兼容性工具」里选到它。
#
# Bottles（Wine 前缀管理器）与把 dwproton 注册为它的 Proton runner 在
# modules/home/xumel/packages/gaming.nix。
{ perSystem, pkgs, ... }:

{
  programs.steam = {
    enable = true;
    # packages/dwproton.nix 由 blueprint 暴露为 perSystem.self.dwproton。
    extraCompatPackages = [ perSystem.self.dwproton ];
  };
  environment.systemPackages = with pkgs; [
    steam-run
  ];
}
