# -*- coding: utf-8 -*-
"""Calibrate how many characters of deck prose fit on one rendered line.

The builder has to know whether a prose column overflows before it writes 20
pages, and a text frame's declared height does not answer that. This probe draws
paragraphs of known length in the exact widths the predictor pages use, renders
them through the same path the preview uses, and reads the pixel rows between
two amber markers to recover the wrapped line count.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "2026-09-23", "deck"))

from pptx import Presentation                                        # noqa: E402
from pptx.util import Emu, Inches, Pt                                # noqa: E402

import deck_kit as K                                                 # noqa: E402

SCALE = 1.0 / 1.75
TMP = os.path.join(HERE, "_preview_tmp")
OUT = os.path.join(TMP, "cal")


def sc(v):
    return Emu(int(round(Inches(v) * SCALE)))


def main():
    prs = Presentation()
    prs.slide_width = Emu(int(12192000 * SCALE))
    prs.slide_height = Emu(int(6858000 * SCALE))
    s = K.blank(prs)

    # A 4.35 in column of prose at 11 pt, one paragraph of 240 characters, with
    # an amber marker bar directly under the text box so the rendered rows
    # between the two markers give the line count.
    txt = ("abcdefghij klmnopqrs tuvwxyz AB CDEF GH " * 6).strip()
    print("probe paragraph length %d characters" % len(txt))

    boxes = [
        ("p11_435", 0.50, 0.40, 4.35, 11),
        ("p12_435", 5.20, 0.40, 4.35, 12),
        ("p11_760", 0.50, 3.20, 7.60, 11),
    ]
    for name, x, y, w, size in boxes:
        bar = s.shapes.add_shape(K.MSO_SHAPE.RECTANGLE, sc(x), sc(y), sc(w), sc(0.03))
        bar.fill.solid()
        bar.fill.fore_color.rgb = K.AMBER
        bar.line.fill.background()
        bar.shadow.inherit = False
        box = s.shapes.add_textbox(sc(x), sc(y + 0.05), sc(w), sc(2.4))
        tf = box.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        p.space_after = Pt(0)
        r = p.add_run()
        r.text = txt
        K.style_run(r, size * SCALE)
        bar2 = s.shapes.add_shape(K.MSO_SHAPE.RECTANGLE, sc(x), sc(y + 2.55), sc(w), sc(0.03))
        bar2.fill.solid()
        bar2.fill.fore_color.rgb = K.AMBER
        bar2.line.fill.background()
        bar2.shadow.inherit = False
        print("%-10s x=%.2f w=%.2f size=%d pt" % (name, x, w, size))

    os.makedirs(TMP, exist_ok=True)
    path = os.path.join(TMP, "cal.pptx")
    prs.save(path)
    print("wrote %s" % path)


if __name__ == "__main__":
    main()
