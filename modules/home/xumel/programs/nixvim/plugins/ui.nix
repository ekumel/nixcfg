# 主 UI 类插件：which-key / lualine / bufferline / neo-tree / web-devicons。
# 键位统一在 ../keymaps.nix 里维护。
{ lib, ... }:

{
  programs.nixvim = {
    plugins = {
      # which-key：键位提示面板（groups 给每个 <leader>xx 前缀一个分类）
      which-key = {
        enable = true;
        settings = {
          win = {
            border = "rounded";
            padding = [ 1 2 ];
            wo.winblend = 10;
          };
          layout = {
            width.min = 20;
            width.max = 40;
            spacing = 2;
          };
          # 避免与 neoscroll 冲突：滚动键用 <C-n>/<C-p>
          keys.scroll_down = "<C-n>";
          keys.scroll_up = "<C-p>";
          # which-key 的 spec / triggers 里「按键」本身用 `__unkeyed-N`（数组位置），
          # 不能用 `key = ...`（which-key 会报 Invalid field `key`）。
          spec = [
            { __unkeyed-1 = "<leader>f"; group = "Find"; }
            { __unkeyed-1 = "<leader>g"; group = "Git"; }
            { __unkeyed-1 = "<leader>i"; group = "Indent"; }
            { __unkeyed-1 = "<leader>r"; group = "Refactor"; }
            { __unkeyed-1 = "<leader>s"; group = "LSP/Search"; }
            { __unkeyed-1 = "<leader>t"; group = "Terminal"; }
            { __unkeyed-1 = "<leader>m"; group = "Markdown"; }
            { __unkeyed-1 = "<leader>b"; group = "Buffer"; }
            { __unkeyed-1 = "<leader>c"; group = "Code"; }
            { __unkeyed-1 = "<leader>d"; group = "Diagnostics"; }
            { __unkeyed-1 = "<leader>j"; group = "Jump (hop)"; }
            { __unkeyed-1 = "<leader>l"; group = "LSP"; }
            { __unkeyed-1 = "<leader>x"; group = "Close buffer"; }
            { __unkeyed-1 = "<leader>z"; group = "Scroll/Cursor"; }
            # Neovim 0.10+ 原生注释：gcc / gc{motion} / gcap / gcgc
            { __unkeyed-1 = "gc"; group = "Comment"; mode = [ "n" "x" ]; }
          ];
          # 单独的 d / y 触发 which-key 弹出 operator / motion help
          triggers = [
            "<auto>"
            { __unkeyed-1 = "d"; mode = "n"; }
            { __unkeyed-1 = "y"; mode = "n"; }
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
            follow_current_file = { enabled = true; };
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
              { name = "filename"; path = 1; }
              {
                name = "diagnostics";
                sections = [ "error" "warn" ];
                symbols = { error = "E:"; warn = "W:"; };
                diagnostics_color = {
                  error = { fg = "#ef6f83"; };
                  warn = { fg = "#d9a95e"; };
                };
                always_visible = true;
                update_in_insert = true;
              }
            ];
            lualine_x = [ "encoding" "filetype" ];
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
            offsets = [
              {
                filetype = "neo-tree";
                text = "File Explorer";
                highlight = "Directory";
                separator = true;
                position = "right";
              }
              {
                filetype = "AgenticChat";
                text = "Agentic";
                highlight = "Directory";
                separator = true;
                position = "left";
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