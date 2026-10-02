# Ollama 本地推理服务：混元翻译（HY-MT1.5）+ GLM-OCR。
#
# 硬件：本机 AMD Radeon RX 9060 XT 16GB（PCI 1002:7590，gfx1201 / RDNA 4），
# 走 pkgs.ollama-rocm。选 ROCm 而非 Vulkan 的依据：
#   - nixpkgs 锁定的 ROCm 是 7.2.3，rocmPackages.clr.gpuTargets 里显式包含
#     gfx1201（还单列了 gfx1201 这个包），即 RX 9060 XT 属于官方编译目标；
#   - ollama 0.34.3 早已越过 RDNA4 原生识别的版本节点（启动日志会出现
#     library=ROCm compute=gfx1200），不需要 HSA_OVERRIDE_GFX_VERSION 兜底；
#   - Vulkan（ollama-vulkan / OLLAMA_VULKAN=1）只作为 ROCm 万一不工作时的
#     备选，通常比 ROCm 慢 5~10%。
#
# 内核侧前置条件已由 modules/nixos/desktop/default.nix 的
# hardware.graphics.enable = true 满足（amdgpu 已加载，/dev/dri/renderD128
# 存在）。ollama 的 systemd 单元自带 SupplementaryGroups = [ "render" ]，
# 不依赖用户组。
#
# 模型走 services.ollama.loadModels 声明式管理：ollama.service 起来后
# ollama-model-loader.service 自动并行 `ollama pull`，nixos-rebuild 幂等。
# syncModels 保持 false —— 手动 ollama pull 的其它模型不会被自动删掉。
{ pkgs, ... }:

{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;

    # 仅本机可用：不开防火墙端口，局域网内的手机/平板连不上（默认取向）。
    # 要让局域网设备访问，改成 host = "0.0.0.0" 并 openFirewall = true。
    host = "127.0.0.1";
    port = 11434;
    openFirewall = false;

    # gfx1201 在 ROCm 7.2+ 上是原生目标，通常留 null 即可。
    # 万一 `ollama ps` 显示 100% CPU / 0 VRAM（日志报 "no compatible GPUs"），
    # 改成 "12.0.1" 让它落到 RDNA4 基线再 rebuild。
    # rocmOverrideGfx = "12.0.1";

    loadModels = [
      # 翻译：腾讯 Hunyuan-MT-1.5-7B 的 Q4_K_M 直量化（社区，4.6GB / 256K 上下文）。
      # 7B 是腾讯自家 WMT25 冠军模型的升级版 —— 术语干预、上下文感知、
      # 保留格式（代码/表格）、混合语种与解释型翻译这些能力都是为 7B 做的，
      # 官方称需 5~8GB 显存，本机 16GB 装下后仍余量充足。
      # 嫌重可换 1.8B（约 1.1GB，短句更快）：
      #   "demonbyron/HY-MT1.5-1.8B:Q4_K_M"
      #
      # 这个翻译模型是 completion 型，不吃 system prompt，提示词要按官方模板走
      # （否则容易输出没人话、重复刷屏）。中译外：
      #   将以下文本翻译为{target_language},注意只需要输出翻译后的结果,不要额外解释: {text}
      # 外译中 / 非中文之间：
      #   Translate the following segment into {target_language}, without additional explanation. {text}
      # 术语干预（前置一行术语对照）：
      #   参考下面的翻译: {源术语} 翻译成 {目标术语}
      # 社区直量化版若出现复读/幻觉，降级到调过采样参数的 1.8B
      # （xieweicong95/HY-MT1.5-1.8B，仅 1.8B 有该调优版）再观察。
      "demonbyron/HY-MT1.5-7B:Q4_K_M"

      # OCR：GLM-OCR 官方模型，只有 0.9B（2.2GB）但 128K 上下文，
      # vision + tools。带 "Text/Table/Figure Recognition" 提示词分别做
      # 文字 / 表格 / 图表识别。
      "glm-ocr"
    ];
  };
}
