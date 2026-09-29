# ClamAV 杀毒引擎：clamd 守护进程 + freshclam 病毒库更新 + 定时扫描。
#
# 基于 nixpkgs 的 services.clamav 模块（见
# /nix/store/.../nixos/modules/services/security/clamav.nix）。本文件只是把它
# 包成本仓库的启用清单 + 一组针对 GUI 使用场景的覆盖选项：
#
#   - LocalSocket / LocalSocketGroup = clamav：clamav-gui 通过本地 UNIX socket
#     连 clamd，socket 属组必须能让 GUI 用户读 / 写；
#   - xumel 加入 clamav 组：这样 GUI 能读 /var/lib/clamav 的病毒库
#     （owner = clamav，group = clamav，xumel 在组里就能遍历），也能
#     与 LocalSocket 通信；
#   - 病毒库目录 /var/lib/clamav 走 StateDirectory（systemd 自动建，属主 = 进程用户）；
#     clamav 用户组的成员因此拥有 rx 权限（StateDirectory 默认 mode = 0700，
#     这里调成 0750 让组成员能读）；
#   - scanner 默认 04:00 全盘扫；用户可以随时通过 GUI 或 `clamscan` 手动扫。
#
# 注意：freshclam 第一次跑会因为病毒库还没下载而必须重启若干次；nixpkgs 的
# clamav-daemon.service 已经 after / wants clamav-freshclam.service，所以
# 病毒库未就绪时 clamd 不会启动。等 freshclam.timer 跑过一次后即可正常使用。
{ pkgs, ... }:

{
  services.clamav = {
    package = pkgs.clamav;

    # clamd：扫描守护。GUI 通过 LocalSocket 连它；man clamd.conf。
    daemon = {
      enable = true;
      settings = {
        # 让 GUI 用户（xumel 在 clamav 组里）能读 socket。
        # clamd 的 LocalSocket 默认 mode = 0660、owner = clamav。
        LocalSocket = "/run/clamav/clamd.ctl";
        LocalSocketGroup = "clamav";
        # LocalSocketMode = "0660";（nixpkgs 默认就是这个）
        # 接受 PING，方便 GUI 探测。
        PingWatchdogTimeout = 30; # 秒；GUI 心跳窗口
      };
    };

    # clamonacc（OnAccess 实时扫描）：本机默认关闭。GUI 用户如果想开，
    # 在 setup tab 里勾上即可——clamd.conf 的 OnAccessIncludePath 由 GUI 写入。
    # NixOS 模块开关放在这里只是为了防止误启；GUI 端会写 OnAccessIncludePath。
    clamonacc.enable = false;

    # freshclam：病毒库更新。每天 24 次（默认每小时一次），
    # 病毒库变化大时多跑几次；nixpkgs 默认 12 次/天，改为 24 次以更快拿到新威胁。
    updater = {
      enable = true;
      frequency = 24;
      interval = "hourly";
      settings = {
        # NotifyClamd 把 freshclam 完事的信息推给 clamd，让它重新加载病毒库。
        # nixpkgs 默认已经填了 DatabaseMirror = [ "database.clamav.net" ]，
        # 重复声明会被 toKeyValue 拆成两个重复键，不写。
        NotifyClamd = "/etc/clamav/clamd.conf";
        # 安全：freshclam 不要试图自己写日志文件到 /var/log；让 systemd 接管。
        # UpdateLogFile = false;（由 systemd journal 承担）
      };
    };

    # scanner：定时全盘扫。默认每天凌晨 4 点（systemd time spec），
    # 跑 clamdscan --multiscan --fdpass --infected --allmatch <目录>。
    scanner = {
      enable = true;
      interval = "*-*-* 04:00:00";
      scanDirectories = [
        "/home"
        "/var/lib"
        "/tmp"
        "/etc"
        "/var/tmp"
        "/nix/store" # Nix store 也是外来数据来源
      ];
    };
  };

  # 把 xumel 加入 clamav 组：
  #   - 读 /var/lib/clamav 的病毒库（GUI 端不需要，但 on-access scan 时其它进程
  #     可能需要）；这里 xumel 加入后，clamav 用户的文件默认 mode 750，组员能 rx；
  #   - 连 clamd 的 LocalSocket（owner = clamav，group = clamav，mode = 0660）。
  # 其它可能的分组：kvm / docker 等本机不相关。xumel 之前已经在
  # modules/nixos/users.nix 加入 wheel / networkmanager / video / audio /
  # input / libvirtd。这里只追加 clamav，不重复声明。
  users.users.xumel.extraGroups = [ "clamav" ];

  # 让 /var/lib/clamav 对 clamav 组可读（StateDirectory 默认 0700，
  # 但 clamav 进程以 clamav 用户跑，它自己不需要读其他用户的私有数据——
  # 这里改成 0750 让 xumel 也能遍历病毒库目录，方便 GUI 端通过直接文件读
  # 验证病毒库是否存在 / 时戳）。
  systemd.tmpfiles.rules = [
    "d /var/lib/clamav 0750 clamav clamav - -"
  ];
}
