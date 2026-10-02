# baidunetdisk：百度网盘 Linux 客户端（unfree）。
#
# 上游只发 .deb（https://pan.baidu.com/ 下载页入口），文件名带版本号，
# 走百度自家 CDN issuecdn.baidupcs.com，路径模式：
#   https://issuecdn.baidupcs.com/issue/netdisk/LinuxGuanjia/<VERSION>/baidunetdisk_<VERSION>_amd64.deb
# nixpkgs 不收录。
#
# 升级流程：
#   1. 跑 `./scripts/update-third-party.sh baidunetdisk`：脚本探测
#      https://pan.baidu.com/disk/home 下载页、取版本号、生成新 URL、
#      修改 flake.nix 的 url 字段、`nix flake lock --update-input baidunetdisk`；
#   2. 同步更新下方 version 字面量（脚本不会改 .nix 里的 version）；
#   3. aarch64 的 sha256 需要人工到下载页下载后用 nix-prefetch-url 算出；
#   4. `nix flake check` 验证；
#   5. `nixos-rebuild switch` 验证。
#
# 打包策略：Electron app 的「FHS-沙箱 + 预编译资源」组合，src 是 .deb
# 不是 AppImage。解包与 FHS 封装的完整流程（ar 解包 → buildFHSEnv →
# 搬 .desktop 与图标 → 改写 Exec= → bind /etc/nixos）见
# lib/build-deb-fhs.nix，本文件只留本包特有的元数据与路径。
#
# chrome-sandbox 的处理：deb 自带的 chrome-sandbox 是 SUID-root 二进制，
# NixOS 不支持任意 SUID。它本意是让 Electron 用 chrome 沙箱；但上游
# .desktop 的 Exec 行已经带 `--no-sandbox`，并且 Electron 在没有
# chrome-sandbox 时会自动降级到「无沙箱」模式而非拒绝启动，
# 因此直接保留原 chrome-sandbox 文件即可（用不到但也无害）。
{
  pkgs,
  flake,
}:

let
  pname = "baidunetdisk";
  version = "4.17.7";

  # x86_64 的 src 来自 flake input；aarch64 在这里手算（每个 url input
  # 只能配一个 url）。
  srcBySystem = {
    x86_64-linux = flake.inputs.baidunetdisk;
  };

  src =
    srcBySystem.${pkgs.stdenvNoCC.hostPlatform.system}
      or (throw "baidunetdisk: 不支持的系统 ${pkgs.stdenvNoCC.hostPlatform.system}");
in
# 走 flake.lib 而非相对路径 import ../lib/：这样本包被别的 flake 消费
# （作为 overlay 或 packages 引用）时仍能解析，见 lib/default.nix 顶部说明。
(flake.lib.build-deb-fhs pkgs) {
  inherit
    pname
    version
    src
    ;

  # .deb 的 data.tar.* 解开后根目录是 ./opt/baidunetdisk/... 与
  # ./usr/share/...。
  binaryPath = "opt/baidunetdisk/baidunetdisk";
  desktopFile = "baidunetdisk.desktop";

  # .desktop 的 Exec 是 `/opt/baidunetdisk/baidunetdisk --no-sandbox %U`。
  # 主进程 shell wrapper 自己 arg-parses，**不接受** --no-sandbox（传了会报
  # "bad option: --no-sandbox"），所以替换时把 flag 一起 strip 掉。
  execFrom = "/opt/baidunetdisk/baidunetdisk --no-sandbox";

  meta = {
    description = "Baidu Netdisk cloud storage client (Linux)";
    homepage = "https://pan.baidu.com/";
    # 上游「License: https://pan.baidu.com/disk/duty/」是用户协议链接，
    # 非 SPDX。参照 nixpkgs 的处理标 unfree + binaryNativeCode。
    license = pkgs.lib.licenses.unfree;
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
