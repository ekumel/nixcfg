# DankMaterialShell dankHooks → 系统外观广播桥。
#
# 订阅 hook：
#   - onLightModeChanged       值：light | dark
#   - onMatugenCompleted       值：<mode>:<result>   例如 dark:success
#   - onDankHooksStarted       值：started | restarted
#
# ── onDankHooksStarted（一次性写静态项）──────────────────────────────
# org.gnome.desktop.interface 的静态项（gtk-theme / cursor-theme /
# cursor-size / 三个字体键）在这里用 gsettings 写进 ~/.config/dconf/user。
# icon-theme 不在这：见下方"模式相关项"的注释，交由 DMS 自己按模式切换。
#
# 为什么是运行时 gsettings 而不是 home-manager 的声明式配置：
#   dconf 的用户库是运行时二进制文件，且 DMS 每次启动 / 模式切换都要重写它，
#   不能做成 store 软链。原先这些键还在系统层
#   programs.dconf.profiles.user.databases 声明过一份，但 NixOS 只在用户
#   dconf profile 尚未被首次登录创建时播种默认值，之后不再覆盖——首次登录后
#   即失效的僵尸配置，且与本 hook 重复。系统层那份已随主题配置下沉一并移除。
#
# ── onLightModeChanged / onMatugenCompleted（写模式相关项）───────────
#   - color-scheme（GTK4 / libadwaita 选 gtk.css 还是 gtk-dark.css）
#   - GTK3 settings.ini: gtk-application-prefer-dark-theme
#   - qtengine .theme.colorScheme   ← 只写配色，不写 iconTheme
#
# 注意：iconTheme 现在交给 DMS 自己管（settings.json 的
# iconThemePerMode + iconTheme{Dark,Light}）。如果 hook 也写 gsettings
# 的 org.gnome.desktop.interface icon-theme，DMS 会比对失败并提示
# "图标在 dms 外修改"→ 把 settings.json 重置回 "System Default"，
# 于是你在 DMS UI 选什么都会被回滚。所以 hook 故意不再写 iconTheme，
# 只让 qtengine.colorScheme 跟上模式；iconTheme 由用户在 DMS UI 里
# 切模式后看到 Colloid-Light / Colloid-Dark 自动跟随。
#
# ── xsettingsd ───────────────────────────────────────────────────────
# xsettingsd.conf 不写死 Net/IconThemeName，让它从 dconf 回退读取；
# 这里 SIGHUP 让已运行的进程重读配置，XWayland 应用立即跟随。
{ pkgs, ... }:

let
  staticGsettings = [
    # [schema, key, value]
    [
      "org.gnome.desktop.interface"
      "gtk-theme"
      "Darkly"
    ]
    [
      "org.gnome.desktop.interface"
      "font-name"
      "LXGW WenKai 11"
    ]
    [
      "org.gnome.desktop.interface"
      "document-font-name"
      "LXGW WenKai 11"
    ]
    [
      "org.gnome.desktop.interface"
      "monospace-font-name"
      "Maple Mono NF CN 11"
    ]
    [
      "org.gnome.desktop.interface"
      "cursor-theme"
      "Bibata-Modern-Ice"
    ]
    [
      "org.gnome.desktop.interface"
      "cursor-size"
      "48"
    ]
  ];

  applyStatic = pkgs.writeShellScript "apply-static-gsettings.sh" (
    "set -euo pipefail\n"
    + "export DBUS_SESSION_BUS_ADDRESS=\"unix:path=/run/user/$(id -u)/bus\"\n"
    + (pkgs.lib.concatMapStrings (
      row: "gsettings set ${pkgs.lib.escapeShellArgs row}\n"
    ) staticGsettings)
  );
in
{
  xdg.configFile."scripts/dms-mode-hook.sh".source = pkgs.writeShellScript "dms-mode-hook.sh" ''
    set -euo pipefail
    HOOK="$1"; VALUE="$2"

    # DMS 在用户会话里拉起，DBUS 已继承；显式写一遍以防 hook 路径异常。
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

    # ── 静态项：仅在 DMS 启动 / 重启时写一次，避免覆盖用户中途的微调 ──
    if [[ "$HOOK" == "onDankHooksStarted" ]]; then
      ${applyStatic}

      # qtengine 静态项（DMS 启动后覆盖一次）。iconTheme 由 DMS 自己
      # 写（见顶部注释），这里只补齐 colorScheme / 字体 / style。
      QTE="$HOME/.config/qtengine/config.json"
      if [ -f "$QTE" ] && command -v jq >/dev/null 2>&1; then
        tmp=$(mktemp)
        if jq --arg cs "$HOME/.local/share/color-schemes/DankMatugen.colors" \
              --arg font "LXGW WenKai" \
              --arg mono "Maple Mono NF CN" \
              --arg style "Darkly" \
              '.theme.colorScheme = $cs
              | .theme.font.family = $font
              | .theme.fontFixed.family = $mono
              | .theme.style = $style' \
              "$QTE" > "$tmp"; then
          mv "$tmp" "$QTE"
        else
          rm -f "$tmp"
        fi
      fi
      exit 0
    fi

    # ── 模式相关项 ──
    # iconTheme 故意不写：见本文件头部注释，改由 DMS 自己按 settings.json
    # 的 iconThemePerMode + iconTheme{Dark,Light} 切换。
    case "$HOOK:$VALUE" in
      onLightModeChanged:light|onMatugenCompleted:light:*)
        SCHEME=prefer-light
        CS_FILE=DankMatugenLight.colors
        DARK=false
        ;;
      onLightModeChanged:dark|onMatugenCompleted:dark:*)
        SCHEME=prefer-dark
        CS_FILE=DankMatugenDark.colors
        DARK=true
        ;;
      *) exit 0 ;;
    esac

    gsettings set org.gnome.desktop.interface color-scheme "$SCHEME"

    # GTK3 settings.ini：确保 [Settings] 段与 prefer-dark 行存在且为当前值。
    # 该文件未被 home-manager 管理（Nix 端不写），hook 独占。
    GTK3_INI="$HOME/.config/gtk-3.0/settings.ini"
    mkdir -p "$(dirname "$GTK3_INI")"
    if [ ! -f "$GTK3_INI" ] || ! grep -q '^\[Settings\]' "$GTK3_INI"; then
      printf '[Settings]\n' >> "$GTK3_INI"
    fi
    ${pkgs.gnused}/bin/sed -i \
      -e '/^gtk-application-prefer-dark-theme=/d' \
      "$GTK3_INI"
    printf 'gtk-application-prefer-dark-theme=%s\n' "$DARK" >> "$GTK3_INI"

    # qtengine：把 .theme.colorScheme 指到当前模式的配色文件；iconTheme
    # 由 DMS 自己按 settings.json 的 iconTheme{Dark,Light} 写入。
    QTE="$HOME/.config/qtengine/config.json"
    CS_PATH="$HOME/.local/share/color-schemes/$CS_FILE"
    if [ -f "$QTE" ] && command -v jq >/dev/null 2>&1; then
      tmp=$(mktemp)
      if jq --arg cs "$CS_PATH" \
            '.theme.colorScheme = $cs' \
            "$QTE" > "$tmp"; then
        mv "$tmp" "$QTE"
      else
        rm -f "$tmp"
      fi
    fi

    # xsettingsd：SIGHUP 让它重读配置（图标主题项在 conf 里没写死，
    # 实际从 dconf 拿值；新会话窗口立即跟随新主题，已打开的窗口需重启应用）。
    pkill -HUP -x xsettingsd 2>/dev/null || true

    # helix：USR1 = 重载 config.toml / 主题（matugen 刚重写过
    # ~/.config/helix/themes/matugen.toml，见 programs/matugen.nix）。
    # 进程名可能是包装器后的 .hx-wrapped，与 home-manager 的 onChange 一致。
    pkill -USR1 -u "$USER" -x '(hx|\.hx-wrapped)' 2>/dev/null || true
  '';
}
