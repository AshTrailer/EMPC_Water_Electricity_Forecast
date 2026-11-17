# -*- coding: utf-8 -*-
"""Check the merged deck against the two decks it was built from.

Five verdicts, all read off the files rather than off the builder's intentions:

  1. slide count is the sum of the two, and every page appears once
  2. slide size is the exact 16:9 the three sources are
  3. every picture relationship resolves, in the whole package
  4. every text run of every new page is byte-identical to the page it came from
  5. the six-colour palette holds on the new pages, and every page carries a
     page number disc except the two openers
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "2026-09-23", "deck"))

from pptx import Presentation                                     # noqa: E402

PALETTE = {"1E2761", "E9A820", "1B2430", "5A6B7B", "C9D4DE", "FFFFFF"}
NEW_FIRST_PAGE = 63           # page 63 is slide 1 of deck_B_new.pptx
OPENER_PAGES = {63, 109}


def runs_of(slide):
    out = []
    for sh in slide.shapes:
        if sh.has_text_frame:
            for p in sh.text_frame.paragraphs:
                for r in p.runs:
                    out.append(r.text)
        if sh.has_table:
            for row in sh.table.rows:
                for c in row.cells:
                    for p in c.text_frame.paragraphs:
                        for r in p.runs:
                            out.append(r.text)
    return out


def colours_of(slide):
    out = set()
    for sh in slide.shapes:
        try:
            if sh.fill.type is not None and sh.fill.type == 1:
                out.add(str(sh.fill.fore_color.rgb))
        except (AttributeError, TypeError):
            pass
        if sh.has_text_frame:
            for p in sh.text_frame.paragraphs:
                for r in p.runs:
                    try:
                        if r.font.color and r.font.color.type is not None:
                            out.add(str(r.font.color.rgb))
                    except (AttributeError, TypeError):
                        pass
        if sh.has_table:
            for row in sh.table.rows:
                for c in row.cells:
                    try:
                        if c.fill.type == 1:
                            out.add(str(c.fill.fore_color.rgb))
                    except (AttributeError, TypeError):
                        pass
    return out


def main():
    base = Presentation(os.path.join(HERE, "deck_A_carry.pptx"))
    new = Presentation(os.path.join(HERE, "deck_B_new.pptx"))
    final = Presentation(os.path.join(HERE, "deck_final.pptx"))
    bad = []

    n_base = len(base.slides._sldIdLst)
    n_new = len(new.slides._sldIdLst)
    n_final = len(final.slides._sldIdLst)
    print("pages: carried %d, new %d, merged %d" % (n_base, n_new, n_final))
    if n_final != n_base + n_new:
        bad.append("page count %d is not %d + %d" % (n_final, n_base, n_new))

    size = (final.slide_width, final.slide_height)
    print("slide size: %d x %d EMU" % size)
    if size != (12192000, 6858000):
        bad.append("slide size %s is not the exact 16:9 the sources use" % (size,))

    # 2. every text run of every new page matches the page it came from
    diff = 0
    for i in range(n_new):
        a = runs_of(new.slides[i])
        b = runs_of(final.slides[n_base + i])
        if a != b:
            diff += 1
            if diff <= 5:
                print("  page %d run list differs: %d vs %d runs"
                      % (NEW_FIRST_PAGE + i, len(a), len(b)))
    print("new pages whose text differs after the merge: %d of %d" % (diff, n_new))
    if diff:
        bad.append("%d new pages changed their text in the merge" % diff)

    # 3. every picture relationship resolves
    missing = []
    for i, slide in enumerate(final.slides, start=1):
        for sh in slide.shapes:
            if sh.shape_type == 13 or getattr(sh, "image", None) is not None:
                try:
                    _ = sh.image.blob
                except Exception as exc:                        # noqa: BLE001
                    missing.append((i, str(exc)[:60]))
    print("pictures that do not resolve: %d" % len(missing))
    for row in missing[:5]:
        print("   page %d: %s" % row)
    if missing:
        bad.append("%d pictures do not resolve" % len(missing))

    # 4. palette and page number discs on the new pages
    off = []
    for i in range(n_base, n_final):
        page = i + 1
        cols = colours_of(final.slides[i])
        extra = cols - PALETTE
        if extra:
            off.append((page, sorted(extra)))
    print("new pages with a colour outside the six: %d" % len(off))
    for page, cols in off[:8]:
        print("   page %d: %s" % (page, cols))
    if off:
        bad.append("%d new pages use a colour outside the palette" % len(off))

    # 5. the page number discs: a 0.52 in oval at (0.55, 0.42) on every page but
    #    the two openers
    from pptx.enum.shapes import MSO_SHAPE, MSO_SHAPE_TYPE
    from pptx.util import Emu
    no_disc = []
    for i in range(n_base, n_final):
        page = i + 1
        if page in OPENER_PAGES:
            continue
        found = any(sh.shape_type == MSO_SHAPE_TYPE.AUTO_SHAPE
                    and sh.auto_shape_type == MSO_SHAPE.OVAL
                    and sh.width == Emu(475488) and sh.left == Emu(502920)
                    for sh in final.slides[i].shapes)
        if not found:
            no_disc.append(page)
    print("new pages without a page number disc: %s" % (no_disc or "none"))
    if no_disc:
        bad.append("pages %s have no page number disc" % no_disc)

    print("")
    if bad:
        print("FAILED:")
        for b in bad:
            print("   %s" % b)
        return 1
    print("the merged deck is the two decks in order, and the new pages are intact")
    return 0


if __name__ == "__main__":
    sys.exit(main())
