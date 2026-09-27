# 图标与光标主题（系统级默认值）。
#
# 说明：
#   - 光标：ful1e5/Bibata_Cursor 的 Bibata-Modern-Ice（XCursor），上游只
#     发布 XCursor 格式，Hyprland 在找不到 hyprcursor 时自动回退到 XCursor。
#   - dconf 设置统一在 gtk.nix 里：这里只安装包，避免把一份 user profile
#     数据库拆成多个定义。
{ pkgs, flake, lib, ... }:

let
  # nvfetcher 源：统一从 flake.lib.sources 取（见 lib/default.nix）。
  sources = flake.lib.sources pkgs;

  bibata-modern-ice = pkgs.stdenvNoCC.mkDerivation {
    pname = sources.bibata-modern-ice.pname;
    version = sources.bibata-modern-ice.version;

    src = sources.bibata-modern-ice.src;

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
