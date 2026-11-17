# -*- coding: utf-8 -*-
"""Judge every rendered page of the merged deck from its pixels.

Two measurements per page, both read off the PNG rather than off the shape
geometry, because the renderer draws text at the size the text needs and a box
declared too small overflows silently:

    ink_bottom   the lowest row with dark ink, in inches of the 13.333 x 7.5 page
    ink_right    the rightmost column with dark ink, same units

The thresholds are the same two the new-page probe uses. The scope band's second
line ends by 7.44 on a page whose band wraps twice, so 7.45 is the deepest
legitimate ink; the right margin is at 12.75 and nothing may print past 12.80.

A page whose background is a full-bleed rectangle is skipped: its ink is the
page itself and the two thresholds measure nothing there. That is the two NAVY
openers and one carried page, not an exemption for content.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "preview_final")
DECK = os.path.join(HERE, "deck_final.pptx")
PPI = 1334.0 / 13.3333          # the renderer rasterises 13.3333 in into 1334 px

DEEP = 7.45
WIDE = 12.80


def full_bleed_pages():
    """Pages whose background covers the slide: 1-indexed page numbers.

    A tolerance is needed because the two builders that draw those pages use
    deck_kit's 13.333 in, which is 305 EMU narrower than the exact 16:9 the deck
    records. An equality test finds nothing.
    """
    from pptx import Presentation
    prs = Presentation(DECK)
    tol = 0.05 * 914400
    out = set()
    for i, slide in enumerate(prs.slides, start=1):
        for sh in slide.shapes:
            if sh.width is None or sh.height is None:
                continue
            if (abs(sh.width - prs.slide_width) <= tol
                    and abs(sh.height - prs.slide_height) <= tol):
                out.add(i)
                break
    return out


def main():
    from PIL import Image
    skip = full_bleed_pages()
    files = sorted(f for f in os.listdir(OUT) if f.endswith(".png"))
    if not files:
        raise SystemExit("nothing rendered in %s" % OUT)
    low, wide = [], []
    print("%-6s %-9s %-9s %s" % ("page", "ink_bot", "ink_right", "verdict"))
    for i, f in enumerate(files, start=1):
        with Image.open(os.path.join(OUT, f)) as im:
            g = im.convert("L")
            w, h = g.size
            px = g.load()
            # The renderer pens a one pixel grey border round the canvas and the
            # page disc casts a shadow into the top rows, so both scans stay
            # inside the border and the right scan starts below the disc.
            bottom, right = 2, 2
            for y in range(2, h - 2):
                if min(px[x, y] for x in range(2, w - 2)) < 120:
                    bottom = y
            for x in range(2, w - 2):
                if min(px[x, y] for y in range(130, h - 2)) < 120:
                    right = x
        b_in, r_in = bottom / PPI, right / PPI
        bad = []
        if i in skip:
            verdict = "full bleed, skipped"
        else:
            if b_in > DEEP:
                bad.append("LOW %.2f" % b_in)
                low.append(i)
            if r_in > WIDE:
                bad.append("WIDE %.2f" % r_in)
                wide.append(i)
            verdict = " ".join(bad) or "ok"
        if bad or i <= 3 or i >= len(files) - 3:
            print("%-6d %-9.2f %-9.2f %s" % (i, b_in, r_in, verdict))
    print("")
    print("full-bleed pages skipped: %s" % sorted(skip))
    print("pages with ink past %.2f in: %s" % (DEEP, low or "none"))
    print("pages with ink past %.2f in: %s" % (WIDE, wide or "none"))
    return 1 if (low or wide) else 0


if __name__ == "__main__":
    sys.exit(main())
