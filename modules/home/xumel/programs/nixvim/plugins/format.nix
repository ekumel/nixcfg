# 格式化：conform.nvim。保存时按 filetype 调用相应格式化器。
# 键位统一在 ../keymaps.nix 里。
#
# 注意：markdown 误改行尾会让 git blame 噪声变大，故不放进 formatters_by_ft。
# 需要时单独走 :ConformFormat 命令。
{ pkgs, lib, ... }:

{
  programs.nixvim = {
    plugins.conform-nvim = {
      enable = true;
      settings = {
        notify_on_error = false;

        formatters_by_ft = {
          nix = [ "nixfmt" ];
          rust = [ "rustfmt" ];
          python = [ "black" ];
          javascript = [ "prettier" ];
          typescript = [ "prettier" ];
          json = [ "prettier" ];
          yaml = [ "prettier" ];
          css = [ "prettier" ];
          html = [ "prettier" ];
          sh = [ "shfmt" ];
          bash = [ "shfmt" ];
          fish = [ "fish_indent" ];
          lua = [ "stylua" ];
          toml = [ "taplo" ];
        };

        # 显式给 rustfmt / nixfmt 指定二进制路径（其它走默认 PATH 查找）。
        formatters = {
          nixfmt = {
            command = "${lib.getExe pkgs.nixfmt}";
          };
          rustfmt = {
            command = "${lib.getExe pkgs.rustfmt}";
          };
        };
      };
    };
  };
}
