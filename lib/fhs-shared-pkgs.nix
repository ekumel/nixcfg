# fhs-shared-pkgs.nix：被 zedg.nix / kelivo.nix / orca.nix 共用的
# targetPkgs 列表。
#
# 为什么需要这份独立文件：
#   buildFHSEnv 只把列表里每个包自身的 out/lib/bin 输出合到 rootfs 的
#   /usr/lib64，不递归传播 propagatedBuildInputs（与 upstream 的
#   zed-editor-fhs 不同：那里底层是 rust 包，构建依赖自动进 rootfs）。
#   zedg / kelivo / orca 都是预编译的二进制 tarball / .deb，
#   没有任何 Nix 级 buildInputs，所以必须把所有运行时库显式列出来。
#
# 三部分组成：
#   1. 通用图形栈（与原 zedg.nix 同款，zedg 本来就需要）：
#      glib / GTK / 字体 / Wayland / GPU / TLS / dbus 等。
#   2. kelivo 额外的依赖：Flutter app 在 tarball 里用了一堆插件
#      （tray_manager / window_manager / bitsdojo / audioplayers 等），
#      这些插件 NEEDED libayatana-appindicator3 / libdbusmenu-glib /
#      libkeybinder-3 / libgstreamer-1.0 等。这些库 zedg / orca
#      不需要但列在这里也不影响（只是一点 rootfs 体积代价）。
#   3. orca 额外的依赖：Electron 二进制 NEEDED libcups.so.2（打印 /
#      认证），nixpkgs cupswrapper（libcups）补上。其它 GTK / GL /
#      NSS / drm / systemd 等都已在本文件前半段覆盖。
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
  # zedg / orca 不需要它们。列在末尾以便未来再加 zedg 依赖时可以
  # 在这里独立分组。
  libayatana-appindicator # libtray_manager_plugin 间接依赖（ayatana 系列）
  libayatana-indicator # libayatana-appindicator 间接依赖 libayatana-indicator3.so.7
  ayatana-ido # libayatana-appindicator 间接依赖 libayatana-ido3-0.4.so.0
  libdbusmenu # libayatana-appindicator 间接依赖 libdbusmenu-glib.so.4
  libdbusmenu-gtk3 # libayatana-appindicator 间接依赖 libdbusmenu-gtk3.so.4
  keybinder3 # libbitsdojo_window_linux_plugin 依赖
  gst_all_1.gstreamer # libaudioplayers_linux_plugin 间接依赖
  gst_all_1.gst-plugins-base # libgstapp / libgstbase

  # 以下为 orca（Electron 应用）二进制硬编码 NEEDED：
  #   cups（libcups.so.2）—— Chromium 打印 / 认证子系统的客户端。
  #   libxcomposite / libxdamage / libXtst / libxinerama / libxext ——
  #     Chromium 合成 X 事件 / 模拟 / 触摸输入必需。
  #     2026-09 删 monocode 用的 webkitgtk_4_1 后，这些 X 库
  #     不再由共享包间接带入；Electron / Chromium 必需，需要独立列。
  #     libxext 本应在 libxcb 的 transitive 里，但 fhs-shared 的 libxcb
  #     不传导 libxext.so.6（libxext 与 libxcb 是平行的 nixpkgs 包），
  #     所以也独立列。
  #   其它 GTK / GL / NSS / drm / systemd / X11 / Xrandr / Xfixes / Xcursor
  #   / Xi / xkbcommon 等都已在本文件前半段覆盖。
  cups
  libxcomposite
  libxdamage
  libXtst
  libxinerama
  libxext
  libgbm # libgbm.so.1 —— Chromium GPU buffer manager。mesa 不传导
  # libgbm，Electron / Chromium 必需独立列。
]
