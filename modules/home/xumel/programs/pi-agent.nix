# pi coding agent (https://github.com/badlogic/pi-mono) 用户配置。
#
# 配置目录（pi 硬编码到 ~/.pi/agent，绕过 XDG_CONFIG_HOME，因为
# pi 的内部 `xr()` 直接 `path.join(homedir(), ".pi", "agent")`，
# 可由 PI_CODING_AGENT_DIR 环境变量覆盖）：
#
#   ~/.pi/agent/models.json        用户自定义 provider / model 声明（声明式）
#   ~/.pi/agent/auth.json          API key 凭据（软链到 ragenix 解密文件）
#   ~/.pi/agent/models-store.json  pi 自动维护的内置模型缓存（不动）
#   ~/.pi/agent/extensions/        扩展（Orca IDE 等第三方管理，不动）
#   ~/.pi/agent/sessions/          会话存档（不动）
#   ~/.pi/agent/npm/               npm 全局包（不动）
#
# 凭据从 system 侧 modules/nixos/pi-agent.nix 的 `age.secrets.pi-agent-auth`
# 拉取，密文见 secrets/pi-agent-auth.age。本地密钥身份：
#   /home/xumel/.config/age/keys.txt（不进仓库，需自行离线备份）
#
# 升级 pi 本体：mcode（@minimax-ai/code）已经在 modules/home/xumel/packages/
# third-party.nix 里跟踪，pi 仓库的 npm CLI tarball 走同一份 npm 包路径。
{ config, osConfig, ... }:

{
  # ---- 用户自定义 provider / model ----
  #
  # 内置模型（OpenAI / Anthropic / Google 等）由 pi 自动从
  # https://pi.dev/api/models/providers/<id> 拉取，缓存到
  # models-store.json，不需要在这里声明。
  #
  # 这里只声明 pi 不内置的私有 / 自部署 provider（目前只有 MiniMax
  # 一家）。minimax-cn（内置 anthropic-messages API）与 mini-max（这里
  # 自定义的 openai-responses API）共用同一把 API key——auth.json 里
  # 两个 provider 都登记 key，pi 按当前 model 的 provider 字段自动选边。
  home.file.".pi/agent/models.json".text = builtins.toJSON {
    providers = {
      mini-max = {
        name = "mini-max";
        baseUrl = "https://api.minimax.cn/v1";
        api = "openai-responses";
        models = [
          {
            id = "MiniMax-M3";
            input = [
              "text"
              "image"
            ];
          }
          {
            id = "MiniMax-M2.7";
          }
          {
            id = "MiniMax-M2.7-highspeed";
          }
          {
            id = "MiniMax-M3.1-Flash";
            input = [
              "text"
              "image"
            ];
          }
        ];
      };
    };
  };

  # ---- 凭据：软链到 ragenix 解密文件 ----
  #
  # mkOutOfStoreSymlink：软链到运行时解密文件（/run/agenix/pi-agent-auth），
  # 而不是把内容拷进 store。这样：
  #   1. 明文 API key 只出现在 /run（tmpfs，重启即丢），不进 /nix/store；
  #   2. 密文（secrets/pi-agent-auth.age）随仓库一起备份，
  #      换机器只需要 age 私钥就能还原；
  #   3. 旧 plaintext auth.json 第一次激活时被 home-manager 备份为
  #      ~/.pi/agent/auth.json.hm-backup（见 hosts/nixos/configuration.nix
  #      的 `home-manager.backupFileExtension`）。
  #
  # ragenix 解密产物 owner=xumel mode=0400，pi 以 xumel 身份读取 OK。
  home.file.".pi/agent/auth.json".source =
    config.lib.file.mkOutOfStoreSymlink osConfig.age.secrets.pi-agent-auth.path;
}
