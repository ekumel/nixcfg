# xumel 的用户侧凭据（system 侧 ragenix 声明）。
#
# 把 secrets/*.age 解密到 /run/agenix，对应 home-manager 端从这里
# 通过 `osConfig.age.secrets.<name>.path` 软链到 ~/.config/<...>，或由
# shell 启动脚本读出并导出为环境变量。密文/规则：secrets/<name>.age、
# secrets/secrets.nix；解密身份：/home/xumel/.config/age/keys.txt
# （不进仓库，需自行离线备份）。
#
# - github-netrc     → /run/agenix/github-netrc   （nix + 用户双消费）
#                       modules/home/xumel/secrets.nix 软链到 ~/.config/nix/netrc
#                       modules/nixos/nix-github-auth.nix 写到 nix.settings.netrc-file
# - ai-env           → /run/agenix/ai-env（systemd EnvironmentFile 格式，KEY=value 逐行）
#                       MINIMAX_TOKEN_PLAN_KEY 被两方共用同一份密文：
#                         · DMS 的 AiOverviewControl 插件 —— modules/nixos/desktop/dms.nix
#                           用 serviceConfig.EnvironmentFile 交给 dms.service；
#                         · pi / mcode —— modules/home/xumel/secrets.nix 按变量名解析
#                           后 export 为它们认识的 MINIMAX_CN_API_KEY。
#                       #DEEPSEEK_API_KEY 同一插件的 deepseek 适配器用，
#                         待申请后去掉行首 '#'
#
# 首次部署新密文：在 secrets/ 目录里跑
#   ragenix -i ~/.config/age/keys.txt -e <name>.age
# 把内容粘进去、commit 即可。
# 注意 ragenix -e 要求目标文件已存在且是合法 age 密文——新建文件时用
# `cp secrets/<已有密文> secrets/<新名字>.age` 作基底，它会在你编辑后整体重写。
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

    secrets.ai-env = {
      file = ../../secrets/ai-env.age;
      # dms.service（systemd --user，以 xumel 身份跑）要读它拿 provider 凭据；
      # xumel 的交互式 shell 也要读。
      owner = "xumel";
      mode = "0400";
    };
  };
}
