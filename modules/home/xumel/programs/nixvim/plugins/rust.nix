# Rust 开发环境：rust-analyzer (LSP) + rustaceanvim。
#
# 工具链来源：rustc / cargo / rustfmt / rust-analyzer 通过
# modules/home/xumel/packages/cli.nix 提供（不走 mason / rustup）。
#
# 行为：
#   - rust-analyzer 自动作为 LSP 启动；
#   - 保存时跑 clippy（`check.command = "clippy"`），开启 inlay hints / 闭包捕获；
#   - rustaceanvim 提供 :RustLsp / cargo run / cargo test 等；
#   - <leader>r{rc,rr,rb,rt,rD} 走 rustaceanvim.run_split 触发 cargo 任务
#     （键位在 ../keymaps.nix 里）。
{ ... }:

{
  programs.nixvim = {
    lsp.servers.rust-analyzer = {
      enable = true;
      config = {
        cargo = { allFeatures = true; };
        # 保存时跑 clippy（默认是 check）；走 LSP 提供的 folding 替换 treesitter
        check = {
          command = "clippy";
          allTargets = true;
          extraArgs = [ "--all-features" ];
        };
        # Inlay hints
        inlayHints = {
          enable = true;
          parameterHints = true;
          typeHints = true;
          chainingHints = true;
        };
        # 闭包自动捕获（限制数量避免刷屏）
        closureCapture = {
          enable = true;
          limits.maxCaptureCount = 3;
        };
      };
    };

    # rustaceanvim：cargo 任务 + RA 启动包装
    plugins.rustaceanvim = {
      enable = true;
      settings = {
        # 工具链路径默认走 $PATH（cli.nix 已提供 rust-analyzer）
        default_timeout = 3000;
        flags.enable_clippy = true;
      };
    };
  };
}