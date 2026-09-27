# Treesitter：语法高亮 + 缩进。
#
# nixvim 自带 `plugins.treesitter`（推荐），这里走 nixvim 的封装。
# extraPlugins 里的 nvim-treesitter 是为了确保 parser binary 装好；正常用 nixvim
# 的 ensure_installed 会更省心。
{ ... }:

{
  programs.nixvim = {
    plugins.treesitter = {
      enable = true;
      settings = {
        ensure_installed = [
          "nix"
          "lua"
          "vim"
          "vimdoc"
          "bash"
          "fish"
          "python"
          "javascript"
          "typescript"
          "tsx"
          "json"
          "jsonc"
          "toml"
          "yaml"
          "html"
          "css"
          "rust"
          "c"
          "cpp"
          "markdown"
          "markdown_inline"
          "diff"
          "regex"
          "gitcommit"
          "gitignore"
          "git_rebase"
          "query"
        ];

        # 高亮 + 缩进交给 TS；折叠交给 LSP（FoldingProvider）
        indent.enable = true;
        highlight.enable = true;
        folds.enable = false;
      };
    };
  };
}