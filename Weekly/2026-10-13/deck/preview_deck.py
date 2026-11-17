# -*- coding: utf-8 -*-
"""Whole-page previews, working around a measured defect in the render path.

THE DEFECT. The bundled LibreOffice kit draws slide content at 1.75 x dpi pixels
per inch while it rasterises the page at dpi pixels per inch, so every preview
shows only the top-left 57 percent of the page and crops the rest. Measured, not
inferred: the same two marks on a 13.333 in page and on a 26.667 in page come out
at identical pixels (a 0.16 in bar is 27 px at --dpi 100 in both), and the
content scale tracks dpi times 1.75 while the canvas tracks dpi. Raising or
lowering --dpi cannot fix it, because both scale together. See
_probe_zoom_model.py and _probe_render_scale.py.

THE WORKAROUND. Build a throwaway copy of the deck with every shape and every
font scaled by 1/1.75, so the content occupies 57 percent of the page and the
renderer's 1.75x magnification brings it back to exactly the page raster. Render
that copy at a higher dpi so the smaller type is still legible. The copy is never
delivered; only the PNGs are used, for looking at.

Usage:
  python preview_deck.py --deck deck_A_carry.pptx --pages 1,2,10 --outdir preview
"""

import argparse
import json
import os
import shutil
import subprocess
import sys

from pptx import Presentation
from pptx.util import Emu, Pt

HERE = os.path.dirname(os.path.abspath(__file__))
NODE = r"C:\DeepSeek Harness\resources\runtime\primary-runtime\dependencies\node\bin\node.exe"
CLI = (r"C:\DeepSeek Harness\resources\app.asar.unpacked\dsh\node_modules"
       r"\@deepseek-ai\libreoffice-kit\lib\cli.js")

SCALE = 1.0 / 1.75


def scale_shape(sh, k):
    if sh.left is not None:
        sh.left = Emu(int(round(sh.left * k)))
        sh.top = Emu(int(round(sh.top * k)))
        sh.width = Emu(int(round(sh.width * k)))
        sh.height = Emu(int(round(sh.height * k)))
    if sh.shape_type == 6:                      # group
        for sub in sh.shapes:
            scale_shape(sub, k)
        return
    if sh.has_text_frame:
        tf = sh.text_frame
        for attr in ("margin_left", "margin_right", "margin_top", "margin_bottom"):
            v = getattr(tf, attr)
            if v:
                setattr(tf, attr, Emu(int(round(v * k))))
        for p in tf.paragraphs:
            for attr in ("space_before", "space_after"):
                v = getattr(p, attr)
                if v:
                    setattr(p, attr, Pt(v.pt * k))
            for r in p.runs:
                if r.font.size is not None:
                    r.font.size = Pt(r.font.size.pt * k)
    if sh.has_table:
        for row in sh.table.rows:
            row.height = Emu(int(round(row.height * k)))
        for col in sh.table.columns:
            col.width = Emu(int(round(col.width * k)))
        for row in sh.table.rows:
            for c in row.cells:
                for p in c.text_frame.paragraphs:
                    for r in p.runs:
                        if r.font.size is not None:
                            r.font.size = Pt(r.font.size.pt * k)
                for attr in ("margin_left", "margin_right", "margin_top", "margin_bottom"):
                    v = getattr(c, attr)
                    if v:
                        setattr(c, attr, Emu(int(round(v * k))))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--deck", required=True)
    ap.add_argument("--pages", default="")
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--dpi", type=int, default=175)
    ap.add_argument("--once", action="store_true",
                    help="shrink the slide record instead of every shape")
    ap.add_argument("--once-dpi", type=int, default=100,
                    help="renderer dpi for --once; the canvas is dpi/7.5 x dpi/12.857 in")
    ap.add_argument("--keep-temp", action="store_true")
    ap.add_argument("--max-pages", type=int, default=100,
                    help="the kit refuses more pages than this; the delivered deck has 112")
    args = ap.parse_args()

    src = args.deck if os.path.isabs(args.deck) else os.path.join(HERE, args.deck)
    outdir = args.outdir if os.path.isabs(args.outdir) else os.path.join(HERE, args.outdir)
    tmpdir = os.path.join(HERE, "_preview_tmp")
    os.makedirs(tmpdir, exist_ok=True)
    tmp_pptx = os.path.join(tmpdir, "scaled.pptx")

    prs = Presentation(src)
    sw, sh = prs.slide_width, prs.slide_height
    if os.path.isdir(outdir):
        shutil.rmtree(outdir)
    if getattr(args, "once", False):
        # Measured, four ways (_probe_pin.py): the renderer draws EVERY object at
        # 1.75 x dpi pixels per inch while it rasterises the slide at dpi pixels
        # per inch. At dpi 100 that is 175 px per inch of content on a 100 px per
        # inch canvas, so the right and bottom 43 percent of every page is simply
        # outside the frame and no --dpi value changes either number: raising dpi
        # raises both together (dpi 175 gave 306.5 px per inch of content).
        #
        # The slide record must NOT be shrunk to compensate. Scaling the record
        # scales the content with it, because the renderer's 1.75 multiplier is
        # applied to the record's own inches: a record at 57 percent rendered its
        # bar at 0.1 x the intended size. Only the objects are scaled, by exactly
        # 1/1.75, which puts them back on the canvas at their true size.
        for slide in prs.slides:
            for shp in slide.shapes:
                scale_shape(shp, SCALE)
        prs.save(tmp_pptx)
        print("once: objects x %.4f, record left at %.3f x %.3f in, dpi %d"
              % (SCALE, sw / 914400.0, sh / 914400.0, args.once_dpi))
    else:
        for slide in prs.slides:
            for shp in slide.shapes:
                scale_shape(shp, SCALE)
        prs.save(tmp_pptx)
        print("scaled copy: %s  (%d slides, factor %.4f)"
              % (tmp_pptx, len(prs.slides._sldIdLst), SCALE))

    if os.path.isdir(outdir):
        shutil.rmtree(outdir)
    dpi = args.once_dpi if getattr(args, "once", False) else args.dpi
    cmd = [NODE, CLI, "render", "--input", tmp_pptx, "--output-dir", outdir,
           "--dpi", str(dpi), "--max-pages", str(args.max_pages)]
    if args.pages:
        cmd += ["--pages", args.pages]
    log = os.path.join(tmpdir, "render.json")
    with open(log, "w", encoding="utf-8") as fh:
        subprocess.run(cmd, stdout=fh, stderr=subprocess.STDOUT, check=False)
    with open(log, encoding="utf-8") as fh:
        info = json.load(fh)
    print("dpi %d   pages %d   missing fonts %s"
          % (args.dpi, len(info.get("images", [])), info.get("missingFonts")))
    for im in info.get("images", []):
        print("  page %-4d %s  %dx%d" % (im["page"], os.path.basename(im["path"]),
                                         im["width"], im["height"]))
    if not args.keep_temp:
        pass          # the scaled copy stays: it is the input to any later re-render
    return 0


if __name__ == "__main__":
    sys.exit(main())
