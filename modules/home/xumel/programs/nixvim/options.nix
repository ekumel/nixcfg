# 编辑器基本行为：行号、缩进、剪贴板、撤销持久化、分屏方向 …
#
# 数值取自备份 nvim 配置（lua/config/options.lua）：
#   tabstop / shiftwidth = 4；expandtab；autoindent / smartindent；linebreak；
#   scrolloff / sidescrolloff = 8；laststatus = 3（让 lualine 的 globalstatus
#   只渲染一行，不在每个窗口重复）。
#
# 文件类型级的缩进（lua / rust = 4）在 ../autocmds.nix 里再覆盖。
{ ... }:

{
  programs.nixvim.opts = {
    # 行号
    number = true;
    relativenumber = true;

    # 缩进（4 空格，扩展 Tab）
    tabstop = 4;
    shiftwidth = 4;
    softtabstop = 4;
    expandtab = true;
    autoindent = true;
    smartindent = true;

    # 与系统剪贴板互通（Wayland 下需要 wl-clipboard，可走 systemPackages 补）
    clipboard = "unnamedplus";

    # 鼠标可用：终端里默认能选择文本，GUI 里可以拖选 / 滚轮
    mouse = "a";

    # 跨会话撤销（$XDG_STATE_HOME/nvim/undo）
    undofile = true;
    # 不在磁盘上落 .swp / ~ 文件
    swapfile = false;
    backup = false;

    # 分屏方向：新窗口从右 / 下打开
    splitright = true;
    splitbelow = true;

    # wrap：不在 buffer 内自动换行（依赖 linebreak 在视觉层换行）
    wrap = false;
    linebreak = true;

    # 滚动：保留 8 行上下边距
    scrolloff = 8;
    sidescrolloff = 8;

    # 光标 / 显示
    cursorline = true;
    termguicolors = true;
    signcolumn = "auto:2";
    updatetime = 250;

    # 隐藏未保存的 buffer，避免切 buffer 时被 prompt
    hidden = true;

    # 命令历史长度
    history = 1000;

    # 搜索行为
    ignorecase = true;
    smartcase = true;
    incsearch = true;
    hlsearch = true;

    # 补全菜单更顺手
    pumheight = 12;
    completeopt = [ "menu" "menuone" "noselect" ];

    # 真全局状态行（lualine globalstatus = true），避免每个窗口叠一行状态栏
    laststatus = 3;

    # 默认按 UTF-8 解析文件（兼容中文注释 / 字符串）
    encoding = "utf-8";
  };

  programs.nixvim.globals = {
    # 局部 leader（filetype-local keymaps 前缀；本配置里基本不用，但保留习惯）
    maplocalleader = " ";
    # 关掉 netrw（neo-tree 接管）
    loaded_netrw = 1;
    loaded_netrwPlugin = 1;
  };
}