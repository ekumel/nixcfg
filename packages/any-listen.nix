# any-listen：any-listen/any-listen —— 跨平台私有音乐播放服务，
# 桌面端壳（any-listen/any-listen-desktop 只发 release，不发源码；
# 业务代码在 any-listen/any-listen 主仓）。
# 定位是自托管音乐库 + 播放服务（WebDAV / 本地目录 / 网盘挂载），
# 本机上接替 splayer-next 作为主力听歌客户端。
#
# 上游不发源码包，只发三平台预编译产物：macOS .dmg/.zip / Windows .exe /
# Linux .deb + .AppImage（均为 electron-builder standard 产物，另附
# latest-linux.yml 供 electron-updater 用）。nixpkgs 不收录。
#
# 为什么选 .deb 而不是 .AppImage：
#   两者内容几乎相同（electron-builder 从同一份 app 打出），.AppImage 把
#   glibc / GTK / 图标等再打包一份（133 MB），.deb 只有 104 MB。解包后走
#   lib/build-deb-fhs.nix 的公共流程（ar 解包 → buildFHSEnv → 搬 .desktop
#   与图标 → 改写 Exec= → bind /etc/nixos），closure 更小、升级路径与
#   orca / baidunetdisk 一致。理由与 fluxdown.nix 顶部同类。
#
# .deb 内部结构（Electron 标准 layout，与 orca 同型）：
#   /opt/any-listen/any-listen              主二进制（210 MB）
#   /opt/any-listen/{libffmpeg.so,libEGL.so,libGLESv2.so,
#                    libvk_swiftshader.so,libvulkan.so.1,
#                    chrome-sandbox,*.pak,icudtl.dat,locales/,resources/,...}
#   /usr/share/applications/any-listen.desktop
#   /usr/share/icons/hicolor/{16,24,32,48,64,128,256,512}x{...}/apps/any-listen.png
#   control Depends: libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils
#                   libatspi2.0-0 libuuid1 libsecret-1-0
#
# 依赖覆盖（readelf -d 实测 NEEDED，非照抄 control）：
#   主二进制的 NEEDED 与 orca 几乎完全相同——glib / nss / nspr / atk /
#   atk-bridge / cups / dbus / cairo / gtk-3 / pango / X11 / Xcomposite /
#   Xdamage / Xext / Xfixes / Xrandr / gbm / expat / xcb / xkbcommon /
#   udev / asound / atspi / libm / libgcc_s / libc / ld-linux，
#   已全部由 lib/fhs-shared-pkgs.nix 覆盖，本包不重复列出。
#   另有两项 **dlopen 而非链接** 的运行时依赖，readelf -d 看不到、
#   必须在主二进制里 grep 字符串才能确认，二进制里确有引用：
#     libnotify —— Chromium 的通知后端。缺了不会崩，但桌面通知静默失效，
#                  控制台报 "libnotify is not available" 一类的告警。
#     libsecret —— GNOME keyring 后端，Any Listen 拿它存 WebDAV / 网盘
#                  账号密码。缺了登录态存不住。
#   control 里另外声明的 libxss1 / libuuid1 实测在二进制中 **无任何引用**
#   （grep 计数为 0，Electron 这版没编进去），故不加。
#
# chrome-sandbox 的处理（SUID）：
#   与 orca 同款——deb 自带的 chrome-sandbox 是 SUID-root 二进制，NixOS
#   不支持任意 SUID，保留原文件不用；Electron 会自动回退到普通用户
#   namespace + seccomp 的 SUID-less 沙箱，不需要 --no-sandbox（且
#   主进程自己 arg-parse，传了反而报 "bad option: --no-sandbox"）。
#
# 音频：
#   这是个音乐播放器，走 FHS 沙箱不额外加东西即可出声——buildFHSEnv
#   默认 `--dev-bind /dev /dev`（/dev/snd 可见），/etc/alsa 与
#   /etc/asound.conf 在默认 etcBindEntries 里被软链回宿主机，/run 在
#   自动挂载列表里（PipeWire / PulseAudio socket 可达），主二进制链接的
#   libasound.so.2 由共享清单的 alsa-lib 提供。
#
# 版本与 src 由 flake input 提供（flake.nix 的 any-listen URL input，
# flake = false）。version 钉为字面量；升级流程：
#   1. 跑 `./scripts/update-third-party.sh any-listen`：脚本从 GitHub
#      Releases latest（自动跳过 prerelease）取 .deb 资产、改 flake.nix
#      的 url 字段、`nix flake lock --update-input any-listen`；
#   2. 同步更新下方 version 字面量；
#   3. `nix flake check` 与 `nixos-rebuild switch` 验证。
{
  pkgs,
  flake,
}:

let
  pname = "any-listen";
  version = "0.9.0";

  # x86_64 的 src 来自 flake input；aarch64 在这里手算（每个 url input
  # 只能配一个 url）。
  srcBySystem = {
    x86_64-linux = flake.inputs.any-listen;
  };

  src =
    srcBySystem.${pkgs.stdenvNoCC.hostPlatform.system}
      or (throw "any-listen: 不支持的系统 ${pkgs.stdenvNoCC.hostPlatform.system}");
in
# 走 flake.lib 而非相对路径 import ../lib/：这样本包被别的 flake 消费
# （作为 overlay 或 packages 引用）时仍能解析，见 lib/default.nix 顶部说明。
(flake.lib.build-deb-fhs pkgs) {
  inherit
    pname
    version
    src
    ;

  binaryPath = "opt/any-listen/any-listen";
  desktopFile = "any-listen.desktop";

  # .desktop 的 Exec 是 `/opt/any-listen/any-listen %U` → 换成 wrapper
  # 暴露的 `any-listen`（pname 同名）。上游 Categories 值合法
  # （Utility;AudioVideo;Audio;Player;Music;），不传 desktopCategories。
  # 上游 MimeType 只声明了 x-scheme-handler/anylisten（应用内的自定义
  # 协议，用于各音源跳转），本包不把它注册成系统默认处理器——那属于
  # 全局 mime 绑定策略，不是打包职责。
  execFrom = "/opt/any-listen/any-listen";

  # dlopen 型运行时依赖，见文件头「依赖覆盖」段。
  extraTargetPkgs = with pkgs; [
    libnotify
    libsecret
  ];

  meta = {
    description = "Cross-platform private music playback service (desktop shell)";
    homepage = "https://github.com/any-listen/any-listen";
    # 上游 LICENSE 是「Custom License based on AGPL v3.0」，在 AGPL-3.0
    # 之上附加了禁止商业使用的条款（control 里也写着 License: unknown，
    # any-listen-desktop 仓根本没有 LICENSE 文件）。附加限制使其不再是
    # OSI 认证的自由许可，故标 unfree 而非 agpl3Only——仓库 flake.nix
    # 已开 nixpkgs.config.allowUnfree。
    license = pkgs.lib.licenses.unfree;
    platforms = [
      "x86_64-linux"
    ];
  };
}
