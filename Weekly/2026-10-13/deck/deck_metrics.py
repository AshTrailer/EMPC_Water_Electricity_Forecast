# -*- coding: utf-8 -*-
"""The metric definitions, pages 68 and 69 of the deck.

These pages exist because the teacher asked, twice, what the numbers mean: how MSE
and RMSE are formed, over what a median is taken, in what unit, and what each
symbol in every formula stands for. The deck described those things in prose on
twenty different pages and never stated them, which is how a reader ends up unable
to tell a median over days from a median over times of day.

Page 68 says what one error is, what a cell is, and how a cell becomes a number.
Page 69 says how a set of cells is summarised, which is the question a ranking
turns on, and then hands over to the symbol table.

The text here is deliberately plain. A reader who has not seen the deck should be
able to open any later page, read a formula, and find every symbol in it.
"""

import deck_notation as NT

PAGE_68_ROW2 = [
    ("Summarising a set of cells",
     [("m_med_lead", 3.70), ("m_med_slot", 3.05), ("m_pooled", 2.60)],
     ["The second is a median over the 376 cells that share a time of day.",
      "The third mixes both axes, so it is a fingerprint only. It is never a ranking."]),
]

X0 = 0.55
BLOCK_X = (0.55, 6.90)
BLOCK_W = 5.85
ROW_Y = 1.38
ROW_H = 2.55


# Each block: a heading, the formulas with the width each is allowed, and the
# sentences that say what is averaged over what. The two columns side by side.
PAGE_68 = [
    ("What one error is", [("m_err", 3.90)],
     ["Actual minus forecast for one interval, in dollars per megawatt hour."]),
    ("What one cell is", [("m_units", 5.3)],
     ["One time of day crossed with one lead: 288 slots times 376 leads, 108,288 cells.",
      "Slots are five minutes apart. Leads run from 5 minutes to 183.0 hours."]),
    ("How a cell becomes one number", [("m_mse", 3.4), ("m_rmse", 2.0)],
     ["MSE averages the squared errors over the 32 scored days. Date direction only.",
      "RMSE is the square root, which returns dollars per megawatt hour."]),
    ("Summarising a set of cells", [("m_med_lead", 3.40)],
     ["A median over the 288 cells that share a lead. A ranking uses one axis only.",
      "The pooled number mixes both axes: a fingerprint, not a ranking."]),
]

ARROW_ROWS = None

# The three summary objects side by side, as a picture rather than a sentence.
SUMMARY_TABLE = [
    ["what it is taken over", "how many numbers go in", "what it answers"],
    ["the 288 times of day at one lead", "288", "what a lead looks like across the day"],
    ["the 376 leads at one time of day", "376", "what a time of day looks like across leads"],
    ["every cell of the grid", "108,288", "a run fingerprint, never a ranking"],
]

PAGES = [
    {
        "n": 68, "kind": "metrics",
        "title": "What the numbers mean: the error, the cell, and the summaries",
        "subtitle": "what each quantity is, what it is averaged over, and in what unit",
        "blocks": PAGE_68,
        "table": True,
        "scope": ("Scope  32 scored days of a 60-day window; one sample per scored day in every "
                  "cell; both sides clamped to the target day's rolling 30-day Q1 and Q99; all "
                  "errors in dollars per megawatt hour. The symbol table follows on the next "
                  "two pages."),
    },
]


def all_formula_keys():
    out = []
    for p in PAGES:
        for _h, fs, _n in p["blocks"]:
            out.extend(k for k, _w in fs)
    return out


# The two notation pages are owned by deck_notation, so their titles, columns and
# scopes are stated once. This list only fixes the build order.
BUILD = PAGES + [{"n": p["n"], "kind": "notation"} for p in NT.PAGES]


def specs_by_page():
    """Every page this module builds, notation pages included, by page number."""
    out = {}
    for p in BUILD:
        if p["kind"] == "notation":
            src = [q for q in NT.PAGES if q["n"] == p["n"]]
            if not src:
                raise SystemExit("no notation page %d in deck_notation" % p["n"])
            out[p["n"]] = src[0]
        else:
            out[p["n"]] = p
    return out


def spec_of(page_number):
    return specs_by_page()[page_number]


def blocks_fit(page):
    """Price one definition page: every block inside its cell, the page inside budget.

    Raises rather than warns. A block that overflows its cell prints over the block
    below it, and a page that overflows prints into the scope band; both are only
    visible once the page is rendered, and by then it is in the deck.

    The formula heights come from build_new's measured table, so this is the same
    arithmetic the renderer will use rather than a second estimate.
    """
    import build_new as B
    problems = []
    rows = 2
    for i, (head, fs, notes) in enumerate(page["blocks"]):
        col, row = i % 2, i // 2
        x, w = BLOCK_X[col], BLOCK_W
        used = 0.28
        fh = 0.0
        for key, fw in fs:
            nat_w, nat_h = B.FORMULA_WH_14PT[key]
            pt = min(12.0, 14.0 * fw / nat_w)
            fh = max(fh, nat_h * pt / 14.0)
            if nat_w * 12.0 / 14.0 > fw + 0.001:
                problems.append("page %d: formula %s is %.2f in wide at 12 pt, the "
                                "cell allows %.2f" % (page["n"], key,
                                                      nat_w * 12.0 / 14.0, fw))
        used += fh + 0.20
        for note in notes:
            used += B.wrap_lines(note, w, 9.0) * B.LINE_H + 0.08
        if used > ROW_H:
            problems.append("page %d: block %d in the %s column needs %.2f in of the "
                            "%.2f in row" % (page["n"], row + 1, "left" if col == 0 else "right",
                                             used, ROW_H))
    if page.get("table"):
        col0 = page["blocks"][2][2]
        used = 0.28 + 0.46 + sum(B.wrap_lines(n, BLOCK_W, 9.0) * B.LINE_H + 0.08
                                 for n in col0) + 0.20
        used += 0.32 + 0.30 * (len(SUMMARY_TABLE) - 1)
        if used > 6.72 - 1.38:
            problems.append("page %d: the lower half needs %.2f in of %.2f"
                            % (page["n"], used, 6.72 - 1.38))
    if problems:
        raise AssertionError("; ".join(problems))
    return True
