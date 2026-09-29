# flake input 跟踪的第三方预编译包。
#
# 版本 / hash 收在 flake.lock（与 nixpkgs 等其它 input 共用一份 lock）；
# 各 input 的 url 字段（含版本号字面量）写在 flake.nix 顶部。
# 各自的打包细节在对应 packages/*.nix 文件头部；包由 blueprint 暴露为
# perSystem.self.<name>（packages/ 下的包自己从 flake.inputs.<name> 取 src）。
#
# 升级跑 ./scripts/update-third-party.sh：脚本探测上游、改 flake.nix 的 url、
# 重锁，最后 `nixos-rebuild switch`。
{ pkgs, perSystem, ... }:

{
  home.packages = [
    perSystem.self.kelivo # Flutter LLM 客户端（GitHub release 预编译 .tar.gz）
    perSystem.self.wechat # 微信（unfree，官方 AppImage，版本从官方下载页抓取）
    perSystem.self.zedg # Zed 汉化版（FHS 封装便于直接安装扩展）
    perSystem.self.genoffice # GenOffice：开源 AI Office 套件（官方 AppImage）
    perSystem.self.goquark # GoQuark：夸克网盘 CLI / TUI / MCP（单文件 Go 静态二进制）
    perSystem.self.baidunetdisk # 百度网盘 Linux 客户端（unfree，官方 .deb，FHS 封装）
  ]
  # Zed 配套 LSP：集中在 lib/zed-lsp.nix，避免散落到别处后被遗忘。
  ++ (pkgs.callPackage ../../../../lib/zed-lsp.nix { });
}
