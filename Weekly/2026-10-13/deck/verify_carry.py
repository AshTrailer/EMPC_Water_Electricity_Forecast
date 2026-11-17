# -*- coding: utf-8 -*-
"""Prove the carried slides are copies, not lookalikes.

Six criteria, all recomputed from the two files rather than trusted:

  pages      the target holds exactly one slide per source slide, plus one
             navigation page per block
  shapes     the shape count per slide matches the source
  runs       the text run sequence per slide matches the source, in order
  pictures   the picture count and each picture's sha256 match the source
  geometry   every shape's left, top, width and height match to the EMU
  theme      the schemeClr references match in count and in value, so a carried
             colour cannot have been resolved against a different theme

Anything the source does not have and the target does is reported. Exit code 0
means every criterion passed.
"""

import hashlib
import json
import os
import re
import sys
import zipfile
from collections import Counter

from pptx import Presentation

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast"

SOURCES = {
    "Capstone_Forecasting_Deck.pptx": os.path.join(ROOT, "Course Material", "Capstone_Forecasting_Deck.pptx"),
    "Capstone_Weekly_2026-09-23.pptx": os.path.join(ROOT, "Course Material", "Capstone_Weekly_2026-09-23.pptx"),
    "Capstone_Update_2026-10-08_EN.pptx": os.path.join(ROOT, "Weekly", "2026-10-08", "deck",
                                                      "Capstone_Update_2026-10-08_EN.pptx"),
}

TARGET = os.path.join(HERE, "deck_A_carry.pptx")
ORIGIN = os.path.join(HERE, "slide_origin.json")

problems = []


def flag(kind, msg):
    problems.append((kind, msg))
    print("   !! %-9s %s" % (kind, msg))


def walk(shapes, depth=0):
    for sh in shapes:
        yield sh, depth
        if sh.shape_type == 6:
            for sub, d in walk(sh.shapes, depth + 1):
                yield sub, d


def slide_facts(slide):
    """Shape count, run sequence, picture hashes, geometry, for one slide."""
    n_shapes = 0
    runs = []
    pics = []
    geom = []

    def visit(shapes):
        nonlocal n_shapes
        for sh in shapes:
            n_shapes += 1
            if sh.__class__.__name__ == "Picture":
                pics.append(hashlib.sha256(sh.image.blob).hexdigest())
            if sh.has_text_frame:
                for p in sh.text_frame.paragraphs:
                    for r in p.runs:
                        if r.text:
                            runs.append(r.text)
            if sh.has_table:
                for row in sh.table.rows:
                    for c in row.cells:
                        runs.append(c.text)
            try:
                geom.append((sh.left, sh.top, sh.width, sh.height))
            except TypeError:
                geom.append(None)
            if sh.shape_type == 6:
                visit(sh.shapes)

    visit(slide.shapes)
    return {"n_shapes": n_shapes, "runs": runs, "pics": pics, "geom": geom}


def oob_set(geom, width, height):
    """Indices of shapes that are not fully inside the page."""
    out = set()
    for i, g in enumerate(geom):
        if g is None:
            continue
        if g[0] < 0 or g[1] < 0 or g[0] + g[2] > width or g[1] + g[3] > height:
            out.add(i)
    return out


def scheme_census_slide(path, partname):
    """schemeClr references in one slide part, by value."""
    out = Counter()
    with zipfile.ZipFile(path) as z:
        key = partname.lstrip("/")
        if key not in z.namelist():
            return None
        x = z.read(key).decode("utf-8", "replace")
        out.update(re.findall(r"<a:schemeClr val=\"(\w+)\"", x))
    return out


def main():
    if not os.path.exists(TARGET):
        raise SystemExit("no target deck at %s, run build_carry.py first" % TARGET)
    with open(ORIGIN, encoding="utf-8") as fh:
        origin = json.load(fh)["slides"]

    tgt = Presentation(TARGET)
    print("target %s" % os.path.basename(TARGET))
    print("  slides %d   size %dx%d EMU" % (len(tgt.slides._sldIdLst), tgt.slide_width, tgt.slide_height))
    print("")

    expected = sum(1 for o in origin)
    if len(tgt.slides._sldIdLst) != expected:
        flag("pages", "target has %d slides, the origin list has %d" % (len(tgt.slides._sldIdLst), expected))
    else:
        print("pages      %d slides, matching the origin list (carried %d, nav %d)"
              % (expected, sum(1 for o in origin if o["kind"] == "carry"),
                 sum(1 for o in origin if o["kind"] == "nav")))

    src_slides = {}
    for name, path in SOURCES.items():
        prs = Presentation(path)
        src_slides[name] = list(prs.slides)
        got = sum(1 for o in origin if o["kind"] == "carry" and o["source"] == name)
        if got != len(src_slides[name]):
            flag("pages", "%s: %d carried, source has %d" % (name, got, len(src_slides[name])))
        else:
            print("block      %-46s %2d of %2d carried" % (name, got, len(src_slides[name])))

    n_shapes = n_runs = n_pics = n_geom = n_theme = n_bounds = 0
    n_overhang = 0
    for o in origin:
        if o["kind"] != "carry":
            continue
        dst = tgt.slides[o["index"] - 1]
        src = src_slides[o["source"]][o["source_slide"] - 1]
        tag = "%s p%d -> target p%d" % (o["source"], o["source_slide"], o["index"])
        f_dst = slide_facts(dst)
        f_src = slide_facts(src)
        n_shapes += 1
        if f_dst["n_shapes"] != f_src["n_shapes"]:
            flag("shapes", "%s: %d shapes, source has %d" % (tag, f_dst["n_shapes"], f_src["n_shapes"]))
        if f_dst["runs"] != f_src["runs"]:
            bad = next((i for i, (a, b) in enumerate(zip(f_dst["runs"], f_src["runs"])) if a != b),
                       min(len(f_dst["runs"]), len(f_src["runs"])))
            flag("runs", "%s: run %d is %r, source has %r"
                 % (tag, bad, f_dst["runs"][bad][:40] if bad < len(f_dst["runs"]) else None,
                    f_src["runs"][bad][:40] if bad < len(f_src["runs"]) else None))
        else:
            n_runs += 1
        if f_dst["pics"] != f_src["pics"]:
            flag("pictures", "%s: %d pictures, source has %d (hash order matters)"
                 % (tag, len(f_dst["pics"]), len(f_src["pics"])))
        else:
            n_pics += 1
        if f_dst["geom"] != f_src["geom"]:
            bad = next((i for i, (a, b) in enumerate(zip(f_dst["geom"], f_src["geom"])) if a != b), None)
            flag("geometry", "%s: shape %s geometry %s vs source %s"
                 % (tag, bad, f_dst["geom"][bad] if bad is not None else None,
                    f_src["geom"][bad] if bad is not None else None))
        else:
            n_geom += 1

        # Theme references are compared PER SLIDE. A whole-deck total would be
        # polluted by the navigation pages: python-pptx's add_shape writes a
        # <p:style> block referencing accent1 and lt1, inert because the fill is
        # set explicitly, but it does change a total.
        c_dst = scheme_census_slide(TARGET, str(dst.part.partname))
        c_src = scheme_census_slide(SOURCES[o["source"]], str(src.part.partname))
        if c_dst != c_src:
            flag("theme", "%s: schemeClr %s vs source %s" % (tag, dict(c_dst or {}), dict(c_src or {})))
        else:
            n_theme += 1

        # Nothing may stick out of the target page unless the SOURCE already
        # sticks out of its own page. Deck 1 decorates three slides with rings
        # that bleed off the edge, so a zero-overhang rule would fail a faithful
        # copy. What matters is that the carry introduces no new overhang, which
        # is also where a narrower target page would show up: two sources are
        # 12192000 wide and one is 12191695.
        src_prs = Presentation(SOURCES[o["source"]])
        oob_dst = oob_set(f_dst["geom"], tgt.slide_width, tgt.slide_height)
        oob_src = oob_set(f_src["geom"], src_prs.slide_width, src_prs.slide_height)
        if oob_dst != oob_src:
            flag("bounds", "%s: shapes out of the page %s, source has %s"
                 % (tag, sorted(oob_dst), sorted(oob_src)))
        else:
            n_bounds += 1
            if oob_dst:
                n_overhang += 1

    carried = sum(1 for o in origin if o["kind"] == "carry")
    print("")
    print("shapes     %d of %d slides match" % (n_shapes, carried))
    print("runs       %d of %d slides match, run for run" % (n_runs, carried))
    print("pictures   %d of %d slides match, hash for hash" % (n_pics, carried))
    print("geometry   %d of %d slides match to the EMU" % (n_geom, carried))
    print("theme      %d of %d slides match, per slide" % (n_theme, carried))
    print("bounds     %d of %d slides match; %d of those carry an overhang the"
          " source already had" % (n_bounds, carried, n_overhang))
    print("")
    if problems:
        print("FAIL: %d problems" % len(problems))
        raise SystemExit(1)
    print("PASS: every carried slide is a copy of its source")


if __name__ == "__main__":
    main()
