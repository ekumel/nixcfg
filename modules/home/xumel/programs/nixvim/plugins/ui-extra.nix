# UI 扩展：dashboard / noice / toggleterm / nvim-ufo / colorizer。
# 这里放的 UI 插件通常需要 VimEnter / VeryLazy 等延迟事件触发，所以放在 ui.nix 之后单独管理。
{ lib, ... }:

{
  programs.nixvim = {
    # 启动页（`nvim <dir>` 时自动显示，配合 autocmds.nix；
    # 关掉最后一个 buffer 后由 ../lua/welcome.lua 重新拉起）
    #
    # ---- 为什么全在 settings.config 下面 ----
    # nixvim 把 `settings` 原样铺成 `require("dashboard").setup(<settings>)`，
    # 而 dashboard 自己是在 default_options() 的 `config` 子表里找这三项
    # （load_theme 读的是 opts.config.header，见 lua/dashboard/init.lua:196）。
    # 写在 settings 顶层的话，setup 照常执行、nixvim 的类型检查也不报错
    # （它同时接受自由属性），但插件根本读不到 —— 这三项之前就是这么白配的。
    # nixvim 自己的 dashboard 模块也是按 settings.config.* 声明选项的。
    #
    # ---- 为什么快捷键走 shortcut 而不是 center ----
    # `center` 是 **doom 主题专用**的选项（nixvim 选项说明里就标了
    # requiresTheme "doom"）：hyper 主题的 gen_center() 只把「最近项目」和
    # 「最近文件」拼进去，从头到尾没读过 config.center（theme/hyper.lua:351-359）。
    # hyper 里真正会渲染这些动作、并把 key 绑成 buffer-local 映射的是
    # gen_shortcut()（theme/hyper.lua:5-46）。所以原来那份「center」想表达的
    # 四个入口在这里落到 shortcut，键位与文案保持原样。
    plugins.dashboard = {
      enable = true;

      # 明确不让 dashboard 隐藏 bufferline 与 lualine。
      #
      # 这两个默认是 true，dashboard 显示时会 showtabline = 0 / laststatus = 0，
      # 离开时靠 restore_user_options 还原 —— 但那个还原机制在这台机器上
      # **一次都没生效过**，实测现象是「打开一次欢迎界面之后，bufferline 和
      # lualine 就此再也不出现」：
      #
      #   instance() → save_user_options() 先把当前值存进 ctx，再 set_ui_options()
      #   把 showtabline / laststatus 打成 0。而本机会在同一次启动里跑**两次**
      #   instance()：dashboard 自己的 UIEnter（无参数启动时）+ autocmds.nix 的
      #   VimEnter 里那句 `pcall(vim.cmd, "Dashboard")`。第二次进来时存下的
      #   「原值」已经是 0 了，于是 restore 忠实地把 0 写回去 —— 永久丢失。
      #
      # bufferline 配的是 always_show_bufferline = true，本来就是要一直显示的，
      # 所以直接让它别碰这两个选项，问题从根上不存在（也不必去修上游的
      # 两段式 save/restore）。
      settings.hide = {
        statusline = false;
        tabline = false;
      };

      settings.config = {
        # 每一行的显示宽度必须一致（这里都是 27 列）。
        #
        # dashboard 的 utils.center_align() 是**逐行独立**算左边距的
        # （utils.lua:54），所以只要各行宽度不等，左边距就不等，ASCII art
        # 会横向错开：原写法实测宽度是 25 / 25 / 27 / 10，于是第 3、4 行会比
        # 前两行往左偏一列。尾部补空格把四行拉齐，整块 art 就作为一个整体
        # 居中，不会散架。
        header = [
          ""
          "  ██╗  ██╗   NVIM  ◊  DMS  "
          "  ██║  ██║   Lua  +  Rust  "
          "  ╚██████╔╝   base46 engine"
          "   ╚═════╝                 "
          ""
        ];
        shortcut = [
          {
            desc = "Find files";
            action = "Telescope find_files";
            key = "f";
          }
          {
            desc = "Recent files";
            action = "Telescope oldfiles";
            key = "r";
          }
          {
            desc = "Live grep";
            action = "Telescope live_grep";
            key = "g";
          }
          {
            desc = "Toggle file tree";
            action = "Neotree toggle";
            key = "e";
          }
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
          {
            filter = {
              event = "msg_show";
              kind = "";
              find = "written";
            };
            opts.skip = true;
          }
          {
            filter = {
              event = "msg_show";
              kind = "";
              find = "yanked";
            };
            opts.skip = true;
          }
          {
            filter = {
              event = "msg_show";
              kind = "";
              find = "recorded";
            };
            opts.skip = true;
          }
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
