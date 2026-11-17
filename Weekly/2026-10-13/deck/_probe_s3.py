# -*- coding: utf-8 -*-
"""Judge the twenty predictor pages before anything is rendered.

The layout solver in build_new.py refuses a page that cannot fit, so this reports
where every page lands instead of failing on the first one. Read-only.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "2026-09-23", "deck"))
sys.path.insert(0, HERE)

import build_new as B                                                 # noqa: E402
import deck_predictors as P                                           # noqa: E402

BUDGET = B.BOTTOM - B.TOP


def main():
    bad = []
    longdesc = []
    print("%-5s %-8s %-8s %-8s %-8s %-8s %s" % (
        "page", "size", "minfrm", "formula", "symbol", "notes", "verdict"))
    for p in P.PAGES:
        for sym, text in p["symbols"]:
            if len(text) > B.SYM_DESC_CHARS:
                longdesc.append((p["n"], sym, len(text)))
        size, sizes, fh, used = B.predictor_solvable(p)
        sh = B.sym_height(p["symbols"])
        left = fh + sh
        right = B.prose_height(p["prose"], w=4.35) + (B.HDR_H if p.get("head") else 0.0)
        ok = left <= BUDGET and right <= BUDGET
        if not ok:
            bad.append(p["n"])
        print("%-5d %-8.1f %-8.1f %-8.2f %-8.2f %-8.2f %s" % (
            p["n"], size, min(sizes), fh, sh, right,
            "ok" if ok else "OVERFLOW  left %.2f right %.2f of %.2f" % (left, right, BUDGET)))
    print("")
    print("budget %.2f in per column" % BUDGET)
    print("pages over budget: %s" % (bad if bad else "none"))
    print("formulas on these pages: %d references, %d distinct"
          % (sum(len(p["formulas"]) for p in P.PAGES),
             len({f for p in P.PAGES for f in p["formulas"]})))
    missing = {f for p in P.PAGES for f in p["formulas"]} - set(B.FORMULA_WH_14PT)
    print("formulas with no measured size: %s" % (sorted(missing) if missing else "none"))
    print("symbol rows: %d" % sum(len(p["symbols"]) for p in P.PAGES))
    if longdesc:
        print("")
        print("SYMBOL DESCRIPTIONS OVER %d CHARACTERS (%d):" % (B.SYM_DESC_CHARS, len(longdesc)))
        for n, sym, k in longdesc:
            print("   page %-3d %-28s %3d" % (n, sym, k))


if __name__ == "__main__":
    main()
