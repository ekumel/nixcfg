# pi coding agent (https://github.com/badlogic/pi-mono) 用户配置。
#
# 配置目录（pi 硬编码到 ~/.pi/agent，绕过 XDG_CONFIG_HOME，因为
# pi 的内部 `xr()` 直接 `path.join(homedir(), ".pi", "agent")`，
# 可由 PI_CODING_AGENT_DIR 环境变量覆盖）：
#
#   ~/.pi/agent/models.json        用户自定义 provider / model 声明（声明式，不含密钥）
#   ~/.pi/agent/models-store.json  pi 自动维护的内置模型缓存（不动）
#   ~/.pi/agent/extensions/        扩展（Orca IDE 等第三方管理，不动）
#   ~/.pi/agent/sessions/          会话存档（不动）
#   ~/.pi/agent/npm/               npm 全局包（不动）
#
# 凭据不再有 auth.json：pi 与 mcode 都原生读 MINIMAX_CN_API_KEY 环境变量，
# 由 system 侧 modules/nixos/user-secrets.nix 的 `age.secrets.ai-env`
# 解密到 /run/agenix/ai-env，再由 modules/home/xumel/secrets.nix 在
# shell 启动时按变量名取出 MINIMAX_TOKEN_PLAN_KEY 那一行导出。
# 密文见 secrets/ai-env.age。本地密钥身份：
#   /home/xumel/.config/age/keys.txt（不进仓库，需自行离线备份）
# 同一份 ai-env 密文也直接作为 systemd EnvironmentFile 供给 DMS 的
# AiOverviewControl 插件（见 modules/nixos/desktop/dms.nix），不重复加密。
#
# 升级 pi 本体：mcode（@minimax-ai/code）已经在 modules/home/xumel/packages/
# third-party.nix 里跟踪，pi 仓库的 npm CLI tarball 走同一份 npm 包路径。
{ ... }:

{
  # ---- 用户自定义 provider / model ----
  #
  # 内置模型（OpenAI / Anthropic / Google 等）由 pi 自动从
  # https://pi.dev/api/models/providers/<id> 拉取，缓存到
  # models-store.json，不需要在这里声明。
  #
  # 这里只声明 pi 不内置的私有 / 自部署 provider（目前只有 MiniMax
  # 一家）。minimax-cn（内置 anthropic-messages API）与 mini-max（这里
  # 自定义的 openai-responses API）共用同一把 API key。
  #
  # apiKey 写 "$MINIMAX_CN_API_KEY"（pi 的环境变量插值，见其
  # docs/models.md）而不是明文或软链的 auth.json：
  #   - 明文 key 由 ragenix 解密到 /run/agenix/ai-env（tmpfs，KEY=value 格式），
  #     shell 启动时取出 MINIMAX_TOKEN_PLAN_KEY 那一行导出为 MINIMAX_CN_API_KEY
  #     （见 secrets.nix），不进 /nix/store；
  #   - models.json 本身不含密钥，可以安全地留在 store 里被声明式管理；
  #   - 同一把 key 同时供 mcode 与 DMS 插件使用，密文与消费方数量解耦。
  home.file.".pi/agent/models.json".text = builtins.toJSON {
    providers = {
      mini-max = {
        name = "mini-max";
        baseUrl = "https://api.minimax.cn/v1";
        api = "openai-responses";
        apiKey = "$MINIMAX_CN_API_KEY";
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

  # ---- 凭据：不再有 auth.json ----
  #
  # 原来这里用 mkOutOfStoreSymlink 把 ~/.pi/agent/auth.json 软链到
  # /run/agenix/pi-agent-auth。那条路已废弃，原因见下面 secrets.nix 的注释：
  #   1. auth.json 是 pi 的私有格式，明文密文与 pi 版本耦合——pi 自己就改过
  #      一次格式（oauth.json + settings.json → auth.json）；
  #   2. 同一把 key 还要给 mcode 等其它 agent 用，而它们的凭据格式各不相同；
  #   3. 实际上 pi 与 mcode 都原生支持 MINIMAX_CN_API_KEY 环境变量，所以
  #      一份「裸 key」密文 + 一个环境变量就够，不需要任何 agent 专用文件。
  #
  # 现在：ai-env 由 ragenix 解密到 /run/agenix/ai-env（KEY=value 逐行的
  # systemd EnvironmentFile 格式），由 modules/home/xumel/secrets.nix 在
  # fish / bash 启动时取出 MINIMAX_TOKEN_PLAN_KEY 那一行、导出为
  # MINIMAX_CN_API_KEY；本模块只用 models.json 的 apiKey 插值引用它。
  # models.json 不含密钥，可以安全地留在 store 里。
  # 同一份 ai-env 还以 EnvironmentFile 形式供给 DMS 的 AiOverviewControl
  # 插件，所以这把 key 全机只有一份密文。
  #
  # 旧的本机文件在下次激活时会被 home-manager 备份为
  # ~/.pi/agent/auth.json.hm-backup（见 hosts/nixos/configuration.nix 的
  # `home-manager.backupFileExtension`），确认无需保留后可自行删除。
}
