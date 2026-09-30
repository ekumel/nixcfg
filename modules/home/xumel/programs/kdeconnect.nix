# KDE Connect 守护进程（kdeconnectd）用户服务。
# kdeconnectd 使用 D-Bus 激活，但通过 systemd 确保它在会话启动时自动运行。
{ pkgs, ... }:

{
  systemd.user.services.kdeconnectd = {
    description = "KDE Connect Daemon";
    documentation = [ "man:kdeconnectd(1)" ];

    # 依赖 D-Bus session，确保网络就绪
    after = [ "dbus.session.target" "network.target" ];
    wants = [ "dbus.session.target" ];
    partOf = [ "graphical-session.target" ];

    serviceConfig = {
      Type = "dbus";
      BusName = "org.kde.kdeconnect";
      # D-Bus 激活后实际执行命令；systemd 只负责拉起
      ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/libexec/kdeconnectd";
      # 异常退出时自动重启
      Restart = "on-failure";
    };
  };

  # 确保 kdeconnectd 在登录后自动启动
  systemd.user.targets.graphical-session.wantedBy = [ "kdeconnectd.service" ];
}
