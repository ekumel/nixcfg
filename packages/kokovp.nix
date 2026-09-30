# kokovp：brainrom/kokovp — 基于 libmpv + Qt6 的现代视频播放器
# （SMPlayer 功能集的现代重写）。上游不发 release，从 git tag 拉源码
# tarball，CMake 本地构建。
#
# 依赖（上游 CMakeLists.txt 列出）：
#   - Qt6（Core / Widgets / OpenGLWidgets / Network / Xml）
#   - libmpv（pkg-config 名 `mpv`，本包用 pkgs.mpv-unwrapped）
#   - exiv2（可选；CMake `find_package(exiv2)` 不 REQUIRED）
#
# 运行时还需要 mpv 客户端二进制本体做 dlopen（libmpv 的 plugin 路径等），
# 所以 buildInputs 同时拉 mpv，让 wrapQtAppsHook / mpv 的 closure 一并进入。
#
# src 来自 flake.nix 的 kokovp URL input（v1.2.1 tarball，flake = false）。
# flake URL input 默认会把 .tar.gz 自动解包到 store 里的 -source 目录，
# $src 直接是源码根。
#
# 升级流程：
#   1. 手动到 https://github.com/brainrom/kokovp/tags 看新 tag，按
#      `https://github.com/brainrom/kokovp/archive/refs/tags/<tag>.tar.gz`
#      模式更新 flake.nix 的 kokovp url；
#   2. 同步更新下方 version 字面量；
#   3. `nix flake lock --update-input kokovp` 重锁；
#   4. aarch64 的 sha256 需要到 release 页下载对应 tag 后用 nix-prefetch-url
#      算出（当前 input 只配 x86_64）；
#   5. `nix flake check` 验证；
#   6. `nixos-rebuild switch` 验证。
{
  pkgs,
  flake,
}:

let
  inherit (pkgs) lib stdenv cmake pkg-config;

  pname = "kokovp";
  version = "v1.2.1";

  # 当前 input 只配了 x86_64 tarball；aarch64 需要单独抓 tarball 后手算 hash。
  srcBySystem = {
    x86_64-linux = flake.inputs.kokovp;
  };

  src =
    srcBySystem.${stdenv.hostPlatform.system}
      or (throw "kokovp: 不支持的系统 ${stdenv.hostPlatform.system}");

  meta = {
    description = "Modern video player based on libmpv and Qt6";
    homepage = "https://github.com/brainrom/kokovp";
    license = lib.licenses.gpl2Only;
    mainProgram = "kokovp";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      ];
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
in
stdenv.mkDerivation {
  inherit
    pname
    version
    src
    meta
    ;

  nativeBuildInputs = [
    cmake
    pkg-config
    pkgs.qt6.wrapQtAppsHook
  ];

  buildInputs = with pkgs; [
    qt6.qtbase
    # LinguistTools：qt_create_translation / lupdate / lrelease。
    qt6.qttools
    mpv-unwrapped
    mpv
    exiv2
  ];

  # CMake 默认 build type 是 RelWithDebInfo（上游在 CMakeLists 里设了），
  # 显式指 Release 减小编出来的二进制体积并去掉调试符号。
  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  # wrapQtAppsHook 会自动 wrap bin/kokovp，让运行时能找到 Qt6 plugin
  # （platforms、imageformats 等）；手装 .desktop 文件是为了让 XDG 桌面
  # 入口能扫到。Icon= 字段未指定，沿用默认主题。
  installPhase = ''
    runHook preInstall
    install -Dm755 kokovp "$out/bin/kokovp"
    install -Dm644 "$src/kokovp.desktop" "$out/share/applications/kokovp.desktop"
    runHook postInstall
  '';
}
