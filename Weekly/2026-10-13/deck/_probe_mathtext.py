# -*- coding: utf-8 -*-
"""Capability probe: render every formula the new deck will use through
matplotlib mathtext (no TeX distribution on this machine), and report which
constructs survive. Read-only apart from the output directory.

Usage: python _probe_mathtext.py <outdir>
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
    ("index", r"u(k,h) = \mathrm{mod}(s(k)-1+h,\; n_s)+1"),
    ("clamp", r"y_c(k) = \min(\max(y(k),\, q_1(d)),\, q_{99}(d))"),
    ("template", r"T(s) = \frac{1}{\min(k_s,\,n_T)}\sum_{i=1}^{\min(k_s,n_T)} y_s^{(i)}"),
    ("resid", r"r(k) = y(k) - T_{k-1}(s(k))"),
    ("rls", r"G = \frac{P_{rls}\,u}{\lambda + u^{\top} P_{rls}\,u},\qquad \theta \leftarrow \theta + G\,(z-u^{\top}\theta)"),
    ("rlsP", r"P_{rls} \leftarrow \tfrac{1}{\lambda}\left(P_{rls} - G\,u^{\top}P_{rls}\right)"),
    ("m1", r"\hat{y}(k+h\mid k) = y\big(u(k,h) - n_s\big)"),
    ("m2", r"\hat{y}(k+h\mid k) = T(u(k,h))"),
    ("m3", r"\hat{y}(k+h\mid k) = \theta(u(k,h))\cdot y_{prev}(u(k,h))"),
    ("m4", r"\hat{y}(k+h\mid k) = T(u(k,h)) + \hat{r}(k+h\mid k)"),
    ("m4rec", r"\hat{r}(k+s\mid k) = \sum_{j=1}^{p}\phi_j\,\tilde{r}(k+s-j),\qquad \tilde{r} = \begin{cases}\end{cases}"),
    ("m4rec2", r"\hat{r}(k+s\mid k)=\sum_{j=1}^{p}\phi_j\tilde r(k+s-j),\quad \tilde r(\cdot)=r(\cdot)\ \mathrm{if}\ s-j\le 0\ \mathrm{else}\ \hat r(\cdot)"),
    ("m5", r"\hat{y}(k+h\mid k) = y(k)"),
    ("m6", r"\hat{y}(k+h\mid k) = T(u(k,h)) + D_h\,[1,\;r(k),\ldots,r(k-p+1)]^{\top}"),
    ("m7", r"\hat{y}(k+h\mid k) = y(k) + D'_h\,[1,\;\Delta y(k),\ldots,\Delta y(k-p+1)]^{\top}"),
    ("m8", r"\hat{y}(k+h\mid k) = c_h + a_h\,y(k) + b_h\,T(u(k,h)) + \sum_{j=1}^{p}\phi_{hj}\,r(k-j+1) + \sum_{j=1}^{p}\psi_{hj}\,\Delta y(k-j+1)"),
    ("m9", r"\hat{L}(D) = c + b_1\,L(D-1),\qquad \hat{y}(k+h\mid k) = T(u(k,h)) + \big(\hat{L}(D)-\bar{L}\big)"),
    ("m10", r"T_{mw}(s) = \frac{1}{|W|}\sum_{w\in W} T_w(s),\qquad W=\{7,28,56,112\}"),
    ("m12", r"\hat{L}(D{=}\mathrm{today}) = \rho(k)\,\bar{y}_{run}(k) + (1-\rho(k))\,\big(c+b_1 L(d-1)\big)"),
    ("m13", r"\xi_k = A\,\xi_{k-1} + w_k,\qquad y(k) = C_k\,\xi_k + v_k,\qquad \hat{y}(k+h\mid k) = C_{k+h}A^{h}\hat{\xi}_{k\mid k}"),
    ("m13g", r"\hat{y}(k+h\mid k) = G(h,\,u(k,h))\,\hat{\xi}_{k\mid k},\qquad G(h,s) = C_s A^{h}"),
    ("m14", r"T_e(s) = \frac{\sum_{i=0}^{K-1}(1-\alpha)^i\,y^{(i)}(s)}{\sum_{i=0}^{K-1}(1-\alpha)^i},\qquad K = \left\lfloor \frac{\log w_{min}}{\log(1-\alpha)}\right\rfloor"),
    ("m15", r"\hat{y}(k+h\mid k) = S(k),\qquad S(k) = \frac{1}{w}\sum_{i=0}^{w-1} y(k-i)"),
    ("m16", r"\hat{y}(k+h\mid k) = S(k) + \left(\frac{w-1}{2}+h\right)\big(S(k)-S(k-1)\big)"),
    ("m18", r"T_c(s) = \frac{1}{N_c}\sum_{d\in W_c} y_d(s),\qquad c\in\{\mathrm{weekday},\mathrm{weekend}\}"),
    ("m19sel", r"p^{\ast}(s,h) = \arg\min_{p\in P}\ \sum_{d\in D_{28}} \Big(y_c - \mathrm{clip}\big(T(u)+r^{(p)}\big)\Big)^2,\qquad P=\{1,2,3,4,5,6,8\}"),
    ("m20", r"\hat{y}(k+h\mid k) = T(u(k,h)) + \hat{r}^{(p^{\ast}(u,h))}(h)"),
    ("rmse", r"R(s,h) = \sqrt{\frac{1}{n_d}\sum_{d=1}^{n_d} E(s,h,d)^2}"),
    ("dm", r"DM(s,h) = \frac{\bar{d}(s,h)}{\sqrt{\widehat{\mathrm{Var}}(\bar d(s,h))}},\qquad d_i = e^{2}_{model,i}-e^{2}_{off,i}"),
    ("pooled", r"\bar{R} = \sqrt{\frac{1}{n_s\,n_h\,n_d}\sum_{s,h,d} E(s,h,d)^2}"),
    ("rho", r"\rho(k) = \frac{\#\{\text{observed slots today}\}}{n_s}"),
    ("textcmd", r"\operatorname{clip}(x) \quad \text{plain text} \quad \substack{a\\b}"),
    ("cases", r"f(x) = \begin{cases} a & x>0 \\ b & x\le 0\end{cases}"),
    ("mathbb", r"w_m \in \mathbb{R},\quad \sum_{m} w_m = 1"),
    ("leadaxis", r"\ell_i = 5i\ \mathrm{min}\ (i=1\ldots11),\qquad \ell_i = 30(i-11)\ \mathrm{min}\ (i=12\ldots376)"),
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
                w, h = im.size
                lo, hi = im.convert("RGBA").getchannel("A").getextrema()
            rec.update(ok=True, w=w, h=h, aspect=round(w / h, 3), alpha_min=lo)
        except Exception as exc:                                  # noqa: BLE001
            rec.update(ok=False, error="%s: %s" % (type(exc).__name__, exc))
        rows.append(rec)
        print("%-9s %-6s %s" % (name, "OK" if rec["ok"] else "FAIL",
                                ("%dx%d aspect=%.2f alpha_min=%d" % (rec["w"], rec["h"], rec["aspect"], rec["alpha_min"]))
                                if rec["ok"] else rec["error"][:140]))
    bad = [r for r in rows if not r["ok"]]
    opaque = [r for r in rows if r["ok"] and r["alpha_min"] != 0]
    print("\n%d cases, %d rendered, %d failed, %d not transparent" % (len(rows), len(rows) - len(bad), len(bad), len(opaque)))
    with open(os.path.join(outdir, "_report.json"), "w", encoding="utf-8") as fh:
        json.dump(rows, fh, indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
