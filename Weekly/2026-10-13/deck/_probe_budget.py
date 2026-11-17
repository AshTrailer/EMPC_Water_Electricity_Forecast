# -*- coding: utf-8 -*-
"""Report how far each predictor page is over budget, per page and per column.

The fitter in build_new.py raises on the first bad page, which is the right
behaviour at build time and useless when twenty pages need trimming at once. This
prints the whole table and names the two things that have to shrink: the symbol
row count and the prose line count. Read-only.
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
    print("%-5s %-7s %-7s %-7s %-7s %-7s %-7s  %s" % (
        "page", "fmla_h", "symrows", "sym_h", "left", "right", "budget", "needs"))
    for p in P.PAGES:
        fh, sizes = B.stack_height(p["formulas"], 14.0, 7.60)
        sh = B.sym_height(p["symbols"])
        left = fh + sh
        right = B.prose_height(p["prose"], w=4.35)
        needs = []
        if left > BUDGET:
            over = left - BUDGET
            rows = p["symbols"]
            maxrows = int((BUDGET - fh - B.SYM_HDR_H - B.GAP_AFTER_SYM) // B.SYM_ROW_H)
            needs.append("cut %.2f in from symbols: %d rows -> %d"
                         % (over, len(rows), maxrows))
        if right > BUDGET:
            over = right - BUDGET
            lines = B.prose_height(p["prose"], w=4.35) / B.LINE_H
            maxlines = int(BUDGET / B.LINE_H)
            needs.append("cut %.1f notes lines (have %.1f, fit %d)"
                         % (over / B.LINE_H, lines, maxlines))
        longd = [s for s, t in p["symbols"] if len(t) > B.SYM_DESC_CHARS]
        if longd:
            needs.append("symbol text too long: %s" % ", ".join(longd))
        if len(p["symbols"]) > B.SYM_MAX_ROWS:
            needs.append("%d rows over the cap of %d" % (len(p["symbols"]), B.SYM_MAX_ROWS))
        print("%-5d %-7.2f %-7d %-7.2f %-7.2f %-7.2f %-7.2f  %s" % (
            p["n"], fh, len(p["symbols"]), sh, left, right, BUDGET,
            "; ".join(needs) if needs else "fits at 14 pt"))


if __name__ == "__main__":
    main()
