# clamav-gui：ClamAV 的 Qt6 图形前端（上游仓库 https://github.com/wusel1007/clamav-gui）。
#
# 上游不发布 release asset，只发 GitHub tag + 源码；这里直接拿 GitHub 归档 tarball
# 当 src，用 CMake 构建。tarball 根目录是 `wusel1007-clamav-gui-<sha>/`，CMakeLists
# 就在那里，所以直接 buildPhase 默认进入 sourceRoot 即可。
#
# 源码由 nvfetcher 跟踪 GitHub release（见 nvfetcher.toml 的 [clamav-gui]）；
# _sources/generated.nix 暴露 pname / version / src（fetchFromGitHub 形式）。
#
# 升级流程：
#   1. `nvfetcher -c ./nvfetcher.toml` 取最新 tag 并重算 sha256；
#   2. `nixos-rebuild switch` 验证编译。
#
# 关键决策：
#   - wrapQtAppsHook：让二进制在执行时拿到正确的 QT_PLUGIN_PATH / QT_QPA_PLATFORMTHEME
#     等 Qt 运行时变量（nixos 必备）；
#   - 显式列出 qt6 子包（qtbase / qtsvg / qttools / qt5compat / qtwayland），
#     与上游 default.nix 的 buildInputs 列表一致；用 qt6.full 会引入一堆用不到的
#     模块（declarative / quick / 3d 等），没必要。
#   - glibcLocales + LOCALE_ARCHIVE：解决编译期 Qt lupdate 工具需要的 UTF-8
#     locale（linguist 处理 translations/*.ts 时若没有 .utf-8 locale 会报错）。
#   - cmakeFlags 把 CMAKE_INSTALL_BINDIR 设成 bin（默认 install.cmake
#     已经处理好了大部分路径，这里只显式确认 GNUInstallDirs 走默认）。
#
# 注意：上游不暴露 packages 输出（flake.nix 只有 devShells.default），
# 所以本仓库不通过 flake input 拉上游，而是自己 fetch + build。
{
  pkgs,
  flake,
}:

let
  inherit (pkgs) lib stdenv;
  sources = flake.lib.sources pkgs;

  pname = "clamav-gui";
  version = sources.clamav-gui.version;
  src = sources.clamav-gui.src;
in
stdenv.mkDerivation {
  inherit pname version src;

  # 默认 sourceRoot 会去掉尾缀（v 前缀剥过，所以 sourceRoot 就是裸目录名）。
  # buildPhase / installPhase 默认从 $sourceRoot 开始，无需改 sourceRoot。

  # lupdate / lrelease 处理 translations/*.ts 时需要 UTF-8 locale；
  # SOURCE_LICENSE 默认是空也会被 lupdate 探测到。
  LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
  LANG = "en_US.UTF-8";
  LC_ALL = "en_US.UTF-8";

  nativeBuildInputs = with pkgs; [
    pkg-config
    cmake
    qt6.wrapQtAppsHook
    glibcLocales
  ];

  buildInputs = with pkgs; [
    qt6.qtbase
    qt6.qtsvg
    qt6.qttools
    qt6.qt5compat
    qt6.qtwayland
  ];

  # 让 install.cmake 找到正确的 RUNTIME / DATAROOT 路径。上游用 GNUInstallDirs
  # 的 CMAKE_INSTALL_BINDIR / CMAKE_INSTALL_DATADIR，没有强制写死。
  cmakeFlags = [
    "-Wno-dev" # 关掉上游 CMake 引入的策略警告，干净输出
  ];

  # 上游 doCheck 会进入 qtest 子目录；测试需要 clamav 二进制，但只用于开发期，
  # 启用反而让构建变慢，这里直接关掉。
  doCheck = false;

  meta = {
    description = "Graphical user interface for ClamAV (Qt6)";
    homepage = "https://github.com/wusel1007/clamav-gui";
    license = lib.licenses.gpl3Plus;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "clamav-gui";
  };
}
