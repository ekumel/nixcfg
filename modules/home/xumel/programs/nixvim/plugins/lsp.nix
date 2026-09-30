# LSP 集成（新版 vim.lsp API）。
# 全局 LSP 键位（gd/gr/K/...）在 ../keymaps.nix 里。
# 具体服务器（lua_ls / rust-analyzer / pyright）配置在 ./lsp-servers.nix 和 ./rust.nix。
#
# 客户端能力由 nixvim 自动注册到 LSP server；nvim-cmp 的 capability 见 completion.nix。
{ lib, ... }:

{
  programs.nixvim = {
    # 关掉 nixvim 自带的旧版 plugins.lsp 客户端（避免与新 vim.lsp API 冲突）
    plugins.lsp.enable = lib.mkForce false;

    # LSP 通用外观 / 行为
    lsp = {
      # 让 LSP 处理 semantic tokens（颜色 / 语义高亮）
      semanticTokens.enable = true;
      inlayHints.enable = true;
    };
  };
}
