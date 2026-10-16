# 主 UI 类插件：which-key / lualine / bufferline / neo-tree / web-devicons。
# 键位统一在 ../keymaps.nix 里维护。
{ lib, ... }:

let
  # which-key 弹窗的列宽。win.width 与 layout.width.min/max 必须同值，
  # 否则 box_count 会跳回多列 —— 推导见下面 layout.width 的注释。
  # 40 装得下本仓库最长的说明（"Avante: toggle selection mode" 一类），
  # 又不至于像默认那样横着铺满半个屏幕。
  whichKeyWidth = 40;
in

{
  programs.nixvim = {
    plugins = {
      # which-key：键位提示面板（groups 给每个 <leader>xx 前缀一个分类）
      which-key = {
        enable = true;
        settings = {
          win = {
            border = "rounded";
            padding = [
              1
              2
            ];
            wo.winblend = 10;
            # 右下角。
            #
            # which-key v3 用的是 nvim_open_win 浮窗，默认落在**左下角**
            # （上游 lua/which-key/win.lua:33 的 defaults = { col = 0, row = math.huge }，
            #  view.lua:416-417 的注释也写着 "top-left"）。
            # row 保持 math.huge 就是贴底，col 改成一个大数就贴右。
            #
            # 为什么不直接写 math.huge：col/row 最终会被
            # lua/which-key/layout.lua 的 Layout.dim() 夹到屏幕内
            # （view.lua 里 opts.col = Layout.dim(opts.col, vim.o.columns - opts.width)），
            # 所以给一个大数与 math.huge 的结果完全一致，却不用担心 Nix 侧
            # 浮点溢出被 toLuaObject 渲染成 Lua 的 inf 标识符（那会变成 nil）。
            col = 1000000;
            row = 1000000;
            # 浮窗最大宽度（列宽），见下面 layout.width 的说明。
            width = whichKeyWidth;
          };
          layout = {
            # 强制**单列**（每个按键说明占一行）+ 不太宽。
            #
            # which-key v3 的列数算法（上游 lua/which-key/view.lua:336-344）：
            #   container.width = Layout.dim(vim.o.columns, vim.o.columns, Config.win.width)
            #   box_width       = Layout.dim(max_row_width, container.width, Config.layout.width)
            #   box_count       = max(floor(container.width / (box_width + spacing)), 1)
            # 不设 win.width 时 container.width 就是 vim.o.columns，于是 120 列的终端
            # 配 box_width=40 会算出 box_count = floor(120/42) = 2 —— 弹窗横着排两列，
            # 看起来就是"占满宽度"。
            #
            # 这里把 layout.width 的 min/max 都钉成 whichKeyWidth，同时把
            # win.width 也设成同一个值，于是
            #   box_width   = 40（被 min=max 夹死，不再随内容变化）
            #   box_count   = max(floor(40 / (40 + spacing)), 1) = 1   ← 恒为单列
            # 弹窗最终宽度 = min(实际文字宽度 + 边框, win.width)，内容短时会自动收窄。
            #
            # 注意必须让 win.width 和 layout.width 同值：只把 layout.width 设小的话，
            # box_width 会跟着内容变短，box_count 又会跳回 2。
            width.min = whichKeyWidth;
            width.max = whichKeyWidth;
            spacing = 2;
          };
          # 避免与 neoscroll 冲突：滚动键用 <C-n>/<C-p>
          keys.scroll_down = "<C-n>";
          keys.scroll_up = "<C-p>";
          # which-key 的 spec / triggers 里「按键」本身用 `__unkeyed-N`（数组位置），
          # 不能用 `key = ...`（which-key 会报 Invalid field `key`）。
          spec = [
            {
              __unkeyed-1 = "<leader>f";
              group = "Find";
            }
            {
              __unkeyed-1 = "<leader>g";
              group = "Git";
            }
            {
              __unkeyed-1 = "<leader>i";
              group = "Indent";
            }
            {
              __unkeyed-1 = "<leader>r";
              group = "Refactor";
            }
            {
              __unkeyed-1 = "<leader>s";
              group = "LSP/Search";
            }
            {
              __unkeyed-1 = "<leader>t";
              group = "Terminal";
            }
            {
              __unkeyed-1 = "<leader>m";
              group = "Markdown";
            }
            {
              __unkeyed-1 = "<leader>b";
              group = "Buffer";
            }
            {
              __unkeyed-1 = "<leader>c";
              group = "Code";
            }
            {
              # avante（AI 编程助手）——键位在 ../keymaps.nix
              __unkeyed-1 = "<leader>a";
              group = "Avante (AI)";
            }
            {
              __unkeyed-1 = "<leader>d";
              group = "Diagnostics";
            }
            {
              __unkeyed-1 = "<leader>j";
              group = "Jump (hop)";
            }
            {
              __unkeyed-1 = "<leader>l";
              group = "LSP";
            }
            {
              __unkeyed-1 = "<leader>x";
              group = "Close buffer";
            }
            {
              __unkeyed-1 = "<leader>z";
              group = "Scroll/Cursor";
            }
            # Neovim 0.10+ 原生注释：gcc / gc{motion} / gcap / gcgc
            {
              __unkeyed-1 = "gc";
              group = "Comment";
              mode = [
                "n"
                "x"
              ];
            }
          ];
          # 单独的 d / y 触发 which-key 弹出 operator / motion help
          triggers = [
            "<auto>"
            {
              __unkeyed-1 = "d";
              mode = "n";
            }
            {
              __unkeyed-1 = "y";
              mode = "n";
            }
          ];
        };
      };

      # neo-tree：右侧文件树，<leader>e 切换
      neo-tree = {
        enable = true;
        settings = {
          close_if_last_window = false;
          popup_border_style = "rounded";
          filesystem = {
            follow_current_file = {
              enabled = true;
            };
            hijack_netrw_behavior = "disabled";
            use_libuv_file_watcher = true;
            filtered_items = {
              visible = false;
              hide_dotfiles = true;
              hide_gitignored = false;
              always_show = [ ".git" ];
            };
          };
          default_component_configs.indent.with_markers = true;
          window.position = "right";
          window.width = 30;
        };
      };

      # lualine：状态栏（全局一行，避开 stack panel 的伪状态栏）
      # theme = "dms"：配色由 lua/lualine/themes/dms.lua 运行时读取 DMS（matugen）
      # 调色板生成（见 ../theme.nix）；DMS 未生成时该主题模块自行回退 tokyonight。
      lualine = {
        enable = true;
        settings = {
          options = {
            theme = "dms";
            globalstatus = true;
            # agentic / dashboard 等特殊 ft 不渲染 lualine
            disabled_filetypes.statusline = [
              "AgenticChat"
              "AgenticInput"
              "AgenticCode"
              "AgenticFiles"
              "AgenticDiagnostics"
              "AgenticTodos"
            ];
            disabled_filetypes.winbar = [
              "AgenticChat"
              "AgenticInput"
              "AgenticCode"
              "AgenticFiles"
              "AgenticDiagnostics"
              "AgenticTodos"
            ];
          };
          sections = {
            lualine_a = [ "mode" ];
            lualine_b = [ "branch" ];
            lualine_c = [
              {
                name = "filename";
                path = 1;
              }
              {
                name = "diagnostics";
                sections = [
                  "error"
                  "warn"
                ];
                symbols = {
                  error = "E:";
                  warn = "W:";
                };
                diagnostics_color = {
                  error = {
                    fg = "#ef6f83";
                  };
                  warn = {
                    fg = "#d9a95e";
                  };
                };
                always_visible = true;
                update_in_insert = true;
              }
            ];
            lualine_x = [
              "encoding"
              "filetype"
            ];
            lualine_y = [ "progress" ];
            lualine_z = [ "location" ];
          };
        };
      };

      # bufferline：顶部 tab
      bufferline = {
        enable = true;
        settings = {
          options = {
            mode = "buffers";
            diagnostics = "nvim_lsp";
            always_show_bufferline = true;
            # offsets：让 bufferline 给左右两侧的侧边栏各留出等宽的占位，
            # 这样 bufferline 只盖住中间的编辑区。
            #
            # bufferline 4.9.1 的两条硬性限制（上游 lua/bufferline/offset.lua）：
            #   1. filetype 是**精确字符串比较**（offset.lua:115），不认函数，
            #      所以每个侧边栏要各写一条；
            #   2. 只检查顶层 ROW 的**最左 / 最右**两列，且每列取
            #      `win_id[1][2]`——也就是那列里最上面的那个窗口。
            #
            # 顺带说明：offsets 条目里并没有 `position` 字段，左右由
            # `is_left`（匹配到的窗口是不是最左）自动决定。所以下面不写 position。
            #
            # avante 侧边栏在左，实测布局是 col: [Avante, AvanteInput]，
            # 顶层取最上面那个 => filetype 必须是 "Avante"（不是 AvanteInput）。
            offsets = [
              {
                filetype = "Avante";
                text = "Avante";
                highlight = "Directory";
                separator = true;
              }
              {
                filetype = "neo-tree";
                text = "File Explorer";
                highlight = "Directory";
                separator = true;
              }
              {
                filetype = "AgenticChat";
                text = "Agentic";
                highlight = "Directory";
                separator = true;
              }
            ];
            show_buffer_close_icons = false;
            show_close_icon = false;
            separator_style = "padded_slope";
          };
        };
      };

      # 文件类型图标（lualine / neo-tree / bufferline 都会用）
      web-devicons.enable = true;

      # which-key 更偏好 mini.icons（health 检查里会提示未安装）
      mini-icons.enable = true;
    };
  };
}
