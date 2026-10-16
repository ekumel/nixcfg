# ArtCraft 全家桶（系统级安装）。
#
# 上游是 storytold 的开源 Adobe 替代品，官方只发 AppImage；ipeglin/artcraft-nix
# 把它拆包 + autoPatchelf 成常规 derivation（见 flake.nix 的 input 注释）。
# 走它自带的 NixOS 模块而不是 home.packages：模块除了装包，还负责把系统字体
# 暴露到 /usr/share/fonts——ArtCraft 的文字工具只查那个固定路径，不走
# fontconfig，缺了这步矢量图 / PDF / 排版里的文字会全部掉字体。
#
# ---- 字体链路 ----
#   fonts.fontDir.enable = true
#     -> 生成 /run/current-system/sw/share/X11/fonts -> ~/.local/share/fonts 软链
#   tmpfiles "L+ /usr/share/fonts -> /run/current-system/sw/share/X11/fonts"
#     -> ArtCraft 真正会去读的路径
#
# 本机 /usr/share 原本不存在（纯 NixOS），所以模块里那条 "d /usr/share 0755"
# 是建目录而非改权限，无副作用。若以后本机自己接管了 /usr/share/fonts，
# 把 linkFonts 关掉、自行维护那条软链即可。
#
# 字体内容来自 modules/nixos/fonts.nix（霞鹜文楷 + 文泉驿正黑 + Maple Mono NF CN
# + Noto Color Emoji），中英文都覆盖到了。
#
# 升级：`nix flake update artcraft` 后 rebuild。上游 CI 每日验证并写入
# versions.json，每个 app 的历史稳定版都保留。
{
  inputs,
  ...
}:

{
  imports = [ inputs.artcraft.nixosModules.default ];

  programs.artcraft = {
    enable = true;

    # 每个条目取该 app 的最新稳定版；要钉版本就写 `photocraft_0_7_0` 这种
    # `<app>_<x>_<y>_<z>` 形式（历史版本上游都留着）。
    #
    # 没装 designcraft：它是 InDesign 替代品（版面排版 / 出版），不在
    # 图像、视频、PDF 这条线里，要用再加进这个列表即可。
    apps = [
      # 图像
      "photocraft" # Photoshop 替代：像素编辑 + 分层 PSD
      "vectorcraft" # Illustrator 替代：矢量 / SVG，也能编辑 PDF
      "lightcraft" # Lightroom 替代：照片整理 + raw 显影

      # 视频
      "filmcraft" # Premiere Pro 替代：剪辑 / 调色 / 混音
      "effectcraft" # After Effects 替代：动效与合成

      # PDF
      "pdfcraft" # Acrobat 替代：阅读 / 合并 / 拆分 / 加密（0.4.0 起更名）
    ];
  };
}
