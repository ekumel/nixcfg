# GenOffice：Genspark 出品的开源 AI Office 套件
#（.docx / .xlsx / .pptx / .pdf / .html / .md 六合一编辑器）。
#
# 官方仅提供 Linux 的 .deb / .rpm / AppImage 三种分发，nixpkgs 不收录，
# 也不适合在 NixOS 上直接 dpkg / rpm 安装（动态库 / 解释器路径不在 FHS）。
#
# 打包策略：用 nixpkgs 的 `appimageTools.wrapType2`，它会自动做两件事
#   1. `appimageTools.extract` 把官方 AppImage 内的 squashfs 解包到
#      `${contents}/squashfs-root/`，放进 `contents` 字段供后续引用；
#   2. `buildFHSEnv` 在 $out/bin 产出可执行 wrapper，wrapper 进入 FHS
#      沙箱后调用 `appimage-exec.sh -w <contents> --`，跳过解包分支，
#      直接 `exec squashfs-root/AppRun "$@"`。
# 关键：必须用 `wrapType2` 而不是 `wrapAppImage`——后者把 src 本身
#（AppImage 文件）当 contents 传给 `-w`，会让 `appimage-exec.sh` 在
# 「APPDIR 不是目录」时落到 `realpath "$1"`，$1 为空就报
# "realpath: '': 没有那个文件或目录"。
#
# 另一个常见踩坑：bwrap 默认 /etc 是 tmpfs 且只回链 nixpkgs 白名单
# 里的少数条目，本机 /etc/nixos 不在其中。从 /etc/nixos 启动 wrapper
# 会报 "bwrap: Can't chdir to /etc/nixos"，需用 extraBwrapArgs 手动
# --bind 进去（同 zedg.nix）。
#
# 最后把 contents 里的 .desktop / 图标合并到 $out/share/，
# 并把 .desktop 里的 Exec=AppRun 改成 Exec=genoffice，
# 让桌面环境能从 $out/share/applications 扫到启动项。
#
# 版本与 src 由 _sources/generated.nix 提供（nvfetcher 跟踪 GitHub release）。
{
  pkgs,
  flake,
}:

let
  inherit (pkgs) appimageTools;
  # nvfetcher 源：统一从 flake.lib.sources 取（见 lib/default.nix）。
  sources = flake.lib.sources pkgs;

  pname = sources.genoffice.pname;
  version = sources.genoffice.version;
  appimageSrc = sources.genoffice.src;

  # wrapType2 会在内部调 extract，把产物放进自己的 contents 字段。
  # 为了在 extraInstallCommands 里能引用这份解包目录，先手动 extract
  # 一遍（同一 src 会复用 nix store cache，不会多存）。
  contents = appimageTools.extract {
    inherit pname version;
    src = appimageSrc;
  };
in
appimageTools.wrapType2 {
  inherit pname version;
  src = appimageSrc;

  # FHS 沙箱里 /etc 是 tmpfs，只回链了 nixpkgs 白名单里的少数条目，
  # /etc/nixos 不在其中。wrapper 会 --chdir "$(pwd)"，若从 /etc/nixos 启动
  # 就会报 "bwrap: Can't chdir to /etc/nixos"。把宿主机的 /etc/nixos 以可
  # 写方式绑进沙箱，使其既可作为 CWD，也能被 GenOffice 正常读写
  # （用于编辑本机 NixOS 配置）。
  # 原因同 zedg.nix 中的同款 extraBwrapArgs。
  extraBwrapArgs = [
    "--bind"
    "/etc/nixos"
    "/etc/nixos"
  ];

  # wrapType2 把 extract 的输出放在 `contents` 字段；运行时 wrapper
  # 通过 `-w ${contents}` 直接 exec squashfs-root/AppRun。
  extraInstallCommands = ''
    mkdir -p "$out/share/applications"

    # 收不同应用摆位置的差别
    if [ -d "${contents}/usr/share/applications" ]; then
      cp -r "${contents}/usr/share/applications/." "$out/share/applications/"
    fi
    if [ -d "${contents}/applications" ]; then
      cp -r "${contents}/applications/." "$out/share/applications/" 2>/dev/null || true
    fi
    # 个别 Electron App 直接把 .desktop 摔在 squashfs-root/
    for f in ${contents}/*.desktop; do
      [ -e "$f" ] || continue
      cp "$f" "$out/share/applications/"
    done

    # 把 Exec=AppRun 改成 Exec=genoffice，
    # 否则桌面环境看到 Exec=AppRun 会去 $PATH 找 AppRun，找不到。
    for d in "$out/share/applications"/*.desktop; do
      [ -e "$d" ] || continue
      substituteInPlace "$d" --replace-warn "Exec=AppRun" "Exec=genoffice"
    done

    # 图标
    if [ -d "${contents}/usr/share/icons" ]; then
      cp -r "${contents}/usr/share/icons" "$out/share/"
    fi
    if [ -d "${contents}/icons" ]; then
      cp -r "${contents}/icons" "$out/share/" 2>/dev/null || true
    fi
  '';

  meta = {
    description = "Open-source AI office suite (Docs / Sheets / Slides / PDF / HTML / Markdown)";
    homepage = "https://genoffice.ai/";
    license = {
      # 上游仓库未给出统一的 SPDX 标识；标 free = true 以免 rebuild 时
      # nixpkgs 的 license 检查失败。
      free = true;
    };
    platforms = [ "x86_64-linux" ];
    mainProgram = "genoffice";
  };
}
