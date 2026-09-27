{
  description = "xumel 的 NixOS 配置（blueprint 目录约定 + home-manager + Hyprland / matugen）";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    blueprint = {
      url = "github:numtide/blueprint";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 密钥：ragenix（agenix 的 Rust 兼容实现）提供 age NixOS 模块。
    # 密文与规则在 secrets/，解密身份见 secrets/secrets.nix 注释。
    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms = {
      # 取新提交后替换下面的 rev。
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dank-greeter = {
      url = "github:AvengeMedia/dank-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    qtengine = {
      url = "github:kossLAN/qtengine";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darkly = {
      url = "github:Bali10050/Darkly";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland-scroll-overview = {
      url = "github:yayuuu/hyprland-scroll-overview/new-release";
      flake = false;
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      # nixvim 要求 nixpkgs 与自身保持一致（README/install docs 明确不建议 follows）。
      # nixvim 现在作为 home-manager 模块在用户空间导入
      # （见 modules/home/xumel/default.nix）。
    };
  };

  # outputs 由 blueprint 按目录约定生成：
  #   hosts/<hostname>/configuration.nix -> nixosConfigurations.<hostname>
  #   hosts/<hostname>/users/<user>.nix  -> home-manager 用户（随主机一起求值）
  #   modules/nixos/<name>               -> flake.modules.nixos.<name>（nixosModules.<name>）
  #   modules/home/<name>                -> flake.modules.home.<name>（homeModules.<name>）
  #   packages/<name>.nix                -> packages.<system>.<name>（并自动进 flake checks）
  #   lib/default.nix                    -> flake.lib
  outputs =
    inputs:
    inputs.blueprint {
      inherit inputs;

      # 只面向这台 x86_64-linux 机器，避免 flake check 去求值其它系统。
      systems = [ "x86_64-linux" ];

      # 系统空间与 packages/ 共用同一份 nixpkgs 实例：blueprint 会把它作为
      # nixpkgs.pkgs 注入主机，所以 nixpkgs.config 只能在这里声明
      # （modules/nixos/system/nix.nix 不能再设 nixpkgs.config，会冲突）。
      nixpkgs.config.allowUnfree = true;
    };
}
