# dwproton-bin：Dawn Winery 维护的 Proton 分支（基于 Proton-CachyOS），
# 用作 Steam 的第三方 Proton 兼容工具，同时被 Bottles 当自定义 Proton runner。
#
# 放在 packages/（blueprint 约定的包目录，暴露为 perSystem.self.dwproton）：
#   system 侧（modules/nixos/system/gaming.nix，Steam）与用户侧
#   （modules/home/xumel/packages/gaming.nix，Bottles）都要用它。
#   若收进 modules/nixos/，用户空间会反向依赖系统空间，破坏仓库分层
#   （同 fetch/sources.nix 头部所述原则）。
#
# 上游通过自建 Forgejo（dawn.wine）发 x86_64 预编译包：
#   dwproton-<ver>-x86_64.tar.xz
# 解包后是单一顶层目录（由上游 Makefile 的 `redist` 目标
# `tar -cvJf $(BUILD_NAME).tar.xz $(BUILD_NAME)` 产生），里面就是 Proton
# 工具根：compatibilitytool.vdf / toolmanifest.vdf / proton / proton_dist.tar 等。
#
# 关键：它不能被装进 environment.systemPackages / profile——给 Steam 用时必须经
# programs.steam.extraCompatPackages 注入，Steam 才能通过
# STEAM_EXTRA_COMPAT_TOOLS_PATHS 扫到。做法与 nixpkgs 的 proton-ge-bin 完全一致：
# 声明一个 `steamcompattool` 输出，由 lib.makeSearchPathOutput 拼进该环境变量。
# Bottles 则是把这个输出软链进 ~/.local/share/bottles/runners/（见用户侧 gaming.nix）。
#
# 版本与 src 由 fetch/_sources/generated.nix 提供（nvfetcher 跟踪 dawn.wine
# release，见 fetch/nvfetcher.toml 的 [dwproton]）。
{
  pkgs,
  flake,
}:

let
  inherit (pkgs) lib stdenvNoCC;
  # nvfetcher 源：统一从 flake.lib.sources 取（见 lib/default.nix）。
  sources = flake.lib.sources pkgs;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dwproton-bin";
  version = sources.dwproton.version;
  src = sources.dwproton.src;

  # src 是 .tar.xz：手动解到 steamcompattool 输出，省掉标准 unpack 先落
  # $sourceRoot 再整体复制一遍（Proton 解包后体积很大）。
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  outputs = [
    "out"
    "steamcompattool"
  ];

  installPhase = ''
    runHook preInstall

    # out 仅作占位，阻止它被直接加入环境（加入也没用，Steam 只认
    # steamcompattool 输出）。留一行提示，方便排查误用。
    echo "${finalAttrs.pname} must be installed via programs.steam.extraCompatPackages." > $out

    mkdir -p $steamcompattool

    # 解到临时目录，再定位含 compatibilitytool.vdf 的工具根，这样无论
    # 上游是否保留顶层目录都能工作（当前是有单一顶层目录的）。
    tmp="$(mktemp -d)"
    tar -xJf "$src" -C "$tmp"
    toolRoot="$(dirname "$(find "$tmp" -name compatibilitytool.vdf -print -quit)")"
    cp -a "$toolRoot"/. "$steamcompattool/"

    runHook postInstall
  '';

  meta = {
    description = "Dawn Winery's Proton fork (based on Proton-CachyOS), a Steam Play compatibility tool";
    homepage = "https://dawn.wine/dawn-winery/dwproton";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
