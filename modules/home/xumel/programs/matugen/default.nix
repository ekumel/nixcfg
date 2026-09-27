# matugen：Material You 配色生成（范式 B：声明式输入 + 运行时输出）。
#
#   - 「输入」由 home-manager 声明式管理：~/.config/matugen/config.toml
#     （本模块生成），模板直接引用 Nix store 里的文件（只读，安全）。
#     模板源码在 modules/home/xumel/programs/matugen-templates/（部分取自
#     InioX/matugen-themes）。
#   - 「输出」由 matugen / DMS 在运行时写入。这些路径故意不出现在
#     home-manager 的 xdg.configFile 里，否则会被软链成只读 store 路径，
#     运行时写入会失败：
#       ~/.config/hypr/scheme/current.lua             （Hyprland 边框/阴影）
#       ~/.config/kitty/kitty.conf                    （kitty 终端）
#       ~/.config/fuzzel/fuzzel.ini                   （fuzzel 启动器）
#       ~/.config/wlogout/style.css                   （wlogout 会话菜单）
#       ~/.config/starship.toml                       （starship 提示符）
#       ~/.config/yazi/theme.toml                     （yazi 文件管理器）
#       ~/.config/helix/themes/matugen.toml           （helix 编辑器，由本模块模板生成）
#       ~/.config/btop/themes/matugen.theme           （btop，需 btop.conf 选它）
#       ~/.local/share/color-schemes/Matugen.colors   （Qt/qtengine 配色）
#       ~/.cache/wal/colors.json                      （pywalfox）
#       ~/.cache/matugen/vscode-colors{,.json}        （VS Code Matugen 扩展）
#   - 触发入口：programs/hyprland.nix 里的 wallpaper 脚本。
{ pkgs, ... }:

let
  templatesDir = ./matugen-templates;

  matugenConfig = (pkgs.formats.toml { }).generate "matugen-config.toml" {
    config = {
      version_check = false;
      # 图片里找不到合适颜色时使用的兜底色。
      fallback_color = "#ffbf9b";
    };

    templates = {
      # starship：整份 starship.toml 都由模板生成（palette 取自 matugen）。
      starship = {
        input_path = "${templatesDir}/starship.toml";
        output_path = "~/.config/starship.toml";
      };

      # yazi：整份 theme.toml（含文件类型图标定义）。
      yazi = {
        input_path = "${templatesDir}/yazi-theme.toml";
        output_path = "~/.config/yazi/theme.toml";
      };

      # helix：整份主题文件（编辑器 scope → Material You token 映射）。
      helix = {
        input_path = "${templatesDir}/helix-theme.toml";
        output_path = "~/.config/helix/themes/matugen.toml";
      };
    };
  };
in
{
  # matugen 只读取 config.toml，从不回写，因此可以安全地声明式托管。
  # 生成物不在此列（见文件顶部注释）。
  xdg.configFile."matugen/config.toml".source = matugenConfig;
}
