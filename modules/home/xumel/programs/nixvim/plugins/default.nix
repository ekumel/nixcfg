# 插件集合入口：分模块管理各功能域。
# `imports` 放在模块顶层（不要塞进 `programs.nixvim` 里）。
{ pkgs, ... }:

{
  imports = [
    ./treesitter.nix
    ./ui.nix
    ./ui-extra.nix
    ./editing.nix
    ./telescope.nix
    ./completion.nix
    ./lsp.nix
    ./lsp-servers.nix
    ./git.nix
    ./format.nix
    ./scroll.nix
    ./diagnostics.nix
    ./markdown.nix
    ./image.nix
    ./hop.nix
    ./rust.nix
  ];

  # nixvim 不内置的插件才从这里补（避免和 nixvim 自带同名插件重复进 runtimepath，
  # 不同 nixvim 版本 pin 的 plugin 版本可能不同，重复会导致加载顺序 / API 混乱）。
  #
  # nixvim 已自带（用 plugins.<name> 模块启用即可）：
  #   treesitter / gitsigns / diffview / neogit / nvim-ufo / hop / which-key /
  #   render-markdown / markdown-preview / noice / dashboard / toggleterm /
  #   neoscroll / scrollview / colorizer / tiny-inline-diagnostic / image /
  #   nvim-autopairs / nvim-surround / luasnip / friendly-snippets / telescope ...
  programs.nixvim.extraPlugins = with pkgs.vimPlugins; [
    # nixvim 只有 blink-cmp，没有 nvim-cmp 系列，故这些必须从 nixpkgs 补。
    nvim-cmp
    cmp-nvim-lsp
    cmp-buffer
    cmp-path
    cmp_luasnip
    # telescope 的 fzf-native sorter（nixvim 的 telescope 模块不带）
    telescope-fzf-native-nvim
    # image.nvim：改用 extraPlugins + 守卫式 setup（见 ./image.nix，避免 headless 下中断 init）
    image-nvim
  ];

  # 编辑器用到的外部可执行文件（进 wrapped nvim 的 PATH）：
  #   ripgrep / fd      → telescope live_grep / find_files
  #   tree-sitter       → nvim-treesitter `:TSInstall`（health check 也要求）
  #   black / prettier / shfmt / stylua / taplo → conform 各语言格式化
  #
  # 注：diffview 的 health 会探测 `hg`。Git 已满足它的要求，未装 mercurial 只会留
  # 一条 informational warning（装上反而会因中文 locale 解析版本失败报另一条）。
  programs.nixvim.extraPackages = with pkgs; [
    ripgrep
    fd
    tree-sitter
    black
    prettier
    shfmt
    stylua
    taplo
  ];
}
