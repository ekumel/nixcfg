# avante.nvim：Cursor 式 AI 编程助手（侧边栏固定在左）。
#
# 插件来源：nixvim 自己 pin 的那份 nixpkgs 里的 `vimPlugins.avante-nvim`
# （见 plugins/default.nix 的 extraPlugins）。选它而不是新增 flake input 有两个原因：
#   1. nixvim 当前 pin 的版本**没有** plugins.avante 模块（modules/plugins/ 下无
#      avante），只能走 extraPlugins，没法用声明式的 settings；
#   2. nixpkgs 里那个 derivation 已经用 rustPlatform 把 avante 的 4 个原生库
#      （libavante_repo_map / _templates / _tokenizers / _html2md，luajit feature）
#      编译好塞进 $out/lua/，并且 dependencies 里带上了 plenary / nui / img-clip /
#      dressing / treesitter。自己 buildVimPlugin 的话既要多一个 input，又要自己
#      处理这些原生库和依赖，纯属重复劳动。
#
# setup 放在 extraConfigLuaPre 而不是 extraConfigLua —— 这是有意为之：
#   nixvim 生成 init.lua 的顺序是固定的
#     extraConfigLuaPre → extraConfigVim → extraConfigLua → extraConfigLuaPost
#   （见 nixvim modules/output.nix:173-181）
#   而 DMS 配色的 apply_colors() 在 extraConfigLua 里跑。avante 对自己的高亮组
#   用的是**写死的深色 hex**（上游 lua/avante/highlights.lua 里那一堆 #1e222a /
#   #98c379，只有少部分组用 fg_link 链到 NormalFloat），不会跟着当前配色走。
#   所以必须让 avante 先 setup，等 dms_ui.lua 里的 avante() 用 DMS 调色板把它们
#   覆盖掉，侧边栏才是跟着壁纸走的（否则永远是深色，也享受不到热重载）。
#
# selector 用 telescope：nixvim 已带 telescope，且 avante 是**懒加载**它的
# （上游只在真正打开选择器时才 require，见 lua/avante/file_selector.lua:218），
#   所以放在 Pre 里 setup 不会早于 telescope 的 setup。
{ ... }:

{
  programs.nixvim = {
    extraConfigLuaPre = ''
      require("avante").setup({
        -- agentic 模式：让模型自己调工具（读写文件、跑 bash、搜索）改代码，
        -- 而不是只给建议。这是 avante 的默认行为，写出来是为了让人一眼看到
        -- 这个选择的含义——它意味着模型可以真的动你的工作区。
        mode = "agentic",

        -- 默认 provider：MiniMax（国内站）。
        provider = "minimax",

        providers = {
          minimax = {
            -- 复用 avante 内置的 claude provider（Anthropic Messages 协议），
            -- 只换 endpoint / model / api_key_name。
            __inherited_from = "claude",

            -- MiniMax 国内站的 Anthropic 兼容端点。avante 会拼成
            -- <endpoint>/v1/messages（上游 claude.lua:705-720 + utils.url_join），
            -- 即 https://api.minimaxi.com/anthropic/v1/messages。
            -- key 是 sk-cp- 前缀，对应国内站 platform.minimaxi.com。
            -- 换国际站就把这里改成 https://api.minimax.io/anthropic。
            endpoint = "https://api.minimaxi.com/anthropic",

            -- 默认模型给 M3（当前旗舰）而不是 M3.1-Flash-Preview：
            -- Flash 的 thinking 关不掉（显式发 thinking:{"type":"disabled"}
            -- 会被 400 拒），且不传 effort 时默认按 max 档跑——一次 32 token 的
            -- 试调用里 28 token 都花在 thinking 上，日常 agentic 编辑会明显变慢。
            -- Flash 更快更便宜，留给需要时从 /model 里手动切。
            model = "MiniMax-M3",

            -- /model 选择器的候选列表。
            --
            -- 为什么需要这一段：avante 0.2.3 的 claude provider 没有 list_models
            -- 实现，而 model_selector.lua:56-79 对一个既没有 list_models 又
            -- 没有 model_names 的 provider 只会列出 model 那一条。所以之前
            -- 选择器里只有 M2.1 —— 不是 MiniMax 没给模型，是这里没登记。
            -- （上游自己的 bedrock provider 默认值也是用 model_names 实现的，
            -- 见 config.lua:651。）
            --
            -- 这份列表照抄官方 https://api.minimaxi.com/anthropic/v1/models 的
            -- 返回（2026-10 实测，含 Anthropic 兼容端点确实在列的 highspeed 变体）。
            -- 以后 MiniMax 上新模型，重跑一次那条 curl 把新 id 补进来即可。
            model_names = {
              "MiniMax-M3.1-Flash-Preview",
              "MiniMax-M3",
              "MiniMax-M2.7",
              "MiniMax-M2.7-highspeed",
              "MiniMax-M2.5",
              "MiniMax-M2.5-highspeed",
              "MiniMax-M2.1",
              "MiniMax-M2.1-highspeed",
              "MiniMax-M2",
            },

            -- avante 先找 AVANTE_MINIMAX_CN_API_KEY，找不到再回落
            -- MINIMAX_CN_API_KEY（上游 providers/init.lua 的 parse_envvar）。
            -- 后者已经由 modules/home/xumel/secrets.nix 从 /run/agenix/ai-env
            -- 按变量名取出并 export，nvim 从 shell 继承得到——所以这里不需要
            -- 再在 nix 里存第二份明文，也不会因为 rebuild 丢掉 key。
            api_key_name = "MINIMAX_CN_API_KEY",

            -- 默认 30s 对 agentic 模式不够（要读仓库 + 跑工具），放到 5min。
            timeout = 300000,
            extra_request_body = {
              -- 保守值：M3 / M3.1-Flash 的上限都在 512K output tokens 以内，
              -- 32768 足够一次完整的文件改写，又不会让跑飞的请求烧掉一大截额度。
              max_tokens = 32768,
            },
          },
        },

        windows = {
          -- 侧边栏放左边（用户要求）。
          position = "left",
          width = 30,
        },

        -- 选择器统一用 telescope（nixvim 已带；avante 默认的 native 在
        -- 0.2.3 里功能不全，见上游 README 的 "Choose selector other than native"）。
        selector = {
          provider = "telescope",
        },
        file_selector = {
          provider = "telescope",
        },

        behaviour = {
          -- 自动补全建议是实验特性，且对 provider 的调用频率很高（上游
          -- README 明确警告过 token 消耗），默认关掉。需要时用 <leader>as
          -- 临时打开。
          auto_suggestions = false,
        },
      })
    '';

    # `<leader>a*` 键位统一写在 ../keymaps.nix（和仓库其它键位同一处维护）。
    # avante 自己的 auto_set_keymaps 用的是 Utils.safe_keymap_set
    # （上游 init.lua:182），**不会覆盖已存在的映射**，所以 keymaps.nix 里
    # 显式声明的那套才是最终生效的，which-key 也才能正确显示。
    #
    # 文件图标由 ui.nix 里已启用的 mini.icons 提供，avante 会自动用它。
  };
}
