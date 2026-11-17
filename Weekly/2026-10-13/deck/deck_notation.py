# -*- coding: utf-8 -*-
"""The deck's symbols, in one place, with the display form and the plain gloss.

Why this file exists. The pages were carrying a symbol table each, and the same
symbol was described in slightly different words on every page it appeared on.
A reader then has to decide which description is the real one, and the teacher
asked twice for the symbols to be explained so that someone seeing them for the
first time reads the formula and knows what it says.

Two rules hold here.

  1. ONE GLOSS PER SYMBOL. The text of a gloss lives here and nowhere else, so
     two pages cannot describe the same symbol differently, and a page's table is
     rendered from this table rather than typed.
  2. THE DISPLAY FORM IS DERIVED. A key like "y-hat(k+h|k)" becomes y with a hat,
     then the bracket contents as a real subscript. The key is what the data
     files use; the display form is what the slide prints, and nothing has to be
     typed twice.

The keyboard form of a key uses: -hat for a circumflex over the base, -bar for a
mean, -hat(p) for a hat over a subscripted quantity, and _ for its own subscript
where the symbol really has one. A trailing bar written without a separator,
"Lbar", is accepted too, because the later pages name that symbol that way.
"""

import re

# The gloss is written for a reader who has not seen the deck: what the quantity
# is, over what it is taken, and in what unit. Nothing else goes in.
SYMBOLS = {
    # ---------------------------------------------------------------- the frame
    "k": ("interval index",
              "The interval that has just closed. The forecast is made at its end."),
    "h": ("forecast lead",
              "Forecast lead in minutes: 5 minutes to 183.0 hours, 376 of them."),
    "s": ("time-of-day slot",
              "Position in the day, 1 to 288, five minutes each. Slot 1 is 00:00."),
    "u(k,h)": ("slot of the target",
              "The slot the target interval lands on. It is the time of day."),
    "d": ("day",
              "A calendar day. The window has 60, and days 29 to 60 are scored."),
    "y(k)": ("price",
              "The actual price, dollars per megawatt hour, after clamping."),
    "y-hat(k+h|k)": ("forecast",
              "A model's forecast for interval k+h, made at origin k."),
    "e(k,h)": ("error",
              "Actual minus forecast, dollars per megawatt hour. Positive is low."),
    "R(s,h)": ("error of one cell",
              "The error of one cell: RMSE over the 32 scored days, $/MWh."),
    "T(s)": ("template",
              "Mean price of slot s over its last 28 values, one per day."),
    "S(k)": ("smoothed price",
              "Mean of the last 12 five-minute prices at the origin."),
    "L(d)": ("daily level",
              "Mean price of one whole day."),
    "r(k)": ("residual",
              "Price minus template: what the template does not explain."),
    "q1, q99": ("clamp bounds",
              "Bounds of the target day: the 1st and 99th percentile of 30 days."),
    "D_score": ("scored days",
              "The 32 days every cell is averaged over."),
    "n_d": ("sample count",
              "How many scored days carry a value in this cell. 32, or 0."),

    # ------------------------------------------------------------- the models
    "y_prev(u)": ("same slot, yesterday",
              "The price of slot u one day earlier."),
    "n_T": ("template window",
              "The template window: 28 observations, one per day at that slot."),
    "theta(s)": ("slot gain",
              "One correction per slot, applied to yesterday's price."),
    "phi": ("AR coefficients",
              "The AR coefficients: weights on the last p residuals."),
    "p": ("AR order",
              "AR order: how many past residuals the model uses."),
    "p*(s,h)": ("chosen order",
              "The order chosen for one cell, slot s at lead h."),
    "D_h": ("fitted row, one lead",
              "The fitted coefficients for lead h in the direct multi-step fit."),
    "a_h, b_h": ("weights at lead h",
              "Weights on the current price and on the template, at lead h."),
    "L-hat(D)": ("forecast level",
              "The fitted mean price of the target day."),
    "T_w(s)": ("window template",
              "The per-slot mean over a window of w days instead of 28."),
    "alpha": ("decay per day",
              "EWMA decay per day: today's weight over yesterday's, 0.15."),
    "W_c": ("class buffer",
              "Past values of one slot, kept apart for weekdays and weekends."),
    "P": ("candidate orders",
              "The orders the rule tries: 1, 2, 3, 4, 5, 6, 8."),

    # ------------------------------------------- symbols the later pages add
    # The keys here are the spelling the predictor pages already use, so a page
    # needs no translation table of its own.
    "y_s(i)": ("past observation",
              "The i-th most recent value of slot s."),
    "k_s": ("observations on hand",
              "How many values slot s has, capped at the 28 of the window."),
    "G": ("RLS gain",
              "RLS step size on the newest observation."),
    "P_rls": ("RLS covariance",
              "RLS uncertainty. Starts at 100 and falls as evidence arrives."),
    "lambda": ("forgetting factor",
              "Forgetting factor, 0.98: older evidence fades two percent a step."),
    "r-hat(k+s|k)": ("forecast residual",
              "The residual the model predicts for the target."),
    "D'_h": ("difference row",
              "The fitted row for lead h when the fit is on price changes."),
    "Delta y(k)": ("price change",
              "The price change, y(k) minus y(k-1)."),
    "c_h": ("intercept at lead h",
              "The constant the fit adds at lead h."),
    "a_h": ("weight on today",
              "Weight on the price that has just closed, at lead h."),
    "b_h": ("weight on template",
              "Weight on the slot template, at lead h."),
    "phi_h": ("residual weights",
              "Weights on the recent residuals, at lead h."),
    "psi_h": ("difference weights",
              "Weights on the recent price changes, at lead h."),
    "c": ("intercept",
              "The constant of the daily level fit, over 56 days."),
    "b1": ("level persistence",
              "How much of yesterday's level carries into today, over 56 days."),
    "L-bar": ("mean level",
              "The mean daily level over the fitting window."),
    "W": ("window set",
              "The averaging windows used: 7, 28, 56 and 112 days."),
    "T_mw(s)": ("multi-window template",
              "Average of the four window templates at slot s."),
    "T-bar_mw": ("mean of the multi-window template",
              "The multi-window template averaged over the slots."),
    "rho(k)": ("share of today observed",
              "Share of today's 288 slots already closed at the origin."),
    "y-bar_run(k)": ("run mean",
              "Mean price of the part of today that has already closed."),
    "L(d-1)": ("yesterday's level",
              "The realised mean price of the last complete day."),
    "xi": ("decay",
              "Forgetting factor of the online template update, 0.98."),
    "A": ("design matrix",
              "The inputs the anchor combination is fitted on, one row per interval."),
    "C": ("covariance of the fit",
              "How the members move together, so two alike members do not count twice."),
    "K": ("days kept",
              "How many past days the weighted template keeps."),
    "G(h,s)": ("gain",
              "One shift per cell: how far the model moves its forecast."),
    "w_min": ("drop threshold",
              "The weight below which a past day is dropped, 0.01."),
    "y(i)(s)": ("value on a past day",
              "The value slot s took on the i-th most recent complete day."),
    "T_e(s)": ("weighted template",
              "Per-slot mean with recent days weighted more than old ones."),
    "w": ("averaging window",
              "How many points the smoothing covers. 12 points is one hour."),
    "y(k-i)": ("price, i steps back",
              "The price i intervals before the origin."),
    "(w-1)/2": ("average delay",
              "The delay a trailing mean carries: half its window."),
    "S(k-1)": ("smoothed price, one step back",
              "The same smoothed price one interval earlier."),
    "median": ("middle value",
              "The value with half the numbers above it and half below."),
    "N_c": ("observations in class",
              "How many past values the class buffer holds for this slot."),
    "y_d(s)": ("value on day d",
              "The value slot s took on day d, a day of the target's class."),
    "T_c(s)": ("class template",
              "Per-slot mean over one class: weekdays, or weekend days."),
    "phi(p)": ("coefficients at order p",
              "The residual weights for candidate order p."),
    "r-hat(p)": ("candidate residual forecast",
              "The residual forecast from candidate order p."),
    "D_28": ("scoring days for a candidate",
              "The trailing days a candidate is scored on: 7 to 28."),
    "r-hat(p*)(h)": ("chosen residual forecast",
              "The residual forecast from the order this cell chose."),
    "p*(u,h)": ("order of this cell",
              "The chosen order, read at the target slot and the lead."),
}


def _base_and_marks(key):
    """Split a key into (base, main, sub, tail, hat, bar).

    Two spellings reach this function and both have to work. The notation table
    and the early predictor pages write the decoration with a hyphen, "y-hat".
    The later pages write the same quantity with an underscore, "L_hat(D)",
    "Lbar", "ybar_run(k)", because that is what the MATLAB workspace calls it.
    Both are accepted here so a page can use either spelling and still get one
    gloss.
    """
    base = key
    hat = bar = False
    # A trailing bar written without a separator: Lbar, Tbar_mw, ybar_run.
    m = re.match(r"^([A-Za-z{}]*)bar(?=$|_|\()", base)
    if m and m.group(1):
        base, bar = m.group(1) + base[m.end():], True
    elif base.endswith("-hat") or base.endswith("_hat"):
        base, hat = base[:-4], True
    elif base.endswith("-bar") or base.endswith("_bar"):
        base, bar = base[:-4], True
    elif "-hat_" in base or "_hat_" in base:
        base, hat = base.replace("-hat_", "_", 1).replace("_hat_", "_", 1), True
    elif "-bar_" in base or "_bar_" in base:
        base, bar = base.replace("-bar_", "_", 1).replace("_bar_", "_", 1), True
    elif "-hat(" in base or "_hat(" in base:
        i = base.index("-hat(") if "-hat(" in base else base.index("_hat(")
        base, hat = base[:i] + base[i + 4:], True

    tail = ""
    if base.endswith(")") and "(" in base:
        i = base.index("(")
        base, tail = base[:i], base[i:]
    main, sub = base.split("_", 1) if "_" in base else (base, "")
    return base, main, sub, tail, hat, bar


def _alias(key):
    """The spelling the notation table uses, for a key written the other way."""
    _b, main, sub, tail, hat, bar = _base_and_marks(key)
    out = main
    if sub:
        out += "_" + sub
    if hat:
        out += "-hat"
    if bar:
        out += "-bar"
    if tail:
        out += tail
    # The table writes the decoration before the bracket subscript.
    if tail and (hat or bar):
        out = main + ("-hat" if hat else "-bar") + ("_" + sub if sub else "") + tail
    return out


def gloss(key):
    """(what it is, what it means) for a key in either spelling."""
    if key in SYMBOLS:
        return SYMBOLS[key]
    alt = _alias(key)
    if alt in SYMBOLS:
        return SYMBOLS[alt]
    raise KeyError("no gloss for %r (tried %r)" % (key, alt))


def plain(key):
    """One line: what the quantity is, over what it is taken, in what unit."""
    return gloss(key)[1]


def label(key):
    """The name of the symbol, for prose."""
    return gloss(key)[0]


def display(key):
    """The key as a list of runs: (text, is_subscript, hat, bar).

    The base is always one run, however many decorations it carries: a hat and a
    bar are combining marks, and a combining mark placed on its own run renders
    as a dotted circle in some viewers. Only the subscript and the bracket
    argument become runs of their own.
    """
    _b, main, sub, tail, hat, bar = _base_and_marks(key)
    runs = [(main, False, hat, bar)]
    if sub:
        runs.append((sub, True, hat, bar))
    if tail:
        runs.append((tail, True, hat, bar))
    return runs


# ------------------------------------------------------------------ the pages
# Group 1 is the frame: the indices and the two quantities every formula is
# written in. Group 2 is the target and the error. Group 3 is the evaluation.
# Group 4 is the models, one entry per quantity a predictor page introduces.
GROUPS = [
    ("Time", [("k", "interval index"), ("h", "forecast lead"),
              ("s", "time-of-day slot"), ("u(k,h)", "slot of the target"),
              ("d", "day")]),
    ("What is forecast", [("y(k)", "price"), ("y-hat(k+h|k)", "forecast"),
                          ("e(k,h)", "error"), ("r(k)", "residual")]),
    ("How it is scored", [("R(s,h)", "error of one cell"),
                          ("D_score", "scored days"), ("n_d", "sample count"),
                          ("q1, q99", "clamp bounds")]),
    ("Model quantities, alphabetically", [
        ("A", "design matrix"), ("C", "covariance of the fit"),
        ("D_28", "scoring days for a candidate"), ("D'_h", "difference row"),
        ("D_h", "fitted row, one lead"), ("Delta y(k)", "price change"),
        ("G", "RLS gain"), ("G(h,s)", "gain"),
        ("K", "days kept"), ("L(d)", "daily level"), ("L(d-1)", "yesterday's level"),
        ("L-bar", "mean level"), ("Lbar", "mean level"),
        ("L-hat(D)", "forecast level"),
        ("N_c", "observations in class"), ("P", "candidate orders"),
        ("P_rls", "RLS covariance"), ("S(k)", "smoothed price"),
        ("S(k-1)", "smoothed price, one step back"),
        ("T-bar_mw", "mean of the multi-window template"),
        ("T_c(s)", "class template"), ("T_e(s)", "weighted template"),
        ("T_mw(s)", "multi-window template"), ("T_w(s)", "window template"),
        ("T(s)", "template"), ("W", "window set"), ("W_c", "class buffer"),
        ("a_h", "weight on today"), ("alpha", "decay per day"),
        ("b1", "level persistence"), ("b_h", "weight on template"),
        ("c", "intercept"), ("c_h", "intercept at lead h"),
        ("k_s", "observations on hand"), ("lambda", "forgetting factor"),
        ("median", "middle value"), ("n_T", "template window"),
        ("p", "AR order"), ("p*(s,h)", "chosen order"),
        ("p*(u,h)", "order of this cell"), ("phi", "AR coefficients"),
        ("phi(p)", "coefficients at order p"), ("phi_h", "residual weights"),
        ("psi_h", "difference weights"), ("r-hat(k+s|k)", "forecast residual"),
        ("r-hat(p)", "candidate residual forecast"),
        ("r-hat(p*)(h)", "chosen residual forecast"), ("rho(k)", "share of today observed"),
        ("theta(s)", "slot gain"), ("w", "averaging window"),
        ("w_min", "drop threshold"), ("xi", "decay"),
        ("y(i)(s)", "value on a past day"), ("y(k-i)", "price, i steps back"),
        ("y-bar_run(k)", "run mean"), ("ybar_run(k)", "run mean"),
        ("y_d(s)", "value on day d"),
        ("y_prev(u)", "same slot, yesterday"), ("y_s(i)", "past observation"),
        ("(w-1)/2", "average delay"),
    ]),
]


def group_keys():
    """Every key the notation pages list, in order."""
    return [k for _title, rows in GROUPS for k, _n in rows]


def unlisted(rows):
    """Symbol keys a page uses that the notation pages do not list."""
    listed = set(group_keys())
    return [k for k in rows if k not in listed]


# --------------------------------------------------------------------- pages
# Two pages, because 71 rows do not fit on one. Page one carries the frame and
# the first third of the model quantities; page two carries the rest, across four
# columns. The groups of each column are named here and the CUTS are placed by
# the fitter, so a column cannot overflow because someone typed a boundary.
PAGES = [
    {
        "n": 69,
        "kind": "notation",
        "title": "Every symbol in this deck, and what each one is",
        "subtitle": "the frame, the quantities every formula is written in, and how a number is scored",
        "groups": [("Time", "What is forecast", "How it is scored"),
                   ("Model quantities",), ("Model quantities",), ("Model quantities",)],
        "model_split": True,
        "scope": ("Scope  one gloss per symbol, and the gloss lives in one table, so two "
                  "pages cannot describe the same symbol differently. The model quantities "
                  "continue alphabetically on the next page."),
    },
    {
        "n": 70,
        "kind": "notation",
        "title": "Every symbol, continued: the quantities a model page introduces",
        "subtitle": "alphabetical down the columns, so a symbol found on a slide can be looked up here",
        "groups": [("Model quantities",), ("Model quantities",),
                   ("Model quantities",), ("Model quantities",)],
        "scope": ("Scope  same table, same order. A symbol used by one predictor page and "
                  "nowhere else is still listed here, and the page that introduces it repeats "
                  "it in its own table."),
    },
]

# Where the model list is cut between the two pages, split evenly so the second
# page's columns do not end up holding three rows while the first holds twenty.
SPLIT_AT = "N_c"
SPLIT_FRACTION = 0.30


def sort_key(key):
    """Case-insensitive, decoration-free, so the page reads alphabetically."""
    return re.sub(r"[^a-z0-9]", "", key.lower())


# The height budget on a closing-style page, in inches: content top to scope band.
BUDGET = 6.72 - 1.38
# Four columns have to fit the 12.20 in content width: the columns are sized from
# the content width rather than typed, so the fourth cannot run off the slide. The
# first build used 3.66 in columns and the fourth ended past the right edge.
COLUMN_GAP = 0.145
COLUMN_W = (12.20 - 3 * COLUMN_GAP) / 4.0
COLUMN_SIZE = 9.0
ROW_HEAD_H = 0.30


def row_height(key, width=COLUMN_W, size=COLUMN_SIZE):
    """Rendered height of one table row: the symbol line plus its gloss.

    The gloss is one line at this width for every symbol in the table. If a gloss
    is ever lengthened past the column it wraps, and this function is what turns
    that into a taller row rather than an overlap.
    """
    lines = 1
    per_line = 83.0 * width / 4.35 * (11.0 / size)
    cur = 0
    for word in gloss(key)[1].split():
        need = len(word) + (1 if cur else 0)
        if cur + need > per_line:
            lines += 1
            cur = len(word)
        else:
            cur += need
    return ROW_HEAD_H + 0.22 * (lines - 1)


def _ordered_model_rows():
    """The model quantities, sorted by key so the list is alphabetical on the page."""
    for title, rows in GROUPS:
        if title.startswith("Model quantities"):
            keep = [r for r in rows if r[0] not in ("Lbar", "ybar_run(k)")]
            return sorted(keep, key=lambda r: sort_key(r[0]))
    return []


def fit_columns(rows, n_col):
    """Split `rows` into `n_col` contiguous groups of nearly equal height.

    Two passes. The first finds how many rows a column can hold, starting from the
    widest column that fits; the second divides the rows as evenly as that allows,
    so the last column does not end up holding three rows while the first holds
    twenty. Every column is then checked against the budget.

    Raises if the rows do not fit: a notation column that overflows is only
    visible once it is rendered, and by then it has already been written into the
    deck.
    """
    pre = [0.0] * (len(rows) + 1)
    for i, (k, _g) in enumerate(rows):
        pre[i + 1] = pre[i] + row_height(k)

    def col_h(a, b):
        return pre[b] - pre[a] + ROW_HEAD_H

    cap = len(rows) // n_col
    while cap >= 1 and col_h(0, cap) > BUDGET:
        cap -= 1
    if cap < 1:
        raise AssertionError(
            "not even one row fits a column of %.2f in: the tallest row is %.2f "
            "against a budget of %.2f" % (COLUMN_W, col_h(0, 1), BUDGET))
    per = min(cap, -(-len(rows) // n_col))
    out, start = [], 0
    for c in range(n_col):
        left = len(rows) - start
        cols_left = n_col - c
        take = per if cols_left > 1 else left
        if left - take > cap * (cols_left - 1):
            take = left - cap * (cols_left - 1)
        end = start + take
        if col_h(start, end) > BUDGET:
            raise AssertionError(
                "column %d of %d needs %.2f in for rows %d to %d against a budget "
                "of %.2f" % (c + 1, n_col, col_h(start, end), start, end, BUDGET))
        out.append(rows[start:end])
        start = end
    if start != len(rows):
        raise AssertionError("%d of %d rows were placed" % (start, len(rows)))
    return out


def page_rows(page):
    """The rows of one page: a list of columns, each a list of (head_or_key, gloss)."""
    by_title = {t: rows for t, rows in GROUPS}
    full = _ordered_model_rows()
    if page.get("model_split"):
        n = max(1, int(round(len(full) * SPLIT_FRACTION)))
        model = full[:n]
    else:
        model = full[max(1, int(round(len(full) * SPLIT_FRACTION))):]
    n_model_cols = sum(1 for g in page["groups"] if "Model quantities" in g)
    groups = fit_columns(model, max(1, n_model_cols))
    out, mi = [], 0
    for col in page["groups"]:
        items = []
        for title in col:
            if title.startswith("Model quantities"):
                items.append(("__head__", title))
                items.extend(groups[mi])
                mi += 1
            else:
                items.append(("__head__", title))
                items.extend(by_title[title])
        out.append(items)
    return out


def page_fit(page):
    """(column heights, tallest) for one page, for the pre-build report."""
    heights = []
    for items in page_rows(page):
        h = sum(ROW_HEAD_H if k == "__head__" else row_height(k) for k, _ in items)
        heights.append(h)
    return heights, max(heights) if heights else 0.0


def all_listed():
    """Every key the two notation pages print, in order."""
    out = []
    for page in PAGES:
        for items in page_rows(page):
            out.extend(k for k, _ in items if k != "__head__")
    return out



def missing(keys):
    """Keys a page uses that this table does not define. The build fails on these."""
    out = []
    for k in keys:
        try:
            gloss(k)
        except KeyError:
            out.append(k)
    return out
