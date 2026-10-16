# 仓库开发环境：blueprint 把本文件暴露为 devShells.<system>.default，
# 因此 `nix develop` 即可进入。direnv 用户配了 nix-direnv 的话会自动加载。
#
# 这个 devshell 解决两件事：
#   1. 提供格式化 / 静态检查工具，让 `nix fmt` + lint 不依赖宿主机环境；
#   2. 提供 scripts/update-third-party.sh 需要的全部外部命令——这个脚本
#      此前只能在装了 jq / npm / prefetch-npm-deps 的宿主机上跑，现在
#      在本仓库内闭环。
{
  pkgs,
  ...
}:

let
  # 语言服务器：与本仓库编辑器侧保持一致——helix 与 nixvim 都用 nil
  # （见 modules/home/xumel/programs/helix.nix），Zed 侧另装了 nil+nixd
  # 见 lib/zed-lsp.nix。开发 shell 里给 nil 即可。
  lsp = [ pkgs.nil ];

  # 格式化 + 静态检查。nixfmt 必须与 formatter.nix 里的版本一致，
  # 否则 `nix fmt` 与 `nix develop` 内的 nixfmt 会给出不同结果。
  #   statix  —— nixpkgs 的 linter（未用绑定、错误 API 调用等）
  #   deadnix —— 死代码检测（未使用的 let 绑定 / 参数）
  formatAndLint = [
    pkgs.nixfmt
    pkgs.statix
    pkgs.deadnix
  ];

  # scripts/update-third-party.sh 的外部命令依赖。逐个对应脚本里的实际调用：
  #   bash / curl / git / jq / tar   —— 探测 API、改写文件、git 备份回滚
  #   prefetch-npm-deps              —— 当前脚本已不再用（mcode / pi-agent 已下线，
  #                                     npm CLI 包改走 numtide/llm-agents.nix 上游打包）；
  #                                     保留只是为了以后再写 npm updater 时不用改 shellHook
  #   nodejs_22                      —— 同上，当前无消费者
  scriptDeps = [
    pkgs.bash
    pkgs.curl
    pkgs.git
    pkgs.jq
    pkgs.prefetch-npm-deps
    pkgs.nodejs_22
    pkgs.gnutar
  ];
in
pkgs.mkShell {
  name = "nixos-config-devshell";

  packages = lsp ++ formatAndLint ++ scriptDeps;

  shellHook = ''
    echo "nixos 配置开发环境已就绪"
    echo "  nix fmt                     格式化（等价于 devshell 内的 nixfmt）"
    echo "  statix check .              静态检查"
    echo "  deadnix --edit              清理未使用的 let 绑定"
    echo "  nix flake check             求值全部 output（--no-build 更快）"
    echo "  ./scripts/update-third-party.sh [包名...]   升级第三方源"
  '';
}
