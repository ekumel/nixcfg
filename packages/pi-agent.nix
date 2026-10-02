# pi-agent：@earendil-works/pi-coding-agent — Mario Zechner（mitsuhiko 也在
# maintainers 名单里）的开源 coding agent CLI。仓库在 pi-mono monorepo
# （https://github.com/badlogic/pi-mono），npm 包是预打包好的发布产物
# （bin: pi → dist/bundle/cli.js，dist/ 由上游 `npm run prepublishOnly`
# 跑 tsc + esbuild 生成），不需要源码构建。
#
# 上游同时维护 SDK / TUI / agent-core / codemode / mcp 等若干子包，
# 全部以 `@earendil-works/*` scope 发布到 npm registry，运行时由本
# 包的 dist/bundle/cli.js 通过 npm 解析到 node_modules/。本 derivation
# 直接消费 npm tarball，跟 mcode 同款路线：
#
#   1. flake input 提供 tarball URL（带版本号字面量）；
#   2. buildNpmPackage 解 tarball → cp 生成 package-lock.json（带
#      integrity hashes）→ prefetch-npm-deps 抓 deps cacache；
#   3. 不要 npm run build（dist/ 已经存在）；
#   4. bin 字段自动装出 $out/bin/pi。
#
# 为什么不直接吃 tarball 自带的 npm-shrinkwrap.json：npm 11+ 生成的
# shrinkwrap 在 workspace 风格里会省略 `@earendil-works/*` 子包的
# `integrity` 字段（这些子包对 npm registry 来说是 resolved 但
# 上游选择不写 hash），prefetch-npm-deps 看到没 integrity 就报
# "non-git dependencies should have associated integrity"。所以跟
# mcode 一样：在 tarball 根目录跑一次 `npm install --package-lock-only
# --omit=dev --ignore-scripts`，让 npm 把每个 dep 的 integrity 写进
# package-lock.json，再给 prefetch 用。这份 lockfile 由 update 脚本
# 重新生成并 commit。
#
# 依赖栈：21 个直接依赖（@earendil-works/* 6 个 + @silvia-odwyer/
# photon-node WASM image lib + 14 个普通包），全部从 npm registry 拉，
# 没有 git URL / 本地 link / native gyp 模块。photon-node 的
# photon_rs_bg.wasm 由上游 `copy-binary-assets` 脚本在 publish 前拷到
# dist/，我们这边已经预打包好。
#
# 升级跑 `./scripts/update-third-party.sh pi-agent`：脚本探测 npm
# registry dist-tags.latest、取 tarball URL、改 flake.nix 的 url 字段、
# 重生 packages/pi-agent-package-lock.json、用 prefetch-npm-deps + nix
# hash path 算 npmDepsHash 写回此处。
{
  pkgs,
  flake,
}:

pkgs.buildNpmPackage (finalAttrs: {
  pname = "pi-agent";
  version = "0.99.1";

  src = flake.inputs.pi-agent;

  # 上游 npm tarball 自带 npm-shrinkwrap.json 但缺 integrity（见文件
  # 顶部注释），buildNpmPackage 的 prefetch-npm-deps 看到
  # shrinkwrap 存在会优先用它、然后报 "non-git dependencies should
  # have associated integrity"。所以两个动作都要做：
  #   1. rm 掉上游的 shrinkwrap，让 buildNpmPackage 退回读 package-lock.json；
  #   2. cp 一份 vendored lockfile 进去（升级脚本重生，详见文件顶部）。
  # 不能只 cp 不 rm——buildNpmPackage 的 hook 顺序是先看 shrinkwrap，
  # 看到就跳过 package-lock.json。
  postPatch = ''
    rm -f npm-shrinkwrap.json
    cp ${./pi-agent-package-lock.json} package-lock.json
  '';

  # npm ci --omit=dev 后 node_modules cacache 的 sha256。
  # 升级脚本会跑 `nix-shell -p prefetch-npm-deps` + `nix hash path`
  # 算出 base64 写回此处。
  npmDepsHash = "sha256-odEi/e05Sz82lSGSh8LS+QpKCODycuXjO/fvnSIkgRk=";

  # pi 的 npm 包没有「build」脚本——dist/bundle/cli.js 是上游 release
  # 时已经预打包好的产物（含 photon-node WASM、theme、assets 等都
  # 通过 copy-binary-assets 拷好了），npm install 之后直接可用。
  # 关掉 buildNpmPackage 默认要跑的 `npm run build`。
  dontNpmBuild = true;

  # npm 注册表 URL；buildNpmPackage 默认就是 public registry，但
  # README 推荐 `--registry=https://registry.npmjs.org/`，显式钉死
  # 避免受用户 ~/.npmrc 影响。
  npmRegistry = "https://registry.npmjs.org/";

  # 安装到 $out/：npmInstallHook 把整个 src 拷到
  # $out/lib/node_modules/@earendil-works/pi-coding-agent/，
  # nodejsInstallExecutables 按 package.json 的 "bin" 字段自动生成
  # $out/bin/pi（wrapper → node dist/bundle/cli.js）。
  # 所以这里不需要自定义 installPhase。

  # pi 不需要 ~/.pi/agent/ 之外的运行时目录；BYOK 的 api key、sessions、
  # models-store.json 都写到那里（见 modules/home/xumel/programs/
  # pi-agent.nix）。不需要在 derivation 里预置。

  # 上游 package.json 声明 "license": "MIT"，仓库也是 MIT。
  meta = {
    description = "Coding agent CLI with read, bash, edit, write tools and session management";
    homepage = "https://github.com/badlogic/pi-mono";
    license = pkgs.lib.licenses.mit;
    mainProgram = "pi";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})
