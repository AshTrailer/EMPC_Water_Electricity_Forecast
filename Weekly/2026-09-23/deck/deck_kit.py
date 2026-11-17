# -*- coding: utf-8 -*-
"""deck_kit - reusable builder for the capstone forecasting deck.

Distilled from the 2026-09-15 deck (build_deck.py) plus the measured style report,
with three deliberate corrections against the rules in the meta skill `ppt`:

  1. Colour budget. The old deck used 12 distinct RGBs (measured). ppt-002 allows
     1 primary + 1 accent + 3 neutral greys + white. Here: NAVY primary, AMBER
     accent, INK/MUTED/LINE greys, white, plus TINT - a very light *tint of the
     primary* used only as a card fill, so the hue count stays at two.
  2. Legibility. The old deck ran body text at 12.0-13.5 pt and tables at 10 pt.
     ppt-001 wants body >= 14 pt, notes >= 10 pt, titles >= 24 pt. BODY = 14,
     SMALL = 11 (cards/tables only), FOOT = 10, TITLE = 27.
  3. Formulas. The old deck wrote them as text runs and the manual workaround was
     pasting opaque dark LaTeX tiles. Here every formula goes through
     render_formula.render(), which guarantees a transparent background and dark
     ink, and the caller gets the aspect ratio back so nothing is stretched.

Geometry is unchanged from the original deck so the two look like one series:
content left margin 0.55", content width 12.2", numbered disc at (0.55, 0.42),
title box at (1.25, 0.34, 11.5, 0.7), footnote band at y = 7.02", 16:9 13.333x7.5.
"""

import os

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.util import Emu, Inches, Pt

import render_formula

# ---------------------------------------------------------------- palette
NAVY = RGBColor(0x1E, 0x27, 0x61)     # primary
AMBER = RGBColor(0xE9, 0xA8, 0x20)    # accent - used sparingly
INK = RGBColor(0x1B, 0x24, 0x30)      # body text
MUTED = RGBColor(0x5A, 0x6B, 0x7B)    # secondary text
LINE = RGBColor(0xC9, 0xD4, 0xDE)     # rules / card borders
TINT = RGBColor(0xEA, 0xF1, 0xF8)     # card fill = tint of NAVY
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
LIGHT = RGBColor(0xCA, 0xDC, 0xFC)    # cover / section subtitle on dark
FAINT = RGBColor(0x9F, 0xB3, 0xC8)    # cover metadata on dark
DARK = RGBColor(0x14, 0x21, 0x3D)     # full-bleed section pages only

HDR = "Cambria"
BODY_FONT = "Calibri"

# ---------------------------------------------------------------- type scale
TITLE = 27
SUB = 13
BODY = 14
SMALL = 11
FOOT = 10
COVER = 40
SECTION = 34

SLIDE_W = 13.333
SLIDE_H = 7.5
MARGIN = 0.55
CONTENT_W = 12.2


def new_deck():
   prs = Presentation()
   prs.slide_width = Inches(SLIDE_W)
   prs.slide_height = Inches(SLIDE_H)
   return prs


def blank(prs):
   return prs.slides.add_slide(prs.slide_layouts[6])


# ---------------------------------------------------------------- primitives
def add_rect(slide, x, y, w, h, fill=None, line=None, line_w=0.75, rounded=None):
   shape = slide.shapes.add_shape(
      MSO_SHAPE.ROUNDED_RECTANGLE if rounded is not None else MSO_SHAPE.RECTANGLE,
      Inches(x), Inches(y), Inches(w), Inches(h))
   shape.shadow.inherit = False
   if rounded is not None:
      shape.adjustments[0] = rounded
   if fill is None:
      shape.fill.background()
   else:
      shape.fill.solid()
      shape.fill.fore_color.rgb = fill
   if line is None:
      shape.line.fill.background()
   else:
      shape.line.color.rgb = line
      shape.line.width = Pt(line_w)
   shape.text_frame.text = ""
   return shape


def textbox(slide, x, y, w, h, anchor=MSO_ANCHOR.TOP, wrap=True):
   tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
   tf = tb.text_frame
   tf.word_wrap = wrap
   tf.vertical_anchor = anchor
   tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
   return tb, tf


def style_run(run, size=BODY, color=INK, bold=False, italic=False, font=BODY_FONT):
   run.font.size = Pt(size)
   run.font.color.rgb = color
   run.font.bold = bold
   run.font.italic = italic
   run.font.name = font


def para(tf, text, size=BODY, color=INK, bold=False, italic=False, font=BODY_FONT,
         first=False, space_before=0, space_after=4, align=PP_ALIGN.LEFT):
   p = tf.paragraphs[0] if first else tf.add_paragraph()
   p.alignment = align
   p.space_before = Pt(space_before)
   p.space_after = Pt(space_after)
   run = p.add_run()
   run.text = text
   style_run(run, size, color, bold, italic, font)
   return p


def bullets(tf, items, size=BODY, color=INK, first=True, space_after=6, dot=NAVY,
            indent=0.0):
   """items: str, or (label, rest) to bold the label."""
   for i, item in enumerate(items):
      p = tf.paragraphs[0] if (first and i == 0) else tf.add_paragraph()
      p.space_after = Pt(space_after)
      p.level = 0
      r_dot = p.add_run()
      r_dot.text = "\u25aa  "
      style_run(r_dot, size, dot, True)
      if isinstance(item, tuple):
         r1 = p.add_run()
         r1.text = item[0]
         style_run(r1, size, color, True)
         r2 = p.add_run()
         r2.text = item[1]
         style_run(r2, size, color, False)
      else:
         r = p.add_run()
         r.text = item
         style_run(r, size, color, False)


def header(slide, title, subtitle=None, number=None):
   if number is not None:
      disc = slide.shapes.add_shape(MSO_SHAPE.OVAL, Inches(MARGIN), Inches(0.42),
                                    Inches(0.52), Inches(0.52))
      disc.shadow.inherit = False
      disc.fill.solid()
      disc.fill.fore_color.rgb = NAVY
      disc.line.fill.background()
      tf = disc.text_frame
      tf.word_wrap = False
      tf.vertical_anchor = MSO_ANCHOR.MIDDLE
      p = tf.paragraphs[0]
      p.alignment = PP_ALIGN.CENTER
      r = p.add_run()
      r.text = str(number)
      style_run(r, 18, WHITE, True, font=HDR)
   _, tf = textbox(slide, 1.25 if number is not None else MARGIN, 0.34,
                   11.5 if number is not None else CONTENT_W, 0.7,
                   anchor=MSO_ANCHOR.MIDDLE)
   para(tf, title, TITLE, INK, True, font=HDR, first=True, space_after=0)
   if subtitle:
      _, tf2 = textbox(slide, 1.25 if number is not None else MARGIN, 1.06,
                       11.5 if number is not None else CONTENT_W, 0.3)
      para(tf2, subtitle, SUB, MUTED, first=True, space_after=0)


def footnote(slide, text):
   _, tf = textbox(slide, MARGIN, 7.02, CONTENT_W, 0.36)
   para(tf, text, FOOT, MUTED, italic=True, first=True, space_after=0)


def add_table(slide, x, y, w, rows, col_w=None, size=SMALL, row_h=0.30,
              head_h=0.36, first_col_bold=False):
   """rows[0] is the header. col_w = list of relative weights."""
   n_rows = len(rows)
   n_cols = len(rows[0])
   shape = slide.shapes.add_table(n_rows, n_cols, Inches(x), Inches(y),
                                  Inches(w), Inches(head_h + row_h * (n_rows - 1)))
   table = shape.table
   table.first_row = False
   table.horz_banding = False
   if col_w:
      total = float(sum(col_w))
      for j, cw in enumerate(col_w):
         table.columns[j].width = Emu(int(Inches(w) * cw / total))
   table.rows[0].height = Inches(head_h)
   for i in range(1, n_rows):
      table.rows[i].height = Inches(row_h)
   for i, row in enumerate(rows):
      for j, val in enumerate(row):
         cell = table.cell(i, j)
         cell.margin_left = cell.margin_right = Inches(0.06)
         cell.margin_top = cell.margin_bottom = Inches(0.02)
         cell.vertical_anchor = MSO_ANCHOR.MIDDLE
         cell.fill.solid()
         cell.fill.fore_color.rgb = NAVY if i == 0 else (WHITE if i % 2 else TINT)
         tf = cell.text_frame
         tf.word_wrap = True
         p = tf.paragraphs[0]
         p.alignment = PP_ALIGN.LEFT if j == 0 else PP_ALIGN.CENTER
         p.space_after = Pt(0)
         r = p.add_run()
         r.text = str(val)
         bold = (i == 0) or (first_col_bold and j == 0)
         style_run(r, size, WHITE if i == 0 else INK, bold)
   return table


def fit_image(slide, path, x, y, w, h):
   """Scale to fit inside the box, centred, never cropped or stretched."""
   from PIL import Image
   with Image.open(path) as im:
      iw, ih = im.size
   scale = min(w / iw, h / ih)
   dw, dh = iw * scale, ih * scale
   return slide.shapes.add_picture(path, Inches(x + (w - dw) / 2),
                                   Inches(y + (h - dh) / 2),
                                   Inches(dw), Inches(dh))


def add_formula(slide, tex, x, y, max_w, tmpdir, fontsize=14, color="#1B2430",
                dpi=600, align="left"):
   """Render `tex` to a transparent PNG and place it at its natural type size.

   Sizing by WIDTH is wrong: a short formula like y(k) has a tall aspect ratio, so
   fitting it to the full column width makes it several inches high and it runs off
   the slide. The picture is therefore placed at the size the renderer produced
   (pixels / dpi), and only shrunk when it would exceed `max_w`.

   Returns (picture, height_inches, info). Raises if the renderer produced an
   opaque background, so the dark-tile regression cannot reach the deck again.
   """
   os.makedirs(tmpdir, exist_ok=True)
   name = "f_%08x.png" % (abs(hash((tex, fontsize, color))) % (1 << 32))
   out = os.path.join(tmpdir, name)
   info = render_formula.render(tex, out, fontsize=fontsize, color=color, dpi=dpi)
   if not info["transparent"]:
      raise RuntimeError("formula rendered opaque: %s" % tex)
   w = info["w"] / float(dpi)
   h = info["h"] / float(dpi)
   if w > max_w:
      h *= max_w / w
      w = max_w
   pic = slide.shapes.add_picture(out, Inches(x), Inches(y), Inches(w), Inches(h))
   return pic, h, info


def formula_block(slide, x, y, max_w, lines, tmpdir, size=14, gap=0.09,
                  label_size=None):
   """lines: list of (label_or_None, tex). Returns the y after the block."""
   cur = y
   for label, tex in lines:
      if label:
         _, tf = textbox(slide, x, cur, max_w, 0.24)
         para(tf, label, label_size or SUB, NAVY, True, font=HDR, first=True,
              space_after=0)
         cur += 0.25
      _, h, _ = add_formula(slide, tex, x, cur, max_w, tmpdir, fontsize=size)
      cur += h + gap
   return cur


def ring_motif(slide, cx, cy):
   """Two concentric rings. Kept inside the slide - the original deck let them
   bleed off the right edge, which the static QA flags as an out-of-bounds shape."""
   for rad, col in ((0.42, NAVY), (0.24, AMBER)):
      ring = slide.shapes.add_shape(MSO_SHAPE.OVAL, Inches(cx - rad), Inches(cy - rad),
                                    Inches(rad * 2), Inches(rad * 2))
      ring.shadow.inherit = False
      ring.fill.background()
      ring.line.color.rgb = col
      ring.line.width = Pt(1.1)


def dark_page(prs, title, subtitle=None, body=None, footer_note=None):
   slide = blank(prs)
   add_rect(slide, 0, 0, SLIDE_W, SLIDE_H, fill=NAVY)
   ring_motif(slide, 11.9, 1.05)
   ring_motif(slide, 12.7, 1.95)
   title_y = 0.9 if body else 2.35
   _, tf = textbox(slide, 0.9, title_y, 11.5, 1.0)
   para(tf, title, SECTION, WHITE, True, font=HDR, first=True, space_after=8)
   if subtitle:
      _, tfs = textbox(slide, 0.9, title_y + 0.78, 11.5, 0.5)
      para(tfs, subtitle, 16, LIGHT, first=True, space_after=0)
   if body:
      _, tf2 = textbox(slide, 0.9, title_y + 1.25, 11.5, 4.4)
      for i, line in enumerate(body):
         p = tf2.paragraphs[0] if i == 0 else tf2.add_paragraph()
         p.space_after = Pt(12)
         rd = p.add_run()
         rd.text = "\u25cf  "
         style_run(rd, 16, AMBER, True)
         r = p.add_run()
         r.text = line
         style_run(r, 16, WHITE)
   if footer_note:
      _, tff = textbox(slide, 0.9, 6.75, 11.5, 0.3)
      para(tff, footer_note, FOOT, LIGHT, italic=True, first=True, space_after=0)
   return slide
