# 全局键位（合并自 backup/nvim 的 lua/config/keymaps.lua 与本地习惯）。
#
# 习惯：
#   <leader>          = Space
#   <leader>e         文件树（neo-tree）
#   <leader>ff / fg   文件 / 内容模糊搜索（telescope）
#   <leader>b         缓冲区（bufferline 跳转 / 关闭 / 重排）
#   <leader>g         git（gitsigns / diffview / neogit）
#   <leader>r         refactor（rust cargo 任务 / LSP rename / code action）
#   <leader>a         agentic (AI 助手)
#   <leader>m         markdown 渲染 / 预览
#   <leader>t         terminal 调度
#   <C-h/j/k/l>       窗口焦点
#   <C-\>             terminal 切换（toggleterm）
#   <leader>tt        terminal toggle
#
# `programs.nixvim.keymaps` 是顶层 listOf<keymap-submodule>，
# 选项里 `desc` / `silent` / `expr` / `noremap` 等都在 `options = { ... }` 子集中。
#
# 注意 action 的两种形态：
#   1. 普通字符串  = vim 会按 vimscript 表达式 / 命令 / 按键序列解释
#      （带 `expr = true` 时整串按 vimscript 表达式求值，例如 `v:count == 0 ? ... : ...`）
#   2. `action.__raw = "<lua>"` 会被 nixvim 原样塞进生成的 Lua。
#      但 `vim.keymap.set(mode, lhs, rhs, opts)` 的 `rhs` 必须是可调用对象，
#      所以"裸" require / 模块方法调用在这里都会被当作 rhs 求值然后失败；
#      必须显式包成 `function() ... end`。
{ ... }:

let
  # 把一段裸 Lua 包成 `function() ... end`，方便 keymap action 用。
  # 多行 raw 也行（每行会被包进函数体）。
  fn = body: "function() ${body} end";
in
{
  programs.nixvim.keymaps = [
    # ============================================================
    # 编辑 / 移动（来自 backup keymaps.lua）
    # ============================================================
    # gj / gk 在非 count 下落到行尾 / 行首（更符合视觉行直觉）
    # 用普通 string + expr = true：vim 会按 vimscript 表达式求值。
    { mode = "n"; key = "j"; action = "v:count == 0 ? 'gj' : 'j'"; options.expr = true; options.silent = true; options.desc = "Down (gj if no count)"; }
    { mode = "n"; key = "k"; action = "v:count == 0 ? 'gk' : 'k'"; options.expr = true; options.silent = true; options.desc = "Up (gk if no count)"; }

    # 上下移行（normal/visual 模式）
    { mode = "n"; key = "<A-j>"; action = ":m .+1<CR>=="; options.desc = "Move line down"; }
    { mode = "n"; key = "<A-k>"; action = ":m .-2<CR>=="; options.desc = "Move line up"; }
    { mode = "v"; key = "<A-j>"; action = ":m '>+1<CR>gv=gv"; options.desc = "Move selection down"; }
    { mode = "v"; key = "<A-k>"; action = ":m '<-2<CR>gv=gv"; options.desc = "Move selection up"; }

    # 搜索时保持光标居中
    { mode = "n"; key = "n"; action = "nzz"; options.desc = "Next match (centered)"; }
    { mode = "n"; key = "N"; action = "Nzz"; options.desc = "Prev match (centered)"; }

    # visual p → 不污染寄存器地粘贴
    { mode = "v"; key = "p"; action = "\"_dP"; options.desc = "Paste without yanking"; }

    # x 当成剪切前缀（which-key 才能弹出操作符 / text-object 帮助）
    { mode = [ "n" "x" ]; key = "x"; action = "\"+d"; options.desc = "Cut to clipboard"; }

    # 清搜索高亮
    { mode = "n"; key = "<Esc>"; action = "<cmd>nohlsearch<cr>"; options.desc = "Clear hlsearch"; }

    # 翻页保持光标列
    { mode = "n"; key = "<C-d>"; action = "<C-d>zz"; options.desc = "Half-page down (centered)"; }
    { mode = "n"; key = "<C-u>"; action = "<C-u>zz"; options.desc = "Half-page up (centered)"; }

    # 缩进可视化（v 模式下整体缩进）
    { mode = "v"; key = "<"; action = "<gv"; options.desc = "Indent left"; }
    { mode = "v"; key = ">"; action = ">gv"; options.desc = "Indent right"; }

    # ============================================================
    # 窗口管理（来自 backup）
    # ============================================================
    { mode = "n"; key = "<C-h>"; action = "<C-w>h"; options.desc = "Window left"; }
    { mode = "n"; key = "<C-j>"; action = "<C-w>j"; options.desc = "Window down"; }
    { mode = "n"; key = "<C-k>"; action = "<C-w>k"; options.desc = "Window up"; }
    { mode = "n"; key = "<C-l>"; action = "<C-w>l"; options.desc = "Window right"; }

    # 调整分屏大小
    { mode = "n"; key = "<C-Up>";    action = "<cmd>resize +2<CR>";  options.desc = "Increase height"; }
    { mode = "n"; key = "<C-Down>";  action = "<cmd>resize -2<CR>";  options.desc = "Decrease height"; }
    { mode = "n"; key = "<C-Left>";  action = "<cmd>vertical resize -2<CR>"; options.desc = "Decrease width"; }
    { mode = "n"; key = "<C-Right>"; action = "<cmd>vertical resize +2<CR>"; options.desc = "Increase width"; }

    # 新分屏
    { mode = "n"; key = "|"; action = "<cmd>vsplit<CR>";   options.desc = "Vertical split"; }
    { mode = "n"; key = "-"; action = "<cmd>split<CR>";     options.desc = "Horizontal split"; }

    # 居中 / 顶 / 底（本地习惯）
    # 注意：不要用 `<leader>t` / `<leader>b` 这种单键，否则会和 `<leader>tt` / `<leader>bb`
    # 等组前缀冲突，导致 vim 每次都要等 timeoutlen 才响应。
    { mode = "n"; key = "<leader>zz"; action = "zz"; options.desc = "Cursor center"; }
    { mode = "n"; key = "<leader>zt"; action = "zt"; options.desc = "Cursor top"; }
    { mode = "n"; key = "<leader>zb"; action = "zb"; options.desc = "Cursor bottom"; }

    # 快速保存 / 退出
    { mode = "n"; key = "<leader>w"; action = "<cmd>write<cr>";           options.desc = "Save file"; }
    { mode = "n"; key = "<leader>q"; action = "<cmd>confirm quit<cr>";    options.desc = "Quit"; }
    { mode = "n"; key = "<leader>Q"; action = "<cmd>confirm qall<cr>";   options.desc = "Quit all"; }

    # 系统剪贴板
    { mode = "v"; key = "<leader>y"; action = "\"+y"; options.desc = "Yank to clipboard"; }
    { mode = "v"; key = "<leader>d"; action = "\"+d"; options.desc = "Cut to clipboard"; }
    { mode = "n"; key = "<leader>Y"; action = "\"+Y"; options.desc = "Yank line to clipboard"; }

    # ============================================================
    # 缓冲区（bufferline）
    # ============================================================
    { mode = "n"; key = "<Tab>";   action = "<cmd>BufferLineCycleNext<CR>"; options.desc = "Next buffer"; }
    { mode = "n"; key = "<S-Tab>"; action = "<cmd>BufferLineCyclePrev<CR>"; options.desc = "Prev buffer"; }

    { mode = "n"; key = "<leader>x"; action = "<cmd>bdelete<CR>";             options.desc = "Close current buffer"; }
    { mode = "n"; key = "<leader>X"; action = "<cmd>BufferLineCloseOthers<CR>"; options.desc = "Close other buffers"; }

    { mode = "n"; key = "<leader>bd"; action = "<cmd>bdelete<CR>";             options.desc = "Close current buffer"; }
    { mode = "n"; key = "<leader>bD"; action = "<cmd>BufferLineCloseOthers<CR>"; options.desc = "Close other buffers"; }
    { mode = "n"; key = "<leader>bl"; action = "<cmd>BufferLineCloseLeft<CR>";   options.desc = "Close buffers to the left"; }
    { mode = "n"; key = "<leader>br"; action = "<cmd>BufferLineCloseRight<CR>";  options.desc = "Close buffers to the right"; }
    { mode = "n"; key = "<leader>bb"; action = "<cmd>BufferLinePick<CR>";        options.desc = "Pick buffer"; }
    { mode = "n"; key = "<leader>bn"; action = "<cmd>BufferLineCycleNext<CR>";   options.desc = "Next buffer"; }
    { mode = "n"; key = "<leader>bp"; action = "<cmd>BufferLineCyclePrev<CR>";   options.desc = "Prev buffer"; }
    { mode = "n"; key = "<leader>bj"; action = "<cmd>BufferLineMoveNext<CR>";    options.desc = "Move buffer right"; }
    { mode = "n"; key = "<leader>bk"; action = "<cmd>BufferLineMovePrev<CR>";    options.desc = "Move buffer left"; }

    # ============================================================
    # 终端（toggleterm）
    # ============================================================
    { mode = "n"; key = "<leader>tt"; action = "<cmd>ToggleTerm<CR>";                  options.desc = "Toggle terminal"; }
    { mode = "n"; key = "<leader>tf"; action = "<cmd>ToggleTerm direction=float<CR>"; options.desc = "Float terminal"; }
    { mode = "t"; key = "<Esc><Esc>"; action = "<C-\\><C-n>";                          options.desc = "Exit terminal to Normal"; }

    # ============================================================
    # 文件树（neo-tree）
    # ============================================================
    { mode = "n"; key = "<leader>e";  action = "<cmd>Neotree toggle<cr>";            options.desc = "Toggle file tree"; }
    { mode = "n"; key = "<leader>o";  action = "<cmd>Neotree show_old_file<cr>";    options.desc = "Reveal current file"; }
    { mode = "n"; key = "<leader>fp"; action = "<cmd>Neotree filesystem reveal<cr>"; options.desc = "Reveal in tree"; }

    # ============================================================
    # Telescope 搜索（每个都需要 `function() ... end` 包装）
    # ============================================================
    { mode = "n"; key = "<leader>ff";  action.__raw = fn "require('telescope.builtin').find_files()"; options.desc = "Find files"; }
    { mode = "n"; key = "<leader>fg";  action.__raw = fn "require('telescope.builtin').live_grep()";  options.desc = "Live grep"; }
    { mode = "n"; key = "<leader>fb";  action.__raw = fn "require('telescope.builtin').buffers()";    options.desc = "Buffers"; }
    { mode = "n"; key = "<leader>fh";  action.__raw = fn "require('telescope.builtin').help_tags()";  options.desc = "Help tags"; }
    { mode = "n"; key = "<leader>fr";  action.__raw = fn "require('telescope.builtin').oldfiles()";   options.desc = "Recent files"; }
    { mode = "n"; key = "<leader>fc";  action.__raw = fn "require('telescope.builtin').commands()";   options.desc = "Commands"; }
    { mode = "n"; key = "<leader>fs";  action.__raw = fn "require('telescope.builtin').lsp_document_symbols()";     options.desc = "Doc symbols"; }
    { mode = "n"; key = "<leader>fS";  action.__raw = fn "require('telescope.builtin').lsp_dynamic_workspace_symbols()"; options.desc = "Workspace symbols"; }
    { mode = "n"; key = "<leader>f?r"; action.__raw = fn "require('telescope.builtin').registers()"; options.desc = "Registers"; }
    # 用 <leader>fw / <leader>fT 而不是 fsw / fth，避免与 <leader>fs / <leader>ft 形成
    # 前缀重叠（那样每次按 <leader>fs 都要等 timeoutlen）。
    { mode = "n"; key = "<leader>fw"; action.__raw = fn "require('telescope.builtin').grep_string()"; options.desc = "Grep word under cursor"; }
    { mode = "n"; key = "<leader>fT"; action.__raw = fn "require('telescope.builtin').colorscheme()"; options.desc = "Colorscheme/Theme"; }
    { mode = "n"; key = "<leader>ft";  action.__raw = fn "require('telescope.builtin').todo()"; options.desc = "TODO comments"; }
    { mode = "n"; key = "<leader>fd";  action.__raw = fn "require('telescope.builtin').diagnostics()"; options.desc = "Diagnostics"; }
    { mode = "n"; key = "<leader>gs";  action.__raw = fn "require('telescope.builtin').git_files()"; options.desc = "Git files"; }
    { mode = "n"; key = "<leader>gc";  action.__raw = fn "require('telescope.builtin').git_status()"; options.desc = "Git status"; }

    # ============================================================
    # LSP（Neovim 0.11 已内置 gd/gD/gi/gr*/K，不再重复映射，避免与 `gr*` 默认组冲突）
    # ============================================================
    # 只补 leader 前缀的常用操作：
    { mode = "n"; key = "<leader>rn"; action.__raw = fn "vim.lsp.buf.rename()";        options.desc = "LSP rename"; }
    { mode = "n"; key = "<leader>ca"; action.__raw = fn "vim.lsp.buf.code_action()";   options.desc = "LSP code action"; }
    # 格式化放 <leader>cf（Code Format），避开 <leader>f* 搜索组前缀
    { mode = "n"; key = "<leader>cf"; action.__raw = fn "vim.lsp.buf.format({ async = true })"; options.desc = "LSP format buffer"; }
    { mode = "n"; key = "<leader>cwa"; action.__raw = fn "vim.lsp.buf.add_workspace_folder()";    options.desc = "Add workspace folder"; }
    { mode = "n"; key = "<leader>cwr"; action.__raw = fn "vim.lsp.buf.remove_workspace_folder()"; options.desc = "Remove workspace folder"; }

    # 诊断快速跳转
    { mode = "n"; key = "<leader>dd"; action.__raw = fn "vim.diagnostic.open_float()"; options.desc = "Float diagnostics"; }
    { mode = "n"; key = "[d";         action.__raw = fn "vim.diagnostic.goto_prev()";  options.desc = "Prev diagnostic"; }
    { mode = "n"; key = "]d";         action.__raw = fn "vim.diagnostic.goto_next()";  options.desc = "Next diagnostic"; }

    # ============================================================
    # Git（gitsigns / diffview / neogit）
    # ============================================================
    # gitsigns.next_hunk/prev_hunk 必须在 schedule 内（避免快速按键丢失）
    { mode = "n"; key = "]c"; action.__raw = fn "vim.schedule(function() require('gitsigns').next_hunk() end)"; options.desc = "Next hunk"; }
    { mode = "n"; key = "[c"; action.__raw = fn "vim.schedule(function() require('gitsigns').prev_hunk() end)"; options.desc = "Prev hunk"; }
    { mode = "n"; key = "<leader>gs"; action.__raw = fn "require('gitsigns').stage_hunk()";   options.desc = "Stage hunk"; }
    { mode = "n"; key = "<leader>gr"; action.__raw = fn "require('gitsigns').reset_hunk()";   options.desc = "Reset hunk"; }
    { mode = "n"; key = "<leader>gS"; action.__raw = fn "require('gitsigns').stage_buffer()"; options.desc = "Stage buffer"; }
    { mode = "n"; key = "<leader>gp"; action = "<cmd>Gitsigns preview_hunk_inline<cr>";   options.desc = "Preview hunk"; }
    { mode = "n"; key = "<leader>gb"; action = "<cmd>Gitsigns blame_line<cr>";            options.desc = "Blame line"; }
    { mode = "n"; key = "<leader>gd"; action = "<cmd>Gitsigns diffthis<cr>";              options.desc = "Diff this"; }

    { mode = "n"; key = "<leader>gv"; action = "<cmd>DiffviewOpen<CR>";           options.desc = "Diffview open"; }
    { mode = "n"; key = "<leader>gV"; action = "<cmd>DiffviewFileHistory<CR>";    options.desc = "Diffview file history"; }
    { mode = "n"; key = "<leader>gg"; action = "<cmd>Neogit<CR>";                options.desc = "Neogit status"; }

    # ============================================================
    # Conform（格式化）
    # ============================================================
    { mode = "n"; key = "<leader>fm"; action = "<cmd>ConformInfo<cr>"; options.desc = "Conform info"; }

    # ============================================================
    # Markdown（render-markdown / markdown-preview）
    # ============================================================
    { mode = "n"; key = "<leader>mr"; action = "<cmd>RenderMarkdown toggle<CR>";    options.desc = "Toggle markdown render"; }
    { mode = "n"; key = "<leader>mp"; action = "<cmd>MarkdownPreviewToggle<CR>";    options.desc = "Toggle markdown preview"; }

    # ============================================================
    # 编辑增强
    # ============================================================
    { mode = "n"; key = "<leader>ig"; action.__raw = fn "require('blink.indent').enable(not require('blink.indent').is_enabled())"; options.desc = "Toggle indent guides"; }

    # ============================================================
    # Hop（快速跳转）
    # ============================================================
    { mode = "n"; key = "<leader>js"; action.__raw = fn "require('hop').hint_char2()";  options.desc = "Hop characters"; }
    { mode = "n"; key = "<leader>jw"; action.__raw = fn "require('hop').hint_words()";  options.desc = "Hop word"; }
    { mode = "n"; key = "<leader>jl"; action.__raw = fn "require('hop').hint_lines()";  options.desc = "Hop line"; }
    { mode = [ "n" "x" "o" ]; key = "s"; action.__raw = fn "require('hop').hint_char2()";    options.desc = "Hop jump (2 chars)"; }
    { mode = [ "n" "x" "o" ]; key = "S"; action.__raw = fn "require('hop').hint_words()";    options.desc = "Hop word"; }
    { mode = [ "n" "x" "o" ]; key = "F"; action.__raw = fn "require('hop').hint_vertical()"; options.desc = "Hop vertical"; }

    # ============================================================
    # Rust（rustaceanvim 提供 cargo 集成）
    # ============================================================
    { mode = "n"; key = "<leader>rr"; action.__raw = fn "require('rustaceanvim.run_split').run('cargo run')";   options.desc = "cargo run"; }
    { mode = "n"; key = "<leader>rb"; action.__raw = fn "require('rustaceanvim.run_split').run('cargo build')"; options.desc = "cargo build"; }
    { mode = "n"; key = "<leader>rt"; action.__raw = fn "require('rustaceanvim.run_split').run('cargo test')";  options.desc = "cargo test"; }
    { mode = "n"; key = "<leader>rc"; action.__raw = fn "require('rustaceanvim.run_split').run('cargo check')"; options.desc = "cargo check"; }
    { mode = "n"; key = "<leader>rD"; action.__raw = fn "require('rustaceanvim.run_split').run('cargo doc')";   options.desc = "cargo doc"; }
  ];
}