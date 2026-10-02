# 用户空间 Hyprland 自定义配置（home-manager）。
#
# `~/.config/hypr/hyprland.lua` 由 DankMaterialShell 接管
# （见 modules/nixos/desktop/dms.nix）：DMS 会生成主配置并 require
# `dms.colors / outputs / layout / cursor / binds / binds-user / windowrules`。
# 本模块不再生成 hyprland.lua，只生成 ~/.config/hypr/custom.lua：
# 一份由用户在主配置末尾手动 `require("custom")` 载入的自定义层。
#
# 之所以用 home-manager 生成而不是手写：这里需要引用 Nix store 路径
# （scroll-overview 插件 .so、fcitx5 / polkit / keyring / xsettingsd 等），
# 只有交给 Nix 才能在每次 rebuild 后仍指向正确的闭包。
#
# Lua 本体在同目录的 custom.lua.in —— 一份带 ${...} 占位符的 Lua 模板，
# 由 pkgs.substitute 填入下面的 store 路径。放在 .nix 之外是为了让编辑器
# 能对 Lua 做语法高亮与跳转；改配置请改 custom.lua.in，不要改生成结果。
{
  pkgs,
  lib,
  flake,
  inputs,
  osConfig,
  ...
}:

let
  # 用 i18n.inputMethod 生成的包装器（fcitx5-with-addons），否则启动的是
  # 不带附加组件的裸 fcitx5，拼音等 addon 全部加载不了。
  # 用户空间模块拿不到 NixOS 的 i18n 选项，通过 home-manager 注入的
  # `osConfig`（系统配置）读取。
  fcitx5 = lib.getExe' osConfig.i18n.inputMethod.package "fcitx5";
  # greeter 直接拉起 Hyprland；会话目标 hyprland-session.target 由 DMS
  # 在初始化时写入 ~/.config/systemd/user/，这里把它拉起，
  # 否则 xdg-desktop-portal 会因 Requisite=graphical-session.target 失败。
  systemctl = lib.getExe' pkgs.systemd "systemctl";
  # 把 Wayland 会话环境同步给 systemd/dbus，供 D-Bus 激活的 portal 使用。
  dbusUpdateEnv = lib.getExe' pkgs.dbus "dbus-update-activation-environment";
  # KWallet 6 的两个守护进程：
  #   - ksecretd：实现 org.freedesktop.secrets（libsecret 客户端入口），
  #     同时承担 xdg-desktop-portal-kwallet 与旧版 kwallet API；
  #   - kwalletd6：org.kde.kwalletd6，给走 KF6 Wallet 的 KDE 应用。
  # 都来自 pkgs.kdePackages.kwallet，gobject-introspection + libsecret 在运行时需要。
  # ksecretd 先于 kwalletd6 启动，让 Secret Service 先可用，避免 libsecret
  # 首请求等待 D-Bus 自动激活。
  ksecretdDaemon = lib.getExe' pkgs.kdePackages.kwallet "ksecretd";
  kwalletd6Daemon = lib.getExe' pkgs.kdePackages.kwallet "kwalletd6";
  # xsettingsd：把 GTK 主题 / 图标 / 光标通过 XSETTINGS 协议广播到 X11 / XWayland。
  # dconf 只对走 GSettings 的应用生效，纯 X11 / X Toolkit 客户端需要这个守护进程。
  xsettingsd = lib.getExe pkgs.xsettingsd;
  # hyprpolkitagent 的可执行文件在 libexec/（没有 bin/），用 lib.getExe 会指错。
  polkitAgent = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";

  # hyprland-scroll-overview：类 niri 的滚动工作区概览（Hyprland 插件）。
  # 必须用与运行中的合成器完全相同的 Hyprland 包来构建，理由与构建步骤见
  # lib/hyprland-scroll-overview.nix。
  scrollOverview = flake.lib.hyprland-scroll-overview pkgs {
    inherit
      flake
      lib
      ;

    # 合成器由 programs.hyprland.package 设为 inputs.hyprland 的 main 包
    # （见 modules/nixos/desktop/hyprland.nix），这里传同一个。
    hyprland = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  };
  scrollOverviewPlugin = "${scrollOverview}/lib/libscrolloverview.so";

  # 把 custom.lua.in 里的 ${...} 占位符换成实际 store 路径。
  #
  # 用 builtins.replaceStrings（纯 Nix，不经 shell）而不是 pkgs.substitute：
  # 后者把 substitutions `toString` 后直接拼进 shell 字符串、不做转义，含
  # `$` 的查找串（'${fcitx5}'）会被 shell 当变量展开吃掉。replaceStrings
  # 在求值期完成替换，没有引号与转义问题，也不用额外拉 inplace-manager。
  #
  # 模板里 `^$` 这类 Lua 正则锚点是裸 $，与 ${...} 形式不同，不会被误替换。
  # 模式串写成双引号字符串并用 \$ 转义，才能得到字面量 ${name}。
  placeholderValues = {
    "\${dbusUpdateEnv}" = dbusUpdateEnv;
    "\${fcitx5}" = fcitx5;
    "\${ksecretdDaemon}" = ksecretdDaemon;
    "\${kwalletd6Daemon}" = kwalletd6Daemon;
    "\${polkitAgent}" = polkitAgent;
    "\${scrollOverviewPlugin}" = scrollOverviewPlugin;
    "\${systemctl}" = systemctl;
    "\${xsettingsd}" = xsettingsd;
  };

  customLua = pkgs.writeText "custom.lua" (
    builtins.replaceStrings (builtins.attrNames placeholderValues)
      (builtins.attrValues placeholderValues)
      (builtins.readFile ./hyprland/custom.lua.in)
  );
in
{
  # scrollOverview 作为用户包安装，确保插件 .so 被系统闭包引用（Lua 配置里
  # 引用的 store 路径本身不是运行时依赖，不随配置一起保活）。
  home.packages = [ scrollOverview ];

  # DMS 接管 hyprland.lua；这里只生成供其手动 require 的自定义层。
  xdg.configFile."hypr/custom.lua".source = customLua;
}
