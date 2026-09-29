# 系统空间凭据：ragenix（agenix 兼容）在激活时用本机 age 身份把
# secrets/github-netrc.age 解密到 /run/agenix，nix 通过 netrc-file 使用，
# 完成 GitHub 认证（root 的 sudo nixos-rebuild 与普通用户的 nix build 都生效）。
#
# 旧方案是把明文 token 写进 nix.settings.access-tokens，会落到 world-readable
# 的 /etc/nix/nix.conf 与 /nix/store，现已移除。
#
# - 密文/规则：secrets/github-netrc.age、secrets/secrets.nix
# - 解密身份：/home/xumel/.config/age/keys.txt（不进仓库，需自行备份）
# - 用户侧 ~/.config/nix/netrc 软链到同一份解密文件
#   （见 modules/home/xumel/secrets.nix），fish 的 GITHUB_TOKEN 也从中解析。
{ config, inputs, ... }:

{
  imports = [ inputs.ragenix.nixosModules.default ];

  age = {
    # 专用 age 身份：单机场景下比重装即更换的 SSH host key 更易恢复。
    identityPaths = [ "/home/xumel/.config/age/keys.txt" ];

    secrets.github-netrc = {
      file = ../../secrets/github-netrc.age;
      # xumel 要读它来生成用户侧 netrc；root 的 nix 守护进程不受权限位限制。
      owner = "xumel";
      mode = "0400";
    };
  };

  nix.settings.netrc-file = config.age.secrets.github-netrc.path;
}
