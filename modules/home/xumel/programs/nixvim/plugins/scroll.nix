# 平滑滚动 + scrollbar 标记。
{ ... }:

{
  programs.nixvim = {
    # neoscroll：接管 <C-u>/<C-d>/<C-b>/<C-f>/<C-y>/<C-e>/zz/zb/zt/G/gg 的滚动动画
    plugins.neoscroll = {
      enable = true;
      settings = {
        mappings = [ "<C-u>" "<C-d>" "<C-b>" "<C-f>" "<C-y>" "<C-e>" "zt" "zz" "zb" "G" "gg" ];
        hide_cursor = true;
        stop_eof = true;
        respect_scrolloff = false;
        cursor_scrolls_alone = true;
        duration_multiplier = 1.0;
        easing = "quadratic";
        performance_mode = false;
      };
    };

    # scrollview：右侧 scrollbar 标记（避开 neo-tree / dashboard 等）
    plugins.scrollview = {
      enable = true;
      settings = {
        excluded_filetypes = [
          "neo-tree"
          "dashboard"
          "prompt"
          "noice"
          "toggleterm"
          "NvimTree"
        ];
      };
    };
  };
}