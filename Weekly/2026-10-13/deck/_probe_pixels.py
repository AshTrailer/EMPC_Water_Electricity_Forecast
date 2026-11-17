# -*- coding: utf-8 -*-
"""Exact pixel readout of two known geometry elements on the navigation page.

   navy bar   0.16 in tall, full width, at y = 0
   amber rule 0.05 in tall, x 0.58 .. 2.78 in, y 3.70 in

Prints the raw pixels so the scale factor is a measurement, not an inference.
"""

import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PAGE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "preview_carry", "page-0001.png")


def main():
    im = Image.open(PAGE).convert("RGB")
    W, H = im.size
    print("%s  %dx%d" % (os.path.basename(PAGE), W, H))

    print("\ncolumn x=8, rows 0..34:")
    for y in range(0, 35):
        p = im.getpixel((8, y))
        mark = ""
        if y > 0:
            q = im.getpixel((8, y - 1))
            if max(abs(a - b) for a, b in zip(p, q)) > 12:
                mark = "   <-- change"
        print("  y=%2d  rgb=%s%s" % (y, p, mark))

    print("\nrow scan for amber (233,168,32) +-10:")
    hits = []
    for y in range(H):
        p = im.getpixel((int(W * 0.10), y))
        if all(abs(a - b) <= 10 for a, b in zip(p, (233, 168, 32))):
            hits.append(y)
    if hits:
        yc = (hits[0] + hits[-1]) // 2
        xs = [x for x in range(W)
              if all(abs(a - b) <= 10 for a, b in zip(im.getpixel((x, yc)), (233, 168, 32)))]
        print("  amber rows %d..%d  (height %d px)" % (hits[0], hits[-1], hits[-1] - hits[0] + 1))
        print("  amber left %d  right %d  (width %d px)" % (xs[0], xs[-1], xs[-1] - xs[0] + 1))
    else:
        print("  none at x=%d" % int(W * 0.10))

    print("\nrow scan for the note text band, dark ink below the rule:")
    for y in range(H - 1, 0, -1):
        row = [im.getpixel((x, y)) for x in range(0, W, 3)]
        if any(p[0] < 120 and p[1] < 120 for p in row):
            print("  lowest dark row %d" % y)
            break


if __name__ == "__main__":
    main()
