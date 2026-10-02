# 仓库范围的 Nix 辅助函数，blueprint 暴露为 flake.lib。
#
# blueprint 只把本文件（lib/default.nix）暴露为 flake.lib，同目录的其它
# .nix 不会自动进 output——它们是本文件的内部实现，由这里 import 后
# 再以 flake.lib.<name> 的形式分发出去。
#
# 消费方一律走 flake.lib.<name>，不要用相对路径直接 import lib/ 下的文件：
#   # 好：包/模块被别的 flake 消费时仍然能解析
#   (flake.lib.build-deb-fhs pkgs) { inherit pname version src; ... }
#   # 差：相对路径一旦跨 flake 消费就断
#   pkgs.lib.callPackageWith ../lib/build-deb-fhs.nix { ... }
#
#   packages/ 下的文件天然有 flake 参数（blueprint 注入），modules/ 下的
#   模块也已按需声明 { flake, ... }，所以两边都能直接取。
#
# 每个函数都显式接 pkgs 而不是在这里闭包捕获：本文件由 blueprint 求值时
# 不带 per-system 参数，拿不到 pkgs，由调用方传入才能保证用的是消费方
# 那一份 nixpkgs 实例（与 nixpkgs.follows / allowUnfree 的配置保持一致）。
#
# 形如 `pkgs: args: import ./foo.nix ({ inherit pkgs; } // args)` 的两层
# 写法是刻意的：Nix 的 attrset pattern 没有自动柯里化，直接写
# `pkgs: import ./foo.nix { inherit pkgs; }` 会在 foo.nix 还有必填参数时
# 立刻抛 "function called without required argument"。先吃掉 pkgs、再把
# 余下参数原样转发，消费侧才能写成自然的 `(flake.lib.foo pkgs) { ... }`。
{ ... }:

let
  # ---- buildFHSEnv 封装相关 ----
  # fhs-shared-pkgs.nix：预编译二进制包（.deb / tarball）跑在
  # buildFHSEnv 里时需要的公共 targetPkgs 列表。只有 pkgs 一个参数。
  fhs-shared-pkgs = pkgs: import ./fhs-shared-pkgs.nix { inherit pkgs; };

  # build-deb-fhs.nix：「解包 .deb + buildFHSEnv 封装」整套固定流程。
  # 除 pkgs 外还有 pname / version / src / binaryPath 等必填参数。
  build-deb-fhs = pkgs: args: import ./build-deb-fhs.nix ({ inherit pkgs; } // args);

  # darkly-gtk.nix：编译 Darkly GTK 主题并接上 DMS 动态配色。除 pkgs 外
  # 还要 lib / flake（取 darkly-gtk 源）/ userHome（DMS 运行时 CSS 路径）。
  darkly-gtk = pkgs: args: import ./darkly-gtk.nix ({ inherit pkgs; } // args);

  # hyprland-scroll-overview.nix：用系统同版本 Hyprland 构建滚动工作区
  # 概览插件。除 pkgs 外还要 lib / flake（取插件源）/ hyprland（合成器包）。
  hyprland-scroll-overview =
    pkgs: args: import ./hyprland-scroll-overview.nix ({ inherit pkgs; } // args);

  # ---- 用户空间小工具 ----
  # icon-overrides.nix：给 Colloid 主题未收录的应用图标加背景蒙版。
  # callPackage 风格，pname 必填、其余参数有默认值，由调用方给。
  icon-overrides = pkgs: args: pkgs.callPackage ./icon-overrides.nix args;

  # zed-lsp.nix：Zed 编辑器需要的语言服务器（nil + nixd）。
  # 全部参数都能由 callPackage 从 pkgs 作用域补齐，这里可以就地求值。
  zed-lsp = pkgs: pkgs.callPackage ./zed-lsp.nix { };
in
{
  inherit
    fhs-shared-pkgs
    build-deb-fhs
    darkly-gtk
    hyprland-scroll-overview
    icon-overrides
    zed-lsp
    ;
}
