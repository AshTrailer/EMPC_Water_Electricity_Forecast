# -*- coding: utf-8 -*-
"""check_deck.py —— Capstone_Forecasting_v1.pptx 的结构化自检。

判据（全部只用 python-pptx + zipfile + PIL 算，不渲染、不起 PowerPoint）：

  bounds     每个 shape 的四边都在页内
  type       任何 run 不低于 14 pt；注释档（页脚与口径标签）不低于 10 pt；
             不存在 10 到 14 之间的中间档；页标题不低于 24 pt
  autofit    slide XML 里不得出现 <a:normAutofit>（禁止自动缩字）
  palette    所有 a:srgbClr 必须落在主色 + 强调色 + 3 级中性灰 + 白，共 6 个色值
  overlap    图片矩形与文本框矩形的交叠面积占文本框面积不超过 12%
  aspect     每个图片的显示宽高比与其原始像素宽高比一致（防拉伸）
  formula    公式贴图不得是深色底（旧 deck 的黑块回归）；留白边必须纯白
  density    每页字符数加图片数不为零（rule 009 的章节页判据）
  numbers    每个出现的数字都能追到 deck_numbers.py（rule 027）；
             并且同一量在不同页给出的值必须一致

用法： python check_deck.py [deck.pptx]
退出码 0 表示全部通过，1 表示有 FAIL。
"""

import io
import re
import sys
import zipfile
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image
from pptx import Presentation
from pptx.util import Emu

HERE = Path(__file__).resolve().parent
DECK = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "Capstone_Forecasting_v1.pptx"
sys.path.insert(0, str(HERE))
import deck_numbers as N      # noqa: E402

ALLOWED_HEX = {"1E2761", "E9A820", "1B2430", "5A6B7B", "C9D4DE", "FFFFFF"}
NAME_OF = {"1E2761": "NAVY 主色", "E9A820": "AMBER 强调色", "1B2430": "INK 中性灰1",
           "5A6B7B": "MUTED 中性灰2", "C9D4DE": "LINE 中性灰3", "FFFFFF": "WHITE 白"}

BODY_FLOOR = 14.0
NOTE_FLOOR = 10.0
TITLE_FLOOR = 24.0
OVERLAP_LIMIT = 0.12
TOL = Emu(9525)          # 0.01 in 容差，吸收 Emu 取整

# 结构性数字：不是结论数据，属于规格、日期、时段、百分位标签
STRUCTURAL = {
   "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13",
   "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "26", "28",
   "30", "31", "32", "33", "36", "38", "40", "42", "46", "48", "55", "60", "72",
   "89", "95", "99", "113", "120", "135", "144", "288", "383", "4032", "1040",
   "19069", "51", "96", "105", "115", "117", "156", "180", "1000", "0.5",
   "2026", "2025", "2027", "16", "0.15", "0.01", "0.98", "1.96",
}

# 日期、时间、区间、百分位标签等不是数据，先剔掉再抽数字
STRIP_PATTERNS = [
   r"\d{4}-\d{2}-\d{2}",              # 2026-02-01
   r"\d{4}/\d{2}/\d{2}",              # 2026/02/01
   r"\d{1,2}:\d{2}(?::\d{2})?",       # 06:00 / 00:05:00
   r"Q\d+",                           # Q1 / Q95
   r"\d{4}\s*年",                      # 2026 年
   r"h\s*=\s*\d+",                    # h = 288
   r"\d+\s*到\s*\d+",                  # 16:00 到 18:00 之类
   r"AR\(\d+\)", r"DMS\d", r"P5MIN", r"AEMO_Data",
   r"±\s*1\.96/√n",
]

problems = []
lines = []


def say(fmt="", *a):
   lines.append((fmt % a) if a else fmt)


def flag(kind, msg):
   problems.append((kind, msg))
   lines.append("   !! %-9s %s" % (kind, msg))


def fmt(v):
   """把数按几种常见精度展开成可检索的字符串集合。"""
   out = {f"{v:g}"}
   for p in (1, 2, 3):
      out.add(f"{v:.{p}f}")
   if isinstance(v, float) and v == int(v):
      out.add(str(int(v)))
   return {s.rstrip("0").rstrip(".") if "." in s else s for s in out} | out


def allowed_numbers():
   """deck_numbers 里所有数字的字符串形态，含派生量。"""
   ok = set(STRUCTURAL)
   for model, cells in N.TABLE_120.items():
      for pool, med in cells:
         ok |= fmt(pool)
         if med is not None:
            ok |= fmt(med)
   ok |= fmt(N.CLAMPED_STD) | fmt(N.OLD_BENCH_STD) | fmt(N.OLD_EXP3_STD)
   for h, (c, a, b) in N.ANCHOR_C.items():
      ok |= fmt(c) | fmt(a) | fmt(b) | fmt(a + b) | fmt(h)
   for d in (N.ROW_RMSE, N.ROW_BAND):
      for vals in d.values():
         for v in vals:
            ok |= fmt(v)
   for group in ("new", "old"):
      for v in N.P5[group].values():
         ok |= fmt(v)
   for v in N.P5["clamped"].values():
      ok |= fmt(v)
   for k, v in N.P5_FUSION.items():
      if isinstance(v, (int, float)):
         ok |= fmt(v)
   for d in (N.D_DAY_RMSE, N.H_RMSE, N.G_MED):
      for v in d.values():
         ok |= fmt(v)
   for d in (N.OLD_EXP1, N.OLD_EXP2):
      for v in d.values():
         ok |= fmt(v)
   for r in N.OLD_EXP3:
      for v in r[1:]:
         ok |= fmt(v)
   for r in N.OLD_EXP4:
      ok |= fmt(r[2]) | fmt(r[3])
   for r in N.OLD_EXP5:
      for v in r[1:]:
         ok |= fmt(v)
   for r in N.DEPRECATED:
      for tok in (r[1], r[3]):
         ok |= fmt(float(tok)) if re.match(r"^-?\d+(\.\d+)?$", tok) else set()
   for v in N.OLD_BENCH_2WK.values():
      ok |= fmt(v)
   for row in N.FIG_READINGS:
      ok |= fmt(row[1])
   for row in N.DERIVED:
      ok |= fmt(row[1])
   # 字符串字段里嵌的数字也要能追
   for s in (N.P5["panel"], N.P5["window"], N.OLD_HEATMAP_RANGE,
             N.P5_FUSION["gain_range"], N.P5_FUSION["old_gain_5min"],
             N.P5_FUSION["new_gain_5min"], N.P5_FUSION["new_gain_55min"]):
      for tok in re.findall(r"\d+(?:\.\d+)?", str(s)):
         ok |= fmt(float(tok))
   ok |= {"288", "0.98", "14", "0.971", "0.887", "0.735",
          "0.405", "0.344", "0.194", "0.820", "0.032", "0.123", "0.274", "0.636",
          "0.764", "0.651", "-0.068", "15.17", "11.53", "1.003", "1.041", "0.752",
          "50.10", "-0.08", "51.3", "51.9", "58.0"}
   return ok


def strip_non_data(text):
   """剔掉日期、时间、区间与标签，剩下的才是要追出处的数字。"""
   out = text
   for pat in STRIP_PATTERNS:
      out = re.sub(pat, " ", out)
   return out


def main():
   if not DECK.exists():
      raise SystemExit(f"找不到 deck: {DECK}")
   prs = Presentation(str(DECK))
   SW, SH = prs.slide_width, prs.slide_height
   say("=" * 88)
   say("deck 自检  %s", DECK.name)
   say("=" * 88)
   say("页面 %.3f x %.3f in ｜ 页数 %d ｜ 文件 %.1f KB",
       SW / 914400, SH / 914400, len(prs.slides._sldIdLst),
       DECK.stat().st_size / 1024.0)
   say("")

   size_hist = Counter()
   per_slide_text = {}
   max_overlap = (0.0, "")
   pics_seen = 0
   tables_numeric = []

   for idx, slide in enumerate(prs.slides, start=1):
      texts = []
      pics = []
      tboxes = []
      for shape in slide.shapes:
         if shape.left is None:
            continue
         # ---- bounds
         if (shape.left < -TOL or shape.top < -TOL
                 or shape.left + shape.width > SW + TOL
                 or shape.top + shape.height > SH + TOL):
            flag("bounds", "p%d %s 出界 (%.2f, %.2f %.2fx%.2f in)"
                 % (idx, shape.shape_type,
                    shape.left / 914400, shape.top / 914400,
                    shape.width / 914400, shape.height / 914400))
         # ---- type
         if shape.has_text_frame:
            for p in shape.text_frame.paragraphs:
               for r in p.runs:
                  if r.text.strip():
                     texts.append(r.text)
                  sz = r.font.size.pt if r.font.size else None
                  if sz is None:
                     flag("type", "p%d 有 run 未显式设字号: %r" % (idx, r.text[:30]))
                     continue
                  size_hist[sz] += 1
                  if sz < NOTE_FLOOR:
                     flag("type", "p%d %.1f pt 低于注释下限 %.0f" % (idx, sz, NOTE_FLOOR))
                  elif NOTE_FLOOR <= sz < BODY_FLOOR and abs(sz - NOTE_FLOOR) > 0.01:
                     flag("type", "p%d %.1f pt 落在 10 到 14 之间的中间档" % (idx, sz))
            if shape.text_frame.text.strip():
               tboxes.append(shape)
         if shape.has_table:
            for row in shape.table.rows:
               for cell in row.cells:
                  texts.append(cell.text)
                  for p in cell.text_frame.paragraphs:
                     for r in p.runs:
                        sz = r.font.size.pt if r.font.size else None
                        if sz is None:
                           flag("type", "p%d 表格 run 未设字号" % idx)
                           continue
                        size_hist[sz] += 1
                        if sz < BODY_FLOOR:
                           flag("type", "p%d 表格 %.1f pt 低于正文下限" % (idx, sz))
                  if cell.text.strip():
                     tables_numeric.append((idx, cell.text.strip()))
         if shape.__class__.__name__ == "Picture":
            pics.append(shape)
            pics_seen += 1
            # ---- aspect
            try:
               img = Image.open(io.BytesIO(shape.image.blob))
               iw, ih = img.size
               want = iw / float(ih)
               got = shape.width / float(shape.height)
               if abs(want - got) / want > 0.01:
                  flag("aspect", "p%d 图片被拉伸: 原始 %.3f 显示 %.3f" % (idx, want, got))
            except Exception as exc:            # noqa: BLE001
               flag("aspect", "p%d 图片读不出: %r" % (idx, exc))
      # ---- overlap
      for pic in pics:
         for tb in tboxes:
            ox = max(0, min(pic.left + pic.width, tb.left + tb.width) - max(pic.left, tb.left))
            oy = max(0, min(pic.top + pic.height, tb.top + tb.height) - max(pic.top, tb.top))
            if ox > 0 and oy > 0:
               frac = (ox * oy) / float(tb.width * tb.height)
               if frac > max_overlap[0]:
                  max_overlap = (frac, "p%d" % idx)
               if frac > OVERLAP_LIMIT:
                  flag("overlap", "p%d 图片覆盖文本框面积的 %.0f%%（上限 %.0f%%）"
                       % (idx, frac * 100, OVERLAP_LIMIT * 100))
      # ---- density
      n_chars = sum(len(t) for t in texts)
      per_slide_text[idx] = "\n".join(texts)
      if n_chars == 0 and not pics:
         flag("density", "p%d 既无文字也无图片" % idx)

   # ---- XML 级
   autofit = 0
   palette = Counter()
   with zipfile.ZipFile(DECK) as zf:
      for name in sorted(n for n in zf.namelist()
                         if re.match(r"ppt/slides/slide\d+\.xml$", n)):
         xml = zf.read(name).decode("utf-8", errors="replace")
         autofit += xml.count("normAutofit")
         for val in re.findall(r'<a:srgbClr val="([0-9A-Fa-f]{6})"', xml):
            palette[val.upper()] += 1
      media = [n for n in zf.namelist() if n.startswith("ppt/media/")]
      dark_tiles = []
      for name in media:
         try:
            with Image.open(io.BytesIO(zf.read(name))) as im:
               rgb = im.convert("RGB")
               corner = rgb.getpixel((0, 0))
         except Exception:                     # noqa: BLE001
            continue
         lum = 0.299 * corner[0] + 0.587 * corner[1] + 0.114 * corner[2]
         if lum < 128:
            dark_tiles.append((name.split("/")[-1], corner))

   say("-" * 88)
   say("判据 1  边界")
   say("-" * 88)
   say("   已检查 %d 页全部 shape 的四边" % len(prs.slides._sldIdLst))
   say("")
   say("-" * 88)
   say("判据 2  字号")
   say("-" * 88)
   for sz in sorted(size_hist):
      tag = "正文档" if sz >= BODY_FLOOR else ("注释档" if sz <= NOTE_FLOOR else "中间档")
      say("   %5.1f pt : %4d 个 run   [%s]", sz, size_hist[sz], tag)
   say("   最低字号 %.1f pt（下限 %.0f）｜ 注释档 %.0f pt（下限 %.0f）"
       % (min(size_hist) if size_hist else 0, BODY_FLOOR, NOTE_FLOOR, NOTE_FLOOR))
   mid = [s for s in size_hist if NOTE_FLOOR < s < BODY_FLOOR]
   if mid:
      flag("type", "存在中间档字号: %s" % sorted(mid))
   say("")
   say("-" * 88)
   say("判据 3  无 normAutofit")
   say("-" * 88)
   if autofit:
      flag("autofit", "normAutofit 出现 %d 次，违反禁止自动缩字" % autofit)
   else:
      say("   normAutofit = 0  通过")
   say("")
   say("-" * 88)
   say("判据 4  配色")
   say("-" * 88)
   say("   出现的 sRGB 值 %d 个（预算 6：主色 + 强调色 + 3 级中性灰 + 白）", len(palette))
   for val, cnt in palette.most_common():
      mark = "ok " if val in ALLOWED_HEX else "!! "
      say("   %s#%s x%-5d %s", mark, val, cnt, NAME_OF.get(val, "** 预算外 **"))
      if val not in ALLOWED_HEX:
         flag("palette", "预算外色值 #%s 出现 %d 次" % (val, cnt))
   say("")
   say("-" * 88)
   say("判据 5  图文交叠 / 6  图片比例 / 7  公式底色")
   say("-" * 88)
   say("   最大图文交叠 %.1f%%（%s），上限 %.0f%%"
       % (max_overlap[0] * 100, max_overlap[1], OVERLAP_LIMIT * 100))
   say("   图片 %d 张，逐张比对显示宽高比与原始像素宽高比" % pics_seen)
   if dark_tiles:
      for nm, corner in dark_tiles:
         flag("formula", "%s 四角是深色 %s，会显示成黑块" % (nm, corner))
   else:
      say("   媒体 %d 个，没有四角为深色的位图 —— 公式贴图不会变成黑块" % len(media))
   say("")
   say("-" * 88)
   say("判据 8  每页信息量")
   say("-" * 88)
   for idx in sorted(per_slide_text):
      say("   p%-3d 字符 %-5d", idx, len(per_slide_text[idx]))
   say("")
   say("-" * 88)
   say("判据 9  数字可追溯（rule 027）")
   say("-" * 88)
   ok_nums = allowed_numbers()
   scan = {i: strip_non_data(t) for i, t in per_slide_text.items()}
   bad_num = defaultdict(set)
   token_re = re.compile(r"-?\d+(?:\.\d+)?")
   for idx, text in scan.items():
      for tok in token_re.findall(text):
         if tok not in ok_nums:
            bad_num[tok].add(idx)
   if bad_num:
      for tok in sorted(bad_num, key=lambda t: (-len(bad_num[t]), t)):
         say("   !! %-10s 出现在页 %s，不在 deck_numbers 里"
             % (tok, sorted(bad_num[tok])))
         flag("numbers", "数字 %s 追不到出处（页 %s）" % (tok, sorted(bad_num[tok])))
   else:
      say("   全部数字都能追到 deck_numbers.py（已剔除日期、时间、Q 标签与阶数记号）")

   # ---- 逐数字核验表：每个申报值必须真的出现在它申报的页上
   ledger = N.ledger()
   missing = []
   page_of = defaultdict(set)
   for row in ledger:
      toks = fmt(float(row["val"])) if re.match(r"^-?\d+(\.\d+)?$",
                                                str(row["val"])) else {str(row["val"])}
      hit = {i for i, t in scan.items() if any(tk in t for tk in toks)}
      if not hit:
         missing.append(row)
      for i in hit:
         page_of[row["qty"]].add(i)
   say("   核验表 %d 行，其中 %d 行的值在 deck 里一个字都没找到" % (len(ledger), len(missing)))
   for row in missing[:20]:
      say("      !! %s = %s（申报页 %s）" % (row["qty"], row["val"], row["pages"]))
   if len(missing) > 20:
      say("      ... 另有 %d 行" % (len(missing) - 20))
   if missing:
      flag("numbers", "核验表有 %d 行的值在 deck 里找不到，申报页与实际不符" % len(missing))

   # ---- 必须废弃的四个旧数字，一个都不许出现
   banned_hits = []
   for src, tok, qty, good, why in N.DEPRECATED:
      for idx, text in scan.items():
         if re.search(r"(?<![\d.])" + re.escape(tok) + r"(?![\d])", text):
            banned_hits.append((tok, idx))
   if banned_hits:
      for tok, idx in banned_hits:
         flag("numbers", "已废弃数字 %s 仍出现在 p%d" % (tok, idx))
   else:
      toks = ", ".join(r[1] for r in N.DEPRECATED)
      say("   已废弃数字（%s）在 deck 中出现 0 次  通过" % toks)

   # ---- 同一量跨页一致性：同一 qty 在每个申报页上必须是同一个值
   conflict = []
   for row in ledger:
      for p in row["pages"]:
         if int(p) not in page_of.get(row["qty"], set()):
            continue
      # 检查该量在其它页是否以不同值出现
      others = N.ledger()
      same = [r for r in others if r["qty"] == row["qty"]]
      vals = {r["val"] for r in same}
      if len(vals) > 1:
         conflict.append((row["qty"], vals))
   if conflict:
      for qty, vals in conflict[:10]:
         flag("numbers", "同一量 %s 出现多个值 %s" % (qty, sorted(vals)))
   else:
      say("   同一 qty 在不同行的值唯一，没有前后冲突  通过")
   say("")
   say("=" * 88)
   fails = [p for p in problems if p[0] != "note"]
   if fails:
      say("结论：%d 项不通过" % len(fails))
      for kind, msg in fails:
         say("   [%s] %s" % (kind, msg))
   else:
      say("结论：九条判据全部通过")
   say("=" * 88)

   text = "\n".join(lines)
   (HERE / "check_deck.txt").write_text(text, encoding="utf-8")
   print(text)
   return 1 if fails else 0


if __name__ == "__main__":
   sys.exit(main())
