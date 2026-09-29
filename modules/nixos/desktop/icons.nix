# 图标与光标主题（系统级默认值）。
#
# 说明：
#   - 光标：ful1e5/Bibata_Cursor 的 Bibata-Modern-Ice（XCursor），上游只
#     发布 XCursor 格式，Hyprland 在找不到 hyprcursor 时自动回退到 XCursor。
#   - dconf 设置统一在 gtk.nix 里：这里只安装包，避免把一份 user profile
#     数据库拆成多个定义。
{ pkgs, flake, lib, ... }:

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
