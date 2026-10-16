-- 欢迎界面（dashboard）与 buffer 生命周期的两条体验修正：
--
-- 1. 关掉最后一个文件 buffer 之后，不要只剩一棵铺满整屏的文件树：
--    自动切到最近用过的 buffer；一个文件都不剩时把欢迎界面拉回来。
-- 2. 欢迎界面的文字按**它自己窗口**的宽度居中，而不是整屏宽度，
--    这样 avante 侧边栏（左侧 30 列）开 / 关时文字都停在编辑区正中。
--
-- ---- 原因 1 ----
-- 是 neo-tree 的 `close_if_last_window = false`（见 plugins/ui.nix）与 Vim 的
-- 窗口关闭语义叠加出来的：`:bdelete` 掉最后一个文件 buffer 时，主窗口因为
-- 没有别的 buffer 可显示而整个消失，neo-tree 就成了唯一窗口，于是被拉满整行。
-- 这里改成：主窗口消失时立刻给它找一个普通 buffer，或者干脆重开欢迎界面，
-- neo-tree 就永远不会是唯一的窗口，也就没有「铺满」这回事。
--
-- ---- 原因 2 ----
-- 上游 dashboard 把居中宽度写死成 `vim.o.columns`（整屏宽度）：
--   lua/dashboard/utils.lua:54
--     table.insert(fills, math.floor((vim.o.columns - vim.api.nvim_strwidth(line)) / 2))
-- 而且这段只在**渲染那一刻**算一次并把结果写进 buffer。它自己的重绘只挂在
-- VimResized 上（lua/dashboard/init.lua:216-222），而开 / 关 avante 只是改
-- 窗口布局、不改屏幕尺寸，那个事件根本不触发 —— 所以文字会停在整屏中点，
-- 相对被挤窄后的编辑区就偏了。
-- 要修就得两件事一起做：把宽度换成 dashboard 自己窗口的宽度，再在窗口
-- 布局变化后重画一次。
--
-- ---- 重画为什么不能直接 `:Dashboard` ----
-- db:instance() 开头就是 `if mode == 'i' or not vim.bo.modifiable then return end`
-- （lua/dashboard/init.lua:261），而渲染完成的 dashboard buffer 恰恰是
-- modifiable = false（theme 收尾时写死，theme/hyper.lua:573）—— 直接
-- `:Dashboard` 会被它**静默挡掉**：不报错，就是不重画。放开 modifiable 倒是能
-- 触发，但它会新开一个 scratch buffer 把旧 buffer 顶掉（bufhidden = wipe），
-- 而 theme 的渲染是**异步**的（theme_instance 里 project_list 走 uv 回调），
-- 上一次还没写完就被擦掉，正文会残缺。
--
-- 所以这里改走上游自己那条路：截下 theme(config) 的 config，原地清空同一个
-- buffer 再用同一个 config 重绘（upstream 的 VimResized 处理器也是这么干的）。
-- buffer 身份不变，在途的异步渲染就不会写到已失效的 buffer 上。
local M = {}

local augroup = "NvimWelcome"

--- 最近一次**真正渲染**时 dashboard 窗口的宽度。nil = 还没渲染过。
---
--- 记录点放在 center_align 里而不是「我们主动拉起欢迎界面」时：渲染路径不止
--- 一条（dashboard 自己在 UIEnter 会自动开、autocmds.nix 的 VimEnter 会显式
--- :Dashboard、用户还能手敲），只在 M.show() 里记的话这个值会陈旧，
--- recenter() 的「宽度没变就跳过」就会误判成没变化而什么也不做。
local rendered_width = nil

--- 上一次渲染用的 config（bufnr / winid / 主题配置都在里面）。
--- 上游只把它关在 load_theme 的闭包里（lua/dashboard/init.lua:195-256），
--- 外部拿不到，所以靠下面 capture_theme_config() 截下来。
local theme_config = nil

--- 包装后的 theme 入口：调它就等于调真theme，顺便把 config 记下来。
local theme_entry = nil

--- 重画进行中标志。theme 渲染是异步的，这里由 DashboardLoaded 事件收尾，
--- 而不是函数返回就置位 —— 否则并发的窗口事件会在上一次还没写完时
--- 把 buffer 擦掉重画，正文会残缺。
local rendering = false

--- 重画请求去抖标志。
local pending = false

-- ============================================================
-- buffer 判定
-- ============================================================

--- 普通文件 buffer：listed、不是特殊类型、而且有名字。
---
--- 前两个条件排除的是特殊 buffer，但它们的排除方式并不统一：
---   - neo-tree / 终端 / avante：`buftype ~= ""`（nofile / terminal）
---   - dashboard：**buflisted = false**。上游 buf_local() 的 opts 表里压根没有
---     buftype，只把 buflisted 设成了 false（lua/dashboard/init.lua:63-88），
---     所以只查 buftype 会把欢迎界面自己当成「普通文件」。
---
--- 第三个条件（必须有名字）同样关键：`:bdelete` 掉最后一个文件 buffer 之后，
--- Vim 会顺手补一个无名的空 buffer —— 它 buflisted = true、buftype = ""，
--- 前两个条件全都通过。若把它算成「还有文件开着」，欢迎界面就永远轮不到出现。
local function is_file_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return false end
  if not vim.bo[buf].buflisted or vim.bo[buf].buftype ~= "" then return false end
  return vim.api.nvim_buf_get_name(buf) ~= ""
end

--- 当前列出的普通文件 buffer。
local function file_bufs()
  local out = {}
  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if is_file_buf(info.bufnr) then table.insert(out, info.bufnr) end
  end
  return out
end

--- 当前 tabpage 里正在显示普通文件的窗口，没有则 nil。
local function file_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_file_buf(vim.api.nvim_win_get_buf(win)) then return win end
  end
end

--- 找一个能承载「普通内容」的窗口；定义在下面的「欢迎界面」一节。
--- focus_mru() 要用它，而那一节在它后面，所以必须提前声明 ——
--- Lua 的 local 是词法作用域，声明写在使用点之后的话，focus_mru 拿到的
--- 会是个 nil 全局，运行时直接报 "attempt to call global 'host_win'"。
local host_win

--- 把 neo-tree 拉回它自己配置的宽度（定义在下面「buffer 判定」一节末尾）。
--- focus_mru() 要用它，同样必须提前声明。
local restore_neo_tree_width

--- 切到最近用过的文件 buffer。getbufinfo 的 lastused 越小越近。
local function focus_mru()
  local target, target_used
  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if is_file_buf(info.bufnr) and (not target_used or info.lastused < target_used) then
      target, target_used = info.bufnr, info.lastused
    end
  end
  if not target then return false end

  -- 必须走 host_win()，**不能**在拿不到普通窗口时退回当前窗口：当前窗口很可能
  -- 正是 neo-tree / 终端那一个，把文件 buffer 塞进去等于把文件树本身顶掉，
  -- 布局随即崩掉（实测：文件树被撑到 78 列、只剩 1 列的空窗口）。
  local win = host_win()
  vim.api.nvim_set_current_win(win)
  vim.fn.bufload(target)
  vim.api.nvim_win_set_buf(win, target)
  restore_neo_tree_width()
  return true
end

--- 把 neo-tree 拉回它自己配置的宽度。
---
--- 为什么必须事后修正：`:bdelete` 掉最后一个文件 buffer 时，Vim 会**直接关掉**
--- 那个窗口 —— 旁边还有窗口的情况下它不会退化成「显示一个空 buffer」，实测就是
--- 整个消失。于是 neo-tree 一瞬间铺满整屏（实测 80 / 80），我们随后补出来的窗口
--- 不过是把一棵满宽的文件树对半分成 40 / 39，看上去仍然是「文件树占满宽度」。
---
--- 想提前拦住是做不到的：实测 `BufWinLeave` 与 `BufDelete` 两个钩子触发时那个
--- 窗口**都已经不存在了**（顺序是「关窗口 → BufWinLeave → BufDelete」），而
--- neo-tree 那个 `close_if_last_window` 选项在 3.42.0 里只声明、只做健康检查，
--- 根本没有消费方，改它没用。所以只能在补完布局之后把宽度改回去。
restore_neo_tree_width = function()
  local ok, mgr = pcall(require, "neo-tree.sources.manager")
  if not ok or type(mgr.get_state) ~= "function" then return end
  local ok2, state = pcall(mgr.get_state, "filesystem")
  if not ok2 or type(state) ~= "table" or type(state.window) ~= "table" then return end

  local width = state.window.width
  -- 只认绝对列数；"50%" 这类比例值交给 neo-tree 自己处理。
  if type(width) ~= "number" or width < 10 then return end
  local win = state.winid
  if not win or not vim.api.nvim_win_is_valid(win) then return end
  if vim.api.nvim_win_get_width(win) <= width then return end

  -- 顺手给编辑区留够宽度，别把树修回去之后编辑区反而被挤没了。
  vim.api.nvim_win_set_width(win, math.min(width, vim.o.columns - 20))
end

-- ============================================================
-- 欢迎界面
-- ============================================================

--- 正在显示 dashboard 的窗口（只在当前 tabpage 里找），没有则 nil。
--- 提前声明：下面好几个函数都要用它。
local dashboard_win

dashboard_win = function()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "dashboard" then return win end
  end
end

--- 找一个能承载欢迎界面的窗口：`buftype` 为空的那种。
---
--- neo-tree 是 nofile、终端是 terminal、avante 也是 nofile，都会被跳过。
--- 没找到说明当前只剩文件树这类窗口 —— 开一个新的，并且用 `topleft`
--- 而不是默认的 `rightbelow`，这样 neo-tree 仍然待在最右（它配的就是
--- position = "right"，见 plugins/ui.nix）。
host_win = function()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" then return win end
  end
  vim.cmd("topleft vsplit")
  return vim.api.nvim_get_current_win()
end

--- 拉起欢迎界面（首次进入，或没有文件 buffer 时用）。
function M.show()
  vim.api.nvim_set_current_win(host_win())

  -- db:instance() 开头是
  --   `if mode == 'i' or not vim.bo.modifiable then return end`
  -- （lua/dashboard/init.lua:261），而 modifiable = false 的 buffer 它**静默
  -- 返回、不报错**。这在只剩文件树时必然踩到：
  --   - host_win() 找不到 buftype 为空的窗口，`topleft vsplit` 开新窗口；
  --   - 但 :vsplit 会把当前窗口的 buffer 复制一份 —— 当前是 neo-tree，
  --     它的 buffer 是 buftype = "nofile" + modifiable = false；
  --   - 于是 :Dashboard 什么都不做，新窗口里装的还是文件树，
  --     结果 neo-tree 被复制成两个窗口平分整屏（实测 w=40 / w=39）。
  -- 塞一个全新的普通 buffer 进去再渲染，绕开这道门。
  local buf = vim.api.nvim_win_get_buf(0)
  if not vim.bo[buf].modifiable then
    vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(false, false))
  end

  pcall(vim.cmd, "Dashboard")

  -- 我们补出来的窗口是从「已被 neo-tree 撑满整屏」的状态里切出来的，不修宽度
  -- 的话文件树会一直占着将近一半屏幕。
  restore_neo_tree_width()
end

--- 按当前窗口宽度原地重画欢迎界面。返回是否真的画了。
local function redraw(win)
  if not theme_entry or not theme_config then return false end
  local buf = vim.api.nvim_win_get_buf(win)
  if not vim.api.nvim_buf_is_valid(buf) then return false end

  vim.bo[buf].modifiable = true
  -- theme 的各个 gen_* 都是从 nvim_buf_line_count 往后**追加**写的
  -- （theme/hyper.lua:571-572 只在头部插空行），不清空就会叠成好几份。
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  -- 复用同一个 config、只把 buffer/窗口指向当前这个 —— buffer 身份不变，
  -- 在途的异步渲染就不会写到已失效的 buffer 上。
  theme_entry(vim.tbl_extend("force", theme_config, { bufnr = buf, winid = win }))
  return true
end

--- 窗口布局变了之后重画欢迎界面。
---
--- 上游只在 VimResized 上重画（lua/dashboard/init.lua:216-222），开 / 关
--- avante 这种只改窗口布局的事件它看不到，所以这里补上。
local function recenter()
  if rendering then return end
  local win = dashboard_win()
  if not win then return end
  local w = vim.api.nvim_win_get_width(win)
  -- 宽度和上次渲染时一样就跳过：终端改大小这类事件上游自己会重画一遍
  -- （它把重绘挂在 VimResized 上），不必再来一次。
  if w == rendered_width then return end

  rendering = true
  -- theme 渲染完会发 User DashboardLoaded，用它来解锁；万一上游哪天不发，
  -- 这一条兜底，免得 rendering 卡在 true 之后再也不重画。
  vim.defer_fn(function() rendering = false end, 1000)
  if not redraw(win) then rendering = false end
end

--- 把连续的窗口事件合并成一次重画。
---
--- 去抖而不是直接回调，是因为布局会连着变好几步（先建窗口、各窗口再各自
--- resize），在事件发生的那一刻量到的宽度往往还是旧的；而且 API 驱动的改宽
--- （nvim_win_set_width）未必发得出 WinResized。等一小会儿再处理最省事。
local function schedule_recenter()
  if pending then return end
  pending = true
  vim.defer_fn(function()
    pending = false
    recenter()
  end, 60)
end

-- ============================================================
-- 两处对上游的改写
-- ============================================================

--- 覆盖 dashboard 的居中计算：把写死的 `vim.o.columns` 换成 dashboard
--- 自己窗口的宽度；不在显示 dashboard 时退回整屏宽度，保持上游行为。
---
--- 只改这一处不够 —— 内容是渲染那一刻算好写进 buffer 的，必须再配合
--- recenter() 在布局变化后重画，两条缺一不可。
---
--- 幂等标志放在模块局部变量上：函数值挂不了字段（Lua 的 function 没有
--- metatable，`fn.x = true` 直接报 "attempt to index a function value"）。
local center_patched = false

local function patch_center_align()
  if center_patched then return end
  local ok, utils = pcall(require, "dashboard.utils")
  if not ok or type(utils.center_align) ~= "function" then return end
  center_patched = true

  utils.center_align = function(lines)
    local win = dashboard_win()
    local w = win and vim.api.nvim_win_get_width(win) or vim.o.columns
    -- 记下这次是按多宽渲染的，recenter() 靠它判断「需不需要重画」。
    rendered_width = w
    local out = {}
    for i, line in ipairs(lines) do
      local fill = math.floor((w - vim.api.nvim_strwidth(line)) / 2)
      if fill < 0 then fill = 0 end
      out[i] = (" "):rep(fill) .. line
    end
    return out
  end
end

--- 截下 theme(config) 的 config。
---
--- load_theme 每次渲染都走 `require(theme_key)(config)`
--- （lua/dashboard/init.lua:212），所以把 package.loaded 里那一项换成转发壳，
--- 就能在不影响渲染的前提下把 config 留下来 —— 它自己的 VimResized 重绘
--- 走的也是同一条路，等于复用上游的语义而不是另发明一套。
local function capture_theme_config()
  if theme_entry then return end
  local ok, db = pcall(require, "dashboard")
  if not ok then return end
  local name = (db.opts and db.opts.theme) or "hyper"
  local key = "dashboard.theme." .. name
  local ok2, mod = pcall(require, key)
  if not ok2 or type(mod) ~= "table" then return end

  theme_entry = setmetatable({}, {
    __call = function(_, config)
      theme_config = config
      return mod(config)
    end,
  })
  package.loaded[key] = theme_entry
end

-- ============================================================
-- 接线
-- ============================================================

--- Neovim 是否正在退出。
---
--- 不能写成 `vim.v.exiting ~= nil`：未退出时 `v:exiting` 的值是 `v:null`，
--- Lua 侧取到的是 **vim.NIL**（userdata），`~= nil` 恒为真 —— 那样守卫会
--- 永远提前返回，整个功能等于没装。所以三种表示都要排除掉。
local function is_exiting()
  local v = vim.v.exiting
  return v ~= nil and v ~= vim.NIL and v ~= false
end

--- 每次有普通文件 buffer 被删掉之后的收尾动作。
---
--- 只在「没有任何窗口正在显示普通文件」时才动手：只要还有窗口开着文件，
--- 说明 Vim 自己已经切好了，插手反而碍事。
local function on_buffers_changed()
  -- 正在退出就别开窗口了，否则 `:bdelete` + 退出这条路上会挡住退出。
  if is_exiting() then return end
  if file_win() then return end
  if #file_bufs() == 0 then
    M.show()
  else
    focus_mru()
  end
end

function M.setup()
  vim.api.nvim_create_augroup(augroup, { clear = true })

  patch_center_align()
  capture_theme_config()

  vim.api.nvim_create_autocmd("BufDelete", {
    group = augroup,
    desc = "buffer 关掉后自动切下一个；没有 buffer 则显示欢迎界面",
    callback = function(args)
      -- 只对普通文件 buffer 反应：telescope / avante / 终端这些插件自己的
      -- scratch buffer 被删掉时，不该把欢迎界面拽出来。
      if not vim.api.nvim_buf_is_valid(args.buf) then return end
      if vim.bo[args.buf].buftype ~= "" then return end
      if is_exiting() then return end
      -- BufDelete 触发时窗口通常已经被 Vim 关掉了（见 restore_neo_tree_width
      -- 的说明），所以这里只负责决定「接下来显示欢迎界面还是切到别的文件」，
      -- 必须 schedule 到下一轮主循环，等布局稳定了再动手。
      vim.schedule(on_buffers_changed)
    end,
  })

  -- 开 / 关 avante 会新建或销毁窗口，同时把编辑区挤窄 / 拉宽。三个事件都挂上：
  -- WinResized 覆盖宽度变化，WinNew / WinClosed 兜住宽度恰好没变、但窗口
  -- 归属变了的情况。
  for _, event in ipairs({ "WinNew", "WinClosed", "WinResized" }) do
    vim.api.nvim_create_autocmd(event, {
      group = augroup,
      desc = "窗口布局变化后让欢迎界面重新按窗口宽度居中",
      callback = schedule_recenter,
    })
  end

  -- theme 渲染收尾时会发这个 User 事件（theme/hyper.lua:576-580），
  -- 拿它来解除 rendering 锁：theme 渲染是异步的，函数返回不代表画完了。
  vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "DashboardLoaded",
    desc = "欢迎界面画完，解锁重画",
    callback = function() rendering = false end,
  })
end

return M