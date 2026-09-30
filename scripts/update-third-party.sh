#!/usr/bin/env bash
# update-third-party.sh — 探测第三方上游最新版本、修改 flake.nix 的 url、
# 修改 packages/*.nix 的 version 字面量、`nix flake lock` 重锁。
#
# 用法：
#   ./scripts/update-third-party.sh              # 全部 9 个 input 都更新
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

# kokovp：上游不发 release，但有 git tag（v1.0.0 / v1.1.0 / v1.2.0 / v1.2.1
# 等）。我们直接从 GitHub tags API 拿最新 tag，按
# `https://github.com/brainrom/kokovp/archive/refs/tags/<tag>.tar.gz` 拼 URL。
updater_kokovp() {
  local tags tag version url
  tags=$(curl "${CURL_BASE[@]}" \
    "https://api.github.com/repos/brainrom/kokovp/tags?per_page=1")
  [ -n "$tags" ] || { echo "GitHub tags API 返回空" >&2; return 1; }
  tag=$(printf '%s' "$tags" | jq -r '.[0].name // empty')
  [ -n "$tag" ] || { echo "GitHub tags API 无 name" >&2; return 1; }
  version="$tag"
  url="https://github.com/brainrom/kokovp/archive/refs/tags/${tag}.tar.gz"
  RESULTS+=("kokovp"$'\t'"${url}"$'\t'"${version}")
}

# baidunetdisk：上游 https://pan.baidu.com/download 是 SPA，HTML 模板里
# 没有版本字符串；issuecdn.baidupcs.com 也没有 directory listing。
# 因此未提供自动探测：手动到下载页查版本，按
# `LinuxGuanjia/<version>/baidunetdisk_<version>_amd64.deb` 模式构造 URL，
# 改 flake.nix 的 baidunetdisk url + packages/baidunetdisk.nix 的 version
# 字面量后跑 `nix flake lock --update-input baidunetdisk`。

# mcode：npm registry API（不是 GitHub Releases）。
#   - dist-tags.latest 拿最新 semver 版本号（无 v 前缀）；
#   - versions[<ver>].dist.tarball 拿 tarball URL；
#   - npm tarball 不带 package-lock.json，buildNpmPackage 的
#     prefetch-npm-deps 会找不到锁文件；本 updater 会同时跑
#     `npm install --package-lock-only` 重生 packages/mcode-package-lock.json，
#     再用 prefetch-npm-deps + `nix hash path` 算出 npmDepsHash，
#     直接 perl 写回 packages/mcode.nix。
# 依赖 host 上有 nix-shell（提取 npm / prefetch-npm-deps）。
# 把以上额外动作括在一个函数里：主流程照样处理 flake.nix url
# 字段与 packages/mcode.nix version 字面量（idempotent），然后
# 我们在主流程跑完后重新锁 mcode 即可。
updater_mcode() {
  local pkg_json version tarball_url npm_deps_hash tmp pkg_root

  # npm registry 偶尔 Empty reply / SSL EOF（见 curl error 52 / 56），
  # 这里给探测 API 与拉 tarball 各加 retry 3 次（指数退避 1/2/4s）。
  # 这是把 npm 抓 npm registry 的常见 transient，与下方 prefetch 同源。
  local attempt
  for attempt in 1 2 3; do
    pkg_json=$(curl "${CURL_BASE[@]}" "https://registry.npmjs.org/@minimax-ai/code") && [ -n "$pkg_json" ] && break
    echo "mcode: npm registry API 探测失败（重试 $attempt/3）" >&2
    sleep $((attempt * 1))
  done
  [ -n "$pkg_json" ] || { echo "npm registry 返回空" >&2; return 1; }
  version=$(printf '%s' "$pkg_json" | jq -r '.["dist-tags"].latest // empty')
  [ -n "$version" ] || { echo "npm registry 无 dist-tags.latest" >&2; return 1; }
  tarball_url=$(printf '%s' "$pkg_json" | jq -r ".versions.\"${version}\".dist.tarball // empty")
  [ -n "$tarball_url" ] || { echo "npm registry 无 tarball for ${version}" >&2; return 1; }

  tmp=$(mktemp -d)
  pkg_root="$tmp/package"
  # 拉 tarball + 解压。npm tarball 解出来根目录是 package/。
  for attempt in 1 2 3; do
    if curl -fsSL -o "$tmp/mcode.tgz" "$tarball_url"; then
      break
    fi
    echo "mcode: 下载 tarball 失败（重试 $attempt/3）: $tarball_url" >&2
    sleep $((attempt * 1))
  done
  if [ ! -s "$tmp/mcode.tgz" ]; then
    echo "下载 npm tarball 失败: $tarball_url" >&2
    rm -rf "$tmp"; return 1
  fi
  if ! tar -xzf "$tmp/mcode.tgz" -C "$tmp"; then
    echo "解 tarball 失败" >&2
    rm -rf "$tmp"; return 1
  fi

  # 生成新 lockfile 并覆盖仓库里的 vendored 版本。
  # --omit=dev / --ignore-scripts / --registry=public 与 packages/mcode.nix
  # 的 buildNpmPackage 设置一致，避免 lockfile 锁住 devDependencies
  # 或被 .npmrc 引入私有 registry 包。
  # nix-shell --run 不接受位置参数（-- 后的所有东西都不是 command 的），
  # 必须用 env var 传 pkg_root。
  export PKG_ROOT="$pkg_root"
  if ! nix-shell -p nodejs_24 --run '
    set -e
    cd "$PKG_ROOT"
    npm install --package-lock-only --omit=dev --ignore-scripts \
      --registry=https://registry.npmjs.org/ >/dev/null
  ' >/dev/null 2>&1; then
    echo "npm install --package-lock-only 失败（网络问题？试试重跑）" >&2
    rm -rf "$tmp"; return 1
  fi
  cp "$pkg_root/package-lock.json" "$SCRIPT_DIR/../packages/mcode-package-lock.json"

  # prefetch-npm-deps 抓所有 deps 到 outdir，nix hash path 算 hash
  # （与 buildNpmPackage 内部 prefetch-npm-deps 走同一份货）。
  # prefetch 也走 npm registry；同样 retry。同样用 env var 传参。
  # 关键：retry 前先清空 deps_out，否则上次失败的 cacache 残留导致
  # prefetch 自带 retry 跳过去，hash 与 buildNpmPackage 期望的不一致。
  local deps_out="$tmp/deps"
  export LOCKFILE="$pkg_root/package-lock.json"
  export DEPS_OUT="$deps_out"
  for attempt in 1 2 3; do
    rm -rf "$deps_out"
    if nix-shell -p prefetch-npm-deps --run '
      prefetch-npm-deps "$LOCKFILE" "$DEPS_OUT"
    ' >/dev/null 2>&1; then
      break
    fi
    echo "mcode: prefetch-npm-deps 失败（重试 $attempt/3）" >&2
    sleep $((attempt * 1))
  done
  if [ ! -d "$deps_out/_cacache" ]; then
    echo "prefetch-npm-deps 失败（某个 npm 镜像拉不到？重试）" >&2
    rm -rf "$tmp"; return 1
  fi
  # nix hash path 需要 cd 到 / 否则 path 解析问题。
  npm_deps_hash=$(cd / && "${NIX[@]}" hash path --type sha256 --base64 "$deps_out")
  rm -rf "$tmp"
  [ -n "$npm_deps_hash" ] || { echo "nix hash path 返回空" >&2; return 1; }

  # 把 npmDepsHash 写回 packages/mcode.nix（perl 锁定第一个匹配替换）。
  # 这里的 placeholder 是字面量 `npmDepsHash = "<old>"`；为了不依赖
  # 旧值，用 perl -0777 锁定到第一个匹配进行替换（一个 file 里只有一个）。
  perl -0777 -i -pe "s|(npmDepsHash = \")[^\"]*(\")|\$1sha256-${npm_deps_hash}\$2|" \
    "$SCRIPT_DIR/../packages/mcode.nix"

  RESULTS+=("mcode"$'\t'"${tarball_url}"$'\t'"${version}")
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
  [kokovp]=updater_kokovp
  [mcode]=updater_mcode
)

if [ "$#" -eq 0 ]; then
  TARGETS=(kelivo genoffice zedg wechat bibata-modern-ice dwproton darkly-gtk goquark prismlauncher-offline-account kokovp mcode)
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
    prismlauncher-offline-account)    file=packages/prismlauncher-offline-account.nix ;;
    kokovp)                   file=packages/kokovp.nix ;;
    mcode)             file=packages/mcode.nix ;;
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
