# xumel 的本机密钥管理（用户侧）：GitHub token 与 MiniMax API key 注入。
#
# token 本体由系统侧 ragenix 在激活时解密到 /run/agenix/github-netrc
# （密文 secrets/github-netrc.age，系统模块见
# modules/nixos/nix-github-auth.nix），这里只把 ~/.config/nix/netrc
# 软链过去——store 里不再出现明文。
#
# MiniMax key 与其它 AI provider 凭据都在 /run/agenix/ai-env 里（systemd
# EnvironmentFile 格式），由 shell 启动脚本按变量名取出后导出为
# MINIMAX_CN_API_KEY（不进任何 agent 的凭据文件，详见文件下半部分）。
#
# 覆盖范围一览：
#   ✓ fetchFromGitHub       → ~/.config/nix/netrc
#   ✓ fetchurl (github.com)  → ~/.config/nix/netrc
#   ✓ nix-prefetch-github    → ~/.config/nix/netrc
#   ✓ scripts/update-third-party.sh 探测 GitHub Releases API → ~/.config/nix/netrc
#   ✓ cargo / pip / go 等    → $GITHUB_TOKEN
#   ✓ nix flake / nix build  → nix.settings.netrc-file（系统侧，同一份文件）
#   ✗ git clone / push       → git 自己读 ~/.gitconfig 与 credential helper，
#                              与本模块无关；如需也认证，配 git credential store
#                              或在 ~/.gitconfig 加 [credential] helper。
#
# 轮换 token：吊销旧 token → 在 secrets/ 里 ragenix -e github-netrc.age
# 写入新值 → nixos-rebuild switch。
{ config, osConfig, ... }:

{
  # mkOutOfStoreSymlink：软链到运行时的解密文件，而不是把内容拷进 store。
  xdg.configFile."nix/netrc".source =
    config.lib.file.mkOutOfStoreSymlink osConfig.age.secrets.github-netrc.path;

  # 让 fish 登录 shell 自动 export GITHUB_TOKEN。
  # 放在 conf.d/ 而不是改 config.fish：fish 自动 source 所有 conf.d/*.fish，
  # 与 programs/fish.nix 解耦，避免两处都在写同一个文件。
  # 从 netrc 解析 password 而非硬编码第二份，避免 token 漂移。
  xdg.configFile."fish/conf.d/github-token.fish".text = ''
    if test -r $HOME/.config/nix/netrc
      # 匹配第一个 "machine github.com" 块下的 password 行。
      set -l token (awk '/^machine github\.com/{flag=1; next} flag && /^password /{print $2; exit}' $HOME/.config/nix/netrc)
      if test -n "$token"
        set -gx GITHUB_TOKEN $token
      end
    end
  '';

  # ---- MiniMax API key：导出为 MINIMAX_CN_API_KEY ----
  #
  # 明文由 ragenix 解密到 /run/agenix/ai-env（tmpfs，0400），格式是 systemd
  # EnvironmentFile 的 KEY=value 逐行。同一份密文也直接喂给 dms.service
  # （见 modules/nixos/desktop/dms.nix），所以这里不是 cat 整个文件，而是按
  # 变量名取出 MINIMAX_TOKEN_PLAN_KEY 那一行。
  #
  # 消费方都原生认 MINIMAX_CN_API_KEY：
  #   pi        —— docs/providers.md 列出 MiniMax (China) = MINIMAX_CN_API_KEY；
  #                自定义 provider 由 models.json 的 apiKey = "$MINIMAX_CN_API_KEY"
  #                插值引用（见 modules/home/xumel/programs/pi-agent.nix）
  #   mcode     —— 包内支持同名变量
  #   其它 agent —— 只要认这个变量名就零配置接入
  #
  # 为什么不用 home.sessionVariables：它把值用 shell 单引号转义后写进
  # profile.d，命令替换 $(cat ...) 会被当字面量、不会执行。
  #
  # 为什么不用 home.file 软链到某个 agent 的凭据文件：那样密文就得内嵌
  # agent 私有格式，与 agent 版本耦合（pi 自己的 auth.json 就变过格式），
  # 且多一个 agent 就要多一份密文。裸 key + 环境变量与消费方解耦。
  #
  # fish：与上面的 github-token.fish 同理放 conf.d/。
  # 先用 string match 的 glob 过滤出目标行，再 replace 掉前缀——顺序不能反：
  # 直接对整个文件做 replace 会把未匹配的行原样一起输出，值就变成整个文件了。
  # 用内建 string 而不是外部 awk/grep：少一个进程，也不依赖 PATH。
  # 空串参数写 "" 而不是 fish 惯用的 ''：后者在 Nix 缩进字符串里是无效转义。
  xdg.configFile."fish/conf.d/minimax-key.fish".text = ''
    if test -r /run/agenix/ai-env
      set -l hit (string match 'MINIMAX_TOKEN_PLAN_KEY=*' -- (cat /run/agenix/ai-env))
      if test (count $hit) -gt 0
        set -gx MINIMAX_CN_API_KEY (string replace 'MINIMAX_TOKEN_PLAN_KEY=' "" -- $hit[1])
      end
    end
  '';

  # bash：登录 shell 是 bash（见 /etc/passwd），home-manager 的
  # ~/.nix-profile/etc/profile.d/home-manager.sh 由 bash 登录时 source，
  # 所以用 home.extraProfileCommands 追加一段。zsh 不需要覆盖。
  # sed 的 -n + s///p 只输出匹配到的那一行；'^' 锚点让 #DEEPSEEK_API_KEY=
  # 这类注释行匹配不到，key 里含 '/' 也不会截断（分隔符换了）。
  home.extraProfileCommands = ''
    if [ -r /run/agenix/ai-env ]; then
      minimax_key="$(sed -n 's|^MINIMAX_TOKEN_PLAN_KEY=||p' /run/agenix/ai-env)"
      if [ -n "$minimax_key" ]; then
        export MINIMAX_CN_API_KEY="$minimax_key"
      fi
      unset minimax_key
    fi
  '';
}
