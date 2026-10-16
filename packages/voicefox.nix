# voicefox：emoeem/voicefox —— Rust + ratatui + libmpv 驱动的键盘优先
# 终端音乐播放器（TUI，多音源 / 歌词 / 本地音乐 / 下载 / 收藏 / 歌单）。
#
# 与本目录其它包的关键差别（对照 goquark.nix / kelivo.nix）：
#   - goquark 是纯 Go 静态二进制，install 完就能跑；
#   - kelivo / zedg / orca 是 GUI app，要走 buildFHSEnv 补 /usr 路径树；
#   - voicefox 介于两者之间：它是**纯终端程序**，不碰 GTK / Wayland /
#     字体 / GPU / 桌面集成那一套，因此完全不需要 FHS 沙箱——FHS 在这里
#     只会白白增加启动开销和 bwrap 依赖。缺的只是动态库，用
#     autoPatchelfHook 补 RPATH 即可。
#
# 动态库处理（这是本包唯一的技术点）：
#   上游 Linux release 的 zip 里**只有 voicefox 一个可执行文件**，不像
#   Windows 版那样附带 libmpv-2.dll。readelf -d 显示它有三个外部依赖
#   在 nixpkgs 之外：
#     libmpv.so.2   → pkgs.mpv（libmpv 本体）
#     libssl.so.3   → pkgs.openssl
#     libcrypto.so.3 → pkgs.openssl
#   其余（libgcc_s / libm / libc / ld-linux）由 stdenv 的 cc-wrapper 链路
#   自动处理，不需要显式列出。
#
#   为什么不用 buildFHSEnv 的 targetPkgs：本机 home.packages 里的 mpv
#   （mpv-with-scripts）已经把 libmpv.so.2 暴露进用户 profile 的 lib 目录
#   （/nix/store/...-home-manager-path/lib/），运行时环境本来就够。但
#   **不能依赖 profile 的偶然状态**——home-manager 重建、profile 被 GC
#   或 mpv 改版本后，这个二进制就会突然报 `error while loading shared
#   libraries: libmpv.so.2`。所以用 autoPatchelfHook 把 nixpkgs 的
#   mpv / openssl 显式写进 RPATH，让依赖关系固化在 store path 里。
#
#   选了 mpv 而不是 libmpv：nixpkgs 的 mpv 是多输出包，`libmpv` 输出
#   在部分版本上不稳定，mpv 主体一定带 libmpv.so.2。
#
# 版本与 src 由 flake input 提供（flake.nix 的 voicefox URL input，
# flake = false，见 third-party.nix 顶部注释）。升级流程：
#   1. 跑 `./scripts/update-third-party.sh voicefox`：脚本探测 GitHub
#      Releases API 取最新 tag、生成新 URL、修改 flake.nix 的 url 字段、
#      `nix flake lock --update-input voicefox`；
#   2. 同步更新下方 version 字面量（脚本不会改 .nix 里的 pname/version）；
#   3. 若上游新增/重命名架构 asset，需同步改 flake.nix 的 url 后缀；
#   4. `nix flake check` 验证；
#   5. `nixos-rebuild switch` 验证。
#
# 运行时行为（不需要在 Nix 侧做任何配置）：
#   配置文件 ~/.config/voicefox/config.toml 由程序**首次启动时自动生成**
#   （上游明确支持自动迁移 + 缺失字段填默认值），所以这里不预置配置。
#   桌面通知走 D-Bus、MPRIS 走 D-Bus（`integration.mpris = true`），
#   音频输出用 libmpv 连 PipeWire——本机 modules/nixos/audio.nix 跑的是
#   `services.pipewire` 且 `pulse.enable = true`，libmpv 默认 ao 走 pulse
#   兼容层，无需额外 wrapper 参数。
{
  pkgs,
  flake,
}:

let
  inherit (pkgs) lib stdenv;
  inherit (stdenv) hostPlatform;

  pname = "voicefox";
  version = "v0.4.0";

  # 上游 zip 的 asset 名按架构区分，而一个 flake url input 只能配一个
  # url（见 goquark.nix 的同类说明）。本机是 x86_64，用 input 里的
  # x86_64 zip；aarch64 需要另建 input 并在此处分支。
  srcBySystem = {
    x86_64-linux = flake.inputs.voicefox;
  };

  src = srcBySystem.${hostPlatform.system} or (throw "voicefox: 不支持的系统 ${hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "voicefox";
  inherit
    version
    src
    ;

  # mpv / openssl 放 buildInputs（而非只写进 RPATH）有两个原因：
  #   1. autoPatchelfHook 的 fixup 阶段在 sandbox 里扫描依赖时，库必须在
  #      buildInputs / nativeBuildInputs 中才能被 NIX_LD 找到；
  #   2. 这样 postFixup 里的 makeLibraryPath 与 hook 的自动修补指向同一
  #      组 store path，不会出现"RPATH 写了一份、hook 又改一份"的偏差。
  # gcc.lib 补 libgcc_s.so.1（原始二进制在 glibc 发行版上链的，nixpkgs
  # 侧由 stdenv.cc 的 lib 提供）。
  buildInputs = [
    pkgs.mpv
    pkgs.openssl
    pkgs.gcc.cc.lib
  ];

  nativeBuildInputs = [ pkgs.autoPatchelfHook ];

  dontConfigure = true;

  # zip 已被 Nix 的 fetchurl 解成扁平目录（根目录直接是 voicefox，
  # 无顶层子目录），跳过 unpackPhase 避免二次 copy——理由同 kelivo.nix。
  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src/voicefox" "$out/bin/voicefox"
    runHook postInstall
  '';

  # 动态库：mpv 提供 libmpv.so.2，openssl 提供 libssl.so.3 / libcrypto.so.3。
  # autoPatchelfHook 已经能自动补上，但这里再显式 set-rpath 一次，原因：
  #   hook 的自动修补依赖 buildInputs 里的**可发现性**，一旦将来把 mpv
  #   挪出 buildInputs（例如改用 mpv.lib 或某个封装包），hook 会静默
  #   失效并产出"能 build 但运行时报 libmpv.so.2 not found"的产物。
  #   显式写死 RPATH 让依赖关系固化在 store path 里，行为不随 buildInputs
  #   的调整而漂移。pkgs.gcc.cc.lib 补 libgcc_s.so.1。
  postFixup = ''
    patchelf --set-rpath "${
      lib.makeLibraryPath [
        pkgs.mpv
        pkgs.openssl
        pkgs.gcc.cc.lib
      ]
    }" "$out/bin/voicefox"
  '';

  meta = {
    description = "Keyboard-first TUI music player powered by libmpv";
    homepage = "https://github.com/emoeem/voicefox";
    license = lib.licenses.mit;
    mainProgram = "voicefox";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
