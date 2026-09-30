# hop.nvim：buffer 内快速跳转（按 hint 字符直达目标）。
{ ... }:

{
  programs.nixvim = {
    plugins.hop = {
      enable = true;
      settings = {
        keys = "asdghklqwertyuiopzxcvbnm";
        term_seq_esc = "jj";
        highlight_hl = {
          fg = "String";
        };
        highlight_current_hl = {
          fg = "IncSearch";
        };
      };
    };
  };
}
