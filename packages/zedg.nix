# zedg：Zed 汉化版（AUR zedg 的 Nix 等价物），使用 buildFHSEnv 打包。
#
# 参考 https://aur.archlinux.org/packages/zedg：
#   - 直接下载上游预编译 tarball（带 /usr/{bin,lib,share} 树）。
#   - 不需要 build 步骤（options=('!debug')，纯二进制）。
#   - 上游 tarball 自带 /usr/lib/zedg/libgit2.so.1.1.0，
#     libgit2 不必额外从 nixpkgs 提供。
#
# 用 buildFHSEnv 而不是裸 mkDerivation 的原因：
#   Zed 假定 /usr/lib、/usr/share 等路径存在（扩展、GPU 驱动加载、wayland
#   socket 等），Nix store 的非 FHS 路径会破坏这些路径解析——nixpkgs 里的
#   zed-editor-fhs 就是同款做法（用 bubblewrap 构造 FHS-like 视图）。
#
# 版本与 src 由 _sources/generated.nix 提供（nvfetcher 跟踪 GitHub release）。
# _sources 中只跟踪 x86_64 的 tarball，aarch64 的 hash 在此 file 内通过
# fetchurl + 写死 hash 二次处理（nvfetcher 的 fetch.url 不支持 per-arch）。
#
# 升级流程：
#   1. 跑 `nvfetcher -c ./nvfetcher.toml`，自动跟新 GitHub release；
#   2. x86_64 的 sha256 由 nvfetcher 重算写进 generated.nix；
#   3. aarch64 的 sha256 需要人工到 release 页下载后用 nix-prefetch-url
#      算出，填到下方 aarch64Sha256；
#   4. `nixos-rebuild switch` 验证。
{
  pkgs,
  flake,
}:

let
  inherit (pkgs) lib stdenv buildFHSEnv;
  # nvfetcher 源：统一从 flake.lib.sources 取（见 lib/default.nix）。
  sources = flake.lib.sources pkgs;

  pname = "zedg";
  version = sources.zedg.version;

  # 与 AUR PKGBUILD 的 source_x86_64 / source_aarch64 对齐。
  # x86_64 的 src 由 nvfetcher 写入 generated.nix（含 url + sha256）。
  srcBySystem = {
    x86_64 = sources.zedg.src;
  };

  src = srcBySystem.${stdenv.hostPlatform.linuxArch}
    or (throw "zedg: 不支持的系统 ${stdenv.hostPlatform.system}");

  # 原始包：解压 tarball，按 AUR `package()` 的做法把整个 usr/ 树复制到 $out。
  unpacked = stdenv.mkDerivation {
    inherit pname version src;
    dontConfigure = true;
    dontBuild = true;
    sourceRoot = ".";
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r usr "$out/"
      # AUR 包要求 bin 可执行。
      chmod 755 "$out/usr/bin/zedg"
      runHook postInstall
    '';
    meta = {
      description = "Zed editor with globalization support (pre-built binary)";
      homepage = "https://github.com/WenYin-Community/zed-globalization";
      license = with lib.licenses; [
        asl20
        gpl3Plus
        agpl3Plus
      ];
      platforms = [ "x86_64-linux" "aarch64-linux" ];
    };
  };

  # targetPkgs 说明（详见 ../lib/fhs-shared-pkgs.nix）：
  #   buildFHSEnv 只把列表里每个包自身的 out/lib/bin 输出合到 rootfs 的
  #   /usr/lib64，不递归传播 propagatedBuildInputs（与 upstream 的
  #   zed-editor-fhs 不同：那里底层是 rust 包，构建依赖自动进 rootfs）。
  #   zedg 是纯二进制 tarball，没有任何 Nix 级 buildInputs，所以这里必须
  #   把所有需要的运行时库显式列出来——统一从 ../lib/fhs-shared-pkgs.nix 拿。
  #
  #   executableName = pname 让 $out/bin/zedg 直接成为 wrapper，这样上游
  #   .desktop 里的 Exec=zedg 不用 substitute 就能被系统识别。
in
buildFHSEnv {
  name = "${pname}-fhs";
  executableName = pname;
  targetPkgs = pkgs: import ../lib/fhs-shared-pkgs.nix { inherit pkgs; };
  multiPkgs = pkgs: [ ];
  # runScript 是 FHS env 启动时调用的命令：直接运行 unpacked 里的二进制。
  runScript = "${unpacked}/usr/bin/zedg";
  # FHS 沙箱里 /etc 是 tmpfs，只回链了 nixpkgs 白名单里的少数条目，/etc/nixos
  # 不在其中。wrapper 在进入沙箱时会 `--chdir "$(pwd)"`，若从 /etc/nixos 启动
  # 就会因目标不存在而报 "bwrap: Can't chdir to /etc/nixos: No such file or
  # directory"。把宿主机的 /etc/nixos 以可写方式绑进沙箱，使其既可作为 CWD，
  # 也能被 Zed 正常读写（用于编辑本机 NixOS 配置）。
  extraBwrapArgs = [
    "--bind"
    "/etc/nixos"
    "/etc/nixos"
  ];
  # 把上游 tarball 自带的 .desktop 与 hicolor 图标暴露到 wrapper 的
  # $out/share/。buildFHSEnv 默认不会复制内部 pkg 的 share 目录，
  # 导致 NixOS 桌面环境扫描不到 zedg.desktop / zedg.png。
  # Exec= 行已经是 `zedg %F`，与上面的 executableName 一致，无需 substitute。
  extraInstallCommands = ''
    cp -r ${unpacked}/usr/share/. $out/share/
    # DMS matugen（core/internal/matugen/matugen.go）只在 PATH 找到 zed /
    # zeditor / zedit 时才生成 Zed 主题。wrapper 默认只暴露 zedg，缺少
    # 任意别名都会让 DMS 跳过 Zed 模板。建一个到同一 wrapper 的软链即可，
    # FHS 沙箱与二进制路径都和 zedg 完全一致，配置目录仍走 XDG 路径。
    ln -s zedg $out/bin/zed
  '';
  passthru = {
    inherit unpacked;
    bin = "${unpacked}/usr/bin/zedg";
  };
}
