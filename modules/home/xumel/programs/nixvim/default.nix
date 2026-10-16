# nixvim 主入口：开启 + 顶层配置。
#
# nixvim 属于用户空间：在 modules/home/xumel/default.nix 里导入
# `inputs.nixvim.homeModules.nixvim`，配置随 home-manager 一起激活。
#
# 拆分结构：
#   options.nix   基本编辑器行为（行号、缩进、剪贴板、undofile …）
#   theme.nix     兜底配色 + DMS（matugen）动态主题
#   keymaps.nix   全局键位
#   welcome.nix   欢迎界面居中 + 关 buffer 后自动切下一个（逻辑见 lua/welcome.lua）
#   plugins/      各功能模块（UI / 编辑 / 搜索 / LSP / completion / git / 格式化 / Rust）
#
# 注意：`imports` 必须放在模块最顶层（这是 NixOS 模块系统关键字），不能塞进
# `programs.nixvim = { imports = [...]; ... }` 里（那里 `imports` 只是普通属性）。
{
  # 只为了拿到 `inputs.nixvim`——见下面 nixpkgs.source 的说明。
  inputs,
  ...
}:

{
  imports = [
    ./options.nix
    ./theme.nix
    ./keymaps.nix
    ./autocmds.nix
    ./welcome.nix
    ./plugins
  ];

  programs.nixvim = {
    enable = true;

    # leader 键必须在 keymaps 之前就绪（keymaps 里大量 <leader> 前缀）。
    globals.mapleader = " ";

    # 消除 nixvim 的 nixpkgs.follows 警告。
    #
    # 警告长相：
    #   Nixvim's inputs pin Nixpkgs to <rev>. Actual Nixpkgs is following <rev>.
    #
    # 背景：nixvim 上游声明了 `inputs.nixpkgs.follows`，把它的 nixpkgs 指向本
    # flake 的 nixpkgs。但 nixvim 的 README / 安装文档**明确不建议**这么用——
    # 它希望 nixpkgs 与自身保持一致。所以正确做法不是顺着它 follow，而是显式
    # 把 source 定成 nixvim 自己那份（它 flake 里跟的是 nixpkgs 的
    # `nixpkgs-unstable` 分支，在 flake.lock 里就是 nixvim 节点的 nixpkgs 引用）。
    #
    # 显式写出来有两个作用：
    #   1. 警告消失（nixvim 看到 source 已被显式指定，就不再要求跟本 flake 一致）。
    #   2. 语义变明确——「nixvim 用它自己那份 nixpkgs」是写在代码里的既定事实，
    #      而不是「碰巧没人 follow」的现状。以后谁加 inputs.nixvim.inputs.nixpkgs.follows
    #      都会被这行挡住。
    #
    # 注意这里取的**不是**本 flake 的 `inputs.nixpkgs`：两者是不同节点
    # （本系统 nixpkgs 是 nixpkgs_3，nixvim 那份是 nixpkgs_4），刻意不跟随。
    nixpkgs.source = inputs.nixvim.inputs.nixpkgs;
  };
}
