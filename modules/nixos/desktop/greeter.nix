# greetd + DankGreeter（DMS 图形登录器）。
#
# 模块来自 flake input `dank-greeter`（见 flake.nix），它负责：
#   - 生成 greetd 的 default_session（以 greetd 的 `greeter` 用户运行）；
#   - 在登录器内用一台 Hyprland 承载 Quickshell 登录界面；
#   - 把用户 DMS 的 settings/session/colors 同步到 /var/lib/dms-greeter，
#     使登录界面与桌面配色、壁纸一致（`configHome` 指定用户家目录）。
# 这里只声明与登录器无关的会话默认值，以及承载合成器所需的设备权限。
{ inputs, ... }:

{
  imports = [
    inputs.dank-greeter.nixosModules.default
  ];

  # 默认启动 Hyprland 会话（登录器据此列出/预选会话）。
  services.displayManager.defaultSession = "hyprland";

  programs.dms-greeter = {
    enable = true;

    compositor = {
      name = "niri"; # Required. Can be also "hyprland" or "sway"
      customConfig = ''
        config-notification {
            disable-failed
        }
        hotkey-overlay {
            skip-at-startup
        }
        environment {
          QT_QPA_PLATFORMTHEME "qtengine"
        }
        cursor {
            xcursor-theme "Bibata-Modern-Ice"
            xcursor-size 48
        }
      '';
    };

    # compositor = {
    #   name = "hyprland"; # Required. Can be also "hyprland" or "sway"
    #   customConfig = ''
    #     hl.env("QT_QPA_PLATFORMTHEME", "qtengine")
    #     hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
    #     hl.env("XCURSOR_SIZE", "48")
    #   '';
    # };

    # Sync your user's DankMaterialShell theme with the greeter. You'll probably want this
    configHome = "/home/xumel";

    # Custom config files for non-standard config locations
    configFiles = [
      "/home/xumel/.config/DankMaterialShell/settings.json"
    ];

    # Save the logs to a file
    logs = {
      save = true;
      path = "/tmp/dms-greeter.log";
    };
  };

  # 承载登录器的 Hyprland / wlroots 需要访问 DRM 设备。
  # greeter 是 greetd 使用的系统服务账户：必须显式声明为系统用户并指定所属组。
  users.users.greeter = {
    isSystemUser = true;
    group = "greeter";
    extraGroups = [
      "video"
      "render"
    ];
  };
  users.groups.greeter = { };
}
