# build-deb-fhs.nix：把「解包 .deb + buildFHSEnv 封装」这套固定流程抽成
# 可复用函数，供 packages/ 下所有 .deb 类预编译包调用。
#
# 为什么抽这一层：
#   baidunetdisk.nix / orca.nix 是同一套流程的两份拷贝——都是 Electron
#   应用、都只发 .deb、都需要「ar 解包 → buildFHSEnv 封装 → 搬 .desktop
#   与图标 → 改写 Exec=」。两份拷贝里 90% 的代码逐字相同，只有三处不同：
#     1. deb 内主二进制的路径（/opt/baidunetdisk/baidunetdisk vs /opt/Orca/orca-ide）
#     2. .desktop 文件名（baidunetdisk.desktop vs orca-ide.desktop）
#     3. .desktop 里 Exec= 的旧串 → 新串（wrapper 暴露的可执行名）
#   抽出来后新增一个 .deb 包只需 ~40 行元数据，且改一处沙箱参数对所有包
#   同时生效——原先两份拷贝里那些「原因同 wechat.nix / genoffice.nix」的
#   交叉注释终于可以收敛到这里写一次。
#
# 为什么必须用 buildFHSEnv 而不是直接 wrapBinary：
#   这些是预编译的 Electron 二进制，硬编码了 /usr/lib、/usr/share、/etc
#   之类的绝对路径，Nix 的 /nix/store 布局下直接跑会到处找不到文件。
#   buildFHSEnv 提供一个带 FHS 层级的 bwrap 沙箱把这些路径补齐。
#
# 沙箱 /etc/nixos 的绑定：
#   FHS 沙箱里 /etc 是 tmpfs，只回链了 nixpkgs 白名单里的少数条目，
#   /etc/nixos 不在其中。wrapper 进入沙箱时会 `--chdir "$(pwd)"`，若用户
#   恰好在 /etc/nixos 下启动就会报 "bwrap: Can't chdir to /etc/nixos: No
#   such file or directory"。所以把宿主机的配置目录可写地 bind 进去。
#   仓库里所有 FHS 包（wechat / genoffice / baidunetdisk / orca）都因此
#   需要这一段，集中在 bindConfigDir 参数里声明。
#
# chrome-sandbox 的处理（SUID）：
#   deb 自带的 chrome-sandbox 是 SUID-root 二进制，NixOS 不支持任意 SUID。
#   但 Electron 在拿不到可用的 SUID sandbox 时会自动回退到普通用户
#   namespace + seccomp 的 SUID-less 沙箱，而不是拒绝启动，所以这里保留
#   原文件不动（用不到但也无害）。注意不要给 Electron 主进程传
#   --no-sandbox：这些应用的主进程自己 arg-parse，传了反而报
#   "bad option: --no-sandbox"。
{
  pkgs,
  stdenvNoCC ? pkgs.stdenvNoCC,
  buildFHSEnv ? pkgs.buildFHSEnv,

  # ---- 必填参数 ----
  pname,
  version,
  src,
  # deb 解包后主二进制所在路径（相对解包根，即 $out）。
  # 这个路径会被拼进 runScript，成为 wrapper 实际执行的程序。
  binaryPath,

  # ---- 可选参数 ----
  # wrapper 对外暴露的可执行名，也是替换 .desktop 里 Exec= 的目标串。
  executableName ? pname,
  # 最终包的 meta。license / description / homepage / platforms 由调用方
  # 给出；mainProgram / sourceProvenance 有默认值且可被覆盖。
  meta ? { },
  # .desktop 文件名（相对 deb 内的 usr/share/applications/）。
  # 传 null 表示该 .deb 不带 .desktop，跳过 Exec 改写。
  desktopFile ? null,
  # .desktop 里 Exec= 的旧串，替换为 execTo。
  # 典型值是 deb 里的绝对路径，可能带 --no-sandbox 之类的 flag。
  execFrom ? null,
  # 替换成的字符串，默认 wrapper 暴露的可执行名（= pname）。
  # orca 的情况是 /opt/Orca/orca-ide → orca（pname 也是 orca）。
  execTo ? pname,
  # 在 fhs-shared-pkgs 之外追加的运行时库。
  # 公共列表已经覆盖通用图形栈 + Electron 的 GTK/GL/NSS/drm/cups，
  # 只有包特有的依赖才需要往这里加。
  extraTargetPkgs ? [ ],
  # bind 进沙箱的宿主机配置目录，见文件头说明。
  bindConfigDir ? "/etc/nixos",
  # passthru 给最终包；默认把 unpacked 暴露出去，便于调试与二次打包。
  passthru ? { },
}:

let
  inherit (pkgs) binutils;

  # ---- 第一步：解包 .deb ----
  #
  # .deb 是 ar 归档，内含 control.tar.* / data.tar.* / debian-binary 三段。
  # 不能用 `dpkg-deb -x`：它把 owner 设成 0:0，Nix chroot 会以
  # "suspicious ownership or permission" 拒收。改为 `ar x` 取出
  # data.tar.* 再 `tar --no-same-owner` 解开。
  #
  # 不用 stdEnv 默认 unpackPhase：.deb 不被 libarchive 当 tar 读，会失败。
  unpacked = stdenvNoCC.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [ binutils ];

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      tmp=$(mktemp -d)
      # ar 解开 .deb：产物里有 control.tar.* / data.tar.* / debian-binary。
      ar x "$src" --output="$tmp"
      # data.tar.* 可能是 .xz / .gz / .zst / 无压缩；用 tar 自动嗅探。
      data_tar=$(ls "$tmp"/data.tar.* 2>/dev/null | head -n1)
      if [ -z "$data_tar" ]; then
        echo "找不到 data.tar.* in $tmp" >&2
        ls -la "$tmp" >&2
        exit 1
      fi
      # --no-same-owner：忽略 tar 内的 uid/gid，否则 Nix chroot 会拒收
      # （root-owned 输出被认为是「suspicious ownership」）。
      tar --extract --file="$data_tar" --directory="$out" --no-same-owner
      # 确保主二进制可执行（deb 里已经是 755，但 tar 在某种 umask 下
      # 可能缩水，再 chmod 一遍保险）。
      chmod +x "$out/${binaryPath}"
      rm -rf "$tmp"
      runHook postInstall
    '';
  };

  # .desktop 搬运 + Exec 改写。上游 .desktop 的 Exec 指向 deb 内部的绝对
  # 路径（如 /opt/Orca/orca-ide），那在 Nix 里不存在，必须换成 wrapper
  # 暴露的可执行名。守卫让缺 .desktop / 缺图标的 deb 也能安全走这条路。
  installDesktop =
    if desktopFile == null then
      ""
    else
      ''
        if [ -f "${unpacked}/usr/share/applications/${desktopFile}" ]; then
          cp "${unpacked}/usr/share/applications/${desktopFile}" \
            "$out/share/applications/${desktopFile}"
          substituteInPlace "$out/share/applications/${desktopFile}" \
            --replace-fail "${execFrom}" "${execTo}"
        fi
      '';

  installIcons = ''
    if [ -d "${unpacked}/usr/share/icons" ]; then
      cp -r "${unpacked}/usr/share/icons/." "$out/share/icons/"
    fi
  '';
in
buildFHSEnv {
  name = "${pname}-fhs";
  inherit executableName;

  # 通用图形栈 + Electron 专属依赖，见 fhs-shared-pkgs.nix 的分组注释。
  targetPkgs = innerPkgs: (import ./fhs-shared-pkgs.nix { pkgs = innerPkgs; }) ++ extraTargetPkgs;

  # multiPkgs 显式置空：这些包没有「同一 app 的多个变体」（不像
  # wine / 32 位变体），buildFHSEnv 的默认行为就是空，这里写出来是为了
  # 表明「是有意为空」而非漏配。_pkgs 前缀表示形参未被使用。
  multiPkgs = _pkgs: [ ];

  extraBwrapArgs = [
    "--bind"
    bindConfigDir
    bindConfigDir
  ];

  # 直接调用解包后的 Electron 主二进制。不额外传 flag：这些应用的主进程
  # 自己 arg-parse，多余 flag 会被当成未知参数拒绝。
  runScript = "${unpacked}/${binaryPath}";

  extraInstallCommands = ''
    mkdir -p "$out/share/applications"
    mkdir -p "$out/share/icons"
  ''
  + installDesktop
  + installIcons;

  inherit passthru;

  meta = {
    mainProgram = executableName;
    sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
  }
  // meta;
}
