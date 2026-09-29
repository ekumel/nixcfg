# image.nvim：终端里显示图片（kitty graphics / sixel / ueberzug）。
#
# 为什么不用 nixvim 自带的 `plugins.image` 模块：
#   它会在生成的 init.lua 里**无条件**执行 `require("image").setup({...})`。
#   在 `nvim --headless` / `nvim -es`（无 UI）下，kitty 后端会抛
#     image/backends/kitty/helpers.lua: failed to open stdout
#   而这个错误会**中断整个 init.lua**，导致其后的 hop / 键位 / autocmd
#   全部不生效（例如 headless 里 `hop.opts == nil`、NvimConfig augroup 不存在）。
#
# 因此这里改成：插件仍通过 extraPlugins 提供，但 setup 放到 extraConfigLua 里
# 并用 `#vim.api.nvim_list_uis() > 0` 守卫，只在有真实 UI 时初始化。
{ ... }:

{
  programs.nixvim = {
    # 关掉 nixvim 的 image 模块（避免它的无条件 setup 在 headless 下中断 init.lua）
    plugins.image.enable = false;
  };

  programs.nixvim.extraConfigLua = ''
    -- 仅在存在真实 UI（非 headless / -es）时初始化 image.nvim
    if #vim.api.nvim_list_uis() > 0 then
      local ok, image = pcall(require, "image")
      if ok then
        pcall(image.setup, {
          backend = "kitty",
          processor = "magick_cli",
          integrations = {
            markdown = {
              enabled = true,
              clear_in_insert_mode = false,
              only_render_image_at_cursor = true,
              only_render_image_at_cursor_mode = "popup",
              download_remote_images = true,
            },
            html = { enabled = false },
            css = { enabled = false },
          },
          max_height_window_percentage = 50,
          hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
        })
      end
    end
  '';
}