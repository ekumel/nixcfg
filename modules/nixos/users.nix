# 账号：管理员 xumel 与 root。
#
# 使用 users.mutableUsers = false 让密码完全由配置声明式保证：
# 每次 activation 都会把密码写成下面 hashedPassword 的值，
# 因此 `passwd` 的临时修改不会持久化。
# 想改密码时，把新的哈希替换进来再 rebuild 即可
# （生成哈希：`openssl passwd -6 新密码`）。
{ ... }:

{
  users.mutableUsers = false;

  users.users.xumel = {
    isNormalUser = true;
    description = "xumel";
    extraGroups = [
      "wheel" # sudo 管理员
      "networkmanager"
      "video"
      "audio"
      "input"
      "libvirtd" # libvirt system URI（virt-manager 默认走这个）
    ];
    # 密码：a
    hashedPassword = "$6$Z9kTxVxHo77QnIVs$N.9NKBopFfeR4PvGM2.aqSUvrI3H9oI6/sIgvBLZl/u3kzzv9OonbnqzTA4o2Zc1lZcv0w./P4iMMUpXk0Zjz.";
  };

  # root 密码：a
  users.users.root.hashedPassword = "$6$Z9kTxVxHo77QnIVs$N.9NKBopFfeR4PvGM2.aqSUvrI3H9oI6/sIgvBLZl/u3kzzv9OonbnqzTA4o2Zc1lZcv0w./P4iMMUpXk0Zjz.";

  # 让 xumel 直接编辑 flake 配置目录 /etc/nixos：
  # 递归把属主改为 xumel，并把权限位设为 0775（属主/组可写）。
  # 注意：模式字段写 `-` 表示“保持原权限位不动”，只改属主，
  # 那样 VSCode 仍然没有写权限，所以这里必须显式写 0775。
  # 每次 activation 都会重新应用，无需再手动 chmod。
  systemd.tmpfiles.rules = [
    "Z /etc/nixos 0775 xumel users - -"
  ];
}
