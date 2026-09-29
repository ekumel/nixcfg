# dwproton-bin：Dawn Winery 维护的 Proton 分支（基于 Proton-CachyOS），
# 用作 Steam 的第三方 Proton 兼容工具，同时被 Bottles 当自定义 Proton runner。
#
# 放在 packages/（blueprint 约定的包目录，暴露为 perSystem.self.dwproton）：
#   system 侧（modules/nixos/gaming.nix，Steam）与用户侧
#   （modules/home/xumel/packages/gaming.nix，Bottles）都要用它。
#   若收进 modules/nixos/，用户空间会反向依赖系统空间，破坏仓库分层。
#
# 上游通过自建 Forgejo（dawn.wine）发 x86_64 预编译包：
#   dwproton-<ver>-x86_64.tar.xz
# flake input 跟踪（flake.nix 的 dwproton URL input，flake = false）。
# 升级流程：
#   1. 跑 `./scripts/update-third-party.sh dwproton`：脚本用 Gitea v1 API
#      探测上游 latest release（端点
#      `https://dawn.wine/api/v1/repos/dawn-winery/dwproton/releases/latest`），
#      生成新 URL、修改 flake.nix 的 url 字段、
#      `nix flake lock --update-input dwproton`（会重新下载 ~340MB 的
#      tarball 并解包）；
#   2. 同步更新下方 version 字面量（脚本不会改 .nix 里的 pname/version）；
#   3. `nix flake check` 与 `nixos-rebuild switch` 验证。
# 解包后是单一顶层目录（由上游 Makefile 的 `redist` 目标
# `tar -cvJf $(BUILD_NAME).tar.xz $(BUILD_NAME)` 产生），里面就是 Proton
# 工具根：compatibilitytool.vdf / toolmanifest.vdf / proton / proton_dist.tar 等。
#
# 关键：它不能被装进 environment.systemPackages / profile——给 Steam 用时必须经
# programs.steam.extraCompatPackages 注入，Steam 才能通过
# STEAM_EXTRA_COMPAT_TOOLS_PATHS 扫到。做法与 nixpkgs 的 proton-ge-bin 完全一致：
# 声明一个 `steamcompattool` 输出，由 lib.makeSearchPathOutput 拼进该环境变量。
# Bottles 则是把这个输出软链进 ~/.local/share/bottles/runners/（见用户侧 gaming.nix）。
{
  pkgs,
  flake,
}:

let
  inherit (pkgs) lib stdenvNoCC;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dwproton-bin";
  version = "dwproton-11.0-13";
  src = flake.inputs.dwproton;

  # 当前 Nix（2.18+）会把 flake URL input 指向的 .tar.xz 自动解包到
  # store 里的 -source 目录，$src 直接就是解包后的根目录；上游是否保留
  # 单一顶层目录两种都有可能。无需再走标准 unpack，先把 locate tool root
  # 抽出，再原地复制到 steamcompattool 输出（Proton 解包后体积很大，
  # 避免落到 $sourceRoot 再整体复制）。
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

    # 定位含 compatibilitytool.vdf 的工具根（兼容有/无单一顶层目录两种
    # 上游打包方式），再原地复制到 $steamcompattool。
    toolRoot="$(dirname "$(find "$src" -name compatibilitytool.vdf -print -quit)")"
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
