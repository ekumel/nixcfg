# nvfetcher 跟踪的第三方预编译包。
#
# 版本 / hash 见 fetch/_sources/generated.nix，上游清单见 fetch/nvfetcher.toml，
# 各自的打包细节在对应 packages/*.nix 文件头部；包由 blueprint 暴露为
# perSystem.self.<name>（packages/ 下的包自己从 flake.lib.sources 取源）。
{ pkgs, perSystem, ... }:

{
  home.packages = [
    perSystem.self.kelivo # Flutter LLM 客户端（GitHub release 预编译 .tar.gz）
    perSystem.self.wechat # 微信（unfree，官方 AppImage，版本从官方下载页抓取）
    perSystem.self.zedg # Zed 汉化版（FHS 封装便于直接安装扩展）
    perSystem.self.genoffice # GenOffice：开源 AI Office 套件（官方 AppImage）
  ]
  # Zed 配套 LSP：集中在 lib/zed-lsp.nix，避免散落到别处后被遗忘。
  ++ (pkgs.callPackage ../../../../lib/zed-lsp.nix { });
}
