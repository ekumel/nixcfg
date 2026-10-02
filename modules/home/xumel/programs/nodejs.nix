# Node.js 工具链：nodejs + pnpm（用户空间）。
#
# 为什么装在 home.packages 而不是系统层 environment.systemPackages：
#   与 programs/gtk.nix、programs/qt.nix 同一分工——系统层只提供运行环境，
#   用户自己用的开发工具链归用户空间。仓库里 nodejs 此前只出现在
#   packages/mcode.nix / packages/pi-agent.nix 的 nodejs = pkgs.nodejs_22
#   （构建期）与 devshell.nix（nix-shell 专用），系统 profile 里没有 node。
#
# ── 为什么 pnpm 直接取 nixpkgs 的 pkgs.pnpm ─────────────────────────
#   1. 这版 nixpkgs 已移除 nodePackages（求值会直接报 "nodePackages has
#      been removed"），npm 生态的包整体上移到顶层，pnpm 就是 pkgs.pnpm。
#   2. pkgs.pnpm 是**自包含的 Rust 二进制**（bin/pnpm 是 ELF，不是 wrapper），
#      不依赖 PATH 里的 node 也能跑；仍然装 nodejs 是因为用户项目本身要
#      node / npm / npx 跑 lifecycle script。
#   3. 不用 corepack：corepack 的 shim 要写进 nodejs 那个只读 store 路径，
#      得再配 --install-directory 到可写目录，多一层；而且 pnpm 自身就会读
#      package.json 的 packageManager 字段按需切版本，不需要 corepack 插手。
#   4. 不用 npm install -g pnpm：装到用户目录不受 Nix 管理，不进 GC roots，
#      升级还得手动重装。
#
# ── nodejs 版本为什么用默认的 24 而不是 nodejs_22 ───────────────────
#   packages/mcode.nix 钉 nodejs_22 是为了绕开 better-sqlite3 在
#   Node 24.20.0 + 中文输入下的 V8 Isolate SIGABRT——那是 mcode 那个
#   native 模块的特定组合，不是 Node 24 本身的问题。pnpm 是纯 Rust 二进制，
#   没有 native 模块，不受该 bug 影响；而 pkgs.pnpm 本来就是对着
#   pkgs.nodejs（当前 24.20.0）构建的，两者同版本最省心。
#   真要给某个项目钉 Node 22，用 nix-shell -p nodejs_22，不要改这里。
{
  pkgs,
  ...
}:

{
  home.packages = [
    pkgs.nodejs
    pkgs.pnpm
  ];

  # pnpm 的全局配置。注意 pnpm 12（Rust 重写）换了配置格式：不再是 pnpm ≤11
  # 那套 ~/.config/pnpm/rc（INI 风格、键名 store-dir），而是 YAML 的
  # ~/.config/pnpm/config.yaml、驼峰键名 storeDir。实测 `pnpm config set
  # store-dir … --global` 自己写出来的就是 config.yaml 里的 `storeDir:`，
  # 写错文件名 / 键名会被静默忽略（pnpm config get 仍返回 undefined）。
  #
  # 为什么必须显式钉 storeDir——本机布局踩中了 pnpm 的 store 回退逻辑：
  #   pnpm 文档规定 store 要与安装目录同盘，「找不到同盘 home 时就放文件系统
  #   根目录」；再退一步，「上层目录都不可写时就把 store 放进项目内
  #   node_modules/.pnpm-store」（pnpm #13525）。
  #   本机 /home 是独立文件系统（st_dev 49），项目所在的 / 与 /etc/nixos 在
  #   另一块盘（st_dev 35）且 / 不可写，于是回退到项目内。实测：
  #     $ cd /etc/nixos && pnpm store path
  #     /etc/nixos/node_modules/.pnpm-store/v11
  #   后果有两个：store 不共享（pnpm 的去重优势全丢），以及在本仓库里跑一次
  #   pnpm 就会留下未跟踪的 node_modules/（.gitignore 没覆盖它）。
  #   显式写死后：项目在 ~ 下时同盘、走硬链接、跨项目共享；项目在别的盘时
  #   退化成拷贝，而不是把 store 塞进 git 仓库。store 可写 = 信任域，本机
  #   单人使用，不额外收紧权限（pnpm 文档 "important" 一节的提醒）。
  xdg.configFile."pnpm/config.yaml".text = ''
    storeDir: /home/xumel/.local/share/pnpm/store
  '';
}
