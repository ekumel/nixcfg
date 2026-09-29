# baidunetdisk：百度网盘 Linux 客户端（unfree）。
#
# 上游只发 .deb（https://pan.baidu.com/ 下载页入口），文件名带版本号，
# 走百度自家 CDN issuecdn.baidupcs.com，路径模式：
#   https://issuecdn.baidupcs.com/issue/netdisk/LinuxGuanjia/<VERSION>/baidunetdisk_<VERSION>_amd64.deb
# nixpkgs 不收录。
#
# 升级流程：
#   1. 跑 `./scripts/update-third-party.sh baidunetdisk`：脚本探测
#      https://pan.baidu.com/disk/home 下载页、取版本号、生成新 URL、
#      修改 flake.nix 的 url 字段、`nix flake lock --update-input baidunetdisk`；
#   2. 同步更新下方 version 字面量（脚本不会改 .nix 里的 version）；
#   3. aarch64 的 sha256 需要人工到下载页下载后用 nix-prefetch-url 算出；
#   4. `nix flake check` 验证；
#   5. `nixos-rebuild switch` 验证。
#
# 打包策略：Electron app 的「FHS-沙箱 + 预编译资源」组合（与 wechat.nix
# 同款思路，但 src 是 .deb 不是 AppImage）。
#   1. dpkg-deb -x 把 .deb 解到 unpacked/opt/baidunetdisk/；
#   2. buildFHSEnv 把 unpacked 当 runScript，运行时走 Electron；
#   3. extraBwrapArgs 把 /etc/nixos 绑进沙箱（与 wechat.nix 同款）；
#   4. extraInstallCommands 把 .desktop / 图标搬到 $out/share/。
#
# chrome-sandbox 的处理：deb 自带的 chrome-sandbox 是 SUID-root 二进制，
# NixOS 不支持任意 SUID。它本意是让 Electron 用 chrome 沙箱；但上游
# .desktop 的 Exec 行已经带 `--no-sandbox`，并且 Electron 在没有
# chrome-sandbox 时会自动降级到「无沙箱」模式而非拒绝启动，
# 因此直接保留原 chrome-sandbox 文件即可（用不到但也无害）。
{
  pkgs,
  flake,
}:

let
  inherit (pkgs) lib stdenvNoCC buildFHSEnv;

  pname = "baidunetdisk";
  version = "4.17.7";

  # x86_64 的 src 来自 flake input；aarch64 在这里手算（每个 url input
  # 只能配一个 url）。
  srcBySystem = {
    x86_64-linux = flake.inputs.baidunetdisk;
  };

  src =
    srcBySystem.${stdenvNoCC.hostPlatform.system}
      or (throw "baidunetdisk: 不支持的系统 ${stdenvNoCC.hostPlatform.system}");

  # 解包 .deb。Nix chroot 里不允许 root-owned 输出，所以不能用 dpkg-deb -x
  # （它把 owner 设为 0:0，触发「suspicious ownership or permission」拒收）。
  # 改为：先 `ar x` 取出 data.tar.*，再 `tar --no-same-owner` 解开。
  # .deb 是 ar 归档，内含 control.tar.* / data.tar.* / debian-binary 三段。
  unpacked = stdenvNoCC.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [ pkgs.binutils ];

    # .deb 不是 stdEnv 默认 unpacker 识别的格式（不被 libarchive 当 tar
    # 读），直接跳过 unpack，在 installPhase 里手解。
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    # .deb 的 data.tar.* 提取后根目录是 ./opt/baidunetdisk/... 与
    # ./usr/share/...；control / postinst 不需要。`ar` 来自 perl（@ARGV
    # 列表里的 perl 包装，会拉 perl 但走 cache）。
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
      chmod +x "$out/opt/baidunetdisk/baidunetdisk"
      rm -rf "$tmp"
      runHook postInstall
    '';
  };

  meta = {
    description = "Baidu Netdisk cloud storage client (Linux)";
    homepage = "https://pan.baidu.com/";
    # 上游「License: https://pan.baidu.com/disk/duty/」是用户协议链接，
    # 非 SPDX。参照 nixpkgs 的处理标 unfree + binaryNativeCode。
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "baidunetdisk";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
in
buildFHSEnv {
  name = "${pname}-fhs";
  executableName = pname;

  # Electron 运行时栈与 wechat / genoffice 类似：GTK / 字体 / Wayland /
  # GPU / TLS / dbus / NSS 等。直接复用 lib/fhs-shared-pkgs.nix。
  targetPkgs = pkgs: import ../lib/fhs-shared-pkgs.nix { inherit pkgs; };
  multiPkgs = pkgs: [ ];

  # FHS 沙箱里 /etc 是 tmpfs，只回链了 nixpkgs 白名单里的少数条目，
  # /etc/nixos 不在其中。wrapper 在进入沙箱时会 `--chdir "$(pwd)"`，
  # 若从 /etc/nixos 启动就会因目标不存在而报 "bwrap: Can't chdir to
  # /etc/nixos: No such file or directory"。把宿主机的 /etc/nixos 以
  # 可写方式绑进沙箱。原因同 wechat.nix / genoffice.nix。
  extraBwrapArgs = [
    "--bind"
    "/etc/nixos"
    "/etc/nixos"
  ];

  # 直接调用解包后的 Electron 主二进制。.desktop 的 Exec 是
  # `/opt/baidunetdisk/baidunetdisk --no-sandbox %U`——我们在 wrapper
  # 里把 `--no-sandbox` 也带上，这样 .desktop 里 Exec=baidunetdisk
  # 就行，不需要 wrapper 自动加 flags。
  runScript = "${unpacked}/opt/baidunetdisk/baidunetdisk --no-sandbox";

  # 复制 deb 自带的 .desktop 与 hicolor 图标到 wrapper 的 $out/share/，
  # 并把 Exec= 里的绝对路径改成 wrapper 暴露的可执行名。
  extraInstallCommands = ''
    mkdir -p "$out/share/applications"
    mkdir -p "$out/share/icons"

    # .desktop
    if [ -f "${unpacked}/usr/share/applications/baidunetdisk.desktop" ]; then
      cp "${unpacked}/usr/share/applications/baidunetdisk.desktop" \
        "$out/share/applications/baidunetdisk.desktop"
      # Exec=/opt/baidunetdisk/baidunetdisk --no-sandbox %U
      # →   Exec=baidunetdisk %U
      # 上游 Exec 已带 --no-sandbox；runScript 也已透传此 flag，
      # 所以这里直接去掉绝对路径即可，不重复加 flag。
      substituteInPlace "$out/share/applications/baidunetdisk.desktop" \
        --replace-fail "/opt/baidunetdisk/baidunetdisk --no-sandbox" "baidunetdisk"
    fi

    # 图标（deb 给了 1 个 scalable/ svg，覆盖大部分场景）。
    if [ -d "${unpacked}/usr/share/icons" ]; then
      cp -r "${unpacked}/usr/share/icons/." "$out/share/icons/"
    fi
  '';

  passthru = {
    inherit unpacked;
  };
}
