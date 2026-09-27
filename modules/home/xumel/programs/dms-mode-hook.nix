# DankMaterialShell dankHooks → 系统外观广播桥。
#
# 订阅 hook：
#   - onLightModeChanged       值：light | dark
#   - onMatugenCompleted       值：<mode>:<result>   例如 dark:success
#   - onDankHooksStarted       值：started | restarted
#
# ── onDankHooksStarted（一次性写静态项）──────────────────────────────
# NixOS 的 programs.dconf.profiles.user.databases 只在用户 dconf profile
# 还没被首次登录创建时播种默认值；profile 已存在后 Nix 不会再覆盖。
# 因此用本钩子在每次 DMS 启动时把静态项写进 dconf：
#   - gtk-theme / cursor-theme / cursor-size / font-name / document-font-name
#     / monospace-font-name
# 这样 pwvucontrol 等 GTK 应用能拿到 Darkly 主题。
#
# ── onLightModeChanged / onMatugenCompleted（写模式相关项）───────────
#   - color-scheme（GTK4 / libadwaita 选 gtk.css 还是 gtk-dark.css）
#   - icon-theme（Colloid ↔ Colloid-dark）
#   - GTK3 settings.ini: gtk-application-prefer-dark-theme
#
# ── qtengine 修补 ────────────────────────────────────────────────────
# DMS 重写 ~/.config/qtengine/config.json 时把 iconTheme 写成
# "Colloid-Light"（pkgs.colloid-icon-theme 不存在该名），并把 colorScheme
# 写成当前模式对应文件。钩子在每次模式切换后修正 iconTheme 命名。
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

      # qtengine 静态项（DMS 启动后覆盖一次）
      QTE="$HOME/.config/qtengine/config.json"
      if [ -f "$QTE" ] && command -v jq >/dev/null 2>&1; then
        tmp=$(mktemp)
        if jq --arg icon "Colloid-dark" \
              --arg cs "$HOME/.local/share/color-schemes/DankMatugen.colors" \
              --arg font "LXGW WenKai" \
              --arg mono "Maple Mono NF CN" \
              --arg style "Darkly" \
              '.theme.iconTheme = $icon
              | .theme.colorScheme = $cs
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
    case "$HOOK:$VALUE" in
      onLightModeChanged:light|onMatugenCompleted:light:*)
        SCHEME=prefer-light
        ICON=Colloid
        CS_FILE=DankMatugenLight.colors
        DARK=false
        ;;
      onLightModeChanged:dark|onMatugenCompleted:dark:*)
        SCHEME=prefer-dark
        ICON=Colloid-dark
        CS_FILE=DankMatugenDark.colors
        DARK=true
        ;;
      *) exit 0 ;;
    esac

    gsettings set org.gnome.desktop.interface color-scheme "$SCHEME"
    gsettings set org.gnome.desktop.interface icon-theme "$ICON"

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

    # qtengine：覆盖 DMS 写的 iconTheme 名 + 指向对应配色文件。
    QTE="$HOME/.config/qtengine/config.json"
    CS_PATH="$HOME/.local/share/color-schemes/$CS_FILE"
    if [ -f "$QTE" ] && command -v jq >/dev/null 2>&1; then
      tmp=$(mktemp)
      if jq --arg icon "$ICON" --arg cs "$CS_PATH" \
            '.theme.iconTheme = $icon | .theme.colorScheme = $cs' \
            "$QTE" > "$tmp"; then
        mv "$tmp" "$QTE"
      else
        rm -f "$tmp"
      fi
    fi

    # xsettingsd：SIGHUP 让它重读配置（图标主题项在 conf 里没写死，
    # 实际从 dconf 拿值；新会话窗口立即跟随新主题，已打开的窗口需重启应用）。
    pkill -HUP -x xsettingsd 2>/dev/null || true
  '';
}
