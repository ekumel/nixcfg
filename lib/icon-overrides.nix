# 主题图标补丁：对 Colloid 主题未收录的小众应用，加一层背景蒙版，
# 让启动器/任务栏图标风格与 Colloid 方块图标一致。
#
# 原理：nixpkgs 的 Flutter/Electron 应用通常把图标装到
#   $out/share/icons/hicolor/<size>x<size>/apps/<name>.png
# GTK 主题查找顺序为 Colloid -> hicolor -> 兜底。若 Colloid 里没收录，
# 启动器会用 hicolor 里那张原图（通常是应用 logo），风格突兀。
#
# 这里在 overrideAttrs 的 postInstall 阶段（追加在原 postInstall 之后），
# 把已经装好的 PNG base64 嵌入到一个 SVG 容器：背景蒙版 + 原图居中缩放
# 叠在上面。SVG 写入
#   $out/share/icons/hicolor/scalable/apps/<name>.svg
# hicolor 主题支持目录扫描，无需 index 重建。librsvg 渲染时按矢量缩放，
# 不会因为缩放而模糊。
#
# 仅当原 PNG 存在时才生成（守卫），未装图标的包（纯 CLI、终端应用等）会
# 安全跳过，不会破坏构建。
#
# 注意：预编译包（如 Tauri AppImage）的 installPhase 是 `cp -r`，会把源
# 目录的只读权限原样复制到 $out，导致 share/icons/hicolor/* 不可写。
# 必须在写 SVG 前 chmod +w，否则 mkdir / install 都会失败。
#
# 用法（在 modules/home/xumel/packages/icon-annotated.nix 里）：
#   (pkgs.callPackage ./icon-overrides.nix { pname = "piliplus"; })
#
# 可调参数：
#   pname         必填。图标查找与输出文件名。
#   pkg           默认 pkgs.${pname}。
#   bg            背景颜色。默认 "#ffffff"（白）。可写 "#fafafaff" 等带 alpha，
#                 或 "transparent"（无背景蒙版，只缩放原图）。
#   cornerRadius  矩形圆角半径（viewBox 单位）。默认 96 (18.75%)。
#                 写 0 变成纯矩形；写 viewBox 变成圆形。
#   scale         原图占内层有色的比例，0<scale<=1。默认 0.75。
#                 scale=1 时原图占满内层无内边距，scale=0.5 时四周各空 25%。
#                 注意：scale 算的是相对内层，而不是 viewBox，所以加 border
#                 时视觉一致。
#   viewBox       SVG viewBox 边长（正方形）。默认 512。改成 256、1024 等均可。
#   border        外层透明边距宽度（viewBox 单位）。默认 0（无外圈透明）。
#                 类似 macOS Big Sur 风格：图标四周留透明间隙，让 dock 底色透出。
#                 viewBox=512 时 border=16 = 3.125% 边距。
#   imageRender   <image> 的 image-rendering 属性。默认 "optimizeQuality"
#                 （缩放时高质量插值，减少锯齿）。其他可选：
#                 "auto" / "optimizeSpeed" / "crisp-edges"。
{ pkgs, lib
, pname
, pkg ? pkgs.${pname}
, bg ? "#ffffff"
, cornerRadius ? 96
, scale ? 0.75
, viewBox ? 512
, border ? 32
, imageRender ? "optimizeQuality"
}:

assert lib.assertMsg (scale > 0 && scale <= 1)
  "icon-overrides: scale must be in (0, 1], got ${toString scale}";
assert lib.assertMsg (border >= 0 && border < viewBox / 2)
  "icon-overrides: border must be in [0, ${toString (viewBox / 2)}), got ${toString border}";

let
  # 内层有色的边长（viewBox 减去两侧 border）
  inner = viewBox - 2 * border;
  # 原图占内层的边长（按 scale 算）
  imgSize = scale * inner;
  # 原图在内层内的内边距（(1-scale)/2 等比）
  pad = (1.0 - scale) / 2.0;
  imgX = border + pad * inner;
  imgY = border + pad * inner;

  # 内层 rect 的圆角按比例缩放（让内外层圆角视觉一致）
  innerRadius = cornerRadius * inner / viewBox;

  # background 节点：bg == "transparent" 时省略内层 rect
  # border > 0 时，外圈 fill="none" 让 dock 底色透出；border == 0 时不画外层。
  innerRect = if bg == "transparent" then "" else
    "  <rect x=\"${toString border}\" y=\"${toString border}\" width=\"${toString inner}\" height=\"${toString inner}\" rx=\"${toString innerRadius}\" ry=\"${toString innerRadius}\" fill=\"${bg}\"/>\n";
  outerRect = if border > 0 then
    "  <rect width=\"${toString viewBox}\" height=\"${toString viewBox}\" rx=\"${toString cornerRadius}\" ry=\"${toString cornerRadius}\" fill=\"none\"/>\n"
    else "";
in
pkg.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    # hicolor 里最大的 PNG 优先（librsvg 在 SVG 中能任意缩放，源图越清晰越好）
    png=$(find "$out/share/icons/hicolor" -path "*/apps/${pname}.png" 2>/dev/null \
          | sort -V | tail -n1)
    if [ -n "$png" ] && [ -f "$png" ]; then
      # 预编译包 installPhase 是 `cp -r`，会把源目录只读权限复制过来。
      # 必须先 chmod +w 才能在 hicolor 下创建/写入文件。
      chmod -R u+w "$out/share/icons/hicolor" 2>/dev/null || true
      b64=$(base64 -w0 < "$png")
      mkdir -p "$out/share/icons/hicolor/scalable/apps"
      # bash 的 dollar-single-quote 字符串：\n 解析为换行；单引号之间不展开；
      # 只有 b64 用双引号夹在两段之间被替换。
      svg=$'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 ${toString viewBox} ${toString viewBox}">\n${outerRect}${innerRect}  <image x="${toString imgX}" y="${toString imgY}" width="${toString imgSize}" height="${toString imgSize}" preserveAspectRatio="xMidYMid meet" image-rendering="${imageRender}" href="data:image/png;base64,'"$b64"$'"/>\n</svg>\n'
      printf '%s' "$svg" > "$out/share/icons/hicolor/scalable/apps/${pname}.svg"
    fi
  '';
})
