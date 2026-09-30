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

    # ---- 第三方预编译包 / 主题 ----
    #
    # 这些源以前由 npins / nvfetcher 跟踪，现在统一收进 flake inputs，共用
    # `flake.lock`。每个 input 都设 `flake = false`，因此 `flake.inputs.<name>`
    # 在求值时直接得到一个 store path 字符串（prefetch 后的单文件或 tarball
    # 解包目录），packages/*.nix 与 system 模块可直接把它当 src 用，不再需要
    # `flake.lib.sources` 包装层。
    #
    # 升级脚本：scripts/update-third-party.sh（~150 行 bash）。
    #   - URL 类（带版本号字面量）：脚本探测上游 → 改 flake.nix 的 url 字段
    #     → `nix flake lock --update-input <name>` 重锁；
    #   - git 类（darkly-gtk）：`nix flake update --update-input darkly-gtk`
    #     即可，flake.lock 会自动滚到 main 最新提交。
    #
    # 不要直接 `nix flake update`（无参）——它会把 nixpkgs / Hyprland 等全滚，
    # 那些由各上游版本节奏控制，不在本脚本范围内。

    # GitHub release 预编译 Flutter app（version 与 build number 在 URL 里）
    kelivo = {
      url = "https://github.com/Chevey339/kelivo/releases/download/v1.2.6/Kelivo_linux_1.2.6%2B73.tar.gz";
      flake = false;
    };

    # GitHub release AppImage
    genoffice = {
      url = "https://github.com/genspark-ai/genoffice/releases/download/v0.11.0/GenOffice-0.11.0.AppImage";
      flake = false;
    };

    # GitHub release tarball（含 usr/{bin,lib,share} 树）
    zedg = {
      url = "https://github.com/WenYin-Community/zed-globalization/releases/download/v1.21.0/zedg-zh-cn-linux-x86_64-v1.21.0.tar.gz";
      flake = false;
    };

    # 微信 Linux AppImage：QQ 官方 dldir 不带版本号（URL 永远不变）。
    # 版本号通过抓取 https://linux.weixin.qq.com/ 解析，
    # 见 scripts/update-third-party.sh 里的 wechat_updater。
    wechat = {
      url = "https://dldir1.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
      flake = false;
    };

    # GitHub release cursor tarball
    bibata-modern-ice = {
      url = "https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz";
      flake = false;
    };

    # GoQuark：ButterFuture 出品的非官方夸克网盘 CLI / TUI / MCP 客户端。
    # 单文件预编译 Go 静态二进制（无 .so），打包时直接 install 到 $out/bin/。
    goquark = {
      url = "https://github.com/ButterFuture/GoQuark/releases/download/v1.0.3/goquark_1.0.3_linux_amd64";
      flake = false;
    };

    # 百度网盘 Linux 客户端（unfree）。上游仅发 .deb，
    # URL 路径模式：LinuxGuanjia/<version>/baidunetdisk_<version>_amd64.deb。
    baidunetdisk = {
      url = "https://issuecdn.baidupcs.com/issue/netdisk/LinuxGuanjia/4.17.7/baidunetdisk_4.17.7_amd64.deb";
      flake = false;
    };

    # Forgejo（dawn.wine）release tarball，非 GitHub；
    # 探测走 Gitea v1 API：/api/v1/repos/<owner>/<repo>/releases/latest
    dwproton = {
      url = "https://dawn.wine/dawn-winery/dwproton/releases/download/dwproton-11.0-13/dwproton-11.0-13-x86_64.tar.xz";
      flake = false;
    };

    # git ref：跟踪 wrymt/darkly-gtk 的 main 分支最新提交。
    # flake.lock 会落具体 commit 与 narHash；`nix flake update darkly-gtk`
    # 即可升到 main 最新。版本字符串（unstable-YYYY-MM-DD）由脚本从 lock
    # 里的 lastModified 派生，同步写回 modules/nixos/desktop/gtk.nix。
    darkly-gtk = {
      url = "github:wrymt/darkly-gtk";
      flake = false;
    };

    # monocode：hardbeat920/monocode 的 GitHub Release .deb（Linux x86_64）。
    # 打包策略与 baidunetdisk 同款（.deb 解包 + buildFHSEnv 封装），
    # 详细见 packages/monocode.nix 顶部注释。.deb 命名规律
    # `MonoCode_<version>_amd64.deb`，version 与 src URL 字面量写在本
    # input 的 url 字段；update-third-party.sh monocode 探测流程同
    # baidunetdisk（手动版）或将来实现 updater_monocode 自动化版。
    monocode = {
      url = "https://github.com/hardbeat920/monocode/releases/download/v0.5.0/MonoCode_0.5.0_amd64.deb";
      flake = false;
    };

    # mcode：MiniMax-AI 发布的 npm CLI tarball（@minimax-ai/code）。
    # 与 monocode 不同，tarball 是 universal（不区分系统架构）：npm
    # publish 时同一个 .tgz 同时支持 linux / darwin（native 模块
    # better-sqlite3 通过 npm optionalDependencies + prebuild-install
    # 选平台 binding）。
    # 升级跑 `./scripts/update-third-party.sh mcode`：脚本从 npm
    # registry dist-tags API 拿最新 version + tarball URL + shasum，
    # 重生 lockfile，用 prefetch-npm-deps 算 npmDepsHash，三处字面量
    # 一次性同步更新（详细见 packages/mcode.nix 顶部注释）。
    mcode = {
      url = "https://registry.npmjs.org/@minimax-ai/code/-/code-0.5.9.tgz";
      flake = false;
    };
  };

  # outputs 由 blueprint 按目录约定生成：
  #   hosts/<hostname>/configuration.nix -> nixosConfigurations.<hostname>
  #   hosts/<hostname>/users/<user>.nix  -> home-manager 用户（随主机一起求值）
  #   modules/nixos/<name>               -> flake.modules.nixos.<name>（nixosModules.<name>）
  #   modules/home/<name>                -> flake.modules.home.<name>（homeModules.<name>）
  #   packages/<name>.nix                -> packages.<system>.<name>（并自动进 flake checks）
  #   formatter.nix                      -> formatter.<system>（nix fmt）
  #   lib/default.nix (optional)         -> flake.lib（当前未用，仓库内仅留工具函数）
  outputs =
    inputs:
    inputs.blueprint {
      inherit inputs;

      # 只面向这台 x86_64-linux 机器，避免 flake check 去求值其它系统。
      systems = [ "x86_64-linux" ];

      # 系统空间与 packages/ 共用同一份 nixpkgs 实例：blueprint 会把它作为
      # nixpkgs.pkgs 注入主机，所以 nixpkgs.config 只能在这里声明
      # （modules/nixos/nix.nix 不能再设 nixpkgs.config，会冲突）。
      nixpkgs.config.allowUnfree = true;
    };
}
