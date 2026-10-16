# fluxdown：zerx-lab/FluxDown —— 开源（AGPL-3.0）全功能下载管理器，
# 官方定位是「免费 IDM 替代品」。本包接替原先的 rayburst，理由见下方
# 「为什么换掉 rayburst」一节。
#
# 技术栈与 rayburst 完全不同，这点直接影响打包依赖：
#   rayburst = Tauri 2（系统 WebKitGTK 渲染）+ aria2-next 引擎
#   FluxDown = Rust + GPUI（ Zed 同源的原生 GPU 渲染 UI，无 WebView）
#               + 自研 Tokio 下载引擎
# 因此 **不需要 webkitgtk_4_1 / libsoup_3**，FHS rootfs 反而比 rayburst
# 轻不少（没有一整套 WebKit 多进程栈）。
#
# 协议：HTTP(S) / FTP / BitTorrent（magnet、DHT、UPnP）/ eD2K（含 Kad
# DHT）/ HLS（AES 解密）/ DASH。另带浏览器扩展（Chrome / Edge / Firefox，
# Native Messaging 中转）、MCP server（给 AI 客户端管下载）、RSS 订阅、
# 定时队列与插件。
#
# 架构（上游 README）：一个引擎多个前端。
#   fluxdown-desktop（GPUI UI）──WebSocket /rpc──┐
#   浏览器扩展 ──Native Messaging── fluxdown_nmh ┼→ fluxdown-agent
#                                                │      │
#                                                │      └→ fluxdownd（下载核心）
#                                                └──────────────┘
# CLI（另发的 FluxDown-CLI-*.tar.gz，musl 静态）走 HTTP API 连 agent。
# 桌面端默认监听 127.0.0.1:17800，管理 API 与 MCP 默认关闭，要在
# 应用「设置 → API 服务」里开。
#
# 打包策略：.deb 解包 + buildFHSEnv 封装，走 lib/build-deb-fhs.nix 的
# 公共流程（与 orca.nix / baidunetdisk.nix 同款），本文件只留本包特有
# 的元数据与依赖。选 .deb 而非 .AppImage：.deb 32 MB，AppImage 44 MB
# （重复打包 glibc / 图形栈）。打包细节见下方注释。
#
# .deb 内部结构（v0.5.5 实测）：
#   opt/fluxdown/fluxdown-desktop   主程序：GPUI 界面（48 MB）
#   opt/fluxdown/fluxdown-agent     agent：UI 网关 + 托盘 + 生命周期（22 MB）
#   opt/fluxdown/fluxdownd          daemon：引擎 + SQLite + 队列 / RSS（31 MB）
#   opt/fluxdown/fluxdown_nmh       浏览器扩展的 native-messaging host（420 KB）
#   opt/fluxdown/flux_down          176 字节 sh 脚本，--silentStart 时转给
#                                   agent --autostart（托盘自启用）
#   usr/bin/fluxdown-desktop       → /opt/fluxdown/fluxdown-desktop 软链
#   usr/bin/fluxdown-agent         → /opt/fluxdown/fluxdown-agent 软链
#   usr/share/applications/com.fluxdown.app.desktop
#   usr/share/icons/hicolor/256x256/apps/com.fluxdown.app.png
#
# **三个二进制必须与主程序同目录**（上游 README 原话：native 部署下
# fluxdown-agent 与 fluxdownd 要留在同一目录，agent 会按自身 exe 所在
# 目录去找 daemon）。解包后保持 opt/fluxdown 的原始布局，runScript 指到
# $unpacked/opt/fluxdown/fluxdown-desktop 时两个 sidecar 就在隔壁。
# 同理**不能**把主二进制单独 install 出来——那样 tray 会起不来。
#
# 依赖处理（readelf -d 实测 NEEDED，逐二进制）：
#   fluxdown-desktop: libxcb / libxkbcommon / libxkbcommon-x11
#                     ← 三者 shared 已覆盖（nixpkgs 的 libxkbcommon 一个
#                       out 同时含 libxkbcommon.so.0 与 libxkbcommon-x11.so.0）
#                     libgcc_s.so.1 ← gcc.cc.lib（**需 extra**，shared 没有）
#                     libc / libm ← buildFHSEnv 的 baseTargetPaths 自带
#   fluxdown-agent:   libgtk-3 / libgdk-3 / libcairo / libgdk_pixbuf /
#                     libgio-2.0 / libgobject-2.0 / libglib-2.0 ← shared 已覆盖
#                     （agent 负责托盘 + GTK 集成，所以 GTK 挂在 agent 上，
#                      主 UI 本身反而不链 GTK）
#   fluxdownd:        仅 libc / libgcc_s / libm —— 纯下载核心，无图形依赖
#   fluxdown_nmh:     仅 libc / libgcc_s
#
# 运行时 dlopen（不在 NEEDED 里，只能从二进制里 grep 字面量确认）：
#   libEGL.so.1        ← mesa（shared 已覆盖）
#   libwayland-client.so.0 ← wayland（shared 已覆盖）
#   Vulkan             ← GPUI 的 wgpu 后端走 Vulkan。deb 的 Depends 只
#                        硬依赖 libvulkan1、mesa-vulkan-drivers 放在
#                        Recommends，且二进制里 grep 不到 "libvulkan"
#                        字面量（ash 用 dlopen 动态拼名），所以按需补上
#                        vulkan-loader——少它就是「窗口起不来 / 黑屏」，
#                        列上的成本只有几 MB。真实 ICD 由宿主 NixOS 的
#                        /run/opengl-driver 经 profile 里的 XDG_DATA_DIRS
#                        提供（buildFHSEnv 自带这行）。
#   libxkbcommon-x11.so.0 ← 见上，同一个 libxkbcommon out
#
# deb 的 Depends 里还有 libxdo3（全局快捷键），但四个二进制都没 NEEDED、
# 也 grep 不到 libxdo 字面量，暂不列；真要全局热键失效再补 xdotool。
#
# 协议处理器：deb 自带的 .desktop 声明了 MimeType
#   application/x-bittorrent + x-scheme-handler/{magnet,ed2k,fluxdown}
# 系统级默认关联写在 modules/nixos/desktop/default.nix 的
# xdg.mime.defaultApplications，指向本包安装的 com.fluxdown.app.desktop。
# 注意上游**没有** thunder（迅雷）scheme，rayburst 那边的
# x-scheme-handler/thunder 关联一并去掉，否则会留一个失效的默认项。
#
# desktop ID 沿用上游的 com.fluxdown.app.desktop，**不需要**像 rayburst
# 那样换名：FluxDown 是 Rust 原生应用，不走 Tauri 的单实例注册，不会
# 往 ~/.local/share/applications 写一份 NoDisplay=true 的同名条目来
# 遮蔽 Nix 装的这份（rayburst 换小写 ID 就是为了绕开这个，见
# lib/build-deb-fhs.nix 的 desktopFileName 注释）。
#
# 网络：buildFHSEnv 的 unshareNet 默认 false，沙箱与宿主共享网络命名
# 空间，所以 agent 监听 127.0.0.1:17800、BT/DHT 出站、远程设备配对都正常。
#
# 渲染踩坑提示（与 rayburst 不同，这里没有坑）：
#   rayburst 走 WebKitGTK 软件合成会白屏，需要在应用里开硬件渲染；
#   FluxDown 是 GPUI + wgpu 原生渲染，NixOS 的 mesa / vulkan 驱动正常
#   就能出画面，不需要任何环境变量开关。
#
# 版本与 src 由 flake input 提供（flake.nix 的 fluxdown URL input，
# flake = false）。version 钉为字面量；升级流程：
#   1. 跑 `./scripts/update-third-party.sh fluxdown`：脚本探测 GitHub
#      Releases latest tag、取 linux-x64 .deb 资产、生成新 URL、修改
#      flake.nix 的 url 字段、`nix flake lock --update-input fluxdown`；
#   2. 同步更新下方 version 字面量（脚本不会改 .nix 里的 pname/version）；
#   3. `nix flake check` 与 `nixos-rebuild switch` 验证。
#
# 为什么换掉 rayburst：
#   两者定位重叠（都是多协议下载管理器 + 浏览器扩展接管 magnet）。
#   FluxDown 换掉它的直接原因是体积与依赖栈：同样是 .deb 封装，
#   FluxDown 不需要把 webkitgtk_4_1 / libsoup_3 / aria2-next 拉进
#   FHS rootfs，closure 小一大截；且没有 rayburst 那个「应用自建
#   .desktop 遮蔽 Nix 那份」的坑。两者数据目录互不兼容
#   （rayburst 在 ~/.local/share/dev.aninsomniacy.rayburst/），旧配置
#   需要手工迁或直接弃用，不自动迁移。
{
  pkgs,
  flake,
}:

let
  pname = "fluxdown";
  version = "0.5.5";

  # x86_64 的 src 来自 flake input；aarch64 上游目前没发 Linux 资产
  # （发布页只有 x64 的 .deb / .AppImage / .tar.gz），aarch64 需要自行
  # 构建，所以这里直接抛错而不是给个跑不通的路径。
  srcBySystem = {
    x86_64-linux = flake.inputs.fluxdown;
  };

  src =
    srcBySystem.${pkgs.stdenvNoCC.hostPlatform.system}
      or (throw "fluxdown: 不支持的系统 ${pkgs.stdenvNoCC.hostPlatform.system}（上游只发 x86_64 Linux 资产）");
in
# 走 flake.lib 而非相对路径 import ../lib/：这样本包被别的 flake 消费
# （作为 overlay 或 packages 引用）时仍能解析，见 lib/default.nix 顶部说明。
(flake.lib.build-deb-fhs pkgs) {
  inherit
    pname
    version
    src
    ;

  # 主二进制在 /opt/fluxdown/ 下，与 agent / daemon 同目录（见顶部说明）。
  binaryPath = "opt/fluxdown/fluxdown-desktop";

  # wrapper 就叫 fluxdown-desktop：上游 .desktop 的 Exec 写的是裸命令名
  # `Exec=fluxdown-desktop %U`，同名暴露后 Exec 天然走 FHS 沙箱，
  # 不需要改写。
  executableName = "fluxdown-desktop";

  desktopFile = "com.fluxdown.app.desktop";

  # execFrom / execTo 同名，substituteInPlace 幂等——显式写出是为了跟
  # orca 那种「deb 内绝对路径 → wrapper 名」的改写区分开，避免以后误以为
  # 漏配。MimeType 里的 magnet / ed2k / fluxdown / x-bittorrent 由桌面
  # 环境读原文件，不需要在这里改写。
  execFrom = "fluxdown-desktop";
  execTo = "fluxdown-desktop";

  # 上游 .desktop 的 Categories=Network;FileTransfer; 是合法值，**不要**
  # 传 desktopCategories：那个开关会整行覆盖 Categories，只在上游漏写
  # 或写错时才需要（rayburst 那种空值才是）。同理 desktopFileName 也不
  # 用改，沿用上游 ID（原因见顶部注释）。

  extraTargetPkgs = [
    pkgs.gcc.cc.lib # libgcc_s.so.1 —— 四个二进制全都要，shared 列表里没有
    pkgs.vulkan-loader # libvulkan.so.1 —— wgpu Vulkan 后端运行期 dlopen
  ];

  meta = {
    description = "Open-source multi-protocol download manager (HTTP/FTP/BitTorrent/eD2K/HLS/DASH) with browser extension and MCP server";
    homepage = "https://github.com/zerx-lab/FluxDown";
    license = pkgs.lib.licenses.agpl3;
    platforms = [
      "x86_64-linux"
    ];
  };
}
