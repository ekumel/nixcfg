# Zed 编辑器所需的语言服务器：目前只有 Nix。
#
# Zed 的官方 Nix 扩展（~/.local/share/zed/extensions/installed/nix）
# 的 extension.toml 里同时注册了 nil 和 nixd 两个 LSP，Zed 会依次在
# PATH 中查找。任何一个缺失都会让对应的 LSP 启动时报
# "command not found"，所以两个都装。
#
# 放在这里集中维护，避免散落在 packages/ 各处后被遗漏。
{
  nil,
  nixd,
}:
[
  nil
  nixd
]
