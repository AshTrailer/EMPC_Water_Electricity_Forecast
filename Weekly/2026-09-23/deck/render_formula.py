# -*- coding: utf-8 -*-
"""Render LaTeX formulas to TRANSPARENT PNGs for the deck.

Why this exists: the previous deck wrote formulas as plain text runs with manual
baseline superscripts. Those runs render (Cambria has the glyphs), but they read
as typeset text rather than mathematics - no real fractions, no summation limits.
The manual workaround was to paste LaTeX images rendered elsewhere, but those came
out as opaque near-black tiles (measured: alpha 255 everywhere, corner RGB
(21,21,23)) which sit on a white slide as black blocks.

This renderer uses matplotlib's built-in mathtext (no TeX distribution needed) and
always writes a transparent background with dark ink, and reports the PNG's
aspect ratio so the caller can size the picture without distorting it.

Usage:
  python render_formula.py --tex "\\hat{r}(t+s|t)=\\phi^T[\\hat{r}(t+s-1|t)]" --out f.png
  python render_formula.py --selftest
"""

import argparse
import json
import os

# must be set BEFORE matplotlib is imported, otherwise it is ignored
os.environ.setdefault("MPLCONFIGDIR",
                      os.path.join(os.path.dirname(os.path.abspath(__file__)), "_mplcache"))
import matplotlib                     # noqa: E402
matplotlib.use("Agg")
import matplotlib.pyplot as plt       # noqa: E402
from PIL import Image                 # noqa: E402

INK = "#1B2430"      # deck body colour
DEFAULT_DPI = 600


def render(tex, out_png, fontsize=14, color=INK, dpi=DEFAULT_DPI):
   """Write `tex` (without the surrounding $) as a transparent-background PNG."""
   fig = plt.figure(figsize=(0.01, 0.01))
   fig.text(0.0, 0.0, "$%s$" % tex, fontsize=fontsize, color=color)
   fig.savefig(out_png, dpi=dpi, transparent=True,
               bbox_inches="tight", pad_inches=0.02)
   plt.close(fig)
   with Image.open(out_png) as im:
      w, h = im.size
      rgba = im.convert("RGBA")
      alpha = rgba.getchannel("A")
      lo, hi = alpha.getextrema()
      corner = rgba.getpixel((0, 0))
   return {
      "tex": tex, "path": os.path.basename(out_png),
      "w": w, "h": h, "aspect": round(w / h, 6),
      "alpha_min": lo, "alpha_max": hi,
      "corner_rgba": list(corner),
      "transparent": lo == 0,
   }


def selftest():
   here = os.path.dirname(os.path.abspath(__file__))
   outdir = os.path.join(here, "_formula_samples")
   os.makedirs(outdir, exist_ok=True)
   samples = [
      r"\hat{r}(t+s|t)=\phi^{T}[\hat{r}(t+s-1|t),\ldots,\hat{r}(t+s-4|t)]^{T}",
      r"\hat{y}(t+s|t)=\mu+\hat{r}(t+s|t)",
      r"e(k,k_i)=y(k)-\hat{y}_{\mathrm{AEMO}}(k\,|\,k_i)",
      r"\hat{y}_{\mathrm{corr}}(k|k_0)=\hat{y}_{\mathrm{AEMO}}(k|k_0)+\hat{e}(k|k_0)",
      r"K=\frac{P\varphi}{\lambda+\varphi^{T}P\varphi}\in\mathbb{R}^{p}",
      r"T_{c}(s)=\frac{1}{N}\sum_{d\in W_{c}}y_{d}(s),\qquad s=1\ldots288",
      r"\hat{e}(k|k_0)=\beta_{h}\;\varepsilon(k_0),\qquad \varepsilon(k)=y(k)-\hat{y}_{\mathrm{AEMO}}(k|k)",
   ]
   rows = []
   for i, tex in enumerate(samples):
      p = os.path.join(outdir, "sample_%02d.png" % i)
      info = render(tex, p)
      rows.append(info)
      print("%-2d %-58s %5dx%-4d aspect=%.3f  alpha=[%d,%d] corner=%s %s" %
            (i, tex[:58], info["w"], info["h"], info["aspect"],
             info["alpha_min"], info["alpha_max"], info["corner_rgba"],
             "OK" if info["transparent"] else "*** NOT TRANSPARENT ***"))
   meta = os.path.join(outdir, "samples.json")
   with open(meta, "w", encoding="utf-8") as fh:
      json.dump(rows, fh, indent=1, ensure_ascii=False)
   bad = [r for r in rows if not r["transparent"]]
   print("")
   print("selftest: %d formulas, %d with a transparent background" % (len(rows), len(rows) - len(bad)))
   if bad:
      raise SystemExit("FAIL: some formulas rendered with an opaque background")
   print("wrote", meta)


def main():
   ap = argparse.ArgumentParser(description="Render a LaTeX formula to a transparent PNG")
   ap.add_argument("--tex")
   ap.add_argument("--out")
   ap.add_argument("--fontsize", type=float, default=14)
   ap.add_argument("--color", default=INK)
   ap.add_argument("--selftest", action="store_true")
   args = ap.parse_args()
   if args.selftest:
      selftest()
      return
   if not args.tex or not args.out:
      raise SystemExit("need --tex and --out (or --selftest)")
   info = render(args.tex, args.out, fontsize=args.fontsize, color=args.color)
   print(json.dumps(info, ensure_ascii=False))


if __name__ == "__main__":
   main()
