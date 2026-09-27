# 仓库格式化入口：blueprint 把本文件暴露为 flake.formatter.<system>，
# 因此 `nix fmt` 即调用它。nixfmt 不处理目录，故用 git 遍历仓库内 *.nix；
# 无参数时默认格式化整个仓库。
{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "nix-fmt";

  runtimeInputs = [
    pkgs.nixfmt
    pkgs.git
  ];

  text = ''
    set -euo pipefail

    if [[ $# = 0 ]]; then
      prj_root=$(git rev-parse --show-toplevel 2>/dev/null || echo .)
      set -- "$prj_root"
    fi

    git ls-files -z -- "$@" \
      | grep -z '\.nix$' \
      | xargs -0 --no-run-if-empty nixfmt
  '';

  meta.description = "format the project with nixfmt";
}
