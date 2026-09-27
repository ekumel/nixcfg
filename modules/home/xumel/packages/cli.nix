# 命令行 / 基础工具（用户 profile）。
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cava
    fastfetch
    bottom
    brightnessctl # 亮度键（见 programs/hyprland.nix 键位）

    # Rust 工具链：改用 nixpkgs 的 rustc/cargo/rust-analyzer。
    # 不再用 rustup：NixOS 上 rustup 下载的工具链依赖 /lib64/ld-linux 解释器，
    # 未启用 programs.nix-ld 时无法运行（本机没有 nix-ld，rustup 里也没有工具链）。
    # rust-analyzer 由 Zed 的内置 Rust 支持在 PATH 中自动发现并使用。
    rustc
    cargo
    rust-analyzer
    rustfmt
    clippy

    # 仓库维护：nvfetcher 跟踪 fetch/ 的第三方源，nixfmt 格式化本仓库。
    nvfetcher
    nixfmt

    # 密钥维护：ragenix 加解密 secrets/*.age（规则见 secrets/secrets.nix）。
    ragenix
  ];
}
