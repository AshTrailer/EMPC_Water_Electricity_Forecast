# -*- coding: utf-8 -*-
"""Lint, render and proof sheet for every formula in deck_formulas.py.

Three jobs, in this order:

  1. LINT     reject constructs matplotlib mathtext cannot parse. The deny list
              was measured on this machine, not copied from documentation:
              \\big \\Big \\bigg \\tfrac \\begin \\end \\le \\overbrace
              \\underbrace \\color all raise ParseFatalException.
  2. RENDER   every formula to a transparent PNG at 600 dpi, and assert the
              background really is transparent and the ink really is not empty.
              This is the check that catches the failure mode the 2026-10-08
              deck has: 17 formula strips with alpha=[255,255] and a white
              corner, which sit on a white page invisibly and on a tinted card
              as a white box.
  3. SHEET    one contact sheet per group, name beside formula, so a human can
              see that each one is typeset correctly rather than merely
              error-free.

Usage:
  python check_formulas.py --outdir <dir> [--sheets]
"""

import argparse
import hashlib
import json
import os
import re
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "2026-09-23", "deck"))

os.environ.setdefault("MPLCONFIGDIR", os.path.join(HERE, "_mplcache"))
import matplotlib                      # noqa: E402
matplotlib.use("Agg")
import matplotlib.pyplot as plt        # noqa: E402
from PIL import Image                  # noqa: E402

import render_formula                  # noqa: E402
from deck_formulas import FORMULAS     # noqa: E402

# the content width every new page uses, in inches; deck_kit.py CONTENT_W
CONTENT_W = 12.2

DENY = [
    (r"\\big(?![a-z])", r"\big is not a mathtext command, use \left( \right)"),
    (r"\\Big", r"\Big is not a mathtext command, use \left( \right)"),
    (r"\\bigg", r"\bigg is not a mathtext command"),
    (r"\\tfrac", r"\tfrac is not a mathtext command, use \frac"),
    (r"\\begin", r"environments such as cases are not supported"),
    (r"\\end", r"environments such as cases are not supported"),
    (r"\\le(?![a-z])", r"\le is not a mathtext command, use \leq"),
    (r"\\overbrace|\\underbrace", r"brace annotations are not supported"),
    (r"\\color", r"\color is not supported"),
    (r"(?<!\\)\$", r"do not put dollar signs in the formula string"),
    (r"\\\\[a-zA-Z]", r"double backslash before a letter"),
]

GROUPS = [
    ("shared", ["slot", "clamp", "clampq", "rlsv", "rlss", "tmpl", "resid", "diff"]),
    ("official", ["off_rule", "off_pick", "off_age", "off_col"]),
    ("bench", ["lead_axis", "err_e", "err_E", "err_R", "err_pool", "dm", "dm_bh"]),
    ("predictors A", ["m1", "m2", "m3", "m4_rec", "m4", "m5", "m6", "m7", "m8", "m8_convex"]),
    ("predictors B", ["m9_fit", "m9", "m10", "m10p", "m11", "m12_rho", "m12", "m18"]),
    ("predictors C", ["m13_ss", "m13_upd", "m13", "m13_g", "m13_rot", "m14", "m14p",
                      "m15", "m16", "m17"]),
    ("predictors D", ["m19_cand", "m19_rule", "m20", "band48", "win_share"]),
]


def lint(name, tex):
    bad = []
    for pat, why in DENY:
        for m in re.finditer(pat, tex):
            bad.append("%s at %d: %s" % (why, m.start(), tex[max(0, m.start() - 20):m.start() + 20]))
    return bad


def out_name(name, tex):
    """A filename that stays unique after case folding.

    Windows is case insensitive, so writing err_e.png and then err_E.png leaves
    ONE file holding the second image. That happened: err_e and err_E ended up
    byte identical and the proof sheet showed the same formula twice while the
    in-memory report looked correct. The crc is what makes the name unique.
    """
    return "%s__%08x.png" % (name.lower(), zlib.crc32(tex.encode("utf-8")) & 0xFFFFFFFF)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--sheets", action="store_true")
    ap.add_argument("--dpi", type=int, default=600)
    args = ap.parse_args()
    os.makedirs(args.outdir, exist_ok=True)

    report = []
    fails = 0
    seen_files = {}
    seen_sha = {}
    print("%-14s %-6s %s" % ("name", "state", "geometry"))
    print("-" * 86)
    for name, (tex, caption) in FORMULAS.items():
        rec = {"name": name, "tex": tex, "caption": caption}
        bad = lint(name, tex)
        if bad:
            rec["state"] = "LINT"
            rec["detail"] = bad
            fails += 1
            print("%-14s %-6s %s" % (name, "LINT", bad[0]))
            report.append(rec)
            continue
        fname = out_name(name, tex)
        if fname in seen_files:
            fails += 1
            print("%-14s %-6s filename collides with %s" % (name, "NAME", seen_files[fname]))
        seen_files[fname] = name
        png = os.path.join(args.outdir, fname)
        try:
            info = render_formula.render(tex, png, fontsize=14, dpi=args.dpi)
        except Exception as exc:                                   # noqa: BLE001
            rec["state"] = "RENDER"
            rec["detail"] = [str(exc).strip().splitlines()[-1][:120]]
            fails += 1
            print("%-14s %-6s %s" % (name, "RENDER", rec["detail"][0]))
            report.append(rec)
            continue
        with Image.open(png) as im:
            rgba = im.convert("RGBA")
            alpha = rgba.getchannel("A")
            lo, hi = alpha.getextrema()
            ink = sum(1 for px in rgba.getchannel("A").get_flattened_data() if px > 8)
            bbox = alpha.getbbox()
        sha = hashlib.sha256(open(png, "rb").read()).hexdigest()
        if sha in seen_sha and seen_sha[sha] != tex:
            fails += 1
            print("%-14s %-6s identical bytes to a different formula: %s"
                  % (name, "COLLIDE", seen_sha[sha][:40]))
        seen_sha[sha] = tex
        aspect = info["w"] / float(info["h"])
        nat_w = info["w"] / float(args.dpi)
        nat_h = info["h"] / float(args.dpi)
        # The picture is placed at its natural size and only shrunk when it
        # would not fit the 12.2 in content width. So the two things worth
        # measuring are: does it fit without shrinking, and how tall is it.
        eff_pt = 14.0 * min(1.0, CONTENT_W / nat_w)
        state = "OK"
        if lo != 0:
            state = "OPAQUE"
        elif ink < 40:
            state = "EMPTY"
        elif nat_w > CONTENT_W:
            state = "WIDE"
        elif nat_h > 0.85:
            state = "TALL"
        if state != "OK":
            fails += 1
        rec.update(state=state, file=fname, w=info["w"], h=info["h"], aspect=round(aspect, 3),
                   nat_w_in=round(nat_w, 3), nat_h_in=round(nat_h, 3), eff_pt=round(eff_pt, 1),
                   alpha_min=lo, ink_px=ink, bbox=bbox, corner=info["corner_rgba"])
        report.append(rec)
        print("%-14s %-6s %5.2f x %5.2f in  aspect=%6.2f  alpha=%d  ink=%6dpx  eff=%4.1fpt"
              % (name, state, nat_w, nat_h, aspect, lo, ink, eff_pt))

    with open(os.path.join(args.outdir, "_formula_report.json"), "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=1, ensure_ascii=False)

    if args.sheets:
        make_sheets(args.outdir, report)

    print("")
    print("%d formulas, %d failed the lint or the render check" % (len(FORMULAS), fails))
    if fails:
        raise SystemExit(1)


def make_sheets(outdir, report):
    """One contact sheet per group: each formula on its own band, named at the left.

    Bands have a fixed height per formula, so a tall formula cannot overlap the
    one below it. That overlap is what makes a proof sheet useless for the only
    job it has: letting a human see that every formula is typeset correctly.
    """
    by_name = {r["name"]: r for r in report if r.get("state") == "OK"}
    for gi, (title, names) in enumerate(GROUPS, 1):
        names = [n for n in names if n in by_name]
        if not names:
            continue
        bands = [max(0.30, by_name[n]["nat_h_in"]) + 0.18 for n in names]
        total = sum(bands) + 0.45
        fig = plt.figure(figsize=(13.5, total))
        fig.patch.set_facecolor("white")
        fig.text(0.5, 1.0 - 0.20 / total, "formula proof sheet %d: %s" % (gi, title),
                 fontsize=12, color="#1B2430", ha="center", va="top")
        y = 1.0 - 0.44 / total
        for n, h_in in zip(names, bands):
            frac = h_in / total
            png = os.path.join(outdir, by_name[n]["file"])
            ax = fig.add_axes([0.12, y - frac * 0.94, 0.87, frac * 0.88])
            ax.set_facecolor("white")
            ax.imshow(Image.open(png))
            ax.axis("off")
            fig.text(0.005, y - frac * 0.50, n, fontsize=8, family="monospace",
                     color="#5A6B7B", va="center")
            y -= frac
        out = os.path.join(outdir, "_proof_sheet_%d.png" % gi)
        fig.savefig(out, dpi=150, facecolor="white")
        plt.close(fig)
        print("wrote", out)


if __name__ == "__main__":
    main()
