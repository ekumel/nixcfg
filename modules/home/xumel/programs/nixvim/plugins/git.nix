# Git：gitsigns（行尾 blame / hunk 标记）+ diffview（并排 diff）+ neogit（magit 风格 UI）。
# 键位统一在 ../keymaps.nix 里。
{ ... }:

{
  programs.nixvim = {
    plugins = {
      # gitsigns：实时显示 add/change/delete，行尾 blame
      gitsigns = {
        enable = true;
        settings = {
          signs = {
            add = { text = "▎"; };
            change = { text = "▎"; };
            delete = { text = " "; };
            topdelete = { text = " "; };
            changedelete = { text = "▎"; };
          };
          current_line_blame = true;
          current_line_blame_opts = {
            virt_text = true;
            virt_text_pos = "eol";
            delay = 500;
            ignore_whitespace = false;
          };
        };
      };

      # diffview：并排 / 上下 diff 视图
      diffview = {
        enable = true;
        settings.view.default.layout = "diff2_horizontal";
      };

      # neogit：magit 风格 git UI（在 diffview 之上）
      neogit = {
        enable = true;
        settings = {
          disable_commit_confirmation = false;
          integrations.diffview = true;
        };
      };
    };
  };
}