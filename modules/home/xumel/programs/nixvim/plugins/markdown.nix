# Markdown：render-markdown（buffer 内渲染）+ markdown-preview（浏览器预览）。
{ ... }:

{
  programs.nixvim = {
    # in-buffer 渲染（标题 / checkboxes / 代码块 / 引号块）
    plugins.render-markdown = {
      enable = true;
      settings = {
        # 不处理 latex（系统没装 utftex/latex2text，开启会 health 报警）
        latex.enabled = false;
      };
    };

    # 浏览器预览（依赖 node / pandoc 之类的，由 markdown-preview 自己提示）
    plugins.markdown-preview = {
      enable = true;
    };
  };
}
