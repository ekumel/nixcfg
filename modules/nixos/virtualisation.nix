# 虚拟化：KVM/QEMU + libvirtd + virt-manager。
# 硬件侧的内核模块（kvm-amd）已在 hosts/nixos/hardware.nix 启用。
{ ... }:

{
  # libvirt 守护进程。该模块会自动：
  #   - 启动 libvirtd.socket / libvirtd.service
  #   - 创建 libvirtd / qemu-libvirtd 组
  #   - 启动默认 NAT 网络（default）供虚拟机上网
  #   - 准备 /var/lib/libvirt 作为默认 storage pool
  virtualisation.libvirtd.enable = true;

  # virt-manager 图形前端（GTK）。
  # 该模块会自动拉取依赖（spice-gtk、gtk-vnc、gnome 图标主题等），
  # 并配置好 libvirt polkit 规则，无需手工介入。
  programs.virt-manager.enable = true;

  # 允许 libvirtd 监听外部 TCP（默认仅 UNIX socket；日常使用无需打开）。
  # virtualisation.libvirtd.listenAddress = "127.0.0.1";
}