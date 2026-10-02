# 图标与光标主题（系统级安装）。
#
# 为什么必须在系统空间而不是用户空间：
#   DankGreeter 以 greetd 的 `greeter` 系统用户在登录前运行，并把用户的 DMS
#   设置（配色 / 壁纸 / 主题名）同步到 /var/lib/dms-greeter 渲染登录界面
#   （见 greeter.nix 的 configHome / configFiles）。登录界面引用的光标与图标
#   主题名（compositor 的 xcursor-theme、用户 DMS settings 里的 icon-theme）
#   必须在系统 profile 里找得到——用户的 home.packages 在此阶段尚不可见。
#
#   主题「键名」的声明不在本文件：
#     - 光标：greeter.nix 的 compositor config 显式指定 xcursor-theme；
#     - 图标：用户侧由 modules/home/xumel/programs/dms-mode-hook.nix 写入
#       dconf（icon-theme 随明暗模式在 Colloid / Colloid-dark 间切换），
#       greeter 读同步过去的 DMS 设置。
#   此前这些键还在已删除的 modules/nixos/desktop/gtk.nix 里用
#   programs.dconf.profiles.user.databases 声明过一份，但 NixOS 只在用户
#   dconf profile 尚未被首次登录创建时播种默认值、之后不再覆盖，等于首次
#   登录后即失效的僵尸配置。
{
  pkgs,
  lib,
  flake,
  ...
}:

let
  # 第三方源统一通过 flake inputs 跟踪（见 flake.nix）。
  # `flake.inputs.<name>` 在 `flake = false` 时是 store path 字符串（prefetch
  # 后的单文件或 tarball 解包目录），可直接当 src 用。
  bibata-modern-ice = pkgs.stdenvNoCC.mkDerivation {
    pname = "bibata-modern-ice";
    version = "2.0.7";

    src = flake.inputs.bibata-modern-ice;

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/icons
      # unpackPhase 已把 cwd 切到 Bibata-Modern-Ice/，直接 cp 当前内容。
      cp -r . $out/share/icons/Bibata-Modern-Ice/
      runHook postInstall
    '';

    meta = {
      description = "Bibata Modern Ice cursor theme (XCursor)";
      homepage = "https://github.com/ful1e5/Bibata_Cursor";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
    };
  };
in
{
  environment.systemPackages = [
    bibata-modern-ice
    pkgs.hicolor-icon-theme
    pkgs.papirus-icon-theme
    pkgs.colloid-icon-theme
  ];
}
