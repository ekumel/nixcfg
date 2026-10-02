# xumel 的用户侧凭据（system 侧 ragenix 声明）。
#
# 把 secrets/*.age 解密到 /run/agenix，对应 home-manager 端从这里
# 通过 `osConfig.age.secrets.<name>.path` 软链到 ~/.config/<...>，或由
# shell 启动脚本读出并导出为环境变量。密文/规则：secrets/<name>.age、
# secrets/secrets.nix；解密身份：/home/xumel/.config/age/keys.txt
# （不进仓库，需自行离线备份）。
#
# - github-netrc     → /run/agenix/github-netrc   （nix + 用户双消费）
#                       modules/home/xumel/secrets.nix 软链到 ~/.config/nix/netrc
#                       modules/nixos/nix-github-auth.nix 写到 nix.settings.netrc-file
# - ai-env           → /run/agenix/ai-env（systemd EnvironmentFile 格式，KEY=value 逐行）
#                       MINIMAX_TOKEN_PLAN_KEY 被两方共用同一份密文：
#                         · DMS 的 AiOverviewControl 插件 —— modules/nixos/desktop/dms.nix
#                           用 serviceConfig.EnvironmentFile 交给 dms.service；
#                         · pi / mcode —— modules/home/xumel/secrets.nix 按变量名解析
#                           后 export 为它们认识的 MINIMAX_CN_API_KEY。
#                       #DEEPSEEK_API_KEY 同一插件的 deepseek 适配器用，
#                         待申请后去掉行首 '#'
#
# 首次部署新密文：在 secrets/ 目录里跑
#   ragenix -i ~/.config/age/keys.txt -e <name>.age
# 把内容粘进去、commit 即可。
# 注意 ragenix -e 要求目标文件已存在且是合法 age 密文——新建文件时用
# `cp secrets/<已有密文> secrets/<新名字>.age` 作基底，它会在你编辑后整体重写。
#
# ---- 为什么有下面那个 agenix-install-secrets 服务 ----
#
# ragenix/agenix 的 NixOS 模块有两条解密路径，由 sysusersEnabled 决定：
#   · systemd.sysusers.enable 或 services.userborn.enable 为真 → 生成一个
#     真正的 systemd 服务（sysinit.target 之后），在真实根文件系统里跑；
#   · 否则退回 system.activationScripts，即 initrd 的 activation 脚本。
#
# 本机两个开关都是 false，走的是第二条。而 age 身份在
# /home/xumel/.config/age/keys.txt，/home 是独立的 btrfs 子卷
# （/dev/nvme1n1p2[/@home]），initrd 阶段还没挂载，于是开机日志里是：
#   [agenix] WARNING: config.age.identityPaths entry .../keys.txt not present!
#   [agenix] WARNING: no readable identities found!
#   mv: cannot stat '/run/agenix.d/1/ai-env.tmp': No such file or directory
# 结果 /run/agenix 为空，**所有**密文都没解开（github-netrc 同样受影响：
# 开机后 nix 读不到 netrc、fish 里也没有 GITHUB_TOKEN），而 agenix 只打印
# 警告、不返回非零，于是这个状态一路静默地活到下次 nixos-rebuild switch
# 才被修好。
#
# 为什么不能直接开 systemd.sysusers：模块自带断言
#   opts.enable -> !opts.isNormalUser
#   "xumel is a normal user. systemd-sysusers doesn't create normal users"
# 本机 users.users.xumel 是 isNormalUser = true（见 modules/nixos/users.nix），
# 一开就是构建失败。所以走第三条路：自己加一个排在 local-fs.target 之后
# 的 oneshot，逻辑照抄模块在 sysusers 分支里的那三段（newGeneration +
# installSecrets + chownSecrets），只是把顺序从 sysinit.target 换到
# local-fs.target。
#
# 与模块自带的 initrd 脚本并存、不冲突：两者都用「代号递增」机制
#（/run/agenix → /run/agenix.d/N），本服务建新代号、解密、重新软链、再删旧代号。
# 开机时 initrd 建了空的 1 号，本服务建 2 号并接管；手动 switch 时 activation
# 在真实根里能正常解密建 3 号并清掉 2 号。
#
# 两处与模块行为的有意差异：
#   1. 找不到任何可用身份时**直接失败退出**（模块只是警告后继续）。因为本服务
#      是开机路径，"静默产出空目录"正是这次排查绕了两天的坑，宁可让单元红掉。
#   2. 清理旧代号时遍历删除所有更小的代号（模块只删上一个小的那一个），
#      这样即使历史上积累了多个空代号也能收敛。
{ config, inputs, lib, pkgs, ... }:

{
  imports = [ inputs.ragenix.nixosModules.default ];

  age = {
    # 专用 age 身份：单机场景下比重装即更换的 SSH host key 更易恢复。
    identityPaths = [ "/home/xumel/.config/age/keys.txt" ];

    secrets.github-netrc = {
      file = ../../secrets/github-netrc.age;
      # xumel 要读它来生成用户侧 netrc；root 的 nix 守护进程不受权限位限制。
      owner = "xumel";
      mode = "0400";
    };

    secrets.ai-env = {
      file = ../../secrets/ai-env.age;
      # dms.service（systemd --user，以 xumel 身份跑）要读它拿 provider 凭据；
      # xumel 的交互式 shell 也要读。
      owner = "xumel";
      mode = "0400";
    };
  };

  systemd.services.agenix-install-secrets = lib.mkIf (config.age.secrets != { }) {
    description = "Decrypt agenix secrets once /home is available (see file header)";
    # local-fs.target 完成意味着 /home 已挂载；serviceConfig.RequiresMountsFor 再加
    # 一道保险，直接把依赖挂到 /home 的挂载单元上，不依赖「子卷一定被 local-fs
    # 覆盖」这个假设。DefaultDependencies=no 与模块 sysusers 分支保持一致。
    wantedBy = [ "local-fs.target" ];
    after = [ "local-fs.target" ];
    unitConfig.DefaultDependencies = "no";
    # 脚本要用 mount 判断 /run/agenix.d 是否已是 ramfs。
    path = [ pkgs.mount ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RequiresMountsFor = "/home";
      ExecStart = pkgs.writeShellScript "agenix-install-secrets" (
        let
          secrets = lib.attrValues config.age.secrets;
          locale = toString (config.i18n.defaultLocale or "C");
          decryptOne = s: ''
            echo "decrypting '${s.file}' to '$_true_path'..."
            _tmp="$_true_path.tmp"
            mkdir -p "$(dirname "$_true_path")"
            ( umask u=r,g=,o=; LANG=${locale} ${config.age.ageBin} \
                --decrypt "''${IDENTITIES[@]}" -o "$_tmp" ${s.file} )
            chmod ${s.mode} "$_tmp"
            mv -f "$_tmp" "$_true_path"
            chown ${s.owner}:${s.group} "$_true_path"
            # path 与默认位置不同时，额外在 path 上留一个软链（模块同款行为）。
            if [ "${s.path}" != "${config.age.secretsDir}/${s.name}" ]; then
              ln -sfT "${config.age.secretsDir}/${s.name}" "${s.path}"
            fi
          '';
        in
        ''
          set -eu

          _secretsDir=${config.age.secretsDir}
          _secretsMountPoint=${config.age.secretsMountPoint}

          # ---- 建新代号（照抄模块的 newGeneration）----
          _agenix_generation="$(basename "$(readlink "$_secretsDir")" || echo 0)"
          (( ++_agenix_generation ))
          echo "[agenix] creating new generation in $_secretsMountPoint/$_agenix_generation"
          mkdir -p "$_secretsMountPoint"
          chmod 0751 "$_secretsMountPoint"
          grep -q "$_secretsMountPoint ramfs" /proc/mounts || \
            mount -t ramfs none "$_secretsMountPoint" -o nodev,nosuid,mode=0751
          mkdir -p "$_secretsMountPoint/$_agenix_generation"
          chmod 0751 "$_secretsMountPoint/$_agenix_generation"

          # ---- 收身份（模块这里是警告后继续；我们直接失败）----
          IDENTITIES=()
          for _identity in ${toString config.age.identityPaths}; do
            if [ ! -r "$_identity" ]; then
              echo "[agenix] ERROR: identity $_identity not readable" >&2
              continue
            fi
            if [ ! -s "$_identity" ]; then
              echo "[agenix] ERROR: identity $_identity is empty" >&2
              continue
            fi
            IDENTITIES+=( -i "$_identity" )
          done
          if [ "''${#IDENTITIES[@]}" -eq 0 ]; then
            echo "[agenix] ERROR: no readable age identity; leaving the previous generation untouched" >&2
            exit 1
          fi

          # ---- 逐个解密到新代号（照抄模块的 installSecret）----
          ${lib.concatMapStringsSep "\n" (s: ''
            (
            _true_path="$_secretsMountPoint/$_agenix_generation/${s.name}"
            ${decryptOne s}
            )
          '') secrets}
          wait

          # ---- 软链到新代号，再清掉所有更旧的（模块的 cleanupAndLink）----
          echo "[agenix] symlinking new secrets to $_secretsDir (generation $_agenix_generation)..."
          ln -sfT "$_secretsMountPoint/$_agenix_generation" "$_secretsDir"
          for _old in "$_secretsMountPoint"/*; do
            [ -d "$_old" ] || continue
            _oldname="$(basename "$_old")"
            [ -n "$_oldname" ] || continue
            # 只处理纯数字代号，skip 掉任何意外混入的东西。
            case "$_oldname" in
              *[!0-9]*) continue ;;
            esac
            if [ "$_oldname" -lt "$_agenix_generation" ]; then
              echo "[agenix] removing old secrets (generation $_oldname)..."
              rm -rf "$_old"
            fi
          done

          # ---- chown（模块的 chownSecrets）----
          # 挂载点/代号目录改成 keys 组是沿用模块的约定，不影响正确性，所以
          # 刻意不让它失败：set -e 下这行一旦报错（比如 keys 组不存在、或
          # 将来改成非 root 运行），会让整个单元变红，而此时密钥其实已经
          # 解密完成、软链也换好了——一个"看起来失败但其实成功"的状态更难排查。
          echo "[agenix] chowning..."
          if getent group keys >/dev/null 2>&1; then
            chown :keys "$_secretsMountPoint" "$_secretsMountPoint/$_agenix_generation" || \
              echo "[agenix] WARNING: could not set group 'keys' on the mountpoint (ignored)" >&2
          fi
          ${lib.concatMapStringsSep "\n" (s: "chown ${s.owner}:${s.group} \"$_secretsDir/${s.name}\"") secrets}
        ''
      );
    };
  };
}
