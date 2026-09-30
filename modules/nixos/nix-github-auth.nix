# 把 github-netrc 解密结果接到 nix 的 netrc-file 配置上，
# 完成 GitHub 认证（root 的 sudo nixos-rebuild 与普通用户的 nix build 都生效）。
#
# 旧方案是把明文 token 写进 nix.settings.access-tokens，会落到 world-readable
# 的 /etc/nix/nix.conf 与 /nix/store，现已移除。
#
# - 密文/规则：secrets/github-netrc.age、secrets/secrets.nix
# - ragenix 基础设施 + 用户侧凭据声明：modules/nixos/user-secrets.nix
# - 解密身份：/home/xumel/.config/age/keys.txt（不进仓库，需自行备份）
# - 用户侧 ~/.config/nix/netrc 软链到同一份解密文件
#   （见 modules/home/xumel/secrets.nix），fish 的 GITHUB_TOKEN 也从中解析。
{ config, ... }:

{
  nix.settings.netrc-file = config.age.secrets.github-netrc.path;
}
