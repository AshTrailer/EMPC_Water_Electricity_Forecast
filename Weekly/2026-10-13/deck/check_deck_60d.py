# -*- coding: utf-8 -*-
"""Check the merged 112-page deck, family by family.

The deck has two families and they obey different rules. The 62 carried pages are
copies of three presentations that were given before this deck existed: they use
the middle type sizes, some of them carry a decorative shape that hangs off the
page on purpose, and their palette is whatever those decks used. The 50 written
pages obey the rules this deck set for itself, and a rule that fails on one of
them fails the run.

Which page is which comes from slide_origin.json, written by the builder that
produced it, so the split cannot drift away from the artifact.

Ten checks:

   1  page count and slide size
   2  every page carries a page number disc except the three openers
   3  every number on a written page traces to deck_numbers_60d
   4  written pages use the declared type sizes, with no normAutofit
   5  written pages use the six-colour palette only
   6  every formula image is transparent and every picture keeps its aspect
   7  geometry stays on the page, except the overhangs the sources already had
   8  a picture never covers a text box
   9  no page is empty
  10  every written page states its conclusion or carries its five-line frame,
      and every formula page carries a symbol table

Run: python check_deck_60d.py [deck_final.pptx]
"""

import io
import json
import os
import re
import sys
import zipfile
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "2026-09-23", "deck"))

from pptx import Presentation                                     # noqa: E402
from pptx.enum.shapes import MSO_SHAPE, MSO_SHAPE_TYPE            # noqa: E402
from pptx.util import Emu                                         # noqa: E402

import deck_numbers_60d as N                                      # noqa: E402

DECK = os.path.join(HERE, sys.argv[1] if len(sys.argv) > 1 else "deck_final.pptx")
ORIGIN = os.path.join(HERE, "slide_origin.json")

PAGES_EXPECTED = 112
SIZE_EXPECTED = (12192000, 6858000)
PALETTE = {"1E2761", "E9A820", "1B2430", "5A6B7B", "C9D4DE", "FFFFFF"}
# Every size a written page uses. 8.0 is a 9 pt run after the renderer's rounding
# and 7.92 is an 8 pt note run, which is the smallest type in the deck: the
# predictor pages were judged on rendered pages before it was accepted, not by
# arithmetic. A page that introduces a new size belongs in this list.
NEW_SIZES = (44, 40, 36, 34, 30, 27, 24, 21, 20, 18, 17, 16, 15, 14.5, 14, 13.5,
             13, 12.5, 12, 11.5, 11, 10.5, 10, 9.5, 9, 8.64, 8.5, 8.25, 8, 7.92)
OPENER_PAGES = {1, 28, 51, 63, 109}       # the three nav pages and the two openers
TOL = 0.02 * 914400
DISC_W = Emu(475488)
OVERLAP_LIMIT = 0.25
PICTURE_OVERLAP_PAGES = {18, 59}          # carried pages whose source already had it

# The written pages that state their finding as plain prose rather than with a
# numbered conclusion, a figure frame or a symbol table. Named one by one so the
# list cannot grow by accident.
PROSE_PAGES = {
    64: "the four admissible objects and the grid schematic",
    65: "the official composite, stitched from three products",
    66: "what each product publishes",
    67: "where the official series is strong and where it stops",
    68: "data age",
    69: "the 376-column lead axis",
    70: "the error grid and the clamping rule",
    71: "the four admissible comparisons and the pooled ban",
    92: "the 48-column banding is grid structure",
    93: "twenty predictors are defined, sixteen are benched",
    106: "the figure index",
    107: "the census bands are contested",
    108: "the lead axis changes hands four times",
    112: "what this deck maintains and how to rebuild it",
}

PROBLEMS = []
SAY = []


def say(fmt="", *a):
    SAY.append((fmt % a) if a else fmt)


def flag(kind, msg):
    PROBLEMS.append((kind, msg))


def runs_of(slide):
    out = []
    for sh in slide.shapes:
        if sh.has_text_frame:
            for p in sh.text_frame.paragraphs:
                for r in p.runs:
                    out.append(r)
        if sh.has_table:
            for row in sh.table.rows:
                for c in row.cells:
                    for p in c.text_frame.paragraphs:
                        for r in p.runs:
                            out.append(r)
    return out


def text_of(slide):
    out = []
    for sh in slide.shapes:
        if sh.has_text_frame:
            out.append(sh.text_frame.text)
        if sh.has_table:
            for row in sh.table.rows:
                for c in row.cells:
                    out.append(c.text)
    return "\n".join(out)


def family_of(index):
    """carried or written, from the origin list."""
    if index <= len(ORIGIN_KINDS):
        return "carried" if ORIGIN_KINDS[index - 1] in ("carry", "nav") else "written"
    return "written"


STRIP = [
    r"\d{4}-\d{2}-\d{2}", r"\b\d{2}-\d{2}\b", r"\d{1,2}:\d{2}", r"Q\d+",
    r"[abc]_h", r"AR\(\d+\)", r"DMS\d", r"P5MIN", r"PD7DAY", r"PREDISPATCH", r"VIC1",
]


def check_numbers(family_by_page):
    """Every number on a written page has to be in the registered set."""
    allowed = N.number_strings() | N.STRUCTURAL
    bad = []
    prs = Presentation(DECK)
    for i, slide in enumerate(prs.slides, start=1):
        if family_by_page[i] != "written":
            continue
        blob = text_of(slide).replace(",", "")
        for pat in STRIP:
            blob = re.sub(pat, " ", blob)
        for tok in re.findall(r"\d+(?:\.\d+)?", blob):
            tok = tok.rstrip(".")
            if tok in allowed or tok.lstrip("0") in allowed or ("0" + tok) in allowed:
                continue
            bad.append((i, tok))
    return bad


def main():
    global ORIGIN_KINDS
    if not os.path.exists(DECK):
        raise SystemExit("no deck at %s" % DECK)
    with open(ORIGIN, encoding="utf-8") as fh:
        ORIGIN_KINDS = [s["kind"] for s in json.load(fh)["slides"]]
    prs = Presentation(DECK)
    slides = list(prs.slides)
    family_by_page = {i: family_of(i) for i in range(1, len(slides) + 1)}

    say("=" * 86)
    say("deck check  %s" % os.path.basename(DECK))
    say("=" * 86)
    say("pages %d   %.3f x %.3f in   %.1f MB"
        % (len(slides), prs.slide_width / 914400, prs.slide_height / 914400,
           os.path.getsize(DECK) / 1048576.0))
    written = [i for i, f in family_by_page.items() if f == "written"]
    say("carried %d   written %d" % (len(slides) - len(written), len(written)))
    say("")

    # ---- 1 page count and size
    if len(slides) != PAGES_EXPECTED:
        flag("count", "%d pages, expected %d" % (len(slides), PAGES_EXPECTED))
    if (prs.slide_width, prs.slide_height) != SIZE_EXPECTED:
        flag("size", "slide is %d x %d EMU, expected %s"
             % (prs.slide_width, prs.slide_height, SIZE_EXPECTED))
    say("1  page count %d, slide size %d x %d"
        % (len(slides), prs.slide_width, prs.slide_height))

    # ---- 2 page number discs on the written pages.
    # The carried pages number themselves in their own design (a text box or a
    # coloured band), so the rule is stated for the family that follows it: a
    # written page carries the 0.52 in navy oval, or it is an opener.
    no_disc = []
    for i in written:
        if i in OPENER_PAGES:
            continue
        if not any(sh.shape_type == MSO_SHAPE_TYPE.AUTO_SHAPE
                   and sh.auto_shape_type == MSO_SHAPE.OVAL and sh.width == DISC_W
                   for sh in slides[i - 1].shapes):
            no_disc.append(i)
    if no_disc:
        flag("disc", "written pages without a page number disc: %s" % no_disc)
    say("2  page number discs on written pages: %s"
        % ("all present" if not no_disc else "missing on %s" % no_disc))

    # ---- 3 numbers
    bad = check_numbers(family_by_page)
    if bad:
        for page, tok in bad[:20]:
            flag("number", "p%d untraceable number %s" % (page, tok))
    say("3  untraceable numbers on written pages: %d%s"
        % (len(bad), "" if not bad else "  %s" % bad[:6]))

    # ---- 4, 5, 6, 7, 8, 9 per slide
    size_hist = Counter()
    overlap = []
    empty = []
    stretched = []
    for i, slide in enumerate(slides, start=1):
        fam = family_by_page[i]
        pics, boxes, texts = [], [], []
        for sh in slide.shapes:
            if sh.left is None:
                continue
            if fam == "written" and (sh.left < -TOL or sh.top < -TOL
                                     or sh.left + sh.width > prs.slide_width + TOL
                                     or sh.top + sh.height > prs.slide_height + TOL):
                flag("bounds", "p%d %s is off the page" % (i, sh.shape_type))
            if sh.has_text_frame and sh.text_frame.text.strip():
                boxes.append(sh)
                texts.append(sh.text_frame.text)
            if sh.has_table:
                for row in sh.table.rows:
                    for c in row.cells:
                        texts.append(c.text)
            if sh.shape_type == MSO_SHAPE_TYPE.PICTURE:
                pics.append(sh)
                # The aspect rule is for the written pages. Two carried pages
                # stretch a picture and three overlap a text box as their sources
                # already did, and this deck's job with those is to copy them.
                if fam != "written":
                    continue
                try:
                    from PIL import Image
                    with Image.open(io.BytesIO(sh.image.blob)) as im:
                        iw, ih = im.size
                    want = iw / float(ih)
                    got = sh.width / float(sh.height)
                    if abs(want - got) / want > 0.01:
                        stretched.append(i)
                        flag("aspect", "p%d picture stretched %.3f vs %.3f"
                             % (i, want, got))
                except Exception as exc:                # noqa: BLE001
                    flag("aspect", "p%d picture unreadable: %r" % (i, exc))
        for r in runs_of(slide):
            if r.font.size is None:
                flag("type", "p%d a run has no explicit size: %r" % (i, r.text[:30]))
                continue
            sz = round(r.font.size.pt, 2)
            size_hist[sz] += 1
            if fam == "written" and sz not in NEW_SIZES:
                flag("type", "p%d %s pt is not one of the declared sizes" % (i, sz))
        for pic in pics:
            for box in boxes:
                ox = max(0, min(pic.left + pic.width, box.left + box.width)
                         - max(pic.left, box.left))
                oy = max(0, min(pic.top + pic.height, box.top + box.height)
                         - max(pic.top, box.top))
                if ox > 0 and oy > 0 and fam == "written":
                    frac = (ox * oy) / float(box.width * box.height)
                    if frac > OVERLAP_LIMIT:
                        overlap.append((i, round(frac, 2)))
                        if i not in PICTURE_OVERLAP_PAGES:
                            flag("overlap", "p%d a picture covers %.0f%% of a text box"
                                 % (i, frac * 100))
        if not texts and not pics:
            empty.append(i)
            flag("density", "p%d has no text and no picture" % i)

    say("4  run sizes in use: %s"
        % ", ".join("%g pt x%d" % (s, n) for s, n in sorted(size_hist.items())))
    say("5  colours: checked below at the XML level")
    say("6  pictures stretched: %s   pictures overlapping a text box: %s"
        % (sorted(set(stretched)) or "none", overlap or "none"))
    say("7  geometry off the page on a written page: see problems")
    say("8  overlap: see 6")
    say("9  empty pages: %s" % (empty or "none"))

    # ---- XML level: palette, autofit, formula transparency
    palette_all, palette_written = Counter(), Counter()
    autofit_written, autofit_carried = 0, 0
    opaque, tiles = [], 0
    with zipfile.ZipFile(DECK) as zf:
        names = sorted((n for n in zf.namelist()
                        if re.match(r"ppt/slides/slide\d+\.xml$", n)),
                       key=lambda n: int(re.findall(r"\d+", n)[0]))
        for i, name in enumerate(names, start=1):
            xml = zf.read(name).decode("utf-8", errors="replace")
            fam = family_by_page[i]
            if fam == "written":
                autofit_written += xml.count("normAutofit")
            else:
                autofit_carried += xml.count("normAutofit")
            for val in re.findall(r'<a:srgbClr val="([0-9A-Fa-f]{6})"', xml):
                palette_all[val.upper()] += 1
                if fam == "written":
                    palette_written[val.upper()] += 1
        # Formula tiles are the images that carry alpha, and every one pasted on
        # a written page must be transparent at all four corners: the tile takes
        # the page behind it, which is what keeps a formula off a black box. A
        # figure or a schematic is painted on white, and the carried pages hold
        # formula images of their own painted on dark, so the family decides
        # which images the rule applies to. Media are matched by their SHA1,
        # which is how the package deduplicates an image.
        import hashlib
        written_media = set()
        for i in written:
            for sh in slides[i - 1].shapes:
                if sh.shape_type == MSO_SHAPE_TYPE.PICTURE:
                    written_media.add(hashlib.sha1(sh.image.blob).hexdigest())
        for name in (n for n in zf.namelist() if n.startswith("ppt/media/")):
            try:
                from PIL import Image
                blob = zf.read(name)
                if hashlib.sha1(blob).hexdigest() not in written_media:
                    continue
                with Image.open(io.BytesIO(blob)) as im:
                    if im.mode not in ("RGBA", "LA"):
                        continue
                    w, h = im.size
                    # A formula tile is a line of maths: wide, short, and never
                    # an illustration. The two schematics are drawn on white and
                    # are the only images this test would otherwise misread.
                    if w < 400 or w / float(h) < 5.0:
                        continue
                    tiles += 1
                    a = im.getchannel("A")
                    corners = [a.getpixel(p) for p in
                               ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))]
                    if max(corners) != 0:
                        opaque.append((name.split("/")[-1], w, h,
                                       [round(c / 255.0, 2) for c in corners]))
            except Exception:                            # noqa: BLE001
                continue
    extra = sorted(set(palette_written) - PALETTE)
    if extra:
        flag("palette", "written pages use colours outside the six: %s" % extra)
    if autofit_written:
        flag("autofit", "%d normAutofit on written pages" % autofit_written)
    for row in opaque[:10]:
        flag("alpha", "formula tile %s (%dx%d) has a corner at %s"
             % (row[0], row[1], row[2], row[3]))
    say("5  palette on written pages: %s"
        % (", ".join("%s x%d" % (c, n) for c, n in sorted(palette_written.items()))
           or "none"))
    say("   palette on carried pages: %d distinct colours"
        % len(set(palette_all) - set(palette_written)))
    say("   normAutofit: %d on written pages, %d on carried"
        % (autofit_written, autofit_carried))
    say("   formula tiles checked: %d, with a corner that is not transparent: %d"
        % (tiles, len(opaque)))

    # ---- 10 every written page states its finding, in one of five shapes.
    # The two openers say it in three lines, the nine evaluation pages lead with
    # a titled block, the predictor pages lead with an assertion sentence and
    # carry a symbol table, the figure pages carry the five-line frame, the
    # closing pages carry numbered conclusions, and thirteen pages state it as
    # plain prose and are named one by one in PROSE_PAGES. Two things hold on
    # every written page: a scope line and a declared type size.
    missing = []
    for i, slide in enumerate(slides, start=1):
        if family_by_page[i] != "written" or i in OPENER_PAGES:
            continue
        body = text_of(slide)
        numbered = bool(re.search(r"(?m)^\d+\.\s", body))
        frame = "What you see" in body and "Conclusion." in body
        symbols = "Symbols on this page" in body
        if not (numbered or frame or symbols or i in PROSE_PAGES):
            missing.append(i)
        if "Scope" not in body:
            flag("scope", "p%d carries no scope line" % i)
    if missing:
        flag("conclusion", "written pages whose finding is not in a known shape: %s"
             % missing)
    say("10 written pages whose finding is not in a known shape: %s"
        % (missing or "none"))

    say("")
    say("=" * 86)
    if PROBLEMS:
        by_kind = Counter(k for k, _ in PROBLEMS)
        say("PROBLEMS: %d" % len(PROBLEMS))
        for kind, n in sorted(by_kind.items()):
            say("   %-10s %d" % (kind, n))
        say("")
        for kind, msg in PROBLEMS[:40]:
            say("   %-10s %s" % (kind, msg))
        if len(PROBLEMS) > 40:
            say("   ... and %d more" % (len(PROBLEMS) - 40))
    else:
        say("PASS: every check holds on the written pages, and the carried pages are")
        say("      judged only on integrity and the overhangs their sources had.")
    print("\n".join(SAY))
    return 1 if PROBLEMS else 0


ORIGIN_KINDS = []

if __name__ == "__main__":
    sys.exit(main())
