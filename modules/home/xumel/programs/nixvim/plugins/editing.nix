# 编辑增强：nvim-autopairs / nvim-surround / native comment / blink.indent。
# 键位统一在 ../keymaps.nix 里。
#
# 全部使用 nixvim 自带模块（不再放 extraPlugins，避免版本 pin 不一致）。
{ ... }:

{
  programs.nixvim = {
    plugins = {
      # 自动补全括号 / 引号（nvim-cmp 联动在 completion.nix 里）
      nvim-autopairs = {
        enable = true;
        settings = {
          check_ts = true;
          ts_config = {
            lua = [ "string" "source" ];
            rust = [ "string" "source" ];
            python = [ "string" ];
          };
          disable_filetype = [ "TelescopePrompt" "vim" ];
        };
      };

      # kylechui/nvim-surround（v4 自动注册键位；与 tpope 的 vim-surround 无关）
      nvim-surround.enable = true;

      # 注释：Neovim 0.10+ 原生 treesitter-aware（gcc / gc{motion} / visual gc / gcap / gcgc）
      comment.enable = true;

      # indent guide（替代 indent-blankline，绑定 <leader>ig 切换）
      blink-indent = {
        enable = true;
        settings = {
          static = {
            char = "|";
            highlights = [ "BlinkIndent" ];
          };
          scope = {
            enabled = true;
            indent_at_cursor = false;
          };
        };
      };
    };
  };
}