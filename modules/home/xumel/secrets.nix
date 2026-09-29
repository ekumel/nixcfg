# xumel 的本机密钥管理（用户侧）：GitHub token 注入。
#
# token 本体由系统侧 ragenix 在激活时解密到 /run/agenix/github-netrc
# （密文 secrets/github-netrc.age，系统模块见
# modules/nixos/nix-github-auth.nix），这里只把 ~/.config/nix/netrc
# 软链过去——store 里不再出现明文。
#
# 覆盖范围一览：
#   ✓ fetchFromGitHub       → ~/.config/nix/netrc
#   ✓ fetchurl (github.com)  → ~/.config/nix/netrc
#   ✓ nix-prefetch-github    → ~/.config/nix/netrc
#   ✓ scripts/update-third-party.sh 探测 GitHub Releases API → ~/.config/nix/netrc
#   ✓ cargo / pip / go 等    → $GITHUB_TOKEN
#   ✓ nix flake / nix build  → nix.settings.netrc-file（系统侧，同一份文件）
#   ✗ git clone / push       → git 自己读 ~/.gitconfig 与 credential helper，
#                              与本模块无关；如需也认证，配 git credential store
#                              或在 ~/.gitconfig 加 [credential] helper。
#
# 轮换 token：吊销旧 token → 在 secrets/ 里 ragenix -e github-netrc.age
# 写入新值 → nixos-rebuild switch。
{ config, osConfig, ... }:

{
  # mkOutOfStoreSymlink：软链到运行时的解密文件，而不是把内容拷进 store。
  xdg.configFile."nix/netrc".source =
    config.lib.file.mkOutOfStoreSymlink osConfig.age.secrets.github-netrc.path;

  # 让 fish 登录 shell 自动 export GITHUB_TOKEN。
  # 放在 conf.d/ 而不是改 config.fish：fish 自动 source 所有 conf.d/*.fish，
  # 与 programs/fish.nix 解耦，避免两处都在写同一个文件。
  # 从 netrc 解析 password 而非硬编码第二份，避免 token 漂移。
  xdg.configFile."fish/conf.d/github-token.fish".text = ''
    if test -r $HOME/.config/nix/netrc
      # 匹配第一个 "machine github.com" 块下的 password 行。
      set -l token (awk '/^machine github\.com/{flag=1; next} flag && /^password /{print $2; exit}' $HOME/.config/nix/netrc)
      if test -n "$token"
        set -gx GITHUB_TOKEN $token
      end
    end
  '';
}
