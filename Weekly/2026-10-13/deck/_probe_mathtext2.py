# -*- coding: utf-8 -*-
"""Second probe: isolate the minimal constructs that matplotlib mathtext accepts,
so the deck's formula source can be written against a measured allow/deny list
instead of against LaTeX in general.

Usage: python _probe_mathtext2.py <outdir>
"""

import json
import os
import sys

os.environ.setdefault("MPLCONFIGDIR", os.path.join(os.path.dirname(os.path.abspath(__file__)), "_mplcache"))
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from PIL import Image

CASES = [
    ("sp_backslash_space", r"a\ b"),
    ("tilde_braced", r"\tilde{r}(k)"),
    ("tilde_bare", r"\tilde r(k)"),
    ("argmin", r"\arg\min_{p\in P} f(p)"),
    ("argmin_mathrm", r"\mathrm{arg\,min}_{p\in P} f(p)"),
    ("dfrac", r"\dfrac{1}{2}"),
    ("frac", r"\frac{1}{2}"),
    ("big", r"\big(x\big)"),
    ("left_right", r"\left(x\right)"),
    ("cases", r"f=\begin{cases}a\\b\end{cases}"),
    ("braces", r"P=\{1,2,3\}"),
    ("hash", r"\#\{x\}"),
    ("substack2", r"\substack{a\\b}"),
    ("substack3", r"\substack{a\\b\\c}"),
    ("substack_cond", r"\tilde{r}=\substack{r(k+s-j)\ \mathrm{if}\ s\le j\\ \hat{r}(k+s-j)\ \mathrm{otherwise}}"),
    ("mathrm_today", r"\hat{L}(D=\mathrm{today})"),
    ("brace_eq", r"\hat{L}(D{=}\mathrm{today})"),
    ("text_space", r"\text{the observed slots}"),
    ("times", r"n_s\times n_h"),
    ("leq", r"s-j\le 0"),
    ("mid", r"\hat{y}(k+h\mid k)"),
    ("vdots", r"\vdots"),
    ("cdots", r"r(k),\cdots,r(k-p+1)"),
    ("prctile", r"q_1(d),q_{99}(d)=\mathrm{prctile}\{y(j)\}"),
    ("clip", r"\mathrm{clip}\left(x,\,q_1,\,q_{99}\right)"),
    ("sqrtfrac", r"\sqrt{\frac{1}{n_d}\sum_{d=1}^{n_d}E^2}"),
    ("overbrace", r"\overbrace{x+y}^{\text{total}}"),
    ("underbrace", r"\underbrace{x+y}_{\text{total}}"),
    ("color", r"\color{red}{x}"),
    ("mathbf", r"\mathbf{w}"),
    ("mathcal", r"\mathcal{W}"),
    ("longleftarrow", r"\theta\leftarrow\theta+G\xi"),
    ("approx", r"\lambda\approx 0.98"),
    ("pm", r"\pm 1"),
    ("partial", r"\partial x"),
    ("prime", r"D'_h"),
    ("norm", r"\|x\|_2"),
    ("colon_eq", r"\rho(k):=\frac{n}{288}"),
    ("text_sub", r"p^{\ast}(s,h)"),
]


def main():
    outdir = sys.argv[1]
    os.makedirs(outdir, exist_ok=True)
    rows = []
    for name, tex in CASES:
        png = os.path.join(outdir, name + ".png")
        rec = {"name": name, "tex": tex}
        try:
            fig = plt.figure(figsize=(0.01, 0.01))
            fig.text(0.0, 0.0, "$%s$" % tex, fontsize=14, color="#1B2430")
            fig.savefig(png, dpi=200, transparent=True, bbox_inches="tight", pad_inches=0.02)
            plt.close(fig)
            with Image.open(png) as im:
                rec.update(ok=True, w=im.width, h=im.height, aspect=round(im.width / im.height, 3))
        except Exception as exc:                                  # noqa: BLE001
            msg = str(exc).strip().splitlines()
            rec.update(ok=False, error=msg[-1][:110] if msg else type(exc).__name__)
        rows.append(rec)
        print("%-18s %-5s %s" % (name, "OK" if rec["ok"] else "FAIL",
                                 ("%dx%d a=%.2f" % (rec["w"], rec["h"], rec["aspect"])) if rec["ok"] else rec["error"]))
    ok = sum(1 for r in rows if r["ok"])
    print("\n%d cases: %d accepted, %d rejected" % (len(rows), ok, len(rows) - ok))
    with open(os.path.join(outdir, "_report2.json"), "w", encoding="utf-8") as fh:
        json.dump(rows, fh, indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
