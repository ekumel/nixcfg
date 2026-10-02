# DankMaterialShell（DMS）桌面 shell（系统级安装）。
#
# 包与模块都来自 flake input `dms`（见 flake.nix）。DMS 接管 shell 功能：
# 状态栏、启动器（Spotlight）、通知中心、剪贴板历史、锁屏、电源菜单，
# 以及配色（内置 matugen 动态主题）。
#
# 配色：`enableDynamicTheming` 会安装 matugen 并由 DMS 在壁纸/主题变化时
# 生成 GTK / Qt(qtengine) / kitty / Zen / VSCode 等主题文件。
#
# 启动方式：`systemd.enable` 生成 dms.service，绑定 graphical-session.target；
# 用户会话由 Hyprland 启动的 hyprland-session.target 拉起该目标
# （该 target 由 DMS 写入 ~/.config/systemd/user/，见
# modules/home/xumel/programs/hyprland.nix），无需在合成器配置里再 exec dms。
#
# ---- AI 插件凭据注入（AiOverviewControl）----
# 该插件的 provider 适配器是 shell 脚本，直接读 DMS 进程的环境变量，所以
# 凭据必须出现在 dms.service 的环境里。交互式 shell 的 export 传不进来
# （插件 docs/configuration.md 明确点了这一条），只能用 systemd 注入。
#
# 刻意不用 systemd.user.services.dms.environment：那个选项把值以
# Environment= 明文写进 /etc/systemd/user/dms.service，那文件全局可读，
# 等于把 key 泄进系统配置。EnvironmentFile 只往 unit 里写**路径**，
# 明文留在 ragenix 的 tmpfs 文件里（/run/agenix/ai-env，见
# modules/nixos/user-secrets.nix），不进 store、不落 /etc。
{ config, inputs, pkgs, ... }:

{
  imports = [
    inputs.dms.nixosModules.dank-material-shell
  ];

  programs.dank-material-shell = {
    enable = true;
    # 由 systemd 用户服务自动启动（默认关闭，须显式开启）。
    systemd.enable = true;
    # 让 DMS 接管 Material You 配色（安装 matugen 并在运行时生成主题）。
    enableDynamicTheming = true;
  };

  # dsearch：DMS Spotlight 的文件搜索后端。
  programs.dsearch.enable = true;

  # 往 dms.service 注入 provider 凭据。serviceConfig 是自由键值对，
  # 这里的键名直接按 systemd 原样渲染（不做 camelCase 转换）。
  systemd.user.services.dms.serviceConfig = {
    # 明文是 KEY=value 逐行的 EnvironmentFile，由 DMS 侧
    # AiOverviewControl 的 providers/native/*.bash 消费。
    # 前缀 '-' 表示文件缺失时不报错（agenix 尚未解密的过渡期）。
    EnvironmentFile = "-${config.age.secrets.ai-env.path}";

    # 区域端点不是密文，留在配置里而不是塞进密文。
    #
    # 必须显式指定：插件的 MiniMax 适配器默认打 https://api.minimax.io，
    # 而本机这把 key 是国内站的（pi 侧同样用 api.minimax.cn），
    # 在国际域名会被判 base_resp 2049 "invalid api key"。
    # 该变量同时重定向 /v1/models 与 /v1/token_plan/remains 两个只读端点。
    Environment = "MINIMAX_API_BASE=https://api.minimax.cn";
  };

  # 声音主题（kdePackages.ocean-sound-theme）原先也列在这里，但它与 DMS 这个
  # shell 无关——DMS 一旦停用声音主题就会跟着消失。已移到用户空间
  # modules/home/xumel/programs/audio.nix，与主题名（gsettings
  # org.gnome.desktop.sound theme-name）放在一起。
  environment.systemPackages = with pkgs; [
    ffmpeg
    amdgpu_top
    libinput
    cups-pk-helper
    ccal
    ydotool
    ddcutil
    wlr-utils
  ];
}
