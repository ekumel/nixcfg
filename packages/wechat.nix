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

  appimage = appimageTools.wrapAppImage {
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

      # 输入法补丁：微信打不出中文（fcitx5 本身正常，其他程序也正常）。
      #
      # 根因：微信 4.x 把 Qt **静态链接**进了二进制——主进程的 /proc/*/maps 里
      # 没有任何 libQt*，但二进制内部有完整 Qt 符号（QAccessibleInterface /
      # QPointer / QWaylandShmBuffer…）。会话里没有 QT_IM_MODULE 时，Qt 退回
      # 平台默认实现，微信于是走 Wayland text-input-v2 协议连 fcitx5。fcitx5 侧
      # 能看到 `IC [...] program:wechat frontend:wayland_v2`，说明连接建立了，
      # 但该通道在微信内部不生效（按键 / preedit 到不了 fcitx5），所以切不出候选
      # 框；同时 `Group [x11::0] has 0 InputContext(s)`，传统 XIM 通道一个客户端都
      # 没有。kitty / Zed / zen 同样走 wayland_v2 却正常，说明不是 fcitx5 配错了。
      #
      # 修法：显式指定 QT_IM_MODULE=fcitx，让 Qt 改用二进制内置的 FcitxQt 输入
      # 上下文（走 fcitx5 的 X11 / D-Bus IPC 通道），绕开坏掉的 text-input-v2。
      # 注意值是 `fcitx` 而不是 `fcitx5`——后者是包名，Qt 找不到对应插件。
      #
      # 关键点：FcitxQt 是**内嵌**在二进制里的（搜得到 fcitx::FcitxQtConfigOption /
      # FcitxQtStringKeyValue / QIBusPlatform* 等类），不必从宿主机加载
      # libfcitx5platforminputcontextplugin.so，所以 FHS 沙箱挡不住它；它需要的
      # X11 socket 与 D-Bus socket 也都被 bwrap 正常 bind 进沙箱。
      # $out/bin/wechat 此时还是指向 wechat-4.1.13-bwrap wrapper 的软链，
      # wrapProgram 会把它改名成 .wechat-wrapped 再生成一层 199 字节的脚本；
      # 桌面文件 Exec=wechat %U 走 PATH，命中的正是这个新脚本。
      #
      # 放在 extraInstallCommands 而不是 postFixup：wrapAppImage 是 runCommand
      # 派生的，带 dontFixup = true，postFixup 根本不会执行。
      wrapProgram $out/bin/wechat --set QT_IM_MODULE fcitx
    '';
  };
in

# wrapProgram 要在 installPhase 里可用（extraInstallCommands 与它同处一个
# 阶段），而 wrapAppImage 只接受固定的一批参数，不透传 nativeBuildInputs，
# 所以这里补上 makeWrapper。
appimage.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
})
