# orca：stablyai/orca — "面向 100x 构建者的 AI 编排器"，
# 并行 worktree 里跑多个 coding agent（Claude Code / Codex /
# OpenCode / Pi / OpenClaude / GitHub Copilot / oh-my-pi 等）。
# 带 mobile companion app、design mode、review 流程。
#
# 上游不发源码，发 GitHub Release 三平台包：macOS .dmg / Windows .exe /
# Linux .AppImage + .deb + .rpm + Arch AUR。Linux 选 .deb：180 MB，
# 比 AppImage（216 MB）小、closure 干净；nixpkgs 不收录。
#
# 打包策略：与 baidunetdisk.nix 同款——.deb 解包 + buildFHSEnv 封装。
# 解包与 FHS 封装的完整流程（ar 解包 → buildFHSEnv → 搬 .desktop 与图标
# → 改写 Exec= → bind /etc/nixos）见 lib/build-deb-fhs.nix，本文件只留
# 本包特有的元数据与路径。
#   - electron 主二进制 /opt/Orca/orca-ide（224 MB）带内置 libffmpeg /
#     libEGL / libvulkan / chrome-sandbox，运行时需要 GTK / GL / NSS /
#     dbus / drm / systemd / cups 等「通用图形栈」+ Electron 专属
#     libcups（已在 lib/fhs-shared-pkgs.nix 列出）。
#   - chrome-sandbox 是 SUID-root 二进制，NixOS 不支持任意 SUID；
#     Electron 的 SUID-less fallback 仍能在普通用户 namespace 下起
#     sandbox（Linux user_namespaces + seccomp），不需要 --no-sandbox。
#     注意 orca-ide 是 Electron 主进程，自己处理 args，传 --no-sandbox
#     反而会被当成未知 arg 拒绝（"bad option: --no-sandbox"）。
#
# .deb 内部结构（Electron 标准 layout）：
#   /opt/Orca/orca-ide              主二进制（224 MB，动态链接 GTK 等）
#   /opt/Orca/chrome-sandbox        SUID-root 二进制（Electron 沙箱）
#   /opt/Orca/{chrome_100_percent.pak, chrome_200_percent.pak, icudtl.dat,
#                libEGL.so, libffmpeg.so, libGLESv2.so, libvk_swiftshader.so,
#                libvulkan.so.1, locales/, resources/, ...}
#   /usr/share/applications/orca-ide.desktop
#   /usr/share/icons/hicolor/{16,24,32,48,128,256,512}x{...}/apps/orca-ide.png
#
# 版本与 src 由 flake input 提供（flake.nix 的 orca URL input，
# flake = false）。version 钉为字面量；升级流程：
#   1. 跑 `./scripts/update-third-party.sh orca`：脚本从 latest-linux.yml
#      拿最新 version + .deb URL + sha512，生成新 URL、修改
#      flake.nix 的 url 字段、`nix flake lock --update-input orca`；
#   2. 同步更新下方 version 字面量；
#   3. `nix flake check` 与 `nixos-rebuild switch` 验证。
{
  pkgs,
  flake,
}:

let
  pname = "orca";
  version = "1.4.217";

  # x86_64 的 src 来自 flake input；aarch64 在这里手算（每个 url input
  # 只能配一个 url）。
  srcBySystem = {
    x86_64-linux = flake.inputs.orca;
  };

  src =
    srcBySystem.${pkgs.stdenvNoCC.hostPlatform.system}
      or (throw "orca: 不支持的系统 ${pkgs.stdenvNoCC.hostPlatform.system}");
in
# 走 flake.lib 而非相对路径 import ../lib/：这样本包被别的 flake 消费
# （作为 overlay 或 packages 引用）时仍能解析，见 lib/default.nix 顶部说明。
(flake.lib.build-deb-fhs pkgs) {
  inherit
    pname
    version
    src
    ;

  binaryPath = "opt/Orca/orca-ide";
  desktopFile = "orca-ide.desktop";

  # .desktop 的 Exec 是 `/opt/Orca/orca-ide %U` → 换成 wrapper 暴露的
  # `orca`（pname 同名）。deb 给了 7 档 hicolor 图标，由公共流程搬运。
  execFrom = "/opt/Orca/orca-ide";

  meta = {
    description = "AI orchestrator running Claude Code / Codex / OpenCode / Pi in parallel worktrees";
    homepage = "https://github.com/stablyai/orca";
    # 上游 LICENSE 写 MIT（README 末尾 + LICENSE 文件），
    # 但 code 内容引用大量第三方（Electron / Chromium / 各 agent
    # 的 source），所以这里标 mit 但 meta 加上 platform 限定。
    license = pkgs.lib.licenses.mit;
    platforms = [
      "x86_64-linux"
    ];
  };
}
