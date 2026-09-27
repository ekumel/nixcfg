# 自动命令（来自 backup nvim 的 lua/config/autocmds.lua）。
#
# 1. 保存前剥离行尾空白（markdown 例外，行尾两个空格是有意义的换行）
# 2. 窗口大小改变时等比缩放分屏
# 3. 打开 buffer 时回到上次光标位置
# 4. lua / rust 文件类型：4 空格缩进（与全局一致但显式覆盖以避免被 ftplugin 改写）
# 5. 启动时若是 `nvim <dir>`，显示 dashboard + neo-tree 右侧
#
# 注意：`callback` 在 nixvim 里是 `either str rawLua`，普通字符串会被当作
# vimscript 函数名（vim 会去 :call 一个名为 "function() ... end" 的函数），
# 所以 Lua 回调必须用 `callback = { __raw = "function() ... end"; };` 形式。
{ ... }:

{
  programs.nixvim = {
    # 全部 autocmd 都放进 "NvimConfig" augroup，互相覆盖前先 clear
    autoGroups.NvimConfig.clear = true;

    autoCmd = [
      # ---- 1. 保存前去掉行尾空白（markdown 例外）----
      {
        event = "BufWritePre";
        pattern = "*";
        group = "NvimConfig";
        callback = {
          __raw = ''
            function()
              -- 跳过只读 / 非普通 buffer（help、checkhealth、terminal、prompt…），
              -- 否则 `%s` 会因 'modifiable' 关闭而报 E21。
              if not vim.bo.modifiable or vim.bo.buftype ~= "" then return end
              -- markdown 行尾两个空格是有意义的换行，不处理
              if vim.bo.filetype == "markdown" then return end

              local save = vim.fn.winsaveview()
              vim.cmd([[%s/\s\+$//e]])
              vim.fn.winrestview(save)
            end
          '';
        };
      }

      # ---- 2. 窗口大小变化时等比缩放分屏 ----
      {
        event = [ "VimResized" ];
        group = "NvimConfig";
        command = "tabdo wincmd =";
      }

      # ---- 3. 回到上次编辑位置（仅当 mark 在 buffer 范围内）----
      {
        event = "BufReadPost";
        group = "NvimConfig";
        callback = {
          __raw = ''
            function()
              local mark = vim.api.nvim_buf_get_mark(0, '"')
              local lcount = vim.api.nvim_buf_line_count(0)
              if mark[1] > 0 and mark[1] <= lcount then
                pcall(vim.api.nvim_win_set_cursor, 0, mark)
              end
            end
          '';
        };
      }

      # ---- 4. lua / rust 的本地缩进设置 ----
      {
        event = "FileType";
        group = "NvimConfig";
        pattern = [ "lua" "rust" ];
        callback = {
          __raw = ''
            function()
              vim.opt_local.tabstop = 4
              vim.opt_local.shiftwidth = 4
              vim.opt_local.expandtab = true
            end
          '';
        };
      }

      # ---- 5. 启动时若是 `nvim <dir>`，弹 dashboard + 右侧 neo-tree ----
      {
        event = "VimEnter";
        group = "NvimConfig";
        nested = true;
        callback = {
          __raw = ''
            function()
              local name = vim.fn.expand("%:p")
              if name == "" or vim.fn.isdirectory(name) == 1 then
                vim.schedule(function()
                  if vim.fn.isdirectory(name) == 1 then
                    local dirbuf = vim.api.nvim_get_current_buf()
                    vim.cmd("enew")
                    pcall(vim.api.nvim_buf_delete, dirbuf, { force = true })
                    pcall(vim.cmd, "Dashboard")
                    pcall(vim.fn.chdir, name)
                  end
                  pcall(function()
                    require("neo-tree.command").execute({ action = "show", position = "right" })
                  end)
                end)
              end
            end
          '';
        };
      }
    ];
  };
}