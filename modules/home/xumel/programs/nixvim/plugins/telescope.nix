# Telescope：模糊搜索文件 / 内容 / LSP 符号 / git 文件 / 帮助 / TODO / 寄存器。
# 键位统一在 ../keymaps.nix 里。
#
# fzf-native sorter 从 extraPlugins 拿（nixvim telescope 默认是 builtin sorter）。
{ ... }:

{
  programs.nixvim = {
    plugins.telescope = {
      enable = true;
      settings = {
        defaults = {
          prompt_prefix = " ";
          sorting_strategy = "ascending";
          layout_config.horizontal.prompt_position = "top";
          path_display = { shorten = true; };
          mappings.i = {
            "<C-j>" = "move_selection_next";
            "<C-k>" = "move_selection_previous";
            "<Esc>" = "close";
          };
        };
        pickers.find_files.hidden = true;
        pickers.live_grep.additional_args = [ "--hidden" ];
      };
    };
  };
}