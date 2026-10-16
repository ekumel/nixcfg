#!/usr/bin/env bash
# update-third-party.sh — 探测第三方上游最新版本、修改 flake.nix 的 url、
# 修改 packages/*.nix 的 version 字面量、`nix flake lock` 重锁。
#
# 用法：
#   ./scripts/update-third-party.sh              # 全部 URL 类 input 都更新
#   ./scripts/update-third-party.sh kelivo zedg  # 仅更新指定 input
#   ./scripts/update-third-party.sh voicefox     # 仅 voicefox（终端音乐播放器）
#   ./scripts/update-third-party.sh fluxdown     # 仅 fluxdown（下载器）
#   ./scripts/update-third-party.sh any-listen   # 仅 any-listen（音乐播放服务）
#   ./scripts/update-third-party.sh wechat       # 仅 wechat（URL 不变，只刷
#                                                # narHash + version）
#
# 退出码：0=全部成功，1=探测失败，2=lock/应用改动失败。
#
# 设计原则：
#   - 探测 GitHub Releases / Gitea v1 API（统一 JSON shape：tag_name + assets[]）；
#   - 探测走 ~/.config/nix/netrc（secrets.nix 软链到 ragenix 解密的
#     github-netrc），未找到时 fallback 到 $GITHUB_TOKEN，再不行就裸跑；
#     60/h 速率限制下未认证的 GitHub API 大概率失败。
#   - 每个源一个 updater_<name>() 函数，输出 tab 分隔的
#     "<name>\t<new_url_or_->\t<new_version_in_dot_nix_or_->"；
#     URL 字段为 "-" 表示 URL 不变（wechat / darkly-gtk）。
#   - 应用改动前备份 flake.nix 到 flake.nix.bak，失败可回滚。
#
# 不做的事：
#   - 不动 nixpkgs / Hyprland / home-manager 等非第三方 input——
#     那些由各上游版本节奏控制，单独跑 `nix flake update nixpkgs`。
#   - 不改 packages/*.nix 的 pname / 打包逻辑，只改 version 字面量。
#   - 不自动 git commit / push：留给用户审阅 `git diff` 后手动决定。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

NETRC="${XDG_CONFIG_HOME:-$HOME/.config}/nix/netrc"
CURL_BASE=(curl --silent --show-error --max-time 30 --location)
if [ -r "$NETRC" ]; then CURL_BASE+=(--netrc-file "$NETRC"); fi

if ! command -v jq >/dev/null 2>&1; then
  echo "错误：jq 未安装。nix shell nixpkgs#jq 或 apt install jq" >&2
  exit 1
fi
if ! command -v nix >/dev/null 2>&1; then
  echo "错误：nix 未在 PATH 里" >&2
  exit 1
fi

NIX=(nix --extra-experimental-features 'nix-command flakes')

die() { echo "错误: $*" >&2; exit 1; }

# ---- 探测结果（全局数组） ----
# 元素：<name>\t<new_url_or_->\t<new_dot_nix_version_or_->
declare -a RESULTS=()

# ---- 各源 updater ----

# GitHub release 通用探测：返回 "url<TAB>version"，失败返回 1。
# 用法：probe_github <owner/repo> <asset_regex_ERE>
probe_github() {
  local repo="$1" asset_re="$2"
  local release tag asset url
  release=$(curl "${CURL_BASE[@]}" \
    "https://api.github.com/repos/${repo}/releases/latest")
  if [ -z "$release" ] || [ "$release" = "null" ]; then
    echo "GitHub API 返回空（速率限制？检查 $NETRC 是否就位）" >&2
    return 1
  fi
  tag=$(printf '%s' "$release" | jq -r '.tag_name // empty')
  [ -n "$tag" ] || { echo "GitHub API 无 tag_name" >&2; return 1; }
  asset=$(printf '%s' "$release" | jq -r '.assets[]?.name // empty' \
    | grep -E "$asset_re" | head -n1)
  [ -n "$asset" ] || { echo "未匹配到 asset: $asset_re" >&2; return 1; }
  echo "$tag"$'\t'"$asset"
}

# kelivo：asset 名 = Kelivo_linux_<version>+<build>.tar.gz
# URL 里 + 必须编码为 %2B；version 字面量写 "v<tag>+<build>"。
updater_kelivo() {
  local out tag asset version url
  out=$(probe_github "Chevey339/kelivo" '^Kelivo_linux_.+\.tar\.gz$') || return 1
  IFS=$'\t' read -r tag asset <<<"$out"
  version=$(echo "$asset" | sed -E 's/^Kelivo_linux_(.+)\.tar\.gz$/\1/')
  url="https://github.com/Chevey339/kelivo/releases/download/${tag}/${asset}"
  url="${url//+/%2B}"
  RESULTS+=("kelivo"$'\t'"${url}"$'\t'"v${version}")
}

# genoffice：asset = GenOffice-<version>.AppImage（无 v 前缀）
updater_genoffice() {
  local out tag asset version url
  out=$(probe_github "genspark-ai/genoffice" '^GenOffice-.+\.AppImage$') || return 1
  IFS=$'\t' read -r tag asset <<<"$out"
  version=$(echo "$asset" | sed -E 's/^GenOffice-(.+)\.AppImage$/\1/')
  url="https://github.com/genspark-ai/genoffice/releases/download/${tag}/${asset}"
  RESULTS+=("genoffice"$'\t'"${url}"$'\t'"${version}")
}

# zedg：asset = zedg-zh-cn-linux-x86_64-<tag>.tar.gz；version 字面量保留 v 前缀
updater_zedg() {
  local out tag asset url version
  out=$(probe_github "WenYin-Community/zed-globalization" \
    '^zedg-zh-cn-linux-x86_64-.+\.tar\.gz$') || return 1
  IFS=$'\t' read -r tag asset <<<"$out"
  version="$tag"
  url="https://github.com/WenYin-Community/zed-globalization/releases/download/${tag}/${asset}"
  RESULTS+=("zedg"$'\t'"${url}"$'\t'"${version}")
}

# wechat：URL 永远不变，仅刷 narHash + 改 version 字面量（从官方下载页抓）。
#   抓取 https://linux.weixin.qq.com/ 上的版本字符串。
#   页面里 `bd-version` 是官方下载区里的版本显示（class 加 hash 形式）：
#     bd-version" data-v-1556f5f1>4.1.13
#   其它 X.Y.Z 可能是 Qt 推荐版本、统计数字等，不能用。
updater_wechat() {
  local page version
  page=$(curl "${CURL_BASE[@]}" "https://linux.weixin.qq.com/") || return 1
  # 优先抓 bd-version class 后的版本号（页面唯一真正的 wechat 版本）。
  version=$(printf '%s' "$page" \
    | grep -oE 'bd-version" data-v-[a-f0-9]+>[0-9]+\.[0-9]+\.[0-9]+' \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
  if [ -z "$version" ]; then
    # fallback：页面里更靠后的数字串往往是 wechat 版本（Qt 推荐版本在前面）。
    version=$(printf '%s' "$page" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -n 3 | head -n1)
  fi
  [ -n "$version" ] || { echo "wechat: 未抓到版本号" >&2; return 1; }
  RESULTS+=("wechat"$'\t'"-"$'\t'"${version}")
}

# bibata-modern-ice：asset = Bibata-Modern-Ice.tar.xz
updater_bibata() {
  local out tag asset url version
  out=$(probe_github "ful1e5/Bibata_Cursor" '^Bibata-Modern-Ice\.tar\.xz$') || return 1
  IFS=$'\t' read -r tag asset <<<"$out"
  version="${tag#v}"
  url="https://github.com/ful1e5/Bibata_Cursor/releases/download/${tag}/${asset}"
  RESULTS+=("bibata-modern-ice"$'\t'"${url}"$'\t'"${version}")
}

# goquark：asset = goquark_<version_no_v>_linux_amd64
# 上游 tag 形如 v1.0.3，asset 名里版本号无 v 前缀：goquark_1.0.3_linux_amd64。
# 我们的 version 字面量保留 v 前缀以便与 README / `goquark version` 一致。
updater_goquark() {
  local out tag asset url version
  out=$(probe_github "ButterFuture/GoQuark" '^goquark_.+_linux_amd64$') || return 1
  IFS=$'\t' read -r tag asset url <<<"$out"
  version="$tag"
  url="https://github.com/ButterFuture/GoQuark/releases/download/${tag}/${asset}"
  RESULTS+=("goquark"$'\t'"${url}"$'\t'"${version}")
}

# prismlauncher-offline-account：asset = PrismLauncher-Linux-Qt6-Portable-<version>.tar.gz
# 上游同时还发 plain PrismLauncher-<version>.tar.gz（Qt5 老版）和
# PrismLauncher-Linux-x86_64.AppImage——只挑 Qt6 portable tarball，
# 因为它是 statically linked、unpack 即可，最贴合 Nix 打包模型。
updater_prismlauncher_offline_account() {
  local out tag asset url version
  out=$(probe_github "forsyth47/PrismLauncher-OfflineAccount" \
    '^PrismLauncher-Linux-Qt6-Portable-.+\.tar\.gz$') || return 1
  IFS=$'\t' read -r tag asset <<<"$out"
  # 上游 tag 形如 10.0.5-offline2（带 -offlineN 后缀），保持原样。
  version="$tag"
  url="https://github.com/forsyth47/PrismLauncher-OfflineAccount/releases/download/${tag}/${asset}"
  RESULTS+=("prismlauncher-offline-account"$'\t'"${url}"$'\t'"${version}")
}

# baidunetdisk：上游 https://pan.baidu.com/download 是 SPA，HTML 模板里
# 没有版本字符串；issuecdn.baidupcs.com 也没有 directory listing。
# 因此未提供自动探测：手动到下载页查版本，按
# `LinuxGuanjia/<version>/baidunetdisk_<version>_amd64.deb` 模式构造 URL，
# 改 flake.nix 的 baidunetdisk url + packages/baidunetdisk.nix 的 version
# 字面量后跑 `nix flake lock --update-input baidunetdisk`。

# orca：electron-builder 发布的 latest-linux.yml 元数据。
#   不同于 GitHub Releases API，orca 用 electron-builder 的
#   auto-update 协议——latest-linux.yml 是 YAML：
#     version: 1.4.217
#     files:
#       - url: orca-ide_1.4.217_amd64.deb
#         sha512: <base64 sha512>
#         size: 180987924
#   拿 version + .deb URL + sha512，拼出 absolute URL 写到 flake.nix。
#   sha512 上游已算，flake.nix 的 lock 会从 narHash 反推 sha256
#   （nix prefetch 内部用 sha256），所以这里不需要手动算——交给
#   `nix flake lock --update-input orca` 重锁即可，narHash 会自动
#   落进 flake.lock。
updater_orca() {
  local yml version file_url deb_sha512
  yml=$(curl "${CURL_BASE[@]}" \
    "https://github.com/stablyai/orca/releases/latest/download/latest-linux.yml")
  [ -n "$yml" ] || { echo "orca: latest-linux.yml 下载空" >&2; return 1; }
  version=$(printf '%s' "$yml" | awk '/^version:/{print $2; exit}')
  [ -n "$version" ] || { echo "orca: latest-linux.yml 无 version 字段" >&2; return 1; }
  # electron-builder YAML 用 2 空格缩进；用 awk 找 'url: ...amd64.deb' 行
  file_url=$(printf '%s' "$yml" \
    | awk '/^  - url:/{u=$3} /^    url:/{u=$3} END{print u}' \
    | grep '_amd64\.deb$')
  [ -n "$file_url" ] || file_url=$(printf '%s' "$yml" \
    | awk '/^  - url:/{print $3}' | grep '_amd64\.deb$' | head -n1)
  [ -n "$file_url" ] || { echo "orca: latest-linux.yml 无 amd64.deb 资产" >&2; return 1; }
  # absolute URL：electron-builder 的 url 是相对路径，base 是 release tag URL
  # 但我们只关心 version 字面量、URL 由 flake.nix + 重锁自动拼（升
  # 级后 flake.lock 的 narHash 会刷）。所以这里只取 version，URL
  # 写为模板可推的形式。但 template-only URL 会被 flake 当作不固定
  # URL 锁不住；需要在 flake.nix 写 literal URL（带版本号）。
  # 妥协：写 literal URL，由本 updater 拼绝对 URL 推进 RESULTS。
  local abs_url="https://github.com/stablyai/orca/releases/download/v${version}/${file_url}"
  RESULTS+=("orca"$'\t'"${abs_url}"$'\t'"${version}")
}

# dwproton：Forgejo (dawn.wine)，Gitea v1 API：
#   /api/v1/repos/<owner>/<repo>/releases/latest
# asset = dwproton-<ver>-x86_64.tar.xz；version 字面量保留完整 tag。
updater_dwproton() {
  local release tag asset url version
  release=$(curl "${CURL_BASE[@]}" \
    "https://dawn.wine/api/v1/repos/dawn-winery/dwproton/releases/latest")
  if [ -z "$release" ] || [ "$release" = "null" ]; then
    echo "Forgejo API 返回空（dawn.wine 挂了？）" >&2
    return 1
  fi
  tag=$(printf '%s' "$release" | jq -r '.tag_name // empty')
  [ -n "$tag" ] || { echo "Forgejo API 无 tag_name" >&2; return 1; }
  asset=$(printf '%s' "$release" | jq -r '.assets[]?.name // empty' \
    | grep -E '^dwproton-.+-x86_64\.tar\.xz$' | head -n1)
  [ -n "$asset" ] || { echo "未匹配到 dwproton asset" >&2; return 1; }
  version="$tag"
  url="https://dawn.wine/dawn-winery/dwproton/releases/download/${tag}/${asset}"
  RESULTS+=("dwproton"$'\t'"${url}"$'\t'"${version}")
}

# voicefox：emoeem/voicefox，终端音乐播放器（TUI，Rust + ratatui +
# libmpv）。GitHub release 发的是预编译 zip，asset 按架构命名：
#   voicefox-linux-x86_64.zip / voicefox-linux-aarch64.zip
# tag 形如 v0.4.0；URL 里 asset 名不含版本号，只有 tag 目录带，所以要
# 用 tag + asset 名自己拼绝对 URL。
updater_voicefox() {
  local out tag asset url
  out=$(probe_github "emoeem/voicefox" '^voicefox-linux-x86_64\.zip$') || return 1
  tag=${out%%$'\t'*}
  asset=${out##*$'\t'}
  [ -n "$tag" ] && [ -n "$asset" ] || { echo "voicefox: 解析 tag/asset 失败" >&2; return 1; }
  url="https://github.com/emoeem/voicefox/releases/download/${tag}/${asset}"
  RESULTS+=("voicefox"$'\t'"${url}"$'\t'"${tag}")
}

# fluxdown：zerx-lab/FluxDown，开源多协议下载管理器（Rust + GPUI）。
# 上游同时发 .deb / .AppImage / .tar.gz / .pkg.tar.zst 以及 CLI / Server /
# mobile / extension 一堆并行 tag 的预编译产物，只取桌面端的 Linux
# x86_64 .deb（理由见 packages/fluxdown.nix 顶部注释）。
#   asset 命名 FluxDown-<version>-linux-x64.deb，**平台段写 linux-x64**
#   （不是 amd64；同一个 release 里还有 FluxDown-CLI-<v>-linux-x64.tar.gz
#   和 FluxDown-Server-<v>-linux-x64.tar.gz，正则必须锚住 .deb 后缀，
#   否则会挑中 CLI/server 的压缩包）。
#   probe_github 走 /releases/latest，GitHub 会跳过 prerelease，所以
#   rc 预发布（如 v0.5.6-rc.1）不会被误当成最新版——跟「只跟稳定版」
#   的策略一致。
#   tag 形如 v0.5.5；packages/fluxdown.nix 的 version 字面量不带 v 前缀
#   （与 orca / genoffice 一致），所以这里剥掉。
updater_fluxdown() {
  local out tag asset url version
  out=$(probe_github "zerx-lab/FluxDown" '^FluxDown-[0-9][^-]*-linux-x64\.deb$') || return 1
  IFS=$'\t' read -r tag asset <<<"$out"
  version="${tag#v}"
  url="https://github.com/zerx-lab/FluxDown/releases/download/${tag}/${asset}"
  RESULTS+=("fluxdown"$'\t'"${url}"$'\t'"${version}")
}

# any-listen：any-listen/any-listen-desktop，上游只发 release 不发源码，
# 桌面端壳的私有音乐播放服务（Electron，接替 splayer-next）。
#   asset 命名 any-listen_<version>_amd64.deb。**平台段是 amd64**，
#   注意同一个 release 里的 AppImage 写作
#   any-listen_<version>_x86_64.AppImage（x86_64 不是 amd64），
#   正则锚住 _amd64\.deb$ 才能排除掉 AppImage 与 arm64 的 .deb。
#   probe_github 走 /releases/latest，GitHub 会跳过 prerelease，
#   所以 v0.9.0-beta.13 这类预发布不会被误当成最新版。
#   tag 形如 v0.9.0；packages/any-listen.nix 的 version 字面量不带
#   v 前缀（与 orca / fluxdown 一致），所以这里剥掉。
updater_any_listen() {
  local out tag asset url version
  out=$(probe_github "any-listen/any-listen-desktop" '^any-listen_.+_amd64\.deb$') || return 1
  IFS=$'\t' read -r tag asset <<<"$out"
  version="${tag#v}"
  url="https://github.com/any-listen/any-listen-desktop/releases/download/${tag}/${asset}"
  RESULTS+=("any-listen"$'\t'"${url}"$'\t'"${version}")
}

# darkly-gtk：git ref 跟踪 main，URL 不变（github:wrymt/darkly-gtk）。
# version 字面量从 flake.lock 的 lastModified 派生：unstable-YYYY-MM-DD。
updater_darkly_gtk() {
  "${NIX[@]}" flake lock --update-input darkly-gtk >/dev/null
  local ts date
  ts=$(jq -r '.nodes["darkly-gtk"].locked.lastModified // empty' flake.lock)
  [ -n "$ts" ] || { echo "darkly-gtk: flake.lock 无 lastModified" >&2; return 1; }
  date=$(date -u -d "@$ts" +%Y-%m-%d)
  RESULTS+=("darkly-gtk"$'\t'"-"$'\t'"unstable-${date}")
}

# ---- 主流程 ----
declare -A UPDATERS=(
  [kelivo]=updater_kelivo
  [genoffice]=updater_genoffice
  [zedg]=updater_zedg
  [wechat]=updater_wechat
  [bibata-modern-ice]=updater_bibata
  [dwproton]=updater_dwproton
  [darkly-gtk]=updater_darkly_gtk
  [goquark]=updater_goquark
  [prismlauncher-offline-account]=updater_prismlauncher_offline_account
  [orca]=updater_orca
  [voicefox]=updater_voicefox
  [fluxdown]=updater_fluxdown
  [any-listen]=updater_any_listen
)

if [ "$#" -eq 0 ]; then
  TARGETS=(kelivo genoffice zedg wechat bibata-modern-ice dwproton darkly-gtk goquark prismlauncher-offline-account orca fluxdown any-listen)
else
  TARGETS=("$@")
fi

for t in "${TARGETS[@]}"; do
  fn="${UPDATERS[$t]:-}"
  if [ -z "$fn" ]; then
    echo "未知 input: $t" >&2
    echo "支持: ${!UPDATERS[*]}" >&2
    exit 1
  fi
  printf '→ 探测 %-22s ... ' "$t"
  if "$fn"; then
    echo "ok"
  else
    echo "FAILED" >&2
    exit 1
  fi
done

echo ""
echo "探测结果："
for r in "${RESULTS[@]}"; do
  IFS=$'\t' read -r name url ver <<<"$r"
  if [ "$url" = "-" ]; then
    printf '  %-22s  URL 不变   version = %s\n' "$name" "$ver"
  else
    printf '  %-22s  URL = %s\n  %-22s  version = %s\n' "$name" "$url" "" "$ver"
  fi
done

# ---- 应用改动 ----
cp flake.nix flake.nix.bak
declare -a CHANGED_INPUTS=()

for r in "${RESULTS[@]}"; do
  IFS=$'\t' read -r name url ver <<<"$r"
  # 改 flake.nix 的 url 字段（仅当 URL 有变化）。
  # perl 在 s/// 的 replacement 仍会解释 @xxx 为数组，导致 url 里的
  # @scope 被吃空（如 @minimax-ai → /-ai/code/...）。改用环境变量
  # 把 url 传给 perl，perl 端用 $ENV{...} 读取，避免 bash 把 @scope
  # 插值；并用 \Q...\E 在正则部分锁住 url 字面量防 perl regex 元字符。
  if [ "$url" != "-" ]; then
    UPDATE_URL="$url" UPDATE_NAME="$name" perl -0777 -i -pe '
      my $u = $ENV{UPDATE_URL};
      my $n = $ENV{UPDATE_NAME};
      s|(    \Q$n\E = \{\n      url = )"[^\"]*"|$1"$u"|;
    ' flake.nix
    CHANGED_INPUTS+=("$name")
  fi
  # 改对应 .nix 文件的 version 字面量。
  # 每轮先清空 file：case 命中不了的名字必须留空，否则会沿用上一个
  # target 的文件路径，把 version 写进不相干的包。
  file=""
  case "$name" in
    kelivo)            file=packages/kelivo.nix ;;
    genoffice)         file=packages/genoffice.nix ;;
    zedg)              file=packages/zedg.nix ;;
    wechat)            file=packages/wechat.nix ;;
    bibata-modern-ice) file=modules/nixos/desktop/icons.nix ;;
    dwproton)          file=packages/dwproton.nix ;;
    darkly-gtk)        file=modules/nixos/desktop/gtk.nix ;;
    goquark)           file=packages/goquark.nix ;;
    prismlauncher-offline-account)    file=packages/prismlauncher-offline-account.nix ;;
    orca)              file=packages/orca.nix ;;
    voicefox)          file=packages/voicefox.nix ;;
    fluxdown)          file=packages/fluxdown.nix ;;
    any-listen)        file=packages/any-listen.nix ;;
  esac
  if [ -n "${file:-}" ]; then
    perl -i -0pe "s|^(\s*)version = \"[^\"]*\";|\$1version = \"${ver}\";|m" "$file"
  fi
done

# 重新锁（每个有 URL 变动的 input；wechat / darkly-gtk 不需要重新探测 URL，
# 但仍 --update-input 以让 narHash 刷新）
for r in "${RESULTS[@]}"; do
  IFS=$'\t' read -r name url ver <<<"$r"
  printf '→ 重锁 %-22s ... ' "$name"
  if "${NIX[@]}" flake lock --update-input "$name" 2>&1 | tail -n 5; then
    echo "    ok"
  else
    echo "    FAILED" >&2
    mv flake.nix.bak flake.nix
    exit 2
  fi
done

echo ""
echo "完成。备份在 flake.nix.bak，满意后 rm。"
echo "审阅差异：git diff flake.nix packages/ modules/"
