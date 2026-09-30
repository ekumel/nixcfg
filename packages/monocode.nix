# monocode：hardbeat920/monocode — 多个 coding agent CLI（Claude Code /
# Codex / Cursor / Pi / …）的统一桌面 UI 前端，本地不调上游模型 API。
#
# 上游不发源码，只发 GitHub Release 的 .deb / .AppImage / .rpm / .dmg /
# .exe。Linux 推荐 .deb（README），nixpkgs 不收录。源码构建需要
# Rust + Tauri 系统依赖（webkit2gtk 4.1 / gtk3 / libsoup-3.0 等） +
# npm install 全套前端 deps，closure 膨胀 2GB+；这里走与 baidunetdisk.nix
# 完全相同的「.deb 解包 + buildFHSEnv 封装」路线。
#
# .deb 内部结构（Tauri 2 默认 layout）：
#   usr/bin/monocode          # 主二进制（42 MB，动态链接 GTK/WebKit）
#   usr/share/applications/MonoCode.desktop
#   usr/share/icons/hicolor/32x32/apps/monocode.png
#   usr/share/icons/hicolor/128x128/apps/monocode.png
#   usr/share/icons/hicolor/256x256@2/apps/monocode.png
#
# 二进制硬编码 NEEDED（在 NixOS host 上 ldd 显示 not found）：
#   libgdk-3.so.0 / libgtk-3.so.0      ← gtk3（shared 里已有）
#   libgdk_pixbuf-2.0.so.0             ← gdk-pixbuf（shared 里已有）
#   libwebkit2gtk-4.1.so.0             ← webkitgtk_4_1（已加到 shared）
#   libjavascriptcoregtk-4.1.so.0     ← webkitgtk_4_1 同包
#   libsoup-3.0.so.0                  ← libsoup_3（已加到 shared）
# 其它 glib / cairo / fontconfig / X11 / dbus / 字体 / nss 等都已在
# fhs-shared-pkgs.nix 里，闭包自动 cover。
#
# 注意 nixpkgs 的 attr 名是 webkitgtk_4_1（不是 webkit2gtk_4_1），
# 因为命名规则是 gtk-N_M，跟「实际上是不是 webkit 2」的版本号无关。
#
# 版本与 src 由 flake input 提供（flake.nix 的 monocode URL input，
# flake = false）。version 钉为字面量；升级流程：
#   1. 跑 `./scripts/update-third-party.sh monocode`（脚本探测 GitHub
#      Releases latest tag、取 amd64 .deb 资产、生成新 URL、修改
#      flake.nix 的 url 字段、`nix flake lock --update-input monocode`；
#      若该脚本尚未实现 monocode updater，按 baidunetdisk 注释里的
#      「手动查下载页 → 拼 URL → 改字面量」流程处理）；
#   2. 同步更新下方 version 字面量；
#   3. `nix flake check` 与 `nixos-rebuild switch` 验证。
{
  pkgs,
  flake,
}:

let
  inherit (pkgs) lib stdenvNoCC buildFHSEnv;

  pname = "monocode";
  version = "0.5.0";

  # x86_64 的 src 来自 flake input；aarch64 在这里手算（每个 url input
  # 只能配一个 url）。
  srcBySystem = {
    x86_64-linux = flake.inputs.monocode;
  };

  src =
    srcBySystem.${stdenvNoCC.hostPlatform.system}
      or (throw "monocode: 不支持的系统 ${stdenvNoCC.hostPlatform.system}");

  # .deb 是 ar 归档（含 control.tar.* / data.tar.* / debian-binary），
  # `ar` 来自 binutils。Nix chroot 不允许 root-owned 输出，所以解包时
  # 走 `--no-same-owner`（与 baidunetdisk.nix 同款）。
  unpacked = stdenvNoCC.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [ pkgs.binutils ];

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      tmp=$(mktemp -d)
      ar x "$src" --output="$tmp"
      data_tar=$(ls "$tmp"/data.tar.* 2>/dev/null | head -n1)
      if [ -z "$data_tar" ]; then
        echo "找不到 data.tar.* in $tmp" >&2
        ls -la "$tmp" >&2
        exit 1
      fi
      tar --extract --file="$data_tar" --directory="$out" --no-same-owner
      # 二进制在 deb 里已是 0755，但 tar 在某种 umask 下可能缩水。
      chmod +x "$out/usr/bin/monocode"
      rm -rf "$tmp"
      runHook postInstall
    '';
  };

  meta = {
    description = "Desktop UI for coding agents (Claude Code, Codex, Cursor, Pi, …) — runs whichever you have installed";
    homepage = "https://github.com/hardbeat920/monocode";
    # 上游仓库未提供 LICENSE 文件；按 README「License」一节缺字以
    # 默认「proprietary / unfree」处理（GitHub Releases 也只发签名
    # 资产，没有 SPDX）。
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "monocode";
    platforms = [
      "x86_64-linux"
    ];
  };
in
buildFHSEnv {
  name = "${pname}-fhs";
  executableName = pname;

  # GTK / WebKit / fontconfig / NSS / dbus / Wayland 等运行时栈：
  # 直接复用 lib/fhs-shared-pkgs.nix；monocode 专属的 webkit2gtk_4_1
  # + libsoup_3 已加进该文件（见其顶部注释的「第三部分」）。
  targetPkgs = pkgs: import ../lib/fhs-shared-pkgs.nix { inherit pkgs; };
  multiPkgs = pkgs: [ ];

  # FHS 沙箱里 /etc 是 tmpfs，只回链了 nixpkgs 白名单里的少数条目，
  # /etc/nixos 不在其中。wrapper 在进入沙箱时会 `--chdir "$(pwd)"`，
  # 若从 /etc/nixos 启动就会因目标不存在而报 "bwrap: Can't chdir to
  # /etc/nixos: No such file or directory"。把宿主机的 /etc/nixos 以
  # 可写方式绑进沙箱。原因同 wechat / genoffice / baidunetdisk.nix。
  extraBwrapArgs = [
    "--bind"
    "/etc/nixos"
    "/etc/nixos"
  ];

  # 直接调用解包后的 Tauri 主二进制。.desktop 的 Exec 是 `monocode`
  # （无 flags），wrapper 暴露同名可执行，桌面环境点 .desktop 时
  # wrapper 自动加 bwrap 沙箱。
  runScript = "${unpacked}/usr/bin/monocode";

  # 复制 deb 自带的 .desktop 与 hicolor 图标到 wrapper 的 $out/share/。
  # Tauri 默认 layout 把 .desktop 的 Exec 直接写成「裸命令名」（即
  # monocode），wrapper 暴露同名二进制，因此这里不需要 substituteInPlace。
  extraInstallCommands = ''
    mkdir -p "$out/share/applications"
    mkdir -p "$out/share/icons"

    # .desktop
    cp "${unpacked}/usr/share/applications/MonoCode.desktop" \
      "$out/share/applications/MonoCode.desktop"

    # 图标（hicolor 系列三档）
    cp -r "${unpacked}/usr/share/icons/." "$out/share/icons/"
  '';

  passthru = {
    inherit unpacked;
  };
}