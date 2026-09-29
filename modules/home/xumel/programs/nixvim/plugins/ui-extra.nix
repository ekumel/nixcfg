# UI 扩展：dashboard / noice / toggleterm / nvim-ufo / colorizer。
# 这里放的 UI 插件通常需要 VimEnter / VeryLazy 等延迟事件触发，所以放在 ui.nix 之后单独管理。
{ lib, ... }:

{
  programs.nixvim = {
    # 启动页（`nvim <dir>` 时自动显示，配合 autocmds.nix）
    plugins.dashboard = {
      enable = true;
      settings = {
        header = [
          ""
          "  ██╗  ██╗   NVIM  ◊  DMS"
          "  ██║  ██║   Lua  +  Rust"
          "  ╚██████╔╝   base46 engine"
          "   ╚═════╝"
          ""
        ];
        center = [
          { desc = "Find files";   action = "Telescope find_files"; key = "f"; }
          { desc = "Recent files"; action = "Telescope oldfiles";   key = "r"; }
          { desc = "Live grep";    action = "Telescope live_grep";  key = "g"; }
          { desc = "Toggle file tree"; action = "Neotree toggle";  key = "e"; }
        ];
        footer = [
          ""
          "powered by AvengeMedia/base46 (dms)"
          ""
        ];
      };
    };

    # nvim-notify：noice 的 `view = "notify"` 需要它作为后端
    plugins.notify.enable = true;

    # noice.nvim（接管 messages / cmdline / notify）
    plugins.noice = {
      enable = true;
      settings = {
        lsp = {
          progress.enabled = true;
          hover.enabled = true;
          signature.enabled = true;
          override = {
            "vim.lsp.util.convert_input_to_markdown_lines" = true;
            "vim.lsp.util.stylize_markdown" = true;
            # 让 nvim-cmp 的文档窗口也走 noice（否则 health 会报未接管）
            "cmp.entry.get_documentation" = true;
          };
        };
        presets = {
          command_palette = true;
          long_message_to_split = true;
          lsp_doc_border = true;
        };
        messages.enabled = true;
        messages.view = "notify";
        notify.enabled = true;
        notify.view = "notify";
        cmdline.enabled = true;
        cmdline.view = "cmdline_popup";
        popupmenu.enabled = true;
        # 过滤掉烦人的 "written" / "yanked" / "recorded" 提示
        routes = [
          { filter = { event = "msg_show"; kind = ""; find = "written"; }; opts.skip = true; }
          { filter = { event = "msg_show"; kind = ""; find = "yanked";  }; opts.skip = true; }
          { filter = { event = "msg_show"; kind = ""; find = "recorded"; }; opts.skip = true; }
        ];
      };
    };

    # 浮动终端（toggleterm）
    plugins.toggleterm = {
      enable = true;
      settings = {
        size = 12;
        direction = "horizontal";
        shell.__raw = "fish";
        shade_terminals = true;
        float_opts.border = "curved";
      };
    };

    # 折叠（nvim-ufo：treesitter 优先 + indent 兜底）
    plugins.nvim-ufo = {
      enable = true;
      settings.provider_selector.__raw = ''function() return { "treesitter", "indent" } end'';
    };

    # hex 颜色高亮
    plugins.colorizer.enable = true;
  };

  # nvim-ufo 还需要一些额外的 opt 设置
  programs.nixvim.extraConfigLua = ''
    vim.opt.foldcolumn = "1"
    vim.opt.foldlevel = 99
    vim.opt.fillchars = vim.opt.fillchars or {}
    vim.opt.fillchars.eob = " "
  '';
}