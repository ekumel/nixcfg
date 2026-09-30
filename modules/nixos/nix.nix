# Nix 守护进程：实验特性、二进制缓存、垃圾回收、非自由软件。
{ config, ... }:

{
  nix.settings = {
    # 常用实验特性：flake 与新版 nix 命令。
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    auto-optimise-store = true;

    # Hyprland 的 Cachix 缓存。Hyprland flake（main）不由 Hydra 构建，
    # 不在 cache.nixos.org 里；上游用该缓存发布合成器及其依赖的预构建产物。
    # 见 flake.nix 的 hyprland input 与 wiki.hypr.land/nix/cachix。
    extra-substituters = [ "https://hyprland.cachix.org" ];
    extra-trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
    # 非 root 用户在 wheel 组时必须被信任，否则上面 client 指定的
    # substituters/keys 会被忽略（restricted setting）。
    trusted-users = [
      "root"
      "@wheel"
    ];
  };

  # 自动垃圾回收，避免 store 无限膨胀。
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # 每次 rebuild 后，只保留最近三代系统 generation。
  # 系统 profile 指向新 generation 后即触发删除，最近的（含当前）三代之外全部移除。
  systemd.services.prune-system-generations = {
    description = "Prune old NixOS system generations";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --delete-generations +3";
    };
  };

  # 把清理挂到 activation：nixos-rebuild switch 与系统启动时自动执行。
  system.activationScripts.prune-system-generations = ''
    ${config.systemd.package}/bin/systemctl start prune-system-generations.service || true
  '';

  # 注：allowUnfree 已上移到 flake.nix 的 blueprint nixpkgs.config：
  # blueprint 会把同一份 pkgs 实例作为 nixpkgs.pkgs 注入系统，
  # 这里再设 nixpkgs.config 会与 nixpkgs.pkgs 冲突。
}
