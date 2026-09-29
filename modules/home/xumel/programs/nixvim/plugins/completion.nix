# 补全：nvim-cmp + LuaSnip + friendly-snippets。
#
# nvim-cmp 是 backup nvim 的选择（nixvim 自带的是 blink-cmp）。
# nvim-cmp 从 extraPlugins 补（见 ./default.nix），LuaSnip / friendly-snippets
# 用 nixvim 自带模块；具体 setup 里的 mapping / sources 走 extraConfigLua。
{ ... }:

{
  programs.nixvim = {
    plugins = {
      # nixvim 没有自动启用 blink-cmp，显式关掉以免和 nvim-cmp 重复弹窗
      blink-cmp.enable = false;

      # 片段引擎（cmp_luasnip 依赖）
      luasnip = {
        enable = true;
        settings = {
          history = true;
          updateevents = "TextChanged,TextChangedI";
        };
      };

      # 社区片段合集（VSCode 风格）
      friendly-snippets.enable = true;
    };
  };

  programs.nixvim.extraConfigLua = ''
    -- LSP 能力：把 cmp_nvim_lsp 的能力注册到所有新的 vim.lsp client。
    -- 必须在 client 启动前设置（vim.lsp.config("*", ...) 是全局默认）。
    local cmp_capabilities = vim.lsp.protocol.make_client_capabilities()
    local has_cmp_lsp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
    if has_cmp_lsp then
      cmp_capabilities = vim.tbl_deep_extend(
        "force", cmp_capabilities, cmp_nvim_lsp.default_capabilities()
      )
    end
    vim.lsp.config("*", { capabilities = cmp_capabilities })

    -- nvim-cmp：主补全引擎
    local has_cmp, cmp = pcall(require, "cmp")
    if has_cmp then
      cmp.setup({
        snippet = {
          expand = function(args)
            local ok, luasnip = pcall(require, "luasnip")
            if ok then
              luasnip.lsp_expand(args.body)
            end
          end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-d>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            else
              local ok, luasnip = pcall(require, "luasnip")
              if ok and luasnip.expand_or_jumpable() then
                luasnip.expand_or_jump()
              else
                fallback()
              end
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            else
              local ok, luasnip = pcall(require, "luasnip")
              if ok and luasnip.jumpable(-1) then
                luasnip.jump(-1)
              else
                fallback()
              end
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
        }, {
          { name = "buffer" },
        }),
        formatting = {
          fields = { "kind", "abbr", "menu" },
          format = function(entry, vim_item)
            local kind = ({
              Text = " ", Method = "M", Function = "F", Constructor = "C",
              Field = "F_", Variable = "V", Class = "CL", Interface = "I",
              Module = "MD", Property = "P", Unit = "U", Value = "VA",
              Enum = "E", Keyword = "K", Snippet = "SN", Color = "CO",
              File = "FI", Reference = "R", Folder = "D", EnumMember = "EM",
              Constant = "C", Struct = "ST", Event = "EV", Operator = "O",
              TypeParameter = "T",
            })[vim_item.kind]
            vim_item.kind = kind or ""
            vim_item.menu = ({
              nvim_lsp = "[LSP]",
              luasnip = "[Snip]",
              buffer = "[Buf]",
              path = "[Path]",
            })[entry.source.name]
            return vim_item
          end,
        },
        experimental = { ghost_text = true; },
      })

      -- 与 nvim-autopairs 联动：避免 cmp 接受时 autopairs 重复加括号
      local has_ap, ap_cmp = pcall(require, "nvim-autopairs.completion.cmp")
      if has_ap then
        cmp.event:on("confirm_done", ap_cmp.on_confirm_done())
      end
    end
  '';
}