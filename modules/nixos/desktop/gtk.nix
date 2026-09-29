# GTK 主题：wrymt/darkly-gtk（与 Qt 端 Darkly 样式同源）。
#
# 说明：
#   - darkly-gtk 用 sass 源码构建：sassc 把 sass/{gtk3-light,gtk3-dark,gtk4}.scss
#     编译成 CSS，输出目录布局完全照搬 upstream install.sh：
#       $out/share/themes/Darkly/{assets,gtk-3.0,gtk-4.0}/...
#     GTK 主题“目录名”是 Darkly，所以 dconf 里 gtk-theme 写 "Darkly"。
#   - 上游 install.sh 在没有 darklyrc 时会创建一个空的 _darkly_user_settings.scss
#     以满足 sass 的 @import；这里手动 touch 同样效果，使用默认外观。
#   - XWayland 一致性：dconf 的 org.gnome.desktop.interface.gtk-theme 对 GTK3/GTK4
#     XWayland 应用已经足够；非 GTK 的 X11 应用靠 xsettingsd（见
#     modules/home/xumel/programs/xsettingsd.nix 与
#     modules/home/xumel/programs/hyprland.nix）
#     通过 XSettings 协议同步。
#
# 动态配色（DMS / matugen）：
#   - Darkly 调色板在 sass/_colors.scss 里被硬编码为 `<name>_breeze` 命名色，
#     编译进 gtk.css，规则全部引用这些名字。DMS 写进
#     ~/.config/gtk-{3,4}.0/dank-colors.css 的是 libadwaita 语义色
#     （window_*/accent_* 等），Darkly 从不引用，所以默认不跟随动态色。
#   - GTK 命名色按 provider 解析，且引用发生在规则解析期：在
#     ~/.config/gtk-3.0/gtk.css 里写 @define-color 覆盖不到主题 provider，
#     因此覆盖必须落在主题自己的 CSS 里、并且在规则引用之前。
#   - 本模块在 build 时做两件事：
#       (1) 把每条 `@define-color <n>_breeze <值>;` 改写成引用 DMS 语义色
#           （`@define-color <n>_breeze @window_bg_color;`；明度派生用 mix() 现算）；
#       (2) 在每个编译产物最顶部 @import 两个文件：
#           本地 dms-fallback.css（store 内，保证名字始终有定义）
#           + DMS 运行时生成的 dank-colors.css（绝对路径，覆盖 fallback）。
#   - 只映射 DMS gtk3-light / gtk3-dark 两套模板都保证存在的语义名
#     （accent_/window_/view_/headerbar_/card_）；error/success/warning 保持
#     Breeze 语义色。这样不会因某个模板缺名而让 GTK 解析失败丢弃整张表。
{ pkgs, flake, lib, ... }:
let
  # 第三方源统一通过 flake inputs 跟踪（见 flake.nix）。
  # `flake.inputs.<name>` 在 `flake = false` 时是 store path 字符串（prefetch
  # 后的 tarball 解包目录），可直接当 src 用——不需要 lib/sources 包装。

  # matugen/DMS 的运行时输出位置。与 dms.nix 里的 pywalfox 同步脚本一致，
  # 直接写绝对路径（本机单用户 xumel）。
  userHome = "/home/xumel";

  # Darkly `_breeze` 调色板 → DMS 语义色。
  # 键是 `_breeze` 前缀；值是 `@define-color` 右侧（@名 或 GTK 颜色表达式）。
  # 键必须是 sass/_colors.scss 里出现过的 <name>（对应 <name>_breeze）。
  breezeToDms = {
    # 边框 / 视图
    borders = "mix(@window_bg_color, @window_fg_color, 0.18)";
    content_view_bg = "@view_bg_color";

    # 失效（insensitive）状态：用窗口前景/背景现算，跟随配色
    insensitive_base_color = "mix(@window_bg_color, @window_fg_color, 0.05)";
    insensitive_base_fg_color = "mix(@window_bg_color, @window_fg_color, 0.45)";
    insensitive_bg_color = "mix(@window_bg_color, @window_fg_color, 0.05)";
    insensitive_borders = "mix(@window_bg_color, @window_fg_color, 0.10)";
    insensitive_fg_color = "mix(@window_bg_color, @window_fg_color, 0.45)";
    insensitive_selected_bg_color = "mix(@window_bg_color, @window_fg_color, 0.05)";
    insensitive_selected_fg_color = "mix(@window_bg_color, @window_fg_color, 0.45)";
    insensitive_unfocused_bg_color = "mix(@window_bg_color, @window_fg_color, 0.05)";
    insensitive_unfocused_fg_color = "mix(@window_bg_color, @window_fg_color, 0.45)";
    insensitive_unfocused_selected_bg_color = "mix(@window_bg_color, @window_fg_color, 0.05)";
    insensitive_unfocused_selected_fg_color = "mix(@window_bg_color, @window_fg_color, 0.45)";

    # 链接
    link_color = "@accent_bg_color";
    link_visited_color = "mix(@accent_bg_color, @window_fg_color, 0.4)";

    # 表面 / 文字
    theme_base_color = "@view_bg_color";
    theme_bg_color = "@window_bg_color";
    theme_button_background_backdrop = "@card_bg_color";
    theme_button_background_backdrop_insensitive = "mix(@window_bg_color, @window_fg_color, 0.05)";
    theme_button_background_insensitive = "mix(@window_bg_color, @window_fg_color, 0.05)";
    theme_button_background_normal = "@card_bg_color";

    # 强调 / 焦点 / hover
    theme_button_decoration_focus = "@accent_bg_color";
    theme_button_decoration_focus_backdrop = "mix(@accent_bg_color, @window_bg_color, 0.5)";
    theme_button_decoration_focus_backdrop_insensitive = "mix(@accent_bg_color, @window_bg_color, 0.6)";
    theme_button_decoration_focus_insensitive = "mix(@accent_bg_color, @window_bg_color, 0.6)";
    theme_button_decoration_hover = "@accent_bg_color";
    theme_button_decoration_hover_backdrop = "mix(@accent_bg_color, @window_bg_color, 0.5)";
    theme_button_decoration_hover_backdrop_insensitive = "mix(@accent_bg_color, @window_bg_color, 0.6)";
    theme_button_decoration_hover_insensitive = "mix(@accent_bg_color, @window_bg_color, 0.6)";
    theme_hovering_selected_bg_color = "@accent_bg_color";
    theme_selected_bg_color = "@accent_bg_color";
    theme_selected_fg_color = "@accent_fg_color";
    theme_view_active_decoration_color = "@accent_bg_color";
    theme_view_hover_decoration_color = "@accent_bg_color";

    # 按钮前景
    theme_button_foreground_active = "@accent_fg_color";
    theme_button_foreground_active_backdrop = "mix(@accent_fg_color, @window_bg_color, 0.3)";
    theme_button_foreground_active_backdrop_insensitive = "mix(@window_bg_color, @window_fg_color, 0.45)";
    theme_button_foreground_active_insensitive = "mix(@window_bg_color, @window_fg_color, 0.45)";
    theme_button_foreground_backdrop = "mix(@window_bg_color, @window_fg_color, 0.65)";
    theme_button_foreground_backdrop_insensitive = "mix(@window_bg_color, @window_fg_color, 0.45)";
    theme_button_foreground_insensitive = "mix(@window_bg_color, @window_fg_color, 0.45)";
    theme_button_foreground_normal = "@window_fg_color";
    theme_fg_color = "@window_fg_color";
    theme_text_color = "@view_fg_color";

    # 头部 / 标题栏
    theme_header_background = "@headerbar_bg_color";
    theme_header_background_backdrop = "@headerbar_bg_color";
    theme_header_background_light = "@headerbar_bg_color";
    theme_header_foreground = "@headerbar_fg_color";
    theme_header_foreground_backdrop = "mix(@window_bg_color, @window_fg_color, 0.65)";
    theme_header_foreground_insensitive = "mix(@window_bg_color, @window_fg_color, 0.45)";
    theme_header_foreground_insensitive_backdrop = "mix(@window_bg_color, @window_fg_color, 0.45)";
    theme_titlebar_background = "@headerbar_bg_color";
    theme_titlebar_background_backdrop = "@headerbar_bg_color";
    theme_titlebar_background_light = "@headerbar_bg_color";
    theme_titlebar_foreground = "@headerbar_fg_color";
    theme_titlebar_foreground_backdrop = "mix(@window_bg_color, @window_fg_color, 0.65)";
    theme_titlebar_foreground_insensitive = "mix(@window_bg_color, @window_fg_color, 0.45)";
    theme_titlebar_foreground_insensitive_backdrop = "mix(@window_bg_color, @window_fg_color, 0.45)";

    # 失焦（backdrop / unfocused）
    theme_unfocused_base_color = "@window_bg_color";
    theme_unfocused_bg_color = "@window_bg_color";
    theme_unfocused_fg_color = "mix(@window_bg_color, @window_fg_color, 0.65)";
    theme_unfocused_selected_bg_color = "@accent_bg_color";
    theme_unfocused_selected_bg_color_alt = "@accent_bg_color";
    theme_unfocused_selected_fg_color = "@accent_fg_color";
    theme_unfocused_text_color = "mix(@window_bg_color, @window_fg_color, 0.85)";
    theme_unfocused_view_bg_color = "@window_bg_color";
    theme_unfocused_view_text_color = "mix(@window_bg_color, @window_fg_color, 0.45)";

    # 提示框 / 其它边框
    tooltip_background = "@card_bg_color";
    tooltip_border = "mix(@window_bg_color, @window_fg_color, 0.25)";
    tooltip_text = "@window_fg_color";
    unfocused_borders = "mix(@window_bg_color, @window_fg_color, 0.12)";
    unfocused_insensitive_borders = "mix(@window_bg_color, @window_fg_color, 0.08)";
  };

  # 用 sed 把编译产物里的 `_breeze` 定义改写成上面的映射。
  # 注意只匹配行首的 `@define-color`，不会误伤 gtk4 里 `@media (...) { ... }`
  # 包裹的自适应色（那些行以 @media 开头，且引用改写后的 _breeze）。
  paletteSed = pkgs.writeText "darkly-dms-palette.sed" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList
        (name: value:
          "s|^@define-color ${name}_breeze [^;]*;|@define-color ${name}_breeze ${value};|")
        breezeToDms
    )
  );

  # 兜底：DMS 尚未生成 dank-colors.css 时用上游 Breeze 值，保证上面映射
  # 引用到的语义名始终有定义（否则 GTK 解析到未定义命名色会中断整张表）。
  # 值取自上游 _colors.scss；DMS 的 dank-colors.css 会覆盖同名定义。
  dmsFallback = pkgs.writeText "darkly-dms-fallback.css" ''
    /* Darkly + DMS 兜底命名色（取自上游 _colors.scss 的 Breeze 调色板）。 */
    @define-color accent_bg_color #1b91d5;
    @define-color accent_fg_color #f1f1f1;
    @define-color window_bg_color #222222;
    @define-color window_fg_color #eff0f1;
    @define-color view_bg_color #2c2c2c;
    @define-color view_fg_color #f1f1f1;
    @define-color card_bg_color #2c2c2c;
    @define-color headerbar_bg_color #222222;
    @define-color headerbar_fg_color #eff0f1;
  '';

  darkly-gtk = pkgs.stdenvNoCC.mkDerivation {
    pname = "darkly-gtk";
    version = "unstable-2026-04-26";

    src = flake.inputs.darkly-gtk;

    nativeBuildInputs = [ pkgs.sassc pkgs.gnused ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      # 上游 install.sh：缺 darklyrc 时写入空的用户设置以满足 @import。
      touch sass/_darkly_user_settings.scss

      mkdir -p build
      sassc -M -t compact sass/gtk3-light.scss build/gtk3-light.css
      sassc -M -t compact sass/gtk3-dark.scss  build/gtk3-dark.css
      sassc -M -t compact sass/gtk4.scss       build/gtk4.css

      # (1) 把 _breeze 硬编码调色板改写成引用 DMS 语义色。
      sed -i -f ${paletteSed} build/gtk3-light.css build/gtk3-dark.css build/gtk4.css

      # (1b) 删除 Darkly 自己导出的这些 libadwaita 别名。
      #      GTK4 惰性解析命名色：Darkly 的 `window_bg_color` 定义成
      #      `@theme_bg_color_breeze`，而我们又把 `theme_bg_color_breeze` 指回
      #      `@window_bg_color`，形成引用环；GTK 检测到环会返回 NULL，背景色
      #      回退为 transparent（所以窗口整个透明）。`headerbar_*`、`card_bg_color`
      #      （它原本还是 70% 透明）同理。这几个名字 DMS 明/暗模板都会提供，
      #      fallback 里也有，删掉即可，改由 DMS 的值生效。
      sed -i \
        -e '/^@define-color window_bg_color /d' \
        -e '/^@define-color headerbar_bg_color /d' \
        -e '/^@define-color headerbar_fg_color /d' \
        -e '/^@define-color card_bg_color /d' \
        build/gtk3-light.css build/gtk3-dark.css build/gtk4.css

      # (2) 在最顶部注入 @import：先 fallback（同目录，相对路径），
      #     再 DMS 运行时文件（绝对路径，缺失时仅告警，fallback 仍可用）。
      #     gtk4.css 开头是 reset 规则，所以必须在最终文件顶部插入而不是改 sass。
      inject_imports() {
        local css="$1" runtime="$2"
        {
          printf '@import url("dms-fallback.css");\n'
          printf '@import url("file://%s");\n' "$runtime"
          cat "$css"
        } > "$css.tmp"
        mv "$css.tmp" "$css"
      }
      inject_imports build/gtk3-light.css "${userHome}/.config/gtk-3.0/dank-colors.css"
      inject_imports build/gtk3-dark.css  "${userHome}/.config/gtk-3.0/dank-colors.css"
      inject_imports build/gtk4.css       "${userHome}/.config/gtk-4.0/dank-colors.css"

      dest=$out/share/themes/Darkly
      mkdir -p "$dest/assets" "$dest/gtk-3.0" "$dest/gtk-4.0"

      cp -r assets/*.{png,svg} "$dest/assets/"

      # GTK4 主题资源链接（与 install.sh 一致）。
      ln -s ../assets "$dest/gtk-3.0/darkly-gtk-assets"
      ln -s ../assets "$dest/gtk-4.0/darkly-gtk-assets"
      ln -s ./gtk.css  "$dest/gtk-4.0/gtk-dark.css"

      cp build/gtk3-light.css "$dest/gtk-3.0/gtk.css"
      cp build/gtk3-dark.css  "$dest/gtk-3.0/gtk-dark.css"
      cp build/gtk4.css       "$dest/gtk-4.0/gtk.css"

      # fallback 命名色与 gtk.css 同目录，供相对 @import 命中。
      cp ${dmsFallback} "$dest/gtk-3.0/dms-fallback.css"
      cp ${dmsFallback} "$dest/gtk-4.0/dms-fallback.css"

      runHook postInstall
    '';

    meta = {
      description = "Darkly GTK theme (port of Bali10050/Darkly Qt style)";
      homepage = "https://github.com/wrymt/darkly-gtk";
      license = lib.licenses.lgpl21Only;
      platforms = lib.platforms.linux;
    };
  };
in
{
  environment.systemPackages = [
    darkly-gtk
    # 注：xsettingsd 守护进程属于用户会话，装在用户 profile
    # （modules/home/xumel/programs/xsettingsd.nix）。
  ];

  # GTK 主题 / 图标 / 光标 / 字体：与 qt.nix 保持一致。
  # 注意：Qt（QIconLoader）按“目录名”查找图标主题，GTK 用 index.theme 的
  # Name 字段（dconf 里填 "Vector (Dark)"）。qtengine 里仍填 "Vector-dark"
  # 目录名，详见 qt.nix。
  programs.dconf.profiles.user.databases = [
    {
      settings."org/gnome/desktop/interface" = {
        gtk-theme = "Darkly";
        icon-theme = "Colloid";
        cursor-theme = "Bibata-Modern-Ice";
        # cursor-size 在 GSettings schema 里是 int32，必须显式标注类型。
        cursor-size = lib.gvariant.mkInt32 48;
        # 字体：与 qt.nix 里的 LXGW WenKai / Maple Mono NF CN 一致。
        font-name = "LXGW WenKai 11";
        document-font-name = "LXGW WenKai 11";
        monospace-font-name = "Maple Mono NF CN 11";
      };
    }
  ];
  environment.sessionVariables.GSETTINGS_SCHEMA_DIR =
    "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
}
