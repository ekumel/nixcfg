# goquark：ButterFuture/GoQuark — 非官方夸克网盘 CLI / TUI / MCP 客户端。
#
# 纯 Go 静态二进制（仅一个可执行文件，无 .so、无桌面 / 图标资源），
# 直接装到 $out/bin/ 即可，运行时只需写：
#   - ~/.config/goquark/config.json（Cookie / 设备信息）
#   - ~/Downloads/GoQuark/（默认下载目录，可改）
# 不需要 FHS 沙箱。
#
# 版本与 src 由 flake input 提供（flake.nix 的 goquark URL input，
# flake = false）。这里把 version 钉为字面量；升级流程：
#   1. 跑 `./scripts/update-third-party.sh goquark`：脚本探测 GitHub
#      Releases API、取最新 tag、生成新 URL、修改 flake.nix 的 url 字段、
#      `nix flake lock --update-input goquark`；
#   2. 同步更新下方 version 字面量（脚本不会改 .nix 里的 pname/version）；
#   3. aarch64 的 sha256 需要人工到 release 页下载后用 nix-prefetch-url
#      算出，填到下方 aarch64Sha256；
#   4. `nix flake check` 验证；
#   5. `nixos-rebuild switch` 验证。
#
# 二进制未注入版本号时显示 `dev`，对应 README「版本」一节说的
# `./scripts/version.sh` 流程——这里直接装上游 release，版本号会被 build
# 流程注入，运行时 `goquark version` 显示真实版本。
{
  pkgs,
  flake,
}:

let
  inherit (pkgs) lib stdenvNoCC;

  pname = "goquark";
  version = "v1.0.3";

  # x86_64 的 src 来自 flake input；aarch64 在这里手算（每个 url input
  # 只能配一个 url）。
  srcBySystem = {
    x86_64-linux = flake.inputs.goquark;
  };

  src =
    srcBySystem.${stdenvNoCC.hostPlatform.system}
      or (throw "goquark: 不支持的系统 ${stdenvNoCC.hostPlatform.system}");

  meta = {
    description = "Unofficial Quark Drive CLI / TUI / MCP client";
    homepage = "https://github.com/ButterFuture/GoQuark";
    license = lib.licenses.agpl3Plus;
    mainProgram = "goquark";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
in
stdenvNoCC.mkDerivation {
  inherit
    pname
    version
    src
    meta
    ;

  # flake URL input 拿到的是单一可执行文件（prefetch 后的 store path），
  # 没有 unpack 阶段。也不需要 build / configure。
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/goquark"
    runHook postInstall
  '';
}
