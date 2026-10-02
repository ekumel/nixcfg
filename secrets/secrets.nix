# agenix/ragenix 规则文件：声明每个密文可以被哪些公钥解密。
#
# 密文（*.age）和本文件可以安全提交到公开仓库；私钥不进仓库。
# 本机身份私钥：/home/xumel/.config/age/keys.txt（0600，请自行离线备份；
# 丢失后旧密文无法解密，只能轮换 token 重新加密）。
#
# 常用命令（在 secrets/ 目录内执行）：
#   编辑密文：ragenix -i ~/.config/age/keys.txt -e github-netrc.age
#   新增 recipient 后重加密：ragenix -i ~/.config/age/keys.txt --rekey
let
  # 本机专用 age 身份（age-keygen 生成，公钥对应上面的私钥文件）。
  xumel = "age1x733c29amlt4gsp4l00fq8xjw06em5u3tw2gtxcj8pyw7t0j0v9qkrzss2";
in
{
  "github-netrc.age".publicKeys = [ xumel ];
  # AI provider 凭据，明文是 systemd EnvironmentFile 格式（KEY=value 逐行）：
  #   MINIMAX_TOKEN_PLAN_KEY=sk-cp-…   # DMS 的 AiOverviewControl 插件
  #   #DEEPSEEK_API_KEY=…              # 占位，待申请后去掉行首 '#'
  #
  # 为什么统一成 env 格式而不是「一个裸 key 一份密文」：
  #   裸 key 只能喂给「cat 整个文件当作值」的消费方（原先的 pi / mcode 就是
  #   这么用的：cat → export MINIMAX_CN_API_KEY）。但 DMS 侧的 AiOverviewControl
  #   插件要的是 systemd EnvironmentFile，必须是 KEY=value，且一个文件要能
  #   同时装 MiniMax 与 DeepSeek 两个 provider 的 key。裸 key 格式两者都做不到，
  #   于是同一个 MiniMax key 会被加密两次，轮换要改两个文件、有漏改的风险。
  #   统一成 env 格式后只有这一个真源：谁需要就按变量名取自己那一行。
  #
  # 仍然刻意不存任何 agent 的私有凭据格式（pi 的 auth.json 等）：那种格式
  # 会把密文与 agent 版本耦合——pi 自己的 auth.json 就变过（oauth.json +
  # settings.json → auth.json，见其包内 migrations.js）。env 格式是标准格式，
  #   与任何 agent 的版本无关，加新 agent 不用改密文。
  #
  # 解密到 /run/agenix/ai-env（tmpfs，owner=xumel mode=0400），两个消费方：
  #   1. dms.service —— serviceConfig.EnvironmentFile=/run/agenix/ai-env
  #      （见 modules/nixos/desktop/dms.nix）。必须是 EnvironmentFile 而不是
  #      systemd.user.services.dms.environment：后者会把值以 Environment=
  #      明文写进 /etc/systemd/user/dms.service，那文件全局可读。
  #   2. fish conf.d 与 bash profile —— 按变量名解析出 MINIMAX_TOKEN_PLAN_KEY
  #      后 export 为 MINIMAX_CN_API_KEY（见 modules/home/xumel/secrets.nix）。
  "ai-env.age".publicKeys = [ xumel ];
}
