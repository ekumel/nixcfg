# fhs-shared-pkgs.nix：被 zedg.nix 与 kelivo.nix 共用的 targetPkgs 列表。
#
# 为什么需要这份独立文件：
#   buildFHSEnv 只把列表里每个包自身的 out/lib/bin 输出合到 rootfs 的
#   /usr/lib64，不递归传播 propagatedBuildInputs（与 upstream 的
#   zed-editor-fhs 不同：那里底层是 rust 包，构建依赖自动进 rootfs）。
#   zedg / kelivo 都是纯二进制 tarball，没有任何 Nix 级 buildInputs，
#   所以必须把所有运行时库显式列出来。这份列表 zedg / kelivo 共用。
#
# 两部分组成：
#   1. 通用图形栈（与原 zedg.nix 同款，zedg 本来就需要）：
#      glib / GTK / 字体 / Wayland / GPU / TLS / dbus 等。
#   2. kelivo 额外的依赖：Flutter app 在 tarball 里用了一堆插件
#      （tray_manager / window_manager / bitsdojo / audioplayers 等），
#      这些插件 NEEDED libayatana-appindicator3 / libdbusmenu-glib /
#      libkeybinder-3 / libgstreamer-1.0 等。这些库 zedg 不需要但列
#      在这里也不影响（只是一点 rootfs 体积代价）。
#
# 如何检查依赖是否遗漏：
#   启动包后看是否报 “error while loading shared libraries”，
#   缺哪个就去 nixpkgs 找同名/同子名包加进下方列表。
#   也可以在 host 上用 ldd / readelf -d 看二进制和 .so 的 NEEDED。
{ pkgs }:

with pkgs;
[
  zlib
  glib
  libxau
  libxdmcp
  pcre2
  libffi
  libselinux
  util-linux
  gtk3
  gdk-pixbuf # kelivo 二进制硬编码 NEEDED libgdk_pixbuf-2.0.so.0
  libxkbcommon
  libGL
  nss
  nspr
  alsa-lib
  at-spi2-core
  libxcb
  libxkbfile
  mesa
  openssl
  libgit2
  pango
  cairo
  harfbuzz # kelivo 二进制硬编码 NEEDED libharfbuzz.so.0；
          # nixpkgs 当前 pango 1.57 不再链 harfbuzz，所以这里必须独立列出
  libepoxy # libgtk-3 间接依赖；pango 间接依赖
  expat
  systemd
  libdrm
  libxshmfence
  wayland
  libx11
  libxcursor
  libxi
  libxrandr
  libxfixes
  fontconfig
  freetype
  dbus

  # 以下为 kelivo tarball 中 Flutter plugins 的间接依赖；
  # zedg 不需要它们。列在末尾以便未来再加 zedg 依赖时可以
  # 在这里独立分组。
  libayatana-appindicator # libtray_manager_plugin 间接依赖（ayatana 系列）
  libayatana-indicator # libayatana-appindicator 间接依赖 libayatana-indicator3.so.7
  ayatana-ido # libayatana-appindicator 间接依赖 libayatana-ido3-0.4.so.0
  libdbusmenu # libayatana-appindicator 间接依赖 libdbusmenu-glib.so.4
  libdbusmenu-gtk3 # libayatana-appindicator 间接依赖 libdbusmenu-gtk3.so.4
  keybinder3 # libbitsdojo_window_linux_plugin 依赖
  gst_all_1.gstreamer # libaudioplayers_linux_plugin 间接依赖
  gst_all_1.gst-plugins-base # libgstapp / libgstbase
]
