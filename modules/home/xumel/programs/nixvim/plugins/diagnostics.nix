# Error-Lens 风格的内联诊断（每行诊断消息直接显示在源码旁）。
{ ... }:

{
  programs.nixvim = {
    plugins.tiny-inline-diagnostic = {
      enable = true;
      settings = {
        preset = "modern";
        transparent_bg = false;
        options = {
          show_source = { enabled = true; if_many = true; };
          show_code = true;
          show_related = { enabled = true; max_count = 3; };
          add_messages = {
            messages = true;
            display_count = false;
            use_max_severity = false;
            show_multiple_glyphs = true;
          };
          set_arrow_to_diag_color = false;
          use_icons_from_diagnostic = false;
          throttle = 20;
          multilines = { enabled = true; always_show = true; trim_whitespaces = false; };
          show_diags_only_under_cursor = false;
          enable_on_insert = false;
          enable_on_select = false;
          overflow.mode = "oneline";
          break_line.enabled = false;
          virt_texts.priority = 2048;
          # severity 接受字符串枚举（"error" / "warn" / "info" / "hint"），
          # nixvim 会自动映射到 vim.diagnostic.severity.* 数值。
          severity = [ "error" "warn" "info" "hint" ];
        };
      };
    };
  };
}