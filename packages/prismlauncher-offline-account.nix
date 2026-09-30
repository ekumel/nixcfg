# prismlauncher-offline-account：forsyth47/PrismLauncher-OfflineAccount —
# PrismLauncher 的 fork，移除「禁止离线账号」限制，可免 Microsoft 登录使用。
#
# 上游发 GitHub release portable tarball：
#   PrismLauncher-Linux-Qt6-Portable-<version>.tar.gz
# 内容是 LinuxDeploy / sharun 打出来的 AppDir 布局：bin/、lib/、share/
# 全是 Qt6 应用 + 所有依赖的 bundled shared libs；主二进制 bin/prismlauncher
# 经实测 `ldd` 报 `statically linked`，所以不需要 buildFHSEnv，直接
# stdenvNoCC 解包就行。
#
# 与 Diegiwg/PrismLauncher-Cracked 的关系：
#   - 同一份上游 PrismLauncher release 流程（CMake + sharun AppDir），只是
#     「离线账号限制绕过」改在源码层（fork）而非运行时补丁；
#   - portable tarball 布局完全相同（bin/prism.launcher statically linked，
#     自带 .desktop / hicolor 图标 / metainfo / mime），无需 makeDesktopItem；
#   - 同样的 XDG-portal file picker 配置（QT_QPA_PLATFORMTHEME）。
#
# 上游 PrismLauncher 顶层 bash 脚本只做了几件事：export
# QT_QPA_PLATFORMTHEME、chmod +x、传 `-d portable.txt`。env 我们在 wrapper
# 里复刻，portable.txt 我们去掉（要写 XDG 路径，store 是只读），
# 不传 `-d`，让 launcher 走 `~/.local/share/PrismLauncher` 默认位置。
#
# 升级流程：
#   1. 跑 `./scripts/update-third-party.sh prismlauncher-offline-account`：
#      脚本探测 GitHub Releases API、取最新 tag、生成新 URL、修改 flake.nix
#      的 url 字段、`nix flake lock --update-input prismlauncher-offline-account`；
#   2. 同步更新下方 version 字面量（脚本不会改 .nix 里的 version）；
#   3. aarch64 的 sha256 需要人工到 release 页下载后用 nix-prefetch-url
#      算出，填到下方 aarch64Sha256；
#   4. `nix flake check` 验证；
#   5. `nixos-rebuild switch` 验证。
{
  pkgs,
  flake,
}:

let
  inherit (pkgs) lib stdenvNoCC makeWrapper;

  pname = "prismlauncher-offline-account";
  version = "10.0.5-offline2";

  # x86_64 的 src 来自 flake input；aarch64 在这里手算（每个 url input
  # 只能配一个 url）。
  srcBySystem = {
    x86_64-linux = flake.inputs.prismlauncher-offline-account;
  };

  src =
    srcBySystem.${stdenvNoCC.hostPlatform.system}
      or (throw "prismlauncher-offline-account: 不支持的系统 ${stdenvNoCC.hostPlatform.system}");

  unpacked = stdenvNoCC.mkDerivation {
    inherit pname version src;

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r "$src"/. "$out/"
      chmod -R +w "$out"
      # portable.txt 让 launcher 把数据写到自身所在目录（store 只读，
      # 不允许写）。去掉后 launcher 走 ~/.local/share/PrismLauncher。
      rm -f "$out/portable.txt"
      # PrismLauncher 顶层是上游 shell wrapper，我们用自己的；避免
      # 重复入口（且 wrapper 会 print "Launcher Dir: ..."，启动会刷屏）。
      rm -f "$out/PrismLauncher"
      # sharun 是 LinuxDeploy 同款工具，二进制已 statically linked，
      # 没用；留着也只是占空间。
      rm -f "$out/sharun"
      runHook postInstall
    '';
  };

  meta = {
    description = "PrismLauncher fork with offline account restriction removed (no Microsoft login required)";
    homepage = "https://github.com/forsyth47/PrismLauncher-OfflineAccount";
    license = lib.licenses.gpl3Only;
    mainProgram = "prismlauncher";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version meta;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share"

    # 整个 unpacked 直接当 wrapper 的最终输出（已是 FHS-like 布局，
    # 且 binary statically linked）。
    cp -r ${unpacked}/. "$out/"

    # 用 wrapProgram 在原 bin/prismlauncher 上注入环境（避免另起一份
    # wrapper 脚本路径），与上游 PrismLauncher shell 脚本行为对齐。
    #
    #  - QT_QPA_PLATFORMTHEME=xdgdesktopportal：让文件选择走 XDG portal，
    #    sandbox / Wayland 下能拉起系统文件对话框。
    wrapProgram "$out/bin/prismlauncher" \
      --set QT_QPA_PLATFORMTHEME xdgdesktopportal

    runHook postInstall
  '';
}