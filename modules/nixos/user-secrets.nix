# xumel 的用户侧凭据（system 侧 ragenix 声明）。
#
# 把 secrets/*.age 解密到 /run/agenix，对应 home-manager 端从这里
# 通过 `osConfig.age.secrets.<name>.path` 软链到 ~/.config/<...> 或
# ~/.pi/agent/<...>。密文/规则：secrets/<name>.age、secrets/secrets.nix；
# 解密身份：/home/xumel/.config/age/keys.txt（不进仓库，需自行离线备份）。
#
# - github-netrc     → /run/agenix/github-netrc   （nix + 用户双消费）
#                       modules/home/xumel/secrets.nix 软链到 ~/.config/nix/netrc
#                       modules/nixos/nix-github-auth.nix 写到 nix.settings.netrc-file
# - pi-agent-auth    → /run/agenix/pi-agent-auth  （仅用户消费）
#                       modules/home/xumel/programs/pi-agent.nix 软链到
#                       ~/.pi/agent/auth.json
#
# 首次部署新密文：在 secrets/ 目录里跑
#   ragenix -i ~/.config/age/keys.txt -e <name>.age
# 把内容粘进去、commit 即可。
{ inputs, ... }:

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

    secrets.pi-agent-auth = {
      file = ../../secrets/pi-agent-auth.age;
      owner = "xumel";
      mode = "0400";
    };
  };
}
