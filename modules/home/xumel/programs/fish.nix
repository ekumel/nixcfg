# xumel 的用户级 shell：fish + starship。
#
# fish 走 home-manager 的 programs.fish 生成 ~/.config/fish/config.fish；
# 系统层的 programs.fish.enable（modules/nixos/shell.nix）只负责 /etc/shells
# 与 SHELL 绑定。
#
# starship 刻意不用 programs.starship：~/.config/starship.toml 由 DMS
# （matugen）在运行时生成并覆盖，声明式软链到只读 store 会让 matugen 写入失败。
{ pkgs, ... }:

{
  home.packages = with pkgs; [ starship ];

  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      # 关闭 fish 启动问候（置空）。
      set -g fish_greeting

      # Starship 提示符，配色主题由 DMS（matugen）写入 ~/.config/starship.toml。
      starship init fish | source
    '';

    shellAliases = {
      ls = "ls --color=auto";
      ll = "ls -alh --color=auto";
      la = "ls -A --color=auto";
      l = "ls -CF --color=auto";
      grep = "grep --color=auto";
      ".." = "cd ..";
      "..." = "cd ../..";
      gs = "git status -sb";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline --graph --decorate -20";
      gd = "git diff";
      ff = "fastfetch";
      nrs = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      nfu = "nix flake update --flake /etc/nixos";
    };
  };
}
