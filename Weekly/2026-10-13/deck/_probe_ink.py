# -*- coding: utf-8 -*-
"""Render a probe slide and measure the ink extent of every shape on it.

LibreOffice renders the slide to PNG; this reads the resulting image and reports
the lowest and rightmost non-white pixel, which is the only honest way to know
whether text fits. Reading the text frame's declared height is wrong: pptx
stores the height the caller asked for, not the height the text needs.
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
NODE = r"C:\DeepSeek Harness\resources\runtime\primary-runtime\dependencies\node\bin\node.exe"
CLI = (r"C:\DeepSeek Harness\resources\app.asar.unpacked\dsh\node_modules"
       r"\@deepseek-ai\libreoffice-kit\lib\cli.js")


def render_pdf(pptx, outdir, timeout=300):
    os.makedirs(outdir, exist_ok=True)
    cmd = [NODE, CLI, "convert", "--input", pptx, "--output", outdir,
           "--format", "pdf"]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if p.returncode != 0:
        raise RuntimeError("pdf convert failed: %s\n%s" % (p.stdout, p.stderr))
    return os.path.join(outdir, os.path.splitext(os.path.basename(pptx))[0] + ".pdf")


def render_png(pptx, outdir, timeout=600):
    os.makedirs(outdir, exist_ok=True)
    cmd = [NODE, CLI, "convert", "--input", pptx, "--output", outdir,
           "--format", "png"]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if p.returncode != 0:
        raise RuntimeError("png convert failed: %s\n%s" % (p.stdout, p.stderr))
    files = sorted(os.path.join(outdir, f) for f in os.listdir(outdir)
                   if f.lower().endswith(".png"))
    return files


def ink_extent(png):
    from PIL import Image
    with Image.open(png) as im:
        g = im.convert("L")
        w, h = g.size
        px = g.load()
        bottom = 0
        right = 0
        for y in range(h):
            row = [px[x, y] for x in range(w)]
            if min(row) < 200:
                bottom = y
        for x in range(w):
            col = [px[x, y] for y in range(h)]
            if min(col) < 200:
                right = x
        return w, h, right, bottom


if __name__ == "__main__":
    for f in sys.argv[1:]:
        print(f, ink_extent(f))
