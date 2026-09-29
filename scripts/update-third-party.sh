#!/usr/bin/env bash
# update-third-party.sh — 探测第三方上游最新版本、修改 flake.nix 的 url、
# 修改 packages/*.nix 的 version 字面量、`nix flake lock` 重锁。
#
# 用法：
#   ./scripts/update-third-party.sh              # 全部 7 个 input 都更新
#   ./scripts/update-third-party.sh kelivo zedg  # 仅更新指定 input
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
  IFS=$'\t' read -r tag asset <<<"$out"
  version="$tag"
  url="https://github.com/ButterFuture/GoQuark/releases/download/${tag}/${asset}"
  RESULTS+=("goquark"$'\t'"${url}"$'\t'"${version}")
}

# baidunetdisk：上游 https://pan.baidu.com/download 是 SPA，HTML 模板里
# 没有版本字符串；issuecdn.baidupcs.com 也没有 directory listing。
# 因此未提供自动探测：手动到下载页查版本，按
# `LinuxGuanjia/<version>/baidunetdisk_<version>_amd64.deb` 模式构造 URL，
# 改 flake.nix 的 baidunetdisk url + packages/baidunetdisk.nix 的 version
# 字面量后跑 `nix flake lock --update-input baidunetdisk`。

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
)

if [ "$#" -eq 0 ]; then
  TARGETS=(kelivo genoffice zedg wechat bibata-modern-ice dwproton darkly-gtk goquark)
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
  # 改 flake.nix 的 url 字段（仅当 URL 有变化）
  if [ "$url" != "-" ]; then
    perl -0777 -i -pe "s|(    ${name} = \{\n      url = )\"[^\"]*\"|\$1\"${url}\"|" \
      flake.nix
    CHANGED_INPUTS+=("$name")
  fi
  # 改对应 .nix 文件的 version 字面量
  case "$name" in
    kelivo)            file=packages/kelivo.nix ;;
    genoffice)         file=packages/genoffice.nix ;;
    zedg)              file=packages/zedg.nix ;;
    wechat)            file=packages/wechat.nix ;;
    bibata-modern-ice) file=modules/nixos/desktop/icons.nix ;;
    dwproton)          file=packages/dwproton.nix ;;
    darkly-gtk)        file=modules/nixos/desktop/gtk.nix ;;
    goquark)           file=packages/goquark.nix ;;
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
