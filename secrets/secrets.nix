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
}
