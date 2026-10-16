# Markdown：render-markdown（buffer 内渲染）+ markdown-preview（浏览器预览）。
#
# render-markdown 这里不用 nixvim 的 `plugins.render-markdown.settings`：
# 它要设的 `file_types` 不在 nixvim 暴露的 settingsOptions 白名单里
# （nixvim 只列了 wiki 里 "Useful Configuration Options" 的一部分，
# 见 nixvim plugins/by-name/render-markdown/default.nix），
# 所以关掉 nixvim 生成的 setup 调用，在这里用一次显式 setup 统一配置，
# 避免同一份配置散在两处。
#
# 顺带说明：render-markdown 0.2.x 已经**不读** `vim.g.render_markdown_*`
# 了（只有 lazy.nvim 的 ft 会被采纳，见上游 lua/render-markdown/init.lua:162-168），
# 所以想扩 filetypes 只能走 setup()。
{ ... }:

{
  programs.nixvim = {
    plugins = {
      # in-buffer 渲染（标题 / checkboxes / 代码块 / 引号块）
      render-markdown = {
        enable = true;
        # 由下面的 extraConfigLua 统一调用 setup()
        callSetup = false;
      };

      # 浏览器预览（依赖 node / pandoc 之类的，由 markdown-preview 自己提示）
      markdown-preview = {
        enable = true;
      };
    };

    extraConfigLua = ''
      require("render-markdown").setup({
        -- Avante 的 ft：AI 回复是 markdown，不加的话侧边栏里看到的是原始
        -- "**粗体**" / "## 标题" 文本。上游 issue #175 明确要求把它加进来。
        file_types = { "markdown", "Avante" },
        -- 不处理 latex（系统没装 utftex/latex2text，开启会 health 报警）
        latex = { enabled = false },
      })
    '';
  };
}