# 欢迎界面 + buffer 生命周期的体验修正。
#
# 逻辑全在 lua/welcome.lua（文件头把两个问题各自的根因、上游代码位置都写清楚了），
# 这里只负责把模块放进 runtimepath 并在启动时 setup 一次。
#
# 为什么用 extraConfigLuaPost：nixvim 生成 init.lua 的顺序是固定的
#   extraConfigLuaPre → extraConfigVim → extraConfigLua → extraConfigLuaPost
# （见 nixvim modules/output.nix:173-181）。本模块要抢在两件事之前：
#   1. dashboard 首次渲染之前 —— dashboard 的自动触发在 UIEnter（无参数启动）
#      或 autocmds.nix 的 VimEnter 里，都晚于 Lua 配置阶段，所以来得及打补丁；
#   2. avante 的 setup 之前 —— extraConfigLuaPre 只被 avante.nix 单独占用，
#      Post 排在其后但两者互不干扰（avante 的高亮覆盖由 theme.nix 负责）。
{ ... }:

{
  programs.nixvim = {
    extraFiles."lua/welcome.lua".source = ./lua/welcome.lua;

    extraConfigLuaPost = ''
      require("welcome").setup()
    '';
  };
}
