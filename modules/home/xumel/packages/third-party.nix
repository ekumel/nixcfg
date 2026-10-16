# flake input 跟踪的第三方预编译包。
#
# 版本 / hash 收在 flake.lock（与 nixpkgs 等其它 input 共用一份 lock）；
# 各 input 的 url 字段（含版本号字面量）写在 flake.nix 顶部。
# 各自的打包细节在对应 packages/*.nix 文件头部；包由 blueprint 暴露为
# perSystem.self.<name>（packages/ 下的包自己从 flake.inputs.<name> 取 src）。
#
# 升级跑 ./scripts/update-third-party.sh：脚本探测上游、改 flake.nix 的 url、
# 重锁，最后 `nixos-rebuild switch`。
{
  pkgs,
  perSystem,
  flake,
  inputs,
  ...
}:

{
  home.packages = [
    perSystem.self.kelivo # Flutter LLM 客户端（GitHub release 预编译 .tar.gz）
    perSystem.self.wechat # 微信（unfree，官方 AppImage，版本从官方下载页抓取）
    perSystem.self.zedg # Zed 汉化版（FHS 封装便于直接安装扩展）
    perSystem.self.genoffice # GenOffice：开源 AI Office 套件（官方 AppImage）
    perSystem.self.goquark # GoQuark：夸克网盘 CLI / TUI / MCP（单文件 Go 静态二进制）
    perSystem.self.baidunetdisk # 百度网盘 Linux 客户端（unfree，官方 .deb，FHS 封装）
    perSystem.self.orca # Orca：AI 编排器（Electron，GitHub release .deb，FHS 封装）
    perSystem.self.voicefox # voicefox：Rust + ratatui + libmpv 终端音乐播放器（预编译 zip + patchelf 补 libmpv）
    perSystem.self.fluxdown # FluxDown：开源多协议下载器（Rust + GPUI，接管 magnet / BT / ED2K，带 MCP）
    perSystem.self.any-listen # Any Listen：私有音乐播放服务桌面端（Electron，接替 splayer-next）

    # llm-agents.nix 上游打包的 agent 集合：每日自动重锁，本机只引用
    # 不再维护 npmDepsHash。原本自维护的 mcode（@minimax-ai/code）与
    # pi-agent（@earendil-works/pi-coding-agent）均已下线。
    inputs.llm-agents.packages.${pkgs.system}.opencode2-desktop # OpenCode 2 桌面客户端（numtide/llm-agents.nix）
  ]
  # Zed 配套 LSP：集中在 lib/zed-lsp.nix，避免散落后被遗忘。
  ++ flake.lib.zed-lsp pkgs;
}
