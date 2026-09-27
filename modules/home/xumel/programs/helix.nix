# Helix：终端模态编辑器（命令 `hx`），与 nixvim 并存。
#
# home-manager 生成两个文件：
#   ~/.config/helix/config.toml     编辑器行为 / 主题名
#   ~/.config/helix/languages.toml  LSP 服务器 + 保存时格式化
#
# 主题：theme = "matugen"，该文件由 DMS（matugen）在壁纸 / 明暗模式变化时
# 运行时写入 ~/.config/helix/themes/matugen.toml（模板见
# matugen-templates/helix-theme.toml，注册见 programs/matugen.nix）。
# 与 starship / yazi 同一范式：输出路径不能进 home-manager（软链到只读
# store 后 matugen 无法覆盖）。matugen 还没跑过时 Helix 提示主题缺失并
# 回退内置 default 主题；模式切换后由 programs/dms-mode-hook.nix 里的
# `pkill -USR1 hx` 触发配置 / 主题重载。
{ pkgs, lib, ... }:

let
  inherit (lib) getExe getExe';

  # 格式化参数按 nixvim conform.nvim 的默认值对齐（stdin → stdout）。
  prettier = {
    command = getExe pkgs.prettier;
    args = [
      "--stdin-filepath"
      "%{buffer_name}"
    ];
  };

  # 走 prettier 的语言（与 conform 的 formatters_by_ft 一致）。
  prettierLanguages = [
    "javascript"
    "typescript"
    "json"
    "yaml"
    "css"
    "html"
  ];
in
{
  programs.helix = {
    enable = true;

    # 不抢 nixvim 的默认编辑器位置；需要 $EDITOR/$VISUAL=hx 时再打开：
    #   defaultEditor = true;

    settings = {
      theme = "matugen";

      editor = {
        line-number = "relative";
        cursorline = true;
        scrolloff = 8;
        mouse = true;
        bufferline = "multiple";
        color-modes = true;
        true-color = true;
        indent-guides.render = true;

        cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };

        # 与 telescope 一致：文件选择器显示隐藏文件。
        file-picker.hidden = false;

        lsp = {
          display-messages = true;
          display-inlay-hints = true;
        };

        statusline = {
          left = [
            "mode"
            "spinner"
            "file-name"
            "file-modification-indicator"
          ];
          center = [ "diagnostics" ];
          right = [
            "selections"
            "position"
            "file-encoding"
            "file-type"
            "version-control"
          ];
        };
      };

      # Space 前缀对齐 nixvim 的 <leader> 习惯（Helix 默认未占用 space）。
      keys.normal = {
        space.space = "file_picker";
        space.w = ":write";
        space.q = ":quit";
      };
    };

    languages = {
      language-server = {
        # Rust：与 nixvim（plugins/lsp-servers.nix + plugins/rust.nix）同一套 RA 配置。
        "rust-analyzer" = {
          command = getExe pkgs.rust-analyzer;
          config = {
            cargo.allFeatures = true;
            check = {
              command = "clippy";
              allTargets = true;
              extraArgs = [ "--all-features" ];
            };
            inlayHints = {
              enable = true;
              parameterHints = true;
              typeHints = true;
              chainingHints = true;
              closureCapture = {
                enable = true;
                limits.maxCaptureCount = 3;
              };
            };
          };
        };

        # 本仓库的主力语言：nil 只分析 *.nix（nixd 未安装，不再引用）。
        nil.command = getExe pkgs.nil;

        "lua-language-server" = {
          command = getExe pkgs.lua-language-server;
          config.Lua = {
            runtime.version = "LuaJIT";
            diagnostics.globals = [ "vim" ];
            workspace.checkThirdParty = false;
            telemetry.enable = false;
          };
        };

        pyright = {
          command = getExe' pkgs.pyright "pyright-langserver";
          args = [ "--stdio" ];
        };
      };

      language = [
        {
          name = "nix";
          language-servers = [ "nil" ];
          formatter = {
            command = getExe pkgs.nixfmt;
          };
        }
        {
          name = "rust";
          language-servers = [ "rust-analyzer" ];
          formatter = {
            command = getExe pkgs.rustfmt;
          };
        }
        {
          name = "python";
          language-servers = [ "pyright" ];
          formatter = {
            command = getExe pkgs.black;
            args = [
              "--stdin-filename"
              "%{buffer_name}"
              "--quiet"
              "-"
            ];
          };
        }
        {
          name = "lua";
          language-servers = [ "lua-language-server" ];
          formatter = {
            command = getExe pkgs.stylua;
            args = [
              "--search-parent-directories"
              "--respect-ignores"
              "--stdin-filepath"
              "%{buffer_name}"
              "-"
            ];
          };
        }
        {
          name = "bash";
          formatter = {
            command = getExe pkgs.shfmt;
            args = [
              "-filename"
              "%{buffer_name}"
            ];
          };
        }
        {
          name = "toml";
          formatter = {
            command = getExe pkgs.taplo;
            args = [
              "format"
              "--stdin-filepath"
              "%{buffer_name}"
              "-"
            ];
          };
        }
      ]
      ++ map (name: {
        inherit name;
        formatter = prettier;
      }) prettierLanguages;
    };
  };
}
