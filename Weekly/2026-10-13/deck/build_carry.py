# -*- coding: utf-8 -*-
"""Carry the three English source decks into one archive deck, verbatim.

WHY SHAPE-LEVEL COPY IS EXACT HERE. Measured before writing this, in
_probe_carry.py:

  theme      python-pptx's default template carries the SAME colour scheme as
             all three sources (accent1 = 4F81BD, lt1 = window, everything
             else equal), so a carried schemeClr resolves to the same colour in
             the target and nothing has to be rewritten.
  schemeClr  only two bare forms appear, <a:schemeClr val="accent1"/> and
             <a:schemeClr val="lt1"/>, with no lumMod, shade or tint children,
             so there is no modulation to preserve.
  rels       the only relationship a source slide holds besides its layout is
             an image, and the only relationship id referenced inside slide XML
             is a blip embed (77 of them). No hyperlinks, media, charts or OLE.

So each slide is reproduced by deep-copying the children of its spTree and
remapping the blip embeds. Layouts and masters are not copied: every carried
slide uses the Blank layout, no slide has a title placeholder, and every run
carries an explicit size, so there is nothing left to inherit.

A navigation page goes in front of each block. It is a normal page of the deck,
not a marker saying it was added.
"""

import io
import json
import os
import sys
from copy import deepcopy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "2026-09-23", "deck"))

from pptx import Presentation                                     # noqa: E402
from pptx.util import Emu, Inches, Pt                             # noqa: E402

import deck_kit as K                                              # noqa: E402

A = "http://schemas.openxmlformats.org/drawingml/2006/main"
R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
BLIP = "{%s}blip" % A
EMBED = "{%s}embed" % R

ROOT = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast"

BLOCKS = [
    {
        "file": os.path.join(ROOT, "Course Material", "Capstone_Forecasting_Deck.pptx"),
        "label": "Electricity price forecasting for economic MPC",
        "note": "26 slides, presented 2026-09-17",
    },
    {
        "file": os.path.join(ROOT, "Course Material", "Capstone_Weekly_2026-09-23.pptx"),
        "label": "Data chain audit, predictor baseline, AEMO error model",
        "note": "22 slides, presented 2026-09-23",
    },
    {
        "file": os.path.join(ROOT, "Weekly", "2026-10-08", "deck", "Capstone_Update_2026-10-08_EN.pptx"),
        "label": "VIC1 price forecaster",
        "note": "11 slides, presented 2026-10-08",
    },
]


def shapes_root(slide):
    return slide.shapes._spTree


def copy_slide(src_slide, dst_slide, origin):
    """Deep-copy every shape of src_slide into dst_slide, remapping blip embeds.

    Returns the number of pictures remapped. Raises if the source references a
    relationship this copier does not handle, so an unhandled relation can never
    arrive in the target as a dangling id.
    """
    src_part = src_slide.part
    dst_part = dst_slide.part
    n_pic = 0
    for el in list(shapes_root(src_slide)):
        local = el.tag.split("}")[-1]
        if local in ("nvGrpSpPr", "grpSpPr"):
            continue
        clone = deepcopy(el)
        for blip in clone.iter(BLIP):
            embed = blip.get(EMBED)
            if embed is None:
                raise RuntimeError("%s: blip without r:embed" % origin)
            rel = src_part.rels[embed]
            if not rel.reltype.endswith("/image"):
                raise RuntimeError("%s: blip points at %s, not an image"
                                   % (origin, rel.reltype.rsplit("/", 1)[-1]))
            image_part, new_rid = dst_part.get_or_add_image_part(io.BytesIO(rel.target_part.blob))
            blip.set(EMBED, new_rid)
            n_pic += 1
        for attr in ("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id",
                     "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}link"):
            for node in clone.iter():
                if node.get(attr) is not None:
                    raise RuntimeError("%s: unhandled relationship reference %s on %s"
                                       % (origin, attr, node.tag.split("}")[-1]))
        shapes_root(dst_slide).append(clone)
    return n_pic


def nav_page(prs, label, note):
    """A plain opening page for a carried block: what it is and when it was given."""
    slide = K.blank(prs)
    K.add_rect(slide, 0, 0, K.SLIDE_W, 0.16, fill=K.NAVY)
    _, tf = K.textbox(slide, 0.55, 2.55, 12.2, 1.0)
    K.para(tf, label, 30, K.INK, True, font=K.HDR, first=True, space_after=0)
    K.add_rect(slide, 0.58, 3.70, 2.2, 0.05, fill=K.AMBER)
    _, tf2 = K.textbox(slide, 0.55, 3.98, 12.2, 0.6)
    K.para(tf2, note, 15, K.MUTED, first=True, space_after=0)
    return slide


def main(out="deck_A_carry.pptx"):
    out = out if os.path.isabs(out) else os.path.join(HERE, out)
    prs = K.new_deck()
    # deck_kit writes 13.333 in, which is 12191695 EMU. Two of the three sources
    # are the exact 12192000, so a shape on their right edge would sit 305 EMU
    # outside the target. Set the exact 16:9 size: it is never narrower than a
    # source, and carried shapes keep their absolute EMU either way.
    prs.slide_width = Emu(12192000)
    prs.slide_height = Emu(6858000)
    origin = []
    total_pics = 0
    for block in BLOCKS:
        name = os.path.basename(block["file"])
        if not os.path.exists(block["file"]):
            raise SystemExit("missing source: %s" % block["file"])
        src = Presentation(block["file"])
        nav_page(prs, block["label"], block["note"])
        origin.append({"index": len(origin) + 1, "kind": "nav", "source": name,
                       "source_slide": None, "label": block["label"], "note": block["note"]})
        n = 0
        for i, src_slide in enumerate(src.slides, 1):
            dst = K.blank(prs)
            pics = copy_slide(src_slide, dst, "%s p%d" % (name, i))
            total_pics += pics
            n += 1
            origin.append({"index": len(origin) + 1, "kind": "carry", "source": name,
                           "source_slide": i, "pictures": pics})
        if n != len(src.slides._sldIdLst):
            raise SystemExit("%s: copied %d of %d slides" % (name, n, len(src.slides._sldIdLst)))
        print("%-46s %2d slides carried" % (name, n))

    prs.save(out)
    with open(os.path.join(HERE, "slide_origin.json"), "w", encoding="utf-8") as fh:
        json.dump({"slide_width": prs.slide_width, "slide_height": prs.slide_height,
                   "slides": origin}, fh, indent=1, ensure_ascii=False)
    print("")
    print("wrote %s  (%d slides, %d pictures, %.1f MB)"
          % (out, len(origin), total_pics, os.path.getsize(out) / 1048576.0))


if __name__ == "__main__":
    main()
