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

    # Hyprland 暂时钉在渲染层大重构之前。
    #
    # 2026-09-26 起 Hyprland 做了一整轮 renderer 重构，把 IHyprRenderer 的
    # transient state 收进 render context（150debcf63c0 / 969b4b1117cd /
    # ba616caa9402 …，一路到 10-04）。结果是三处不兼容：
    #   - IHyprRenderer::m_renderPass / m_renderData / m_bBlockSurfaceFeedback
    #     被移除（0.56 的 RenderContext 取代）；
    #   - IPassElement 的 draw / needsLiveBlur / needsPrecomputeBlur /
    #     boundingBox / opaqueRegion 全部改成带 `Render::CRenderContext&` 参数；
    #   - renderRoundedShadow 签名变化。
    #
    # hyprland-scroll-overview 钉在 9/14 的 f08c5f7d（也是上游 new-release 分支
    # 的头，没有更新提交），编译不过。23118f9f7f24（09-22）已核验：三个成员
    # 都在、IPassElement 仍是无参签名，落在插件与重构之间的兼容窗口内。
    #
    # 放开时删掉 url 里的 rev 再 `nix flake update hyprland`，但要同时确认：
    #   1. hyprland-scroll-overview 上游已跟进新 API；
    #   2. DMS（钉在 10/04 的 585827e7）仍能对当时的 Hyprland 编译通过——
    #      它比插件新，混用时先崩的可能是它而不是插件。
    hyprland.url = "github:hyprwm/Hyprland/23118f9f7f24db7447069949c2df7fcd8ba380d0";

    # Firefox Nightly：nix-community/flake-firefox-nightly。它把 nixpkgs-mozilla
    # 的各通道预编译包（release / esr / beta / devedition / nightly）打成
    # `packages.<system>.firefox-*-bin`，由 CI 每小时重跑 flake.lock，所以是
    # 「钉住的 nightly」而不是 nixpkgs 里那个几乎不动的 firefox-nightly。
    #
    # **不要给它加 `inputs.nixpkgs.follows = "nixpkgs"`。** 它的 packages 由它
    # 自带的 nixpkgs（nixos-unstable-small）+ lib-aggregate 产出的 overlay 构造；
    # 强行 follow 本 flake 的 nixos-unstable 会换掉那套 nixpkgs，
    # `firefox-nightly-bin` 随即求值失败。
    #
    # 取用：`inputs.firefox-nightly.packages.${pkgs.system}.firefox-nightly-bin`
    # （见 modules/home/xumel/packages/browsers.nix）。
    # 升级：`nix flake update firefox-nightly`——上游 CI 约每小时才更新一次，
    # 所以这个 input 拿到的版本比 Mozilla 官方发布最多滞后约 1 小时。
    firefox-nightly.url = "github:nix-community/flake-firefox-nightly";

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

    # artcraft：ipeglin/artcraft-nix —— ArtCraft（storytold）全家桶的 Nix 打包。
    # 官方是开源的 Adobe 套件替代品，走 AppImage 分发，由上游拆包 + autoPatchelf
    # 成常规 derivation（AppImage 不再塞图形栈，Rust GUI 只链 glibc/libgcc，
    # 其余库运行时 dlopen，打包时挂在 RPATH 上）。
    #
    #   PhotoCraft  = Photoshop    图像 / 分层 PSD
    #   VectorCraft = Illustrator  矢量 / SVG / PDF
    #   DesignCraft = InDesign     排版
    #   LightCraft  = Lightroom    照片管理 / raw 显影
    #   FilmCraft   = Premiere Pro 视频剪辑
    #   EffectCraft = After Effects 合成 / 特效
    #   PdfCraft    = Acrobat      PDF 阅读 / 合并 / 拆分 / 加密
    #
    # ArtCraft 没有 Word / PPT / 表格 对应品，本机也没装它们；真要补的时候
    # 走 nixpkgs 的 libreoffice-fresh，不要指望这个 input。
    #
    # 只提供 x86_64-linux 产物，本机系统正是 x86_64-linux（见 flake 里的
    # systems 声明），无需判断平台。
    #
    # **可以直接 follows。** 上游自己那份 nixpkgs 只用于 CI 构建 packages
    # 输出（`nixosModules` 走的是本机传入的 pkgs），follows 之后不产生第二份
    # nixpkgs 求值，跟仓库其余 input 的写法一致。
    #
    # 升级：`nix flake update artcraft`。上游 CI 每天扫一次上游 release，
    # 通过验证的版本写进它的 versions.json 并随仓库提交，所以 update 即可
    # 拿到新版本；每个 app 的所有历史稳定版都保留（`<app>_<x>_<y>_<z>` 钉版本）。
    artcraft = {
      url = "github:ipeglin/artcraft-nix";
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

    # denial：denialwm/denial —— Rust + Smithay + Flutter 的 Wayland 合成器，
    # 自带玻璃特效 shell / Settings / 自研 session / 屏幕分享。上游提供
    # 一等 NixOS 模块（programs.denial），文档明确「不会启用 DM、改默认
    # session 或自动登录」，只是把 .desktop 写到 wayland-sessions 目录里，
    # 供 greetd 在会话菜单里出现；现有的 Hyprland + DMS + greetd/dank-greeter
    # 链路不受影响。
    #
    # 钉在 dev 分支：每次 `nix flake update denial` 跳到 dev 最新 commit。
    #
    # **不要 follows nixpkgs。** 上游 flake.nix 注释：
    #   "There is no need to make Denial's Nixpkgs input follow the host's
    #    input; doing so also changes the engine cache key."
    # 它自己锁了一份 nixos-26.05 来构建 Flutter engine，engine 缓存键靠这份
    # 锁独立存在。host 的 native 依赖对齐由 nixosModules.denial 内部的
    # nixpkgs.overlays 把 host 的 pkgs 灌进 denial 包里解决（不替换 denial
    # 自己的 engine producer 锁），详见 packaging/nixos/README.md。
    denial = {
      url = "github:denialwm/denial/dev";
    };

    # llm-agents：numtide 维护的 AI agent / 工具 nix 包集合（每日自动
    # 重锁），覆盖 opencode / claude-code / gemini-cli 等几十种 CLI 与
    # desktop 客户端。我们用它装 opencode2-desktop
    # （packages/opencode2-desktop/），替换原先自维护的 mcode（npm
    # @minimax-ai/code）与 pi-agent（npm @earendil-works/pi-coding-agent）
    # 两个 npm CLI 打包：llm-agents 上游直接交付预编译产物，免去
    # buildNpmPackage + npmDepsHash 的维护负担，升级靠上游每日重锁，
    # 我们这边只需 `nix flake update llm-agents`。
    # 取用：inputs.llm-agents.packages.${pkgs.system}.opencode2-desktop
    # （见 modules/home/xumel/packages/third-party.nix）。
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
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

    # voicefox：emoeem/voicefox —— Rust + ratatui + libmpv 的终端音乐
    # 播放器（TUI，多音源 / 歌词 / 下载 / 收藏）。上游 release 发的是
    # 预编译 zip，asset 名按架构区分（voicefox-linux-x86_64.zip /
    # voicefox-linux-aarch64.zip），tag 形如 v0.4.0。zip 里只有
    # voicefox 一个可执行文件，没有附带 libmpv——Linux 侧必须由系统
    # 提供 libmpv（见 packages/voicefox.nix 的 patchelf 说明）。
    # 升级跑 `./scripts/update-third-party.sh voicefox`：脚本探测
    # GitHub Releases API 的 tag_name、改 flake.nix 的 url 字段、
    # `nix flake lock --update-input voicefox` 重锁。
    voicefox = {
      url = "https://github.com/emoeem/voicefox/releases/download/v0.4.0/voicefox-linux-x86_64.zip";
      flake = false;
    };

    # orca：stablyai/orca 的 GitHub Release .deb（Linux x86_64）。
    # 打包策略与 baidunetdisk 同款（.deb 解包 + buildFHSEnv 封装），
    # 详细见 packages/orca.nix 顶部注释。.deb 命名规律
    # `orca-ide_<version>_amd64.deb`（latest-linux.yml 里列出，
    # version 与 src URL 字面量写在本 input 的 url 字段）。
    # 升级跑 `./scripts/update-third-party.sh orca`：脚本从
    # latest-linux.yml 拿 version + .deb URL + sha512（与 electron-
    # builder 发布的 standard 行为），改 flake.nix 的 url 字段 +
    # `nix flake lock --update-input orca` 重锁。
    orca = {
      url = "https://github.com/stablyai/orca/releases/download/v1.4.217/orca-ide_1.4.217_amd64.deb";
      flake = false;
    };

    # fluxdown：zerx-lab/FluxDown —— 开源（AGPL-3.0）全功能下载管理器，
    # 定位是「免费 IDM 替代品」。Rust + GPUI 原生界面（无 WebView）+
    # 自研 Tokio 引擎，支持 HTTP(S) / FTP / BitTorrent / eD2K / HLS /
    # DASH，另有浏览器扩展与内置 MCP server。接替先前的 rayburst。
    # 选 .deb 而非 .AppImage：.deb 32 MB，AppImage 44 MB（重复打包
    # glibc / 图形栈），.deb 解包后用 lib/build-deb-fhs.nix 的公共流程
    # 封装，closure 更小。打包细节见 packages/fluxdown.nix 顶部注释。
    # 资产命名规律 `FluxDown-<version>-linux-x64.deb`（注意是 linux-x64，
    # 不是 amd64——同 release 的 CLI / Server 资产要靠后缀区分，别选错）。
    # 升级跑 `./scripts/update-third-party.sh fluxdown`：脚本探测 GitHub
    # Releases latest tag（不含 rc 预发布）、取 linux-x64 .deb 资产、
    # 改 flake.nix 的 url 字段、`nix flake lock --update-input fluxdown`
    # 重锁。
    fluxdown = {
      url = "https://github.com/zerx-lab/FluxDown/releases/download/v0.5.5/FluxDown-0.5.5-linux-x64.deb";
      flake = false;
    };

    # any-listen：any-listen/any-listen 的桌面端
    # （any-listen/any-listen-desktop 仓只发 release，不发源码）。
    # 跨平台私有音乐播放服务，本机上接替 splayer-next 作主力听歌客户端。
    # 选 .deb 而非 .AppImage：同一次 electron-builder 产物，.deb 104 MB
    # 比 AppImage 133 MB 小（AppImage 把 glibc / GTK / 图标重打了一份），
    # 解包后走 lib/build-deb-fhs.nix 的公共流程封装。打包细节与依赖
    # 覆盖分析见 packages/any-listen.nix 顶部注释。
    # 资产命名规律 `any-listen_<version>_amd64.deb`（平台段是 amd64，
    # 与 AppImage 的 x86_64 写法不同，正则要锚准 .deb 后缀）。
    # 升级跑 `./scripts/update-third-party.sh any-listen`：脚本探测
    # GitHub Releases latest（自动跳过 beta 预发布）、取 amd64 .deb、
    # 改 flake.nix 的 url 字段、`nix flake lock --update-input any-listen`
    # 重锁。
    any-listen = {
      url = "https://github.com/any-listen/any-listen-desktop/releases/download/v0.9.0/any-listen_0.9.0_amd64.deb";
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
