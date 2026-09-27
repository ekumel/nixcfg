# Shell：为 xumel 提供 fish + starship 的交互环境。
#
# 关键点：不修改登录 shell。users.users.xumel.shell 保持默认的 bash，
# 仅通过 SHELL 环境变量把图形会话/终端里的默认 shell 绑定到 fish，
# 因此 tty、SSH 等登录方式仍然进入 bash，而日常终端直接进入 fish。
{ pkgs, ... }:

{
  # 将 fish 装进系统并写入 /etc/shells（SHELL 指向它时更规范）。
  programs.fish.enable = true;

  # 用环境变量实现 shell 绑定：会写入 /etc/set-environment 并作用于 PAM 会话。
  # 登录 shell 本身（/etc/passwd 中的字段）保持不变，依旧是 bash。
  environment.sessionVariables.SHELL = "${pkgs.fish}/bin/fish";
}
