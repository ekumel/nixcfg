# fcitx5-rime 的用户级配置（雾凇拼音）。
#
# 系统层的 fcitx5 本体与 addons 见 modules/nixos/system/input-method.nix；
# 这里只把词库 / 方案 / 自定义补丁放进 ~/.local/share/fcitx5/rime/。
{ pkgs, ... }:

{
  xdg.dataFile = {
    # rime-ice 基础文件
    "fcitx5/rime/rime_ice.schema.yaml".source = "${pkgs.rime-ice}/share/rime-data/rime_ice.schema.yaml";

    "fcitx5/rime/rime_ice.dict.yaml".source = "${pkgs.rime-ice}/share/rime-data/rime_ice.dict.yaml";

    "fcitx5/rime/double_pinyin_flypy.schema.yaml".source =
      "${pkgs.rime-ice}/share/rime-data/double_pinyin_flypy.schema.yaml";

    # opencc 目录
    "fcitx5/rime/opencc".source = "${pkgs.rime-ice}/share/rime-data/opencc";

    # 自己的配置
    "fcitx5/rime/default.custom.yaml".text = ''
      patch:
        __include: rime_ice_suggestion:/

        schema_list:
          - schema: double_pinyin_flypy
    '';

    "fcitx5/rime/double_pinyin_flypy.custom.yaml".text = ''
      patch:
        "menu/page_size": 9
    '';
  };
}
