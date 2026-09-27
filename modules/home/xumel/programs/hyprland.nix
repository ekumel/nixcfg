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
{
  pkgs,
  lib,
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

  # hyprland-scroll-overview：类 niri 的滚动工作区概览（Hyprland 插件）。
  # 必须用与运行中的合成器完全相同的 Hyprland 包来构建：合成器由
  # programs.hyprland.package 设为 inputs.hyprland 的 main 包（见
  # modules/nixos/desktop/hyprland.nix），这里传入同一个包。若用 pkgs.hyprland
  # （nixpkgs 的 0.56.2）构建，PLUGIN_INIT 的 API 哈希校验会失败，插件被拒绝
  # 加载，其配置项（plugin.scrolloverview.*）也就始终是 unknown config key。
  # 构建步骤与上游 flake 的 packages.scrolloverview 相同（见 flake.nix 的 input）。
  scrollOverview = pkgs.hyprlandPlugins.mkHyprlandPlugin {
    pluginName = "scrolloverview";
    version = "unstable";
    src = inputs.hyprland-scroll-overview;

    hyprland = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    buildInputs = [ pkgs.lua5_4 ];
    dontUseCmakeConfigure = true;

    buildPhase = ''
      runHook preBuild
      export SCROLLOVERVIEW_BUILD_VERSION="unstable"
      make all
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib
      mv scrolloverview.so $out/lib/libscrolloverview.so
      runHook postInstall
    '';

    meta = {
      description = "Scrollable workspace overview plugin for Hyprland";
      homepage = "https://github.com/yayuuu/hyprland-scroll-overview";
      license = lib.licenses.bsd3;
      platforms = lib.platforms.linux;
    };
  };
  scrollOverviewPlugin = "${scrollOverview}/lib/libscrolloverview.so";

  # hyprpolkitagent 的可执行文件在 libexec/（没有 bin/），用 lib.getExe 会指错。
  polkitAgent = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";

  customLua = pkgs.writeText "custom.lua" ''
    -- Hyprland 自定义配置（Lua）。由 Nix 生成，请勿手改；
    -- 修改请编辑 modules/home/xumel/programs/hyprland.nix。
    --
    -- 本文件由 DMS 生成的 ~/.config/hypr/hyprland.lua 手动 require("custom")
    -- 载入（DMS 不感知此文件，导入由用户完成）。

    package.path = package.path .. ";" .. (os.getenv("HOME") or "") .. "/.config/hypr/?.lua"

    ------------------
    ---- 显示器 ----
    ------------------
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

    -- QEMU 虚拟显示器 Virtual-1：EDID 里没有 2560x1440，用自定义 modeline（CVT）。
    hl.monitor({
        output   = "Virtual-1",
        mode     = "modeline 241.50 2560 2608 2640 2720 1440 1443 1448 1481 +hsync -vsync",
        position = "auto",
        scale    = 1,
    })

    --------------------------------
    ---- 工作区概览插件 ----
    --------------------------------
    -- hyprland-scroll-overview（类 niri 的滚动概览）。
    -- 由 Nix 用系统 Hyprland 构建，见本文件上方 scrollOverview。
    hl.plugin.load("${scrollOverviewPlugin}")

    ------------------------
    ---- 环境变量 ----
    ------------------------
    hl.env("QT_QPA_PLATFORMTHEME", "qtengine")
    hl.env("GTK_THEME", "Darkly")
    hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
    hl.env("XCURSOR_SIZE", "48")

    ------------------
    ---- 外观 ----
    ------------------
    hl.config({
        general = {
            resize_on_border = true,
            allow_tearing    = false,
            layout = "scrolling",
        },
        decoration = {
            rounding_power = 2,
            -- 聚焦窗口 0.9，其他窗口 0.8。
            active_opacity   = 0.9,
            inactive_opacity = 0.8,
            shadow = {
                enabled = true, 
                range = 5, 
                render_power = 4,
            },
            blur = {
                enabled = true, 
                size = 8, 
                passes = 2,
                xray = true,
                new_optimizations = true, 
            },
            -- 移动/缩放窗口时的弹簧抖动效果。
            wobble = { enabled = true },
        },
        animations = { enabled = true },
        scrolling = {
            focus_fit_method   = 1,
            follow_min_visible = 0.4,
            wrap_focus         = true,
            wrap_swapcol       = true,
        },
        input = {
            kb_layout = "cn",
            follow_mouse = 0,
            sensitivity = 0,
            touchpad = { natural_scroll = true },
        },
        cursor = {
            enable_hyprcursor   = false,
            no_warps = true
        },
        misc = {
            force_default_wallpaper = 0,
            disable_hyprland_logo   = true,
        },
    })

    -- 工作区概览（hyprland-scroll-overview）配置：
    -- layout = "vertical" 与上面的滚动布局/垂直工作区切换保持一致。
    hl.config({
        plugin = {
            scrolloverview = {
                gesture_distance = 300,
                scale            = 0.5,
                workspace_gap    = 100,
                layout           = "vertical",
                wallpaper        = 0,
                blur             = false,
                shadow = { enabled = true, range = 50 },
            },
        },
    })

    hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1},   {0.32, 1} } })
    hl.curve("almostLinear", { type = "bezier", points = { {0.5, 0.5},  {0.75, 1} } })
    hl.curve("quick",        { type = "bezier", points = { {0.15, 0},   {0.1, 1} } })
    hl.curve("standard",     { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
    hl.curve("easy", { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

    hl.animation({ leaf = "global",     enabled = true, speed = 10,   bezier = "default" })
    hl.animation({ leaf = "border",     enabled = true, speed = 5.39, bezier = "easeOutQuint" })
    hl.animation({ leaf = "windows",    enabled = true, speed = 4.79, spring = "easy" })
    hl.animation({ leaf = "windowsIn",  enabled = true, speed = 4.1,  spring = "easy", style = "popin 87%" })
    hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
    hl.animation({ leaf = "fade",       enabled = true, speed = 3.03, bezier = "quick" })
    hl.animation({ leaf = "layers",     enabled = true, speed = 3.81, bezier = "easeOutQuint" })
    hl.animation({ leaf = "layersIn",   enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
    hl.animation({ leaf = "layersOut",  enabled = true, speed = 1.5,  bezier = "linear", style = "fade" })
    -- 滚动布局：工作区改垂直方向切换，避免与水平“带子”互相干扰。
    hl.animation({ leaf = "workspaces",    enabled = true, speed = 4, bezier = "standard", style = "slidevert" })
    hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 4, bezier = "standard", style = "slidevert" })
    hl.animation({ leaf = "workspacesOut", enabled = true, speed = 4, bezier = "standard", style = "slidevert" })

    -- 3 指水平切换工作区的手势由 DMS 生成（~/.config/hypr/dms/binds.lua），
    -- 这里不再重复定义，否则会被先注册的 DMS 手势 shadow 并触发警告。

    ----------------------
    ---- 自动启动 ----
    ----------------------
    hl.on("hyprland.start", function()
        hl.exec_cmd("${dbusUpdateEnv} --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
        hl.exec_cmd("${systemctl} --user start hyprland-session.target")
        hl.exec_cmd("${fcitx5} -d")
        hl.exec_cmd("${polkitAgent}")
        hl.exec_cmd("${ksecretdDaemon}")
        hl.exec_cmd("${kwalletd6Daemon}")
        hl.exec_cmd("${xsettingsd}")
        -- DMS（dms.service）与 dsearch 均为 systemd 用户服务，随
        -- graphical-session.target 自动启动（由上面的 hyprland-session.target
        -- 间接拉起），此处无需再 exec。
    end)

    ----------------------
    ---- 窗口规则 ----
    ----------------------
    hl.window_rule({
        name  = "suppress-maximize-events",
        match = { class = ".*" },
        suppress_event = "maximize",
    })
    hl.window_rule({
        name  = "fix-xwayland-drags",
        match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
        no_focus = true,
    })

    -- DMS 的弹窗（设置 / 仪表盘等）浮动居中。
    hl.window_rule({
        name  = "dms-floating",
        match = { class = "^(com.danklinux.dms)$" },
        float = true,
        center = true,
    })

    -- DMS 的图层窗口不做进出动画（避免与 shell 自身动画叠加）。
    hl.layer_rule({ match = { namespace = "^dms" }, no_anim = true })
  '';
in
{
  # scrollOverview 作为用户包安装，确保插件 .so 被系统闭包引用（Lua 配置里
  # 引用的 store 路径本身不是运行时依赖，不随配置一起保活）。
  home.packages = [ scrollOverview ];

  # DMS 接管 hyprland.lua；这里只生成供其手动 require 的自定义层。
  xdg.configFile."hypr/custom.lua".source = customLua;
}
