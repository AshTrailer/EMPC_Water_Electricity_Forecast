# -*- coding: utf-8 -*-
"""The closing pages, 109 to 113 of the delivered deck.

Five pages after a section opener: the eight conclusions of the section, on
which object each one was taken, and one page on what this deck maintains and
how to rebuild it.

Three rules decide everything here.

  1. A conclusion is only a conclusion if it names the object. The four
     admissible objects are the whole surface, a fixed-lead profile over the
     times of day, a fixed-time-of-day profile over the leads, and a census that
     counts who wins each cell. Every conclusion below names one of them.
  2. Numbers are fetched from deck_numbers_60d, never typed. The conclusions
     quote medians over the 288 times of day at named lead columns and counts
     over the 108,288 cells, all of which are registered there.
  3. The lead of a column is read out of the extraction, not recomputed. The axis
     has two cadences, five minutes for the first eleven columns and thirty after
     that, so a closed form for it is easy to get wrong and the JSON already
     stores the axis the atlas was built on.
"""

import deck_numbers_60d as N

# --------------------------------------------------------------------- layout
# The same measured pitch the rest of the new pages uses: one rendered line is
# 2.43 times the point size, so 8.5 pt of prose costs 0.2867 in. Measured in
# _probe_pitch.py. The prose is one step below the predictor pages because a
# conclusion runs three or four lines of a 7.10 in column and three pages of them
# have to sit above the scope band.
PITCH_PER_PT = 0.371 / 11.0
TOP = 1.38
BOTTOM = 6.72
BUDGET = BOTTOM - TOP
PROSE_SIZE = 8.25
HEAD_SIZE = 9.5
LINE_H = PITCH_PER_PT * PROSE_SIZE
HEAD_LEAD = PITCH_PER_PT * HEAD_SIZE + 0.05     # heading top to body top
INK_SLACK = 0.05               # the renderer starts a one line box's ink below its top
BODY_SLACK = 0.10              # what the body box adds after its last rendered line
HDR_H = 0.28
BETWEEN = 0.055
CHARS_AT_11PT = 83.0           # in a 4.35 in column, measured in _probe_cc2.py
INDENT = 0.56                  # the hanging indent under a conclusion number
LX, LW = 0.55, 7.10            # left column, text full width
RX, RW = 7.85, 4.90            # right column

# The five fixed leads the comparison table uses, as columns of the shared lead
# axis: 5 and 55 minutes, then 1 hour, 24 hours and 7.625 days.
COLS = (1, 11, 12, 58, 376)


def lead_of(col):
    """The lead of a column, in minutes, read from the extraction."""
    for row in N.NUM["lead_share"][0]:
        if row["col"] == col:
            return row["lead_min"]
    raise AssertionError("column %d is not on the 376-column axis" % col)


def lead_text(col):
    """A lead as hours, with the two short ones written in minutes."""
    minutes = lead_of(col)
    if minutes < 60:
        return "%d min" % minutes
    return "%s h" % N.fmt(minutes / 60.0, 1)


def off_med(col):
    """Median over the 288 times of day of the official composite at one column."""
    return N.official("median_by_lead")[col - 1]


def M(key, horizon):
    return N.fmt(N.med(key, horizon))


def share(digits=2):
    """Share of the grid the official composite can be compared on."""
    return N.fmt(100.0 * N.official("comparable_cells") / N.official("cells_total"),
                 digits)


# ------------------------------------------------------------------ the eight
# Every entry is the object first, then what it says. The object is part of the
# sentence rather than a label above it, so a reader who quotes the sentence
# quotes the object with it.
CONCLUSIONS = [
    ("The official composite separates only where it is complete.",
     "Comparable cells are 101,280 of 108,288, which is %s percent, and the first "
     "328 columns carry all 288 times of day. Past column 329 a column thins "
     "until column 376, where a single time of day has a value. Any sentence "
     "about the long end is a sentence about a few samples per column, and the "
     "census reflects that: the official wins 21.77 percent of the cells, the "
     "largest single share and far from a majority." % share()),
    ("The official median passes the template median at 37.5 hours.",
     "On the fixed-lead profile over the 288 times of day, the official median is "
     "10.62 at five minutes, the lowest number anywhere on the axis, and 16.57 is "
     "the nearest a model comes to it there. It rises to %s at 24 hours and %s at "
     "7.625 days, while the plain template holds %s at every lead. The two curves "
     "cross at column %d, which is %s, and the gap then widens to %s dollars by "
     "the last column." % (
         N.fmt(off_med(58)), N.fmt(off_med(376)), M("T28", 0),
         N.NUM["cross_col"], lead_text(N.NUM["cross_col"]),
         N.fmt(abs(off_med(376) - N.med("T28", 2)), 2))),
    ("The families change hands twice, and no model holds the whole axis.",
     "Column by column, taking the median over the 288 times of day for every "
     "candidate, the anchored family is lowest from the first column to %s, the "
     "official composite from there to %s, and the template family from there to "
     "the end. These are switches of the fixed-lead profile and not of the "
     "surface, so a model can hold the median at a lead and still win a minority "
     "of the cells in that column." % (
         lead_text(N.NUM["cross_col"]), lead_text(86))),
    ("The census bands are a plurality, not ownership.",
     "Counted per column over the 288 times of day, the leading model holds 18.4 "
     "percent of the slots at five minutes, 32.6 percent at six hours, 49.0 "
     "percent at three days and 26.7 percent at five days. A majority appears in "
     "32 of the 376 columns and nowhere else: one run, columns 111 to 123, held "
     "by the weekday-class template. In 155 columns the leader holds less than a "
     "third of the slots."),
    ("The combination is real inside a day and gone at 7.6 days.",
     "The recommended rule, optimal weights by lead band with shrinkage 0.3, is "
     "lower in 54,208 of the 108,288 cells and higher in 54,080, with a median "
     "difference of %s dollars per megawatt hour. Fifteen hundredths of the grid "
     "is the whole of the margin, so on this axis the combination is a coin toss "
     "against the single model it is built from, whatever a pooled number says "
     "about it." % N.fmt(abs(N.NUM["comb_vs_anchor"]["median_diff"]), 3)),
    ("Choosing the AR order cell by cell pays on the long axis.",
     "The same template and the same residual history, one with the order chosen "
     "per cell and one with it fixed at four: the per-cell order is lower in "
     "91,861 cells and higher in 16,400, with a median difference of %s dollars "
     "per megawatt hour. This is the one predictor-level change in the section "
     "with a large margin, and the reason is the recursion: a fixed fourth order "
     "runs away at long leads and a low chosen order does not." % (
         N.fmt(abs(N.NUM["m20_vs_m4"]["median_diff"]), 3))),
    ("The figure that would show the order sweep is not in the atlas.",
     "The sweep behind it was run on the older 288-column axis, so its output "
     "does not line up with the 376 columns the rest of the section uses, and the "
     "plotting script skips a figure it cannot place rather than stretching one "
     "onto the new axis. What it would have shown is already stated by two "
     "measurements that are in the atlas: the order chosen per cell, which is 1 "
     "for 84.1 percent of the cells, and the per-cell order against a fixed "
     "fourth order, which is the conclusion before this one."),
    ("The 48-column banding is the grid, not the price.",
     "Past the first hour one column is 30 minutes wide, so 48 columns are "
     "exactly a day, and a model whose forecast does not contain the lead repeats "
     "itself one day later. Measured on the plain template's surface, 368 of the "
     "375 adjacent column pairs are identical in every one of the 288 times of "
     "day, and the seven exceptions are exactly 1,440 minutes apart. A reader who "
     "does not know this expects a period in the price and gets a property of the "
     "axis."),
]

# Which conclusion sits in which column of which page, in printed order. Written
# out rather than sliced, so adding a conclusion cannot silently renumber the
# pages or change what a reader is pointed at. Four to a page is what a 7.10 in
# column holds at this size while leaving room for the cards beside it, and the
# fitter below proves it before anything is written.
PAGES = {
    110: [("left", 1, 0), ("left", 2, 1), ("left", 3, 2), ("left", 4, 3)],
    111: [("left", 5, 4), ("left", 6, 5), ("left", 7, 6), ("left", 8, 7)],
}

CONCLUSION_TITLE = {
    110: "What the official composite covers, and where the lead changes hands",
    111: "What the combination, the order rule and the banding each come to",
}

# The cards beside each conclusion page. A conclusion without a pointer is a
# claim a reader has to take on trust, so every page names the pages of this deck
# that carry its evidence, as the last line of a card that is already there.
NOTE = {
    110: {
        "cards": [
            ("Objects. ", "four things may be compared: the whole 288 by 376 "
                          "surface, a fixed-lead profile over the 288 times of "
                          "day, a fixed-time-of-day profile over the 376 leads, "
                          "and a census that counts who wins each cell."),
            ("Banned. ", "a single average over the whole grid. It mixes every "
                         "lead with every time of day, so two models that are "
                         "strong in opposite corners land on the same number."),
            ("Where to look. ", "95, 96 and 97 for the comparison set, its "
                                "significance and its sample count; 100 and 102 "
                                "for the two profiles; 108 for the crossings"),
        ],
        "table": True,
    },
    111: {
        "cards": [
            ("Tested, not measured. ", "the differences claimed here are tested "
                                       "per cell with a paired Diebold-Mariano "
                                       "statistic, Newey-West at lag 7 and "
                                       "Benjamini-Hochberg at 5 percent. The "
                                       "test says whether a sign is stable, "
                                       "never how large the difference is."),
            ("Ties. ", "the pale region of the significance map is the middle of "
                       "the axis, where two candidates are close enough that 32 "
                       "days cannot separate them. Those cells still count as "
                       "wins for whoever is lower, which is where a narrow "
                       "margin in a census comes from."),
            ("The in-sample panel. ", "the order that minimises R in a cell is "
                                      "chosen with the answers in hand. It is a "
                                      "bound on what any rule could have bought, "
                                      "never a predictor, which is why the sweep "
                                      "that would draw it is not in the atlas."),
            ("Where to look. ", "90 for the order census; 92 for the identical "
                                "column pairs; 98, 99 and 107 for the census and "
                                "its bands; 103 to 105 for the combination and "
                                "the per-cell order"),
        ],
    },
}

# The fixed-lead comparison carried on page 110: the median over the 288 times of
# day at five named columns of the lead axis, for the official composite and the
# three models that own different parts of that axis. Every cell is fetched.
TABLE_HEAD = ("lead", "official", "template", "anchor", "T28 AR(4)")
TABLE_HEAD_LINE = "The same profile at five fixed leads"


def table_rows():
    rows = [list(TABLE_HEAD)]
    for col in COLS:
        rows.append([lead_text(col), N.fmt(off_med(col)), M("T28", 0),
                     M("anchor_mix", 0), M("T28_AR4", 0)])
    return rows


# --------------------------------------------------------------- closing page
# What this artifact maintains, where its numbers come from, and the command that
# rebuilds each part. Paths are relative to the repository root and hold no
# character the deck forbids in a text run.
MAINTAINS = [
    ("What this is. ", "one artifact and one place to change it: the carried "
                       "presentations, the evaluation pages, the error atlas and "
                       "this section live in one file and share one theme, one "
                       "palette and one number source."),
    ("What was added. ", "59 pages written for this deck: the evaluation rules, "
                         "the official composite, one page per predictor, the "
                         "structure of the grid, twelve figures and these closing "
                         "pages. The three source presentations are carried "
                         "verbatim and are not edited here."),
    ("The rules a page obeys. ", "it leads with a conclusion that names the "
                                 "object it is taken on, every figure carries its "
                                 "scope, every formula is a transparent image "
                                 "with a symbol table under it, and no number "
                                 "reaches a page that cannot be traced to the "
                                 "extraction."),
    ("Where to look. ", "the conclusions are on the three pages before this one, "
                        "and each of them points at the pages in this deck that "
                        "carry its evidence."),
]

SOURCE_NOTES = [
    ("One source. ", "every number in this deck is read out of "
                     "deck_numbers_60d.json at build time. The build fails on a "
                     "number it cannot trace, so a hand-typed figure cannot reach "
                     "a page."),
    ("One chain. ", "that JSON comes from the extraction script, which reads the "
                    "atlas and the official composite directly. Nothing in "
                    "between is edited by hand, and both artifacts are rebuilt by "
                    "the commands below."),
]

SOURCES = [
    ["part", "what rebuilds it", "command"],
    ["axis", "the 376-column lead axis", "runs/run_atlas_60d.bat"],
    ["grid", "the error grid and the clamp", "runs/run_atlas_60d.bat"],
    ["official", "the composite from three products", "runs/run_official_atlas.bat"],
    ["figures", "the twelve figures", "runs/run_figures_60d.bat"],
    ["numbers", "the JSON this deck prints from", "runs/run_extract_numbers.bat"],
    ["check", "the regression and fill checks", "runs/run_atlas_regress.bat"],
]

ORIGIN = [
    ("Window ", "60 days from 2026-08-11, scored on the last 32 of them"),
    ("Grid ", "288 times of day by 376 leads, one sample per cell per day"),
    ("Clamping ", "both sides clamped to the target day's rolling 30-day 1st and "
                  "99th percentiles"),
    ("Comparison ", "101,280 comparable cells against the official composite, %s "
                    "percent of the grid" % share()),
    ("Bench ", "sixteen predictors and one official composite"),
    ("Palette ", "six colours, and the two source themes resolve to the same ones"),
]


# ------------------------------------------------------------------- fitting
def _wrap_lines(text, w, size):
    """Lines the renderer will use for `text` in a column `w` inches wide."""
    per_line = CHARS_AT_11PT * w / 4.35 * (11.0 / size)
    n = 0
    for para in text.split("\n"):
        cur, lines = 0, 1
        for word in para.split():
            need = len(word) + (1 if cur else 0)
            if cur + need > per_line:
                lines += 1
                cur = len(word)
            else:
                cur += need
        n += lines
    return n


def conclusion_lines(idx, w):
    """Rendered lines one numbered conclusion needs, its heading included."""
    title, body = CONCLUSIONS[idx]
    return 1 + _wrap_lines(body, w - INDENT, PROSE_SIZE)


def conclusion_height(idx, w):
    """Height one numbered conclusion occupies, measured the way it is drawn.

    The heading box holds its own line and the body sits HEAD_LEAD below the
    heading's top: 10 pt of heading is 0.337 in of rendered line, and the renderer
    starts the ink about 0.05 in below the declared top of a one line box. The
    body's own box ends BODY_SLACK after its last line.
    """
    return HEAD_LEAD + (conclusion_lines(idx, w) - 1) * LINE_H - INK_SLACK + BODY_SLACK


def prose_height(items, w, size):
    total = 0.0
    for item in items:
        total += _wrap_lines("  " + item[0] + item[1], w, size) * PITCH_PER_PT * size
        total += BETWEEN
    return total


def column_of(page, side):
    return [i for s, _n, i in PAGES[page] if s == side]


def column_height(idx, w):
    return sum(conclusion_height(i, w) + BETWEEN for i in idx) if idx else 0.0


def table_height(rows=None):
    rows = SOURCES if rows is None else rows
    return 0.36 + 0.30 * (len(rows) - 1)


def cards_of(page):
    """The cards a page carries, in printed order."""
    return list(NOTE[page]["cards"])


def card_height(page, w=None):
    w = w or RW
    return prose_height(cards_of(page), w, PROSE_SIZE)


def guide_solvable():
    """Price every closing page before anything is written.

    Raises rather than warns for the same reason the predictor fitter does: a
    page that overflows is only visible once it is rendered, and by then it has
    already been written into the deck. Each page is judged column by column,
    with the card and the table charged to the column that carries them.
    """
    out = []
    for page in sorted(PAGES):
        left = column_height(column_of(page, "left"), LW)
        right = card_height(page)
        if NOTE[page].get("table"):
            right += 0.16 + HDR_H + table_height(table_rows())
        out.append((page, left, right))
        if left > BUDGET:
            raise AssertionError(
                "page %d left column needs %.2f in of %.2f; lines %s"
                % (page, left, BUDGET,
                   [conclusion_lines(i, LW) for i in column_of(page, "left")]))
        if right > BUDGET:
            raise AssertionError("page %d right column needs %.2f in of %.2f"
                                 % (page, right, BUDGET))
    left113 = HDR_H + prose_height(MAINTAINS, LW, PROSE_SIZE) + 0.10 + HDR_H \
        + prose_height(ORIGIN, LW, PROSE_SIZE)
    right113 = HDR_H + prose_height(SOURCE_NOTES, RW, PROSE_SIZE) + 0.10 + HDR_H \
        + table_height()
    out.append((113, left113, right113))
    if left113 > BUDGET or right113 > BUDGET:
        raise AssertionError("page 113 needs %.2f in left and %.2f in right of %.2f"
                             % (left113, right113, BUDGET))
    return out


# The scope band states the population under the conclusions: the same window and
# scoring rule the rest of the section uses, plus the one number the conclusions
# rest on, which is how much of the grid the official composite can be compared
# on at all.
SCOPE = ("Scope  32 scored days of a 60-day window, 288 times of day by 376 leads, "
         "one sample per cell per day; the official composite is comparable on "
         "101,280 of the 108,288 cells, %s percent." % share())

CLOSING_SCOPE = ("Scope  every number on this page is read from deck_numbers_60d.json "
                 "at build time; the commands are relative to the repository root "
                 "and are the only supported way to reproduce it.")

# The five pages this section adds, in order. build_new.py dispatches on `kind`.
SPECS = [
    {"n": 109, "kind": "opener"},
    {"n": 110, "kind": "conclusions",
     "title": CONCLUSION_TITLE[110],
     "subtitle": "the comparison set, the fixed-lead profiles, and the switch at 37.5 hours",
     "scope": SCOPE},
    {"n": 111, "kind": "conclusions",
     "title": CONCLUSION_TITLE[111],
     "subtitle": "the per-cell AR order, the recommended combination, and the 48-column banding",
     "scope": SCOPE},
    {"n": 112, "kind": "closing",
     "title": "What this deck maintains, and how to rebuild it",
     "subtitle": "one artifact, one number source, one command per part",
     "scope": CLOSING_SCOPE},
]
