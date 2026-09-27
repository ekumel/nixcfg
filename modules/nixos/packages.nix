# 系统级软件包与常用程序。
#
# 归属原则：
#   - 这里是系统空间的“基础/恢复”工具：登录后即使用户 profile 损坏也能用
#     （git / curl / kitty 等），以及系统服务会用到的程序；
#   - 面向用户的日常应用与开发工具放在用户空间
#     （modules/home/xumel/packages/）。
{ pkgs, ... }:

{
  # Clash Verge Rev（代理客户端）。TUN 模式需要两个开关一起开：
  #   - serviceMode：以 root 跑 clash-verge-service，由它启动内核，
  #     虚拟网卡与路由由此创建（否则需要应用自己装服务、要 pkexec 授权）；
  #   - tunMode：给 GUI 补上 net_admin/raw 等 capability，并自动把
  #     networking.firewall.checkReversePath 放宽为 "loose"
  #     （不加 capability 时 TUN 下的 DNS 设置不生效）。
  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
  };

  environment.systemPackages = with pkgs; [
    kitty # 终端（DMS 键位 Super + T、KDE 应用的 TerminalApplication）
    git
    wget
    curl
    gvfs # `gio trash` 后端（neo-tree 删文件进回收站；缺它只能回退到自带实现）
  ];
}
