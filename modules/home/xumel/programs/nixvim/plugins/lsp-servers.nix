# LSP 服务器配置（新版 vim.lsp API）。
# 单独放一个文件，避免 lsp.nix 太长；具体服务器由这里启用。
#
# 工具链来源：
#   - lua_ls：nixpkgs `lua-language-server`
#   - rust-analyzer：cli.nix 提供（不走 mason）
#   - pyright：nixpkgs `pyright`
#
# rust 的 cargo / clippy / inlayHints 配置在 ./rust.nix 里。
{ pkgs, lib, ... }:

{
  programs.nixvim = {
    lsp = {
      # 让 on_attach 在每个 LSP client 启动时跑（在 lsp.nix 里定义）
      # 此处只声明 servers
      servers = {
        lua_ls = {
          enable = true;
          config = {
            Lua = {
              runtime = {
                version = "LuaJIT";
              };
              diagnostics = {
                globals = [ "vim" ];
              };
              workspace.checkThirdParty = false;
              telemetry.enable = false;
            };
          };
        };

        pyright = {
          enable = true;
          config = {
            pyright = {
              disableTaggedHints = true;
            };
            python = {
              analysis = {
                autoSearchPaths = true;
                useLibraryCodeForTypes = true;
                diagnosticMode = "openFilesOnly";
              };
            };
          };
        };
      };
    };
  };
}
