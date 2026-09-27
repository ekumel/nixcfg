# nixvim 主入口：开启 + 顶层配置。
#
# nixvim 属于用户空间：在 modules/home/xumel/default.nix 里导入
# `inputs.nixvim.homeModules.nixvim`，配置随 home-manager 一起激活。
#
# 拆分结构：
#   options.nix   基本编辑器行为（行号、缩进、剪贴板、undofile …）
#   theme.nix     兜底配色 + DMS（matugen）动态主题
#   keymaps.nix   全局键位
#   plugins/      各功能模块（UI / 编辑 / 搜索 / LSP / completion / git / 格式化 / Rust）
#
# 注意：`imports` 必须放在模块最顶层（这是 NixOS 模块系统关键字），不能塞进
# `programs.nixvim = { imports = [...]; ... }` 里（那里 `imports` 只是普通属性）。
{
  ...
}:

{
  imports = [
    ./options.nix
    ./theme.nix
    ./keymaps.nix
    ./autocmds.nix
    ./plugins
  ];

  programs.nixvim = {
    enable = true;

    # leader 键必须在 keymaps 之前就绪（keymaps 里大量 <leader> 前缀）。
    globals.mapleader = " ";
  };
}
