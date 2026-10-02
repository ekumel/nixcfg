# wechat：QQ 官方 Linux 客户端（unfree）。
#
# 上游仅在 https://dldir1v6.qq.com/weixin/Universal/Linux/ 提供 AppImage，
# 且文件名不含版本号、只保留最新版，所以 flake.nix 的 wechat URL input 的
# url 里没有版本占位符。版本号历史上从官方下载页 https://linux.weixin.qq.com/
# 的 `main-section__bd-version` 元素抓取。
#
# 升级流程：
#   1. 跑 `./scripts/update-third-party.sh wechat`：脚本用 curl + grep 抓
#      官方下载页、取版本号、修改 packages/wechat.nix 里的 version 字面量
#      （脚本与 flake URL 类不同：URL 不变、只刷 narHash 与 version）；
#   2. 若 aarch64 也需要，手动更新下面 aarch64-linux 的 sha256；
#   3. `nix flake check` 与 `nixos-rebuild switch` 验证。
#
# 打包策略：与 nixpkgs pkgs/by-name/we/wechat/linux.nix 完全相同——
# appimageTools.extract 解包，patchelf --replace-needed 替换 libtiff.so.5
# 到 libtiff.so（nixpkgs 没有 libtiff.so.5 这个版本），再 wrapAppImage
# 产生 $out/bin/wechat wrapper。
{
  pkgs,
  flake,
}:

let
  inherit (pkgs) lib stdenv appimageTools;

  inherit (stdenv.hostPlatform) system;

  pname = "wechat";
  version = "4.1.13";

  # x86_64 的 src 来自 flake input；aarch64 在这里手算（每个 url input
  # 只能配一个 url）。
  srcBySystem = {
    x86_64-linux = flake.inputs.wechat;
  };

  src = srcBySystem.${system} or (throw "wechat: 不支持的系统 ${system}");

  appimageContents = appimageTools.extract {
    inherit pname version src;
    postExtract = ''
      patchelf --replace-needed libtiff.so.5 libtiff.so $out/opt/wechat/wechat
    '';
  };

  meta = {
    description = "Messaging and calling app";
    homepage = "https://www.wechat.com/en/";
    downloadPage = "https://linux.weixin.qq.com/en";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "wechat";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
in
appimageTools.wrapAppImage {
  inherit pname version meta;

  src = appimageContents;

  # FHS 沙箱里 /etc 是 tmpfs，只回链了 nixpkgs 白名单里的少数条目，
  # /etc/nixos 不在其中。wrapper 会 --chdir "$(pwd)"，若从 /etc/nixos 启动
  # 就会报 "bwrap: Can't chdir to /etc/nixos"。把宿主机的 /etc/nixos 以可
  # 写方式绑进沙箱，使其既可作为 CWD。原因同 zedg.nix / genoffice.nix。
  extraBwrapArgs = [
    "--bind"
    "/etc/nixos"
    "/etc/nixos"
  ];

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cp ${appimageContents}/wechat.desktop $out/share/applications/
    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp ${appimageContents}/wechat.png $out/share/icons/hicolor/256x256/apps/

    substituteInPlace $out/share/applications/wechat.desktop --replace-fail AppRun wechat
  '';
}
