# 浏览器：Firefox Nightly（官方 nightly）注入了 zh-CN 语言文件，提供中文界面。
{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # ---- Firefox Nightly 的中文界面 ----
  #
  # 目标：保留 firefox-nightly 159.0a1，同时拿到中文界面。
  #
  # **为什么不能直接换个中文 tarball**：Mozilla 不发布本地化的 Linux nightly
  # tarball。其本地化产物只有三个目录——deb-l10n/、rpm/、xpi/，位于
  # archive.mozilla.org/pub/firefox/nightly/latest-mozilla-central-l10n/linux-x86_64/
  # 里面没有 tar.xz；实测
  #   …/latest-mozilla-central/linux-x86_64/zh-CN/  → HTTP 404
  # 而 DevEdition / Beta / Release 的同一个 URL 都返回 200。Nightly 是唯一
  # 没有官方中文构建的频道，所以换任何 nightly flake 都一样。
  #
  # **为什么不能用 langpack**：AMO 确实为 Nightly 渠道提供 zh-CN 语言包，而且
  # 版本号对得上（浏览器 159.0a1 ↔ langpack 159.0.2026xxxx），但它的 manifest 写的是
  #   strict_min_version = "159.0"   strict_max_version = "159.*"
  # 而 159.0a1 是 alpha，排在 159.0 **之前**，于是 Firefox 判定不兼容：
  #   extensions.json → appDisabled: true
  # 实测把 strict_min_version 改成 159.0a1 确实能让 appDisabled 翻成 false，但
  # xpi 签名随即失效（signedState: -2 → userDisabled: true），连
  # extensions.langpacks.signatures.required=false 也救不回来。两条路都是死胡同，
  # 而且这是 Mozilla 上游的问题，跟本机配置无关。
  #
  # **本方案**：绕开 addon 机制，把语言文件直接烤进 omni.ja。这正是官方本地化
  # 构建的做法——实测官方 zh-CN 包里根本没有 locale/ 目录，中文串是躺在
  # omni.ja / browser/omni.ja 里的 `locale/zh-CN/**`。所以我们照搬这个布局，
  # 就不再经过任何版本兼容或签名校验。
  ffNightlyBin =
    inputs.firefox-nightly.packages.${pkgs.stdenv.hostPlatform.system}.firefox-nightly-bin;

  # 159 的官方 zh-CN 语言包。version 与浏览器主版本对齐，nightly 跨大版本
  # （159 → 160）时需要换一次，URL 见下面的 update 注释。
  #
  #   curl -sSL -o lp.xpi \
  #     "https://addons.mozilla.org/firefox/downloads/file/5112764/chinese_simplified_zh_cn_la-159.0.20261012.90602.xpi"
  #   nix hash file --sri lp.xpi
  #   # 再用 curl -sI 在 AMO 上确认该文件对应当前 nightly 主版本
  ffNightlyLangpack = pkgs.fetchurl {
    url = "https://addons.mozilla.org/firefox/downloads/file/5112764/chinese_simplified_zh_cn_la-159.0.20261012.90602.xpi";
    hash = "sha256-JkqdjoJ3d4qyYOgySkjWSEW5Zofsjw9uTkyms0WdWgw=";
  };

  firefoxNightlyZh =
    pkgs.wrapFirefox
      (ffNightlyBin.passthru.unwrapped.overrideAttrs (oldAttrs: {
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
          pkgs.unzip
          pkgs.zip
        ];

        # 追加到 **installPhase** 而不是 postInstall：这个包的构建日志里
        # postInstall 阶段压根不执行（installPhase → gappsWrapperArgsHook →
        # dropIconThemeCache → fixupPhase，中间没有它），写进 postInstall 会
        # 静默不生效——构建照样成功退出码 0，产物里就是没东西。
        installPhase = (oldAttrs.installPhase or "") + ''
          # 整段塞进子 shell：stdenv 的各 phase 共用同一个 shell，installPhase
          # 里开的 set -u 会漏给后面的 fixupPhase，而 make-binary-wrapper-hook
          # 里用了尚未赋值的 $main，于是构建在 fixup 阶段炸掉（报
          # "main: unbound variable" + "ISO C forbids an empty translation
          # unit"）。退出码非 0，不会静默，但报错完全指不到真正的原因。
          (
          set -euo pipefail
          localeRoot="$out/lib/${ffNightlyBin.passthru.unwrapped.libName}"
          work="$(mktemp -d)"

          unzip -q ${ffNightlyLangpack} -d "$work/lp"

          # langpack 的内部路径与 app omni.ja 里应该放的路径 **几乎逐字一致**
          # （对照官方 zh-CN 构建的 omni.ja 实测，不是猜的）：
          #
          #   根 omni.ja:
          #     localization/zh-CN/toolkit/global/*.ftl        ← 原样
          #     localization/zh-CN/netwerk/necko.ftl           ← 原样
          #     chrome/zh-CN/locale/zh-CN/global/*.properties  ← 原样
          #   browser/omni.ja:
          #     localization/zh-CN/browser/browser.ftl          ← 剥掉 langpack 的 browser/ 基准前缀
          #     chrome/zh-CN/locale/branding/*                 ← 同上
          #
          # 根因是 langpack 的 sources.browser.base_path = "browser/"，即 browser
          # 源以 xpi 根下 browser/ 为基准；app 里没有这层基准。
          #
          # 踩过的坑：先前把 chrome/zh-CN/locale/zh-CN/<X>/ 也改写成
          # locale/zh-CN/<X>/，看着像「摊平」，实际是错的——那是 app 内部的
          # 另一套命名，与 omni.ja 里的真实路径不符。Firefox 直接报
          # "The installation seems to be incomplete" 然后崩溃（omni.ja 连
          # unzip -t 都是好的，纯属路径问题）。
          #
          # 下面刻意只用 $var 和子命令，不写 shell 的参数展开剥前缀形式：那种写法在
          # Nix 缩进字符串里会被当成插值开头，拼出非法记号（实测报 syntax
          # error）。改用 sed 剥前缀。
          stage() { # $1=阶段名 $2=目标相对路径 $3=源文件
            mkdir -p "$work/$1/$(dirname "$2")"
            cp "$3" "$work/$1/$2"
          }

          # ---- 1. 先把原始 omni.ja 整个解开，作为重建的基础 ----
          #
          # **必须解包重建，不能往原归档里追加或替换条目**。实测三组对照：
          #   追加新条目（zip -r archive localization chrome）  → Firefox 正常
          #   替换既有条目（default.locale / multilocale.txt）  → Firefox 崩溃
          #   整包重建（本段做法）                             → 正常，中文界面 ✓
          # 崩溃时报的是 "The installation seems to be incomplete"，而 unzip -t 说
          # 归档完好——因为 Mozilla 的 omni.ja 是 2683 条**全 STORED**（未压缩、
          # 51MB）的归档，zip 改写既有条目后的结构 Gecko 的 zip reader 不接受。
          #
          # unzip 对这个归档会打 "bytes too long ... Compensating" 警告，但条目
          # 其实是全的（2683 进 / 2683 出），所以显式忽略退出码，另用哨兵文件校验。
          mkdir -p "$work/root" "$work/browser"
          unzip -q -o "$localeRoot/omni.ja" -d "$work/root" 2>/dev/null || true
          unzip -q -o "$localeRoot/browser/omni.ja" -d "$work/browser" 2>/dev/null || true
          if [ ! -f "$work/root/greprefs.js" ]; then
            echo "firefox-nightly: omni.ja 解包不完整，跳过注入（保持原样可用）"
            exit 0
          fi

          # ---- 2. 灌入 zh-CN（路径与官方构建逐字一致，见上）----
          cd "$work/lp"
          find localization/zh-CN chrome/zh-CN -type f 2>/dev/null \
            | while read -r f; do stage root "$f" "$f"; done

          find browser/localization/zh-CN browser/chrome/zh-CN -type f 2>/dev/null \
            | while read -r f; do
                rel=$(printf '%s' "$f" | sed 's|^browser/||')
                stage browser "$rel" "$f"
              done

          # ---- 3. 改写「本包默认语言」声明 ----
          printf 'zh-CN' > "$work/root/default.locale"
          mkdir -p "$work/root/res"
          printf 'zh-CN,en-US' > "$work/root/res/multilocale.txt"

          echo "firefox-nightly: zh-CN —— 根 $(find "$work/root/localization/zh-CN" -type f 2>/dev/null | wc -l) / browser $(find "$work/browser/localization/zh-CN" -type f 2>/dev/null | wc -l) 个"

          # ---- 4. 整包重建再换回去 ----
          cd /
          for target in omni.ja browser/omni.ja; do
            stageName=root
            if [ "$target" = "browser/omni.ja" ]; then stageName=browser; fi
            src="$localeRoot/$target"
            [ -d "$work/$stageName" ] || continue

            base=$(basename "$target" .ja)
            archive="$work/$base.rebuilt.ja"
            ( cd "$work/$stageName" && zip -q -X -r "$archive" . )
            rm -f "$src"
            cp "$archive" "$src"
          done

          rm -rf "$work"
          )
        '';
      }))
      {
        extraPolicies = {
          # unwrapped 原本带的 DisableAppUpdate 必须补回来：wrapFirefox 会重新生成
          # policies.json（wrapper.nix 里先 rm -f 旧文件再写新的），不显式给的话
          # 这个策略会丢，Nightly 就会自己给自己打更新。
          #
          # 这里只放这一个策略，**不锁任何 pref**——界面语言改由系统 LANG
          # （zh_CN.UTF-8）推导，用户随时可以在 about:config 里改。
          DisableAppUpdate = true;
        };
      };
in
{
  home.packages = [
    # Firefox Nightly（官方上游，Mozilla 每晚发布），经上面的
    # firefoxNightlyZh 注入了 159 的官方 zh-CN 语言文件。
    #
    # 不用 pkgs.firefox / pkgs.firefox-nightly：前者是 nixpkgs 里的稳定版（已卸载），
    # 后者**在当前 nixpkgs 里已经不存在**（`pkgs.firefox-nightly` 求值报
    # attribute missing，2026-10 实测）。flake-firefox-nightly 由 CI 每小时重跑一次
    # flake.lock，钉住的才是「昨晚的 nightly」。
    #
    # 提供 bin/firefox-nightly + firefox-nightly.desktop。
    firefoxNightlyZh
  ];
}
