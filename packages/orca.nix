# orca：stablyai/orca — "面向 100x 构建者的 AI 编排器"，
# 并行 worktree 里跑多个 coding agent（Claude Code / Codex /
# OpenCode / Pi / OpenClaude / GitHub Copilot / oh-my-pi 等）。
# 带 mobile companion app、design mode、review 流程。
#
# 上游不发源码，发 GitHub Release 三平台包：macOS .dmg / Windows .exe /
# Linux .AppImage + .deb + .rpm + Arch AUR。Linux 选 .deb：180 MB，
# 比 AppImage（216 MB）小、closure 干净；nixpkgs 不收录。
#
# 打包策略：与 baidunetdisk.nix 完全相同——.deb 解包 + buildFHSEnv 封装。
#   - electron 主二进制 /opt/Orca/orca-ide（224 MB）带内置 libffmpeg /
#     libEGL / libvulkan / chrome-sandbox，运行时需要 GTK / GL / NSS /
#     dbus / drm / systemd / cups 等「通用图形栈」+ Electron 专属
#     libcups（已在 lib/fhs-shared-pkgs.nix 列出）。
#   - chrome-sandbox 是 SUID-root 二进制，NixOS 不支持任意 SUID；
#     与 baidunetdisk 同款——传 `--no-sandbox` 给主进程降级到
#     「无沙箱」运行（Electron 自动 fallback）。
#   - .desktop 的 Exec 是 `/opt/Orca/orca-ide %U`——我们在 wrapper
#     里加 `--no-sandbox` flag，wrapper 暴露同名可执行，
#     桌面环境点 .desktop 时由 wrapper 自动加 flag。
#
# .deb 内部结构（Electron 标准 layout）：
#   /opt/Orca/orca-ide              主二进制（224 MB，动态链接 GTK 等）
#   /opt/Orca/chrome-sandbox        SUID-root 二进制（Electron 沙箱）
#   /opt/Orca/{chrome_100_percent.pak, chrome_200_percent.pak, icudtl.dat,
#                libEGL.so, libffmpeg.so, libGLESv2.so, libvk_swiftshader.so,
#                libvulkan.so.1, locales/, resources/, ...}
#   /usr/share/applications/orca-ide.desktop
#   /usr/share/icons/hicolor/{16,24,32,48,128,256,512}x{...}/apps/orca-ide.png
#
# 版本与 src 由 flake input 提供（flake.nix 的 orca URL input，
# flake = false）。version 钉为字面量；升级流程：
#   1. 跑 `./scripts/update-third-party.sh orca`：脚本从 latest-linux.yml
#      拿最新 version + .deb URL + sha512，生成新 URL、修改
#      flake.nix 的 url 字段、`nix flake lock --update-input orca`；
#   2. 同步更新下方 version 字面量；
#   3. `nix flake check` 与 `nixos-rebuild switch` 验证。
{
  pkgs,
  flake,
}:

let
  inherit (pkgs) lib stdenvNoCC buildFHSEnv;

  pname = "orca";
  version = "1.4.217";

  # x86_64 的 src 来自 flake input；aarch64 在这里手算（每个 url input
  # 只能配一个 url）。
  srcBySystem = {
    x86_64-linux = flake.inputs.orca;
  };

  src =
    srcBySystem.${stdenvNoCC.hostPlatform.system}
      or (throw "orca: 不支持的系统 ${stdenvNoCC.hostPlatform.system}");

  # .deb 是 ar 归档（含 control.tar.* / data.tar.* / debian-binary），
  # `ar` 来自 binutils。Nix chroot 不允许 root-owned 输出，所以解包时
  # 走 `--no-same-owner`（与 baidunetdisk.nix / monocode.nix 同款）。
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
      chmod +x "$out/opt/Orca/orca-ide"
      rm -rf "$tmp"
      runHook postInstall
    '';
  };

  meta = {
    description = "AI orchestrator running Claude Code / Codex / OpenCode / Pi in parallel worktrees";
    homepage = "https://github.com/stablyai/orca";
    # 上游 LICENSE 写 MIT（README 末尾 + LICENSE 文件），
    # 但 code 内容引用大量第三方（Electron / Chromium / 各 agent
    # 的 source），所以这里标 mit 但 meta 加上 platform 限定。
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "orca";
    platforms = [
      "x86_64-linux"
    ];
  };
in
buildFHSEnv {
  name = "${pname}-fhs";
  executableName = pname;

  # Electron 运行时栈与 baidunetdisk / wechat / genoffice 同款：
  # GTK / WebKit / 字体 / Wayland / GPU / TLS / dbus / NSS / cups 等。
  # 直接复用 lib/fhs-shared-pkgs.nix；orca 专属的 cups 已加进该文件
  # （见其顶部注释的「第三部分」）。
  targetPkgs = pkgs: import ../lib/fhs-shared-pkgs.nix { inherit pkgs; };
  multiPkgs = pkgs: [ ];

  # FHS 沙箱里 /etc 是 tmpfs，只回链了 nixpkgs 白名单里的少数条目，
  # /etc/nixos 不在其中。wrapper 在进入沙箱时会 `--chdir "$(pwd)"`，
  # 若从 /etc/nixos 启动就会因目标不存在而报 "bwrap: Can't chdir to
  # /etc/nixos: No such file or directory"。把宿主机的 /etc/nixos 以
  # 可写方式绑进沙箱。原因同 wechat / genoffice / baidunetdisk / monocode。
  extraBwrapArgs = [
    "--bind"
    "/etc/nixos"
    "/etc/nixos"
  ];

  # 直接调用解包后的 Electron 主二进制。.desktop 的 Exec 是
  # `/opt/Orca/orca-ide %U`（无 flags）。orca-ide 是 Electron 主进程，
  # 自己处理 args，不需要我们传 --no-sandbox（传了反而被它当成
  # 未知 arg 拒绝："bad option: --no-sandbox"）。
  # chrome-sandbox 在 NixOS 不可用为 SUID-root，但 Electron 的
  # SUID-less fallback 仍能在普通用户 namespace 下启 sandbox
  # （Linux user_namespaces + seccomp），不需要 --no-sandbox。
  # 如果遇到 sandbox 启动问题，再改用 wrapper 强制 --no-sandbox；
  # 现阶段按 .desktop 原样透传。
  runScript = "${unpacked}/opt/Orca/orca-ide";

  # 复制 deb 自带的 .desktop 与 hicolor 图标到 wrapper 的 $out/share/，
  # 并把 Exec= 里的绝对路径改成 wrapper 暴露的可执行名。
  extraInstallCommands = ''
    mkdir -p "$out/share/applications"
    mkdir -p "$out/share/icons"

    # .desktop：Exec=/opt/Orca/orca-ide %U
    #   →   Exec=orca %U
    cp "${unpacked}/usr/share/applications/orca-ide.desktop" \
      "$out/share/applications/orca-ide.desktop"
    substituteInPlace "$out/share/applications/orca-ide.desktop" \
      --replace-fail "/opt/Orca/orca-ide" "orca"

    # 图标（deb 给了 7 档：16/24/32/48/128/256/512）
    cp -r "${unpacked}/usr/share/icons/." "$out/share/icons/"
  '';

  passthru = {
    inherit unpacked;
  };
}