# mcode：MiniMax-AI/minimax-code — 开源终端编码代理 CLI，
# 由 MiniMax 模型（或自带 API key）驱动，可用于构建 / 测试 / 迭代项目。
#
# 上游同时提供源码仓库 https://github.com/MiniMax-AI/minimax-code 和
# npm 发布的 CLI 包 `@minimax-ai/code`，后者已经预打包了 cli.js /
# mcode-tools.js 与运行时 assets（即 examples/pocket-pet 演示工程里的
# skills / agents 等目录），从源码构建需要 pnpm install 整个 monorepo
# 100+ MB 的源码、跑 esbuild 打包，代价远超直接消费 release。
#
# 官方文档（README + https://agent.minimaxi.io/docs/cli/quick-start）把
# `npm install -g @minimax-ai/code@latest` 列为 macOS / Linux 的一等
# 安装方式，install.sh / install.ps1 也是从 npm registry 拉同一个 tarball
# 放进 ~/.minimax-code/bin/。所以这里直接走 npm registry，
# 用 nixpkgs 的 `buildNpmPackage` 重现 `npm install --omit=dev` 的
# 语义，得到纯生产依赖的 CLI。
#
# 版本与 src 由 flake input 提供（flake.nix 的 mcode URL input，
# flake = false）。version 钉为字面量；升级流程：
#   1. 跑 `./scripts/update-third-party.sh mcode`：脚本探测 npm
#      registry API、取最新 dist-tag、按 tarball URL 模板生成 URL、
#      改 flake.nix 的 url 字段、`nix flake lock --update-input mcode`；
#   2. 同步更新下方 version 字面量；
#   3. `nix flake check` 与 `nixos-rebuild switch` 验证。
#
# npmDepsHash 同样由 update 脚本自动算：脚本会跑
# `npm install --package-lock-only` 重新生成 packages/mcode-package-lock.json，
# 再用 `prefetch-npm-deps` + `nix hash path` 算出 hash 写回此处。
# 用户不需要手动碰任何 hash——`nix hash mismatch` 也不会再出现。
#
# better-sqlite3 是 optionalDependencies 里的 native 模块（mcode 用它
# 存 sessions / cron / canvas 等本地状态，参见 packages/local-runtime-v2/
# src/infra/db/），npm install 时会触发 node-gyp 编译，因此 buildInputs
# 需要 python3 + gcc + make，buildNpmPackage 通过 setup-hook 自动拉
# pkgs.stdenv.cc + pkgs.pkg-config，无需手动列。
{
  pkgs,
  flake,
}:

pkgs.buildNpmPackage (finalAttrs: {
  pname = "mcode";
  version = "0.5.9";

  src = flake.inputs.mcode;

  # 上游 npm tarball 不带 package-lock.json，buildNpmPackage 的
  # prefetch-npm-deps 会因找不到锁文件而退出（hash 不固定 → 不可
  # 重现）。补一份 vendored lockfile：这份 lockfile 是升级时在 host 上
  # 跑 `npm install --package-lock-only --omit=dev --registry=…`
  # 生成的，被提交到仓库跟踪。详见 packages/mcode.nix 顶部注释。
  postPatch = ''
    cp ${./mcode-package-lock.json} package-lock.json
  '';

  # npm ci --omit=dev 后 node_modules 整体 sha256。
  # 计算流程见文件顶部注释；填错首次构建会报错并打印正确 hash。
  npmDepsHash = "sha256-ktC4w3YvGCBvNEVvct+B1GSahJOKoomk2h8uLbFmhS4=";

  # better-sqlite3 是 optionalDependencies 里的 native 模块（mcode 用它
  # 存 sessions / cron / canvas 等本地状态，参见 packages/local-runtime-v2/
  # src/infra/db/），npm install 时会触发 node-gyp 编译，因此 buildInputs
  # 需要 python3 + gcc + make，buildNpmPackage 通过 setup-hook 自动拉
  # pkgs.stdenv.cc 与 pkgs.pkg-config，无需手动列。
  buildInputs = [ pkgs.python3 ];

  # npm 注册表 URL；非必要 buildNpmPackage 默认就是 public registry，
  # 但 README 推荐 `--registry=https://registry.npmjs.org/`，这里显式
  # 钉死，避免受用户 ~/.npmrc 影响。
  npmRegistry = "https://registry.npmjs.org/";

  # 保留 optionalDependencies 的 native 模块（better-sqlite3），不要
  # 因为「看似可选」就 prune 掉——mcode 强依赖 sqlite。
  npmFlags = [ "--include=optional" "--ignore-scripts=false" ];

  dontNpmPruneBuild = false;

  # mcode 的 npm 包没有「build」脚本——cli.js / mcode-tools.js 是
  # 上游 release 时已经预打包好的产物（assets / embedded / chunks
  # 也都齐全），npm install 之后直接可用。所以关掉 buildNpmPackage
  # 默认要跑的 `npm run build`。
  dontNpmBuild = true;

  # 安装到 $out/：npmInstallHook 把整个 src 拷到
# $out/lib/node_modules/@minimax-ai/code/，nodejsInstallExecutables
# 按 package.json 的 "bin" 字段自动生成 $out/bin/mcode 与
# $out/bin/mcode-tools（wrapper → node cli.js / mcode-tools.js），
# nodejsInstallManuals 把 README.md / CHANGELOG.md 等装到 share/man/。
# 所以这里不需要自定义 installPhase。

  # README 提示 BYOK 与登录后的 sessions 写到 ~/.minimax 或
  # ~/.minimax-<profile>（packages/config/src/data-dir.ts），由运行时
  # 自然产生，不需要在 derivation 里预置。

  # upstream 没声明 SPDX；package.json 写 "MIT" 但 THIRD_PARTY_NOTICES.md
  # 把整树（包含 transitive deps）的许可证列表单独维护。按 README
  # LICENSE-STATUS.md 的「First-party default license: MIT」声明标 mit。
  meta = {
    description = "Standalone MiniMax Code TUI with managed accounts, BYOK models, cloud tools, plugins, and ACP";
    homepage = "https://github.com/MiniMax-AI/minimax-code";
    license = pkgs.lib.licenses.mit;
    mainProgram = "mcode";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})