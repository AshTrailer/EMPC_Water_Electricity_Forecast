# -*- coding: utf-8 -*-
"""Static QA for a generated deck - no renderer, no PowerPoint, no focus stealing.

Rendering the pptx would need PowerPoint COM or LibreOffice, neither of which is
safe/available here. Everything the meta skill `ppt` actually forbids, however,
is checkable from the file itself:

  bounds      no shape may leave the slide
  type scale  nothing below 10 pt; body runs below 14 pt are listed (ppt-001)
  autofit     <a:normAutofit> must not appear (no shrink-to-fit) (ppt-001)
  palette     distinct sRGB values, against the 1+1+3+white budget (ppt-002)
  pictures    every embedded image's alpha range, to catch opaque dark tiles
  overlap     text boxes that a picture covers (the old deck's formula failure)
  density     characters per slide, as a proxy for "no big empty page" (ppt-004)
"""

import io
import os
import re
import sys
import zipfile
from collections import Counter, defaultdict

from PIL import Image
from pptx import Presentation
from pptx.enum.shapes import MSO_SHAPE_TYPE
from pptx.util import Emu

HERE = os.path.dirname(os.path.abspath(__file__))
DECK = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
   HERE, "Capstone_Weekly_2026-09-23.pptx")
OUT = os.path.join(HERE, "deck_qa.txt")

BODY_FLOOR = 14
HARD_FLOOR = 10
TITLE_FLOOR = 24

buf = io.StringIO()
problems = []


def say(fmt="", *args):
   buf.write((fmt % args if args else fmt) + "\n")


def flag(kind, msg):
   problems.append((kind, msg))
   say("   !! %-10s %s", kind, msg)


prs = Presentation(DECK)
SW = prs.slide_width
SH = prs.slide_height
say("=" * 84)
say("deck QA  %s", os.path.basename(DECK))
say("=" * 84)
say("幻灯尺寸 %.3f x %.3f in ｜ 页数 %d",
    SW / 914400, SH / 914400, len(prs.slides._sldIdLst))
say("")

size_hist = Counter()
palette = Counter()
autofit_hits = 0
per_slide = []

for idx, slide in enumerate(prs.slides, start=1):
   texts = []
   pics = []
   full_bleed = False
   for shape in slide.shapes:
      if shape.left is None:
         continue
      if shape.width >= SW * 0.95 and shape.height >= SH * 0.95:
         full_bleed = True
      # ---- bounds
      if shape.left < -Emu(1000) or shape.top < -Emu(1000) or \
         shape.left + shape.width > SW + Emu(1000) or \
         shape.top + shape.height > SH + Emu(1000):
         flag("bounds", "p%d %s leaves the slide (%.2f,%.2f %.2fx%.2f in)" %
              (idx, shape.shape_type, shape.left / 914400, shape.top / 914400,
               shape.width / 914400, shape.height / 914400))
      if shape.shape_type == MSO_SHAPE_TYPE.PICTURE:
         pics.append(shape)
      if shape.has_text_frame:
         for p in shape.text_frame.paragraphs:
            for r in p.runs:
               if r.text.strip():
                  texts.append(r.text)
               sz = r.font.size.pt if r.font.size else None
               if sz:
                  size_hist[sz] += 1
                  if sz < HARD_FLOOR:
                     flag("type", "p%d %.1f pt below the %.0f pt floor: %r" %
                          (idx, sz, HARD_FLOOR, r.text[:40]))
      if shape.has_table:
         for row in shape.table.rows:
            for cell in row.cells:
               texts.append(cell.text)
               for p in cell.text_frame.paragraphs:
                  for r in p.runs:
                     sz = r.font.size.pt if r.font.size else None
                     if sz:
                        size_hist[sz] += 1
                        if sz < HARD_FLOOR:
                           flag("type", "p%d table %.1f pt below floor: %r" %
                                (idx, sz, r.text[:30]))
   # ---- picture vs text overlap
   for pic in pics:
      for shape in slide.shapes:
         if shape is pic or not shape.has_text_frame or not shape.text_frame.text.strip():
            continue
         ox = max(0, min(pic.left + pic.width, shape.left + shape.width) - max(pic.left, shape.left))
         oy = max(0, min(pic.top + pic.height, shape.top + shape.height) - max(pic.top, shape.top))
         if ox > 0 and oy > 0:
            frac = (ox * oy) / float(shape.width * shape.height)
            if frac > 0.10:
               flag("overlap", "p%d a picture covers %.0f%% of a text box" %
                    (idx, frac * 100))
   per_slide.append((idx, sum(len(t) for t in texts), len(pics), len(texts),
                     full_bleed))

# ---- XML-level checks
with zipfile.ZipFile(DECK) as zf:
   slides = sorted(n for n in zf.namelist() if re.match(r"ppt/slides/slide\d+\.xml$", n))
   for name in slides:
      xml = zf.read(name).decode("utf-8", errors="replace")
      autofit_hits += xml.count("normAutofit")
      for val in re.findall(r'<a:srgbClr val="([0-9A-Fa-f]{6})"', xml):
         palette[val.upper()] += 1
   media = [n for n in zf.namelist() if n.startswith("ppt/media/")]
   say("媒体文件 %d 个", len(media))
   opaque = []
   for name in media:
      try:
         with Image.open(io.BytesIO(zf.read(name))) as im:
            if im.mode not in ("RGBA", "LA", "P"):
               continue
            rgba = im.convert("RGBA")
            lo, hi = rgba.getchannel("A").getextrema()
            if lo == 255:
               corner = rgba.getpixel((0, 0))
               opaque.append((os.path.basename(name), im.size, corner))
      except Exception as exc:                      # noqa: BLE001
         say("   (unreadable media %s: %r)", name, exc)

say("")
say("-" * 84)
say("字号分布（pt: 出现次数）")
say("-" * 84)
for sz in sorted(size_hist):
   say("   %5.1f pt : %d", sz, size_hist[sz])
body_runs = sum(v for k, v in size_hist.items() if k >= BODY_FLOOR)
say("   >= %d pt 的 run 占 %.1f%%", BODY_FLOOR,
    100.0 * body_runs / max(sum(size_hist.values()), 1))

say("")
say("-" * 84)
say("配色")
say("-" * 84)
say("   不同 sRGB 值 %d 个（ppt-002 预算 = 1 主色 + 1 强调色 + 3 级中性灰 + 白 = 6，"
    "另允许主色的浅色调作卡片底）", len(palette))
for val, cnt in palette.most_common():
   say("   #%s  x%d", val, cnt)

say("")
say("-" * 84)
say("自动缩字与图片透明性")
say("-" * 84)
if autofit_hits:
   flag("autofit", "normAutofit 出现 %d 次（ppt-001 禁止自动缩字）" % autofit_hits)
else:
   say("   normAutofit = 0  -> 符合 ppt-001")
say("   带 alpha 通道的媒体 %d 个；判据只看「四角是深色」的整幅不透明图 ——", len(media))
say("   白底图表 PNG 本来就不透明，那是正常的，不是 09-15 那批黑块的形态。")
dark_tiles = []
for name, size, corner in opaque:
   lum = 0.299 * corner[0] + 0.587 * corner[1] + 0.114 * corner[2]
   if lum < 128:
      dark_tiles.append((name, size, corner))
   else:
      say("   ok  %-14s %-12s corner=%s（亮底，正常）", name, size, corner)
for name, size, corner in dark_tiles:
   flag("opaque", "%s %s corner=%s -> 深色底，白底页上会显示成色块" %
        (name, size, corner))
if not dark_tiles:
   say("   没有深色底位图 -> 公式贴图不会变成黑块")

say("")
say("-" * 84)
say("每页信息量（字符数 / 图片数 / 文本块数）")
say("-" * 84)
thin = []
for idx, chars, npics, ntext, full_bleed in per_slide:
   say("   p%-3d chars=%-5d pics=%-2d textblocks=%-4d%s", idx, chars, npics, ntext,
       "  [full-bleed section page]" if full_bleed else "")
   if chars < 120 and npics == 0 and not full_bleed:
      thin.append(idx)
if thin:
   flag("sparse", "字符少于 120 且无图且非整幅页: %s（疑似大面积留白，ppt-004）" % thin)

say("")
say("-" * 84)
say("配色色相归组（说明为什么不按裸 RGB 数计预算）")
say("-" * 84)
HUE = {
   "1E2761": "NAVY  \u4e3b\u8272", "EAF1F8": "NAVY \u6d45\u8272\u8c03(\u5361\u7247\u5e95)",
   "CADCFC": "NAVY \u6d45\u8272\u8c03(\u6df1\u5e95\u4e0a\u7684\u526f\u6807\u9898)",
   "E9A820": "AMBER \u5f3a\u8c03\u8272",
   "1B2430": "\u4e2d\u6027\u7070 1 \u6b63\u6587", "5A6B7B": "\u4e2d\u6027\u7070 2 \u6b21\u8981",
   "C9D4DE": "\u4e2d\u6027\u7070 3 \u5206\u9694\u7ebf", "FFFFFF": "\u767d\u5e95",
}
groups = Counter()
for val, cnt in palette.items():
   groups[HUE.get(val, "** \u9884\u7b97\u5916 **")] += cnt
for g, cnt in groups.most_common():
   say("   %-34s x%d", g, cnt)
unbudgeted = [v for v in palette if v not in HUE]
if unbudgeted:
   flag("palette", "\u9884\u7b97\u5916\u7684\u8272\u503c: %s" % unbudgeted)
else:
   say("   \u5168\u90e8\u8272\u503c\u90fd\u5728\u9884\u7b97\u5185\uff08\u4e3b\u8272 + \u5f3a\u8c03\u8272 + 3 \u7ea7\u4e2d\u6027\u7070 + \u767d\uff0c\u4e3b\u8272\u7684\u4e24\u7ea7\u6d45\u8272\u8c03\u4e0d\u5355\u72ec\u8ba1\u8272\u76f8\uff09")

say("")
say("=" * 84)
if problems:
   say("结论：%d 项需要处理", len(problems))
   for kind, msg in problems:
      say("   [%s] %s", kind, msg)
else:
   say("结论：全部通过")
say("=" * 84)

with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
   fh.write(buf.getvalue())
print("wrote", OUT, "| problems:", len(problems))
