# kelivo：Flutter LLM 客户端。flake input 跟踪（见 flake.nix 的 `kelivo`
# URL input，flake = false）。`flake.inputs.kelivo` 在求值时直接得到 store
# path 字符串，可直接当 src 用。
#
# 升级流程：
#   1. 打开 https://github.com/Chevey339/kelivo/releases 看最新 tag 与
#      对应的 build number（asset 文件名里的 `+N`，如 `1.2.6+73.tar.gz`）；
#   2. 跑 `./scripts/update-third-party.sh kelivo`：脚本探测上游、修改
#      flake.nix 的 kelivo url 字段、`nix flake lock --update-input kelivo`；
#   3. 同步更新下方 version 字面量（脚本不会改 .nix 文件里的 pname/version）；
#   4. `nix flake check` 验证；
#   5. `nixos-rebuild switch` 验证编译。
#
# 上游 release asset `Kelivo_linux_<version>+<build>.tar.gz` 是 Flutter
# 预编译产物：根目录有 `kelivo` 二进制、`lib/*.so` 动态库、
# `data/flutter_assets/` 资源。tarball 解压后可直接塞进 buildFHSEnv 的
# runScript（与 zedg.nix 用上游 usr/ 树是同一思路，但路径不同）。
#
# 关键决策（与 zedg.nix 同款，详见 zedg.nix 注释）：
#   - buildFHSEnv：Flutter app 假定 /usr/lib、/usr/share 等路径存在；
#   - extraBwrapArgs 把 /etc/nixos 绑进沙箱（bwrap --chdir 需要）；
#   - targetPkgs 列出所需运行时库（GTK / Wayland / GPU / TLS 等）；
#   - executableName = pname 让 wrapper 路径直接叫 `kelivo`，与 .desktop
#     的 Exec= 一致。
#
# desktop / 图标说明：
#   与 zedg 不同，kelivo tarball 不带 .desktop 文件和 hicolor 图标。
#   这里从 tarball 自带的 `data/flutter_assets/assets/app_icon.png` 提取
#   图标（缩成 hicolor index.theme 声明过的多个尺寸，原因见下方 icon
#   推导式的注释），并用 makeDesktopItem 现场生成 .desktop 文件（写到
#   wrapper 的 $out/share/applications/，让 NixOS 桌面环境能扫到）。
#   Category 选 Network + ChatTool 等常规 LLM 客户端分类。
{
  pkgs,
  flake,
}:

let
  inherit (pkgs)
    lib
    stdenv
    buildFHSEnv
    makeDesktopItem
    imagemagick
    ;

  # flake.inputs.X 在 flake = false 时是 store path 字符串（prefetch 后的
  # 单文件或 tarball 解包目录），可直接当 src 用。
  pname = "kelivo";
  version = "v1.2.6+73";
  src = flake.inputs.kelivo;

  # 上游 tarball 解压后根目录是 ./kelivo, ./lib, ./data/。
  # 把 kelivo 二进制和 lib/ 复制到 $out/，data/ 也复制（包含 flutter
  # 运行时资源）。runScript 直接调用 $out/kelivo——它会通过相对路径
  # 找到同级的 lib/ 和 data/。
  unpacked = stdenv.mkDerivation {
    inherit pname version src;
    # 当前 Nix（2.18+）会把 flake URL input 指向的 .tar.gz 自动解包到
    # store 里的 -source 目录，$src 就是解包后的根目录。让 std unpacker
    # 对目录再走一次 cp -r 既费时又费盘，所以跳过 unpack，自己在
    # installPhase 里 cd 进去（runPhase 只在 unpackPhase 后 cd 到
    # sourceRoot，dontUnpack 之后这条不会触发）。
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      cd "$src"
      mkdir -p "$out"
      cp -r kelivo lib data "$out/"
      chmod +x "$out/kelivo"
      runHook postInstall
    '';
    meta = {
      description = "Flutter LLM chat client (pre-built binary)";
      homepage = "https://kelivo.psycheas.top/";
      license = lib.licenses.agpl3Plus;
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
  };

  # 从 tarball 自带的那个 1024x1024 图标生成 hicolor 主题目录。
  # buildFHSEnv 默认不暴露内部 pkg 的 share/；我们把图标打包进 wrapper
  # 的 $out/share/icons/。
  #
  # 为什么必须缩成多个尺寸、不能只放 1024x1024：
  #   hicolor 的 index.theme（hicolor-icon-theme 0.18）里 `Directories` 只
  #   声明到 512x512（其后直接是 scalable / symbolic），根本没有 1024x1024
  #   这一项。XDG icon theme spec 规定查找只枚举 index.theme 里列出的目录，
  #   所以 1024x1024/apps/kelivo.png 虽然文件存在，DMS 启动器（会读取
  #   `%s/index.theme` 并解析 Directories / Type）、GTK、Qt 查找时都会忽略它，
  #   启动器里就只剩下一个空白/默认图标。zedg 的图标能正常显示，正是因为上游
  #   tarball 额外带了 512x512/apps/zedg.png。
  #   因此这里用 imagemagick 把源图缩成 index.theme 声明过的几个尺寸。
  icon = stdenv.mkDerivation {
    name = "kelivo-icon";
    src = flake.inputs.kelivo;
    nativeBuildInputs = [ imagemagick ];
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      cd "$src"
      for size in 32 48 64 128 256 512; do
        dir="$out/share/icons/hicolor/''${size}x''${size}/apps"
        mkdir -p "$dir"
        magick data/flutter_assets/assets/app_icon.png \
          -resize "''${size}x''${size}" "$dir/kelivo.png"
      done
      runHook postInstall
    '';
  };

  desktopItem = makeDesktopItem {
    name = "kelivo";
    desktopName = "Kelivo";
    genericName = "LLM Chat Client";
    comment = "Flutter LLM chat client";
    icon = "kelivo";
    exec = "kelivo %U";
    terminal = false;
    type = "Application";
    categories = [
      "Network"
      "Chat"
      "Utility"
    ];
    startupWMClass = "kelivo";
  };
in
buildFHSEnv {
  name = "${pname}-fhs";
  executableName = pname;
  # Flutter app 的运行时库栈与 zedg 类似：GTK / 字体 / Wayland / GPU /
  # TLS / dbus。这里直接复用同一份列表（详见 lib/fhs-shared-pkgs.nix 注释）。
  targetPkgs = pkgs: import ../lib/fhs-shared-pkgs.nix { inherit pkgs; };
  multiPkgs = pkgs: [ ];
  runScript = "${unpacked}/kelivo";
  # 与 zedg.nix 同款：/etc/nixos 不在 FHS 白名单，wrapper --chdir 会失败。
  extraBwrapArgs = [
    "--bind"
    "/etc/nixos"
    "/etc/nixos"
  ];
  # 把图标和 .desktop 暴露到 wrapper 的 $out/share/——buildFHSEnv 默认
  # 不会创建 $out/share/（产物只有 bin/），所以这里手动创建后复制。
  extraInstallCommands = ''
    mkdir -p "$out/share/applications"
    mkdir -p "$out/share/icons"
    cp -r ${icon}/share/icons/. "$out/share/icons/"
    cp ${desktopItem}/share/applications/kelivo.desktop "$out/share/applications/"
  '';
  passthru = {
    inherit unpacked icon;
    bin = "${unpacked}/kelivo";
  };
}
