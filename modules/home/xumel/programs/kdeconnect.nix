# KDE Connect 守护进程（kdeconnectd）用户服务。
# kdeconnectd 使用 D-Bus 激活，但通过 systemd 确保它在会话启动时自动运行。
{ pkgs, ... }:

{
  systemd.user.services.kdeconnectd = {
    # home-manager 的 systemd 模块要求所有列表型字段为属性集形式
    description = {
      "KDE Connect Daemon" = true;
    };
    documentation = {
      "man:kdeconnectd(1)" = true;
    };

    # 依赖 D-Bus session，确保网络就绪
    after = {
      "dbus.session.target" = true;
      "network.target" = true;
    };
    wants = {
      "dbus.session.target" = true;
    };
    partOf = {
      "graphical-session.target" = true;
    };

    serviceConfig = {
      Type = "dbus";
      BusName = "org.kde.kdeconnect";
      # D-Bus 激活后实际执行命令；systemd 只负责拉起
      ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/libexec/kdeconnectd";
      # 异常退出时自动重启
      Restart = "on-failure";
    };

    wantedBy = {
      "graphical-session.target" = true;
    };
  };
}
