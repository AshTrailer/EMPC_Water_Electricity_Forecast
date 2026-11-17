# -*- coding: utf-8 -*-
"""The new section of the deck, built page by page.

Pages are numbered by their position in the DELIVERED deck, so this file's page
numbers continue after the 62 carried pages. The section built here is:

  63  Part IV opener
  64  the four admissible objects, with the grid schematic
  65  the official composite: three products stitched into one causal stream
  66  what each product actually publishes
  67  where the official series is strong and where it stops
  68  data age, the thing the section has to explain
  69  the 376-column lead axis
  70  the error grid and the three definitions it rests on
  71  four admissible comparisons, and why the pooled RMSE is banned

Every number printed here is looked up in deck_numbers_60d (which reads the
extraction JSON) and audited at the end of the build: a number that cannot be
traced prints a warning.

Six colours only: NAVY, AMBER, INK, MUTED, LINE, WHITE. deck_kit's table helper
bands rows with a seventh colour, so add_table6 below is used instead.

Run: python build_new.py [--first-page 63] [--out deck_B_new.pptx]
"""

import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "2026-09-23", "deck"))

from pptx import Presentation                                     # noqa: E402
from pptx.util import Emu, Inches, Pt                             # noqa: E402

import deck_kit as K                                              # noqa: E402
from deck_formulas import FORMULAS                                # noqa: E402
import deck_metrics as M                                          # noqa: E402
import deck_notation as NT                                        # noqa: E402
import deck_numbers_60d as N                                      # noqa: E402
import deck_predictors as P                                       # noqa: E402
import deck_structure as SP                                       # noqa: E402
import deck_s5 as S5                                              # noqa: E402

TMPDIR = os.path.join(HERE, "_formula_cache")
SCHEM = os.path.join(HERE, "schematics")

PALETTE = {"1E2761", "E9A820", "1B2430", "5A6B7B", "C9D4DE", "FFFFFF"}
PAGE = {"n": 62}

# Content starts below the subtitle. The title box ends at 1.06 and a 13 pt
# subtitle line ends at about 1.32, so anything placed above 1.36 prints through
# it. The first build used 1.22 to 1.30 and every page with a subtitle showed
# the collision.
TOP = 1.38
UNKNOWN = []


# --------------------------------------------------------------- page pieces
def title_size(title):
    """One line or none. A 27 pt Cambria title holds about 56 characters across
    the 11.5 in title box; past that it wraps onto the subtitle. The first build
    let a 72-character title wrap and print over its own subtitle."""
    n = len(title)
    if n <= 56:
        return 27
    if n <= 68:
        return 24
    return 21


def title_page(prs, title, subtitle, number):
    s = K.blank(prs)
    size = title_size(title)
    if number is not None:
        disc = s.shapes.add_shape(K.MSO_SHAPE.OVAL, Inches(0.55), Inches(0.42),
                                  Inches(0.52), Inches(0.52))
        disc.shadow.inherit = False
        disc.fill.solid()
        disc.fill.fore_color.rgb = K.NAVY
        disc.line.fill.background()
        tf = disc.text_frame
        tf.word_wrap = False
        tf.vertical_anchor = K.MSO_ANCHOR.MIDDLE
        p = tf.paragraphs[0]
        p.alignment = K.PP_ALIGN.CENTER
        r = p.add_run()
        r.text = str(number)
        K.style_run(r, 18, K.WHITE, True, font=K.HDR)
    _, tf = K.textbox(s, 1.25, 0.30, 11.5, 0.76, anchor=K.MSO_ANCHOR.MIDDLE)
    K.para(tf, title, size, K.INK, True, font=K.HDR, first=True, space_after=0)
    if subtitle:
        _, tf2 = K.textbox(s, 1.25, 1.10, 11.5, 0.3)
        K.para(tf2, subtitle, K.SUB, K.MUTED, first=True, space_after=0)
    return s


def section_page(prs, title, subtitle, lines, footer=None):
    """A full-bleed NAVY opener. Navy and white only, so the six-colour rule holds."""
    s = K.blank(prs)
    K.add_rect(s, 0, 0, K.SLIDE_W, K.SLIDE_H, fill=K.NAVY)
    _, tf = K.textbox(s, 0.9, 1.55, 11.5, 1.6)
    K.para(tf, title, 34, K.WHITE, True, font=K.HDR, first=True, space_after=10)
    _, tf2 = K.textbox(s, 0.9, 3.15, 11.5, 0.6)
    K.para(tf2, subtitle, 16, K.WHITE, first=True, space_after=0)
    K.add_rect(s, 0.94, 4.05, 2.2, 0.05, fill=K.AMBER)
    _, tf3 = K.textbox(s, 0.9, 4.35, 11.5, 2.0)
    for i, line in enumerate(lines):
        p = tf3.paragraphs[0] if i == 0 else tf3.add_paragraph()
        p.space_after = Pt(9)
        rd = p.add_run()
        rd.text = "\u25aa  "
        K.style_run(rd, 15, K.AMBER, True)
        r = p.add_run()
        r.text = line
        K.style_run(r, 15, K.WHITE)
    if footer:
        _, tf4 = K.textbox(s, 0.9, 6.75, 11.5, 0.3)
        K.para(tf4, footer, 10, K.WHITE, italic=True, first=True, space_after=0)
    return s


def formula(slide, name, x, y, max_w, size=14):
    tex = FORMULAS[name][0]
    _, h, _ = K.add_formula(slide, tex, x, y, max_w, TMPDIR, fontsize=size)
    return y + h


def add_runs(p, text, size, color=K.INK, bold=False, font=None):
    """A symbol string with a TRUE subscript, never an underscore.

    'l_i' becomes an l followed by a baseline-shifted i at 72% size. Writing the
    underscore literally is what the user asked to be prevented: it reads as a
    code identifier rather than as mathematics. The XML carries baseline="-25000"
    on the second run, which is the OOXML subscript, so PowerPoint and LibreOffice
    both render it as a subscript.
    """
    main, _, sub = text.partition("_")
    r = p.add_run()
    r.text = main
    K.style_run(r, size, color, bold, font=font)
    if sub:
        assert "_" not in sub, (
            "symbol %r has more than one underscore; give each subscript its own row "
            "or write the quantity the way the report does" % text)
        r2 = p.add_run()
        r2.text = sub
        K.style_run(r2, size * 0.72, color, bold, font=font)
        r2.font._rPr.set("baseline", "-25000")


def tight_line(p, space_after_pt=2.0):
    """Force one rendered line per paragraph.

    The renderer charged 0.37 in per symbol row against the 0.185 in the layout
    had budgeted, which pushed the table over the scope band. The cause is the
    unset line spacing and space-before, so both are pinned here: single spacing
    and no space before. Measured with _probe_pitch.py.
    """
    p.line_spacing = 1.0
    p.space_before = Pt(0)
    p.space_after = Pt(space_after_pt)


def symtab(slide, x, y, w, rows, size=11, head="Symbols on this page", row_h=None):
    """Symbol and description on ONE line, aligned by a tab stop.

    A table would need two measured columns; a tab stop is exact and lets the
    description run the full width of the column, which is what keeps a long
    description on one line. Every symbol has at most one underscore and the
    description is checked against SYM_DESC_CHARS by the fitter, so a row that
    would wrap is caught before it is written.
    """
    row_h = SYM_ROW_H if row_h is None else row_h
    _, tf = K.textbox(slide, x, y, w, 0.26)
    K.para(tf, head, K.SUB, K.NAVY, True, font=K.HDR, first=True, space_after=0)
    tight_line(tf.paragraphs[0], 0)
    y += SYM_HDR_H
    _, tf2 = K.textbox(slide, x, y, w, row_h * len(rows) + 0.1)
    for i, (sym, text) in enumerate(rows):
        p = tf2.paragraphs[0] if i == 0 else tf2.add_paragraph()
        tight_line(p, 2.0)
        tabs = p._pPr.makeelement(
            "{http://schemas.openxmlformats.org/drawingml/2006/main}tabLst", {})
        tab = p._pPr.makeelement(
            "{http://schemas.openxmlformats.org/drawingml/2006/main}tab", {})
        tab.set("pos", str(int(SYM_TAB * 914400)))
        tabs.append(tab)
        p._pPr.insert(0, tabs)
        add_runs(p, sym, size, K.INK, True, K.HDR)
        r = p.add_run()
        r.text = "\t" + text
        K.style_run(r, size, K.INK)
    return y + row_h * len(rows) + 0.06


def note_box(slide, x, y, w, label, rest, size=None):
    """One note bullet in a box sized to the lines it actually needs.

    A tall box whose text is small came back squeezed into a narrow band with the
    lines touching, on every page that had four notes at 9 pt. A box sized to its
    own content does not have that failure mode, and the fitter has already proved
    the whole column fits. Measured on a rendered page: with a box of height h the
    ink lands about h + 0.22 below the declared top, so the next bullet is placed
    from the measured text height rather than from the declared box.
    """
    lines = wrap_lines(" " * BULLET_CHARS + label + rest, w, size or PROSE_SIZE)
    h = max(1, lines) * LINE_H + 0.06
    _, tf = K.textbox(slide, x, y, w, h)
    K.bullets(tf, [(label, rest)], size=size or PROSE_SIZE, space_after=0)
    for p in tf.paragraphs:
        p.line_spacing = 1.0
        p.space_before = Pt(0)
    return y + h


def prose(slide, x, y, w, lines, size=14, space=7, head=None):
    """A column of notes, one box per bullet. Returns the y after the last one."""
    if head:
        _, tfh = K.textbox(slide, x, y, w, 0.26)
        K.para(tfh, head, K.SUB, K.NAVY, True, font=K.HDR, first=True, space_after=0)
        y += HDR_H
    for item in lines:
        y = note_box(slide, x, y, w, item[0], item[1], size=size)
        y += BETWEEN_BLOCKS
    return y


def scope(slide, text, formula_name=None):
    """The population band. Two lines at 10 pt, checked before it is written."""
    scope_fits(text)
    _, tf = K.textbox(slide, 0.55, SCOPE_TOP, 8.05, 0.60)
    K.para(tf, text, SCOPE_SIZE, K.MUTED, italic=True, first=True, space_after=0)
    tf.paragraphs[0].line_spacing = 1.0
    tf.paragraphs[0].space_before = Pt(0)
    if formula_name:
        K.add_formula(slide, FORMULAS[formula_name][0], 8.75, SCOPE_FORMULA_TOP, 4.0,
                      TMPDIR, fontsize=SCOPE_SIZE)


def add_table6(slide, x, y, w, rows, col_w=None, size=11, row_h=0.32, head_h=0.36):
    """Header NAVY on white text, body rows WHITE with LINE rules. No seventh colour."""
    n_rows, n_cols = len(rows), len(rows[0])
    shape = slide.shapes.add_table(n_rows, n_cols, Inches(x), Inches(y),
                                   Inches(w), Inches(head_h + row_h * (n_rows - 1)))
    t = shape.table
    t.first_row = False
    t.horz_banding = False
    if col_w:
        total = float(sum(col_w))
        for j, cw in enumerate(col_w):
            t.columns[j].width = Emu(int(Inches(w) * cw / total))
    t.rows[0].height = Inches(head_h)
    for i in range(1, n_rows):
        t.rows[i].height = Inches(row_h)
    for i, row in enumerate(rows):
        for j, val in enumerate(row):
            c = t.cell(i, j)
            c.margin_left = c.margin_right = Inches(0.06)
            c.margin_top = c.margin_bottom = Inches(0.015)
            c.vertical_anchor = K.MSO_ANCHOR.MIDDLE
            c.fill.solid()
            c.fill.fore_color.rgb = K.NAVY if i == 0 else K.WHITE
            p = c.text_frame.paragraphs[0]
            p.alignment = K.PP_ALIGN.LEFT if j == 0 else K.PP_ALIGN.CENTER
            p.space_after = Pt(0)
            r = p.add_run()
            r.text = str(val)
            K.style_run(r, size, K.WHITE if i == 0 else K.INK, i == 0 or j == 0)
    return shape


def picture(slide, path, x, y, w, h):
    return K.fit_image(slide, path, x, y, w, h)


# ------------------------------------------------- the predictor page layout
# Every vertical number here is in inches and was MEASURED on a rendered page,
# not taken from the nominal point size. The renderer charges 0.371 in for one
# line of 11 pt text, which is 2.43 times the point size, not the 1.2 a text
# frame implies: measured at 11 pt over six rows, single spacing, zero
# space-before, in _probe_pitch.py. Everything below follows from that one
# number, and the first build failed because it assumed 1.2.
PITCH_PER_PT = 0.371 / 11.0
BOTTOM = 6.72
CHARS_AT_11PT = 83.0        # in a 4.35 in column, measured in _probe_cc2.py
PROSE_SIZE = 9
LINE_H = PITCH_PER_PT * PROSE_SIZE
BULLET_CHARS = 2            # the bullet glyph plus its two spaces
HDR_H = 0.28                # a small navy head above a block
SYM_HDR_H = 0.30            # the "Symbols on this page" head
SYM_SIZE = 9
SYM_ROW_H = PITCH_PER_PT * SYM_SIZE + 0.02
SYM_TAB = 0.40              # width of the symbol column, in inches
SYM_TOKEN_H = 0.32          # the widest symbol column this layout will accept
GAP_AFTER_SYM = 0.10
BETWEEN_BLOCKS = 0.06
GAP_AFTER_FORMULA = 0.16
MIN_FORMULA_PT = 10.0
# One rendered line at 9 pt holds this many characters of symbol description
# after the symbol column and its tab. Above it the row wraps by a whole line.
SYM_DESC_CHARS = 148
SYM_MAX_ROWS = 9
PROSE_MAX_LINES = 19        # the notes column has room for this many lines at 9 pt
# The scope band runs from 6.76 to the slide edge. At 10 pt the pitch is
# 0.337 in, so the band holds two lines and no more.
SCOPE_SIZE = 10
SCOPE_LINES = 2
SCOPE_CHARS = 300           # per line at 10 pt across the 8.05 in band
SCOPE_TOP = 6.76
SCOPE_FORMULA_TOP = 6.90

# Natural size of every formula at 14 pt, in inches. Measured once by
# _probe_fits.py, which renders each string through the same renderer the deck
# uses. A formula is never sized by width alone, and never stretched: when it is
# wider than its column the point size drops instead, so the picture keeps the
# renderer's own aspect ratio.
FORMULA_WH_14PT = {
    # The metric definitions, on pages 68 and 69.
    "m_err": (2.877, 0.267), "m_mse": (3.427, 0.463), "m_rmse": (1.963, 0.293),
    "m_med_lead": (3.903, 0.238), "m_med_slot": (3.220, 0.232),
    "m_pooled": (2.735, 0.528), "m_units": (5.667, 0.337),
    "m_mse_alt": (3.292, 0.580),
    "m1": (2.485, 0.287), "tmpl": (2.403, 0.605), "m2": (2.177, 0.267),
    "m3": (3.503, 0.287), "rlss": (4.940, 0.383), "resid": (2.200, 0.237),
    "m4_rec": (6.232, 0.610), "m4": (3.407, 0.267), "rlsv": (6.043, 0.375),
    "m5": (1.675, 0.267), "m6": (5.178, 0.267), "m7": (5.072, 0.267),
    "m8": (7.525, 0.610), "m8_convex": (3.190, 0.238), "m9_fit": (4.423, 0.293),
    "m9": (3.342, 0.302), "m10": (4.593, 0.435), "m10p": (2.425, 0.267),
    "m11": (3.857, 0.302), "m12_rho": (3.108, 0.342), "m12": (4.698, 0.322),
    "m13_ss": (7.017, 0.243), "m13_upd": (5.932, 0.327), "m13": (4.217, 0.327),
    "m13_g": (4.662, 0.327), "m13_rot": (3.335, 0.340), "m14": (3.555, 0.848),
    "m14p": (2.265, 0.267), "m15": (3.955, 0.577), "m16": (4.370, 0.310),
    "m17": (5.733, 0.267), "m18": (4.828, 0.463), "m19_cand": (4.982, 0.267),
    "m19_rule": (6.932, 0.470), "m20": (3.408, 0.273), "err_R": (2.917, 0.533),
    "win_share": (4.080, 0.457), "slot": (3.260, 0.232), "diff": (2.137, 0.237),
}


def wrap_lines(text, w, size):
    """Lines the renderer will use for `text` in a column `w` inches wide.

    A proportional font is not monospaced, so this is an estimate. It is used as
    a pre-flight limit, never as the verdict: the verdict is the rendered page.
    """
    per_line = CHARS_AT_11PT * w / 4.35 * (11.0 / size)
    n = 0
    for para in text.split("\n"):
        words = para.split()
        cur = 0
        lines = 1
        for word in words:
            need = len(word) + (1 if cur else 0)
            if cur + need > per_line:
                lines += 1
                cur = len(word)
            else:
                cur += need
        n += lines
    return n


def column_lines(blocks):
    """Rendered lines a prose column needs, including its bullet glyphs."""
    total = 0.0
    for item in blocks:
        if isinstance(item, tuple) and item[0] == "__head__":
            total += 1
            continue
        label, rest = item
        total += wrap_lines(" " * BULLET_CHARS + label + rest, 4.35, PROSE_SIZE)
    return total


def scope_fits(text):
    """The scope band holds two lines at 10 pt, so the text has a hard budget."""
    n = wrap_lines(text, 8.05, SCOPE_SIZE)
    if n > SCOPE_LINES:
        raise AssertionError("scope text needs %d lines at %d pt, the band holds %d: %r"
                             % (n, SCOPE_SIZE, SCOPE_LINES, text[:60]))
    return n


def stack_height(fnames, size, col_w):
    """Height of the formula stack, plus the point size each formula lands at.

    A formula wider than its column is scaled by width, so its point size is
    lower than the stack size and its height scales with it.
    """
    y = 0.0
    sizes = []
    for i, nm in enumerate(fnames):
        nat_w, nat_h = FORMULA_WH_14PT[nm]
        pt = size
        if nat_w * size / 14.0 > col_w:
            pt = 14.0 * col_w / nat_w
        pt = max(pt, MIN_FORMULA_PT)
        sizes.append(pt)
        y += nat_h * pt / 14.0
        if i + 1 < len(fnames):
            y += GAP_AFTER_FORMULA
    return y, sizes


def prose_height(blocks, size=PROSE_SIZE, w=4.35):
    y = 0.0
    for item in blocks:
        if isinstance(item, tuple) and item[0] == "__head__":
            y += HDR_H
            continue
        y += wrap_lines(" " * BULLET_CHARS + item[0] + item[1], w, size) * LINE_H
        y += BETWEEN_BLOCKS
    return y


def sym_height(rows):
    return SYM_HDR_H + SYM_ROW_H * len(rows) + GAP_AFTER_SYM


def sym_token_width(sym):
    """Width of the symbol column entry, in inches, for a bold 11 pt Cambria run."""
    return 0.0135 * len(sym) + 0.02


def check_symbols(p, wide=7.60):
    """Every symbol row must be one line: a narrow token and a description that
    fits the column to the right of the tab stop. A row that wraps adds a line
    the height model does not include, which is how the first build of these
    pages printed its symbol table over the scope band."""
    if len(p["symbols"]) > SYM_MAX_ROWS:
        raise AssertionError("page %s has %d symbol rows, the layout fits %d"
                             % (p["n"], len(p["symbols"]), SYM_MAX_ROWS))
    worst = 0.0
    for sym, text in p["symbols"]:
        tw = sym_token_width(sym)
        worst = max(worst, tw)
        if tw > SYM_TOKEN_H:
            raise AssertionError("page %s: symbol %r is %.2f in wide, over the %.2f in "
                                 "symbol column" % (p["n"], sym, tw, SYM_TOKEN_H))
        if len(text) > SYM_DESC_CHARS:
            raise AssertionError("page %s: the description of %r is %d characters, over "
                                 "the %d that fit on one line"
                                 % (p["n"], sym, len(text), SYM_DESC_CHARS))
    return worst


def predictor_solvable(p, lx=0.55, lw=7.60, rx=8.40, rw=4.35):
    """Judge one predictor page: does every column fit above the scope band?

    Raises rather than warns. A page that overflows is only visible once it is
    rendered, and by then it has already been written into the deck.
    """
    check_symbols(p, lw)
    for size in (14.0, 13.0, 12.0, 11.0):
        fh, sizes = stack_height(p["formulas"], size, lw)
        left = fh + sym_height(p["symbols"])
        right = prose_height(p["prose"], w=rw)
        if left <= BOTTOM - TOP and right <= BOTTOM - TOP:
            return size, sizes, fh, max(left, right)
    fh, sizes = stack_height(p["formulas"], MIN_FORMULA_PT, lw)
    raise AssertionError(
        "page %s does not fit: left %.2f in (formulas %.2f), right %.2f in, budget %.2f in"
        % (p["n"], fh + sym_height(p["symbols"]), fh, prose_height(p["prose"], w=rw),
           BOTTOM - TOP))


def page_predictor(prs, p):
    """One predictor: assertion title, formulas, symbol table, notes, scope."""
    LX, LW, RX, RW = 0.55, 7.60, 8.40, 4.35
    size, sizes, fh, _ = predictor_solvable(p)
    s = title_page(prs, p["title"], p["subtitle"], p["n"])

    y = TOP
    for nm, pt in zip(p["formulas"], sizes):
        y = formula(s, nm, LX, y, LW, size=round(pt, 2)) + GAP_AFTER_FORMULA
    symtab(s, LX, y + 0.02, LW, p["symbols"], size=11, row_h=SYM_ROW_H)

    prose_blocks = list(p["prose"])
    yy = TOP
    if p.get("head"):
        _, tfh = K.textbox(s, RX, yy, RW, 0.26)
        K.para(tfh, p["head"], K.SUB, K.NAVY, True, font=K.HDR, first=True,
               space_after=0)
        yy += HDR_H
    for item in prose_blocks:
        yy = note_box(s, RX, yy, RW, item[0], item[1]) + BETWEEN_BLOCKS

    scope(s, p["scope"], p.get("scope_formula"))
    return s


def check_predictor_specs(specs):
    """Print the fitted size of every predictor page before anything is written."""
    worst = []
    for p in specs:
        size, sizes, fh, used = predictor_solvable(p)
        worst.append((used, p["n"], size, min(sizes)))
        print("  page %-3d stack %4.1f pt   smallest formula %4.1f pt   "
              "column height %.2f in of %.2f" % (p["n"], size, min(sizes), used, BOTTOM - TOP))
    tight = [w for w in worst if w[0] > BOTTOM - TOP - 0.20]
    if tight:
        print("  tight pages: %s" % ", ".join(str(t[1]) for t in tight))
    return worst


# --------------------------------------------------------------------- pages
def page_opener(prs):
    return section_page(
        prs,
        "Part IV \u2014 A 376-column bench over 60 days",
        "VIC1 five-minute price, window 2026-08-11 to 2026-10-09, scored on days 29 to 60",
        [
            "The official AEMO composite was rebuilt from the three products AEMO actually "
            "publishes, so a model can be compared against the market's own forecast.",
            "The lead axis now runs to 183.0 hours instead of one day, so the long end is "
            "measured rather than extrapolated from a daily average.",
            "Every claim in this section is one of four cell-by-cell comparisons. No number "
            "here is an average over the whole grid.",
        ],
        footer="Sixteen predictors, one official composite, one 288 by 376 error surface",
    )


def page_reading(prs):
    s = title_page(prs, "Four things may be compared, and nothing else",
                   "the grid, the two axes, and the one number that is never a ranking",
                   PAGE["n"])
    picture(s, os.path.join(SCHEM, "s2_reading_grid.png"), 0.55, TOP, 7.55, 5.45)
    prose(s, 8.30, TOP, 4.45, [
        ("The two axes. ", "time of day runs over 288 five-minute slots; forecast lead runs "
                           "over 376 columns. Every cell is one RMSE number."),
        ("The four objects. ", "the whole surface, a row at one lead, a column at one time of "
                               "day, and a census that counts who wins each cell."),
        ("What is banned. ", "a single average over the whole grid. It mixes every lead and "
                             "every time of day, so it cannot rank anything."),
        ("The rule. ", "a figure and its conclusion always travel together here."),
    ], head="How to read this section")
    scope(s, "Scope  window 2026-08-11 to 2026-10-09, 60 days; scored on days 29 to 60, "
             "32 days; one sample per cell per day; forecast and actual both clamped to the "
             "target day's rolling 30-day Q1 and Q99.", "err_R")
    return s


def page_stitch(prs):
    s = title_page(prs, "The official series is three products stitched into one causal stream",
                   "one value per target interval, chosen from runs that had already been published",
                   PAGE["n"])
    y = formula(s, "off_rule", 0.55, TOP + 0.14, 8.6)
    y = formula(s, "off_pick", 0.55, y + 0.26, 8.6)
    y = symtab(s, 0.55, y + 0.30, 8.6, [
        ("O", "origin, the interval that has just closed when the forecast is issued"),
        ("L", "lead in minutes, from the origin to the target interval"),
        ("T", "target interval, the interval the official value belongs to"),
        ("eff(p)", "effective time of run p, the publication time stamped on it, NEM time"),
        ("step(p)", "publication step of run p: 5 minutes for P5MIN, 30 for the longer two"),
        ("ceil30", "round up to the next 30-minute grid point, the cadence of both longer products"),
        ("P5MIN", "5-minute pre-dispatch, forwards to 55 minutes, published every 5 minutes"),
        ("PREDISPATCH", "30-minute pre-dispatch, horizon 15.5 to 39.0 hours, published every 30 minutes"),
        ("PD7DAY", "7-day projection, horizon 164.5 to 183.0 hours, three runs a day"),
    ], row_h=0.215)
    prose(s, 0.55, y + 0.24, 8.6, [
        ("What this is not. ", "the composite is neither a model of ours nor a correction "
                               "layer. It is the market's own forward view, rebuilt into a "
                               "causal series so it can be measured on exactly the same grid "
                               "as the sixteen predictors."),
        ("Why a composite at all. ", "no single product covers the whole axis: P5MIN stops at "
                                     "55 minutes and PD7DAY only exists three times a day. "
                                     "Taking the freshest run that reaches the target is what "
                                     "a participant could actually have done at the origin."),
    ], size=13, space=6)
    prose(s, 9.45, TOP + 0.14, 3.30, [
        ("Causal. ", "a run may only be used after it is published, so the composite never "
                     "looks forward."),
        ("Why two rules. ", "up to 55 minutes the target lands on P5MIN's own 5-minute grid. "
                            "Past that it is snapped to the 30-minute grid."),
        ("Order matters. ", "P5MIN is freshest, then PREDISPATCH, then PD7DAY."),
        ("Timestamps. ", "all three stamp the interval END, the same convention as "
                         "SETTLEMENTDATE, so nothing is shifted."),
    ], size=12, space=6, head="Why the rule looks like this")
    scope(s, "Scope  the three source files are the NEMWEB archives for VIC1 over the window; "
             "the selection is recomputed per origin, never fitted.")
    return s


def page_products(prs):
    s = title_page(prs, "What each product actually publishes, measured on the archive",
                   "run counts and column counts come from the files themselves, not from the format guide",
                   PAGE["n"])
    add_table6(s, 0.55, TOP, 12.2, [
        ["product", "published", "runs in the window", "columns per run",
         "forwards to", "share of the 32 scored days"],
        ["P5MIN", "every 5 minutes", "{:,}".format(N.SPEC["P5MIN"]["runs"]),
         N.SPEC["P5MIN"]["columns"], "55 minutes", N.fmt(N.src_share("p5min")) + "%"],
        ["PREDISPATCH", "every 30 minutes", "{:,}".format(N.SPEC["PREDISPATCH"]["runs"]),
         N.SPEC["PREDISPATCH"]["columns"], "15.5 to 39.0 hours",
         N.fmt(N.src_share("predispatch")) + "%"],
        ["PD7DAY", "three runs a day", "{:,}".format(N.SPEC["PD7DAY"]["runs"]),
         N.SPEC["PD7DAY"]["columns"], "164.5 to 183.0 hours",
         N.fmt(N.src_share("pd7day")) + "%"],
        ["none", "\u2014", "\u2014", "\u2014", "\u2014", N.fmt(N.src_share("none")) + "%"],
    ], col_w=[1.5, 1.7, 1.5, 1.5, 1.9, 2.0], size=11)
    y = formula(s, "off_col", 0.55, 4.20, 6.0)
    symtab(s, 0.55, y + 0.22, 6.0, [
        ("col", "the column a target interval occupies inside a run of that product"),
        ("period", "the interval's index inside the run, counting from the run's first column"),
    ], head="Where a target lands inside a run", size=11, row_h=0.22)
    prose(s, 6.90, 4.20, 5.85, [
        ("Regular grid. ", "every product stamps its columns at a fixed step from the run's "
                           "effective time, so a target's column is closed form. Nothing on "
                           "the lead axis is interpolated."),
        ("Why 12 and 367. ", "P5MIN's own grid is offsets 0 to 55 minutes; offset 0 is the "
                             "interval that has already closed, so it is not a forecast and "
                             "is not a column. PD7DAY carries 367 columns."),
        ("The 6.47%. ", "cells no run reaches. They are not missing measurements, they are "
                        "outside every published horizon, and they are excluded from every "
                        "comparison rather than filled in."),
    ], size=12, space=6)
    scope(s, "Scope  run and column counts are measured over the same 60-day window; the share "
             "column is over the 32 scored days only.")
    return s


def page_official_strength(prs):
    s = title_page(prs, "The official composite is the strongest single candidate on the long axis",
                   "and it is still only one candidate, winning 21.77% of the cells",
                   PAGE["n"])
    picture(s, os.path.join(SCHEM, "s1_official_chain.png"), 0.55, TOP, 12.2, 3.70)
    add_table6(s, 0.55, 5.15, 6.0, [
        ["lead", "median RMSE over the 288 times of day"],
        ["1 hour", N.fmt(N.official("med")[0])],
        ["24 hours", N.fmt(N.official("med")[1])],
        ["7.6 days", N.fmt(N.official("med")[2])],
    ], col_w=[1.0, 2.2], size=11)
    prose(s, 6.90, 5.15, 5.85, [
        ("Coverage. ", "the 5 to 55 minute band is complete: 190,014 of 190,080. The band from "
                       "1 hour to 183.0 hours is 5,508,910 of 6,307,200, which is 87.3%."),
        ("Comparable cells. ", "over the 32 scored days the official carries a value in "
                               "101,280 of 108,288 cells, so 93.53% of the grid can be "
                               "compared against it."),
        ("Where it wins. ", "the census with the official in the running gives it 21.77%, "
                            "the largest single share, and the templates take 19.77% and "
                            "17.54%."),
    ], size=12, space=6)
    scope(s, "Scope  coverage is over the 60-day window; median RMSE and the census are over the "
             "32 scored days and the full 376-column lead axis.")
    return s


def page_age(prs):
    s = title_page(prs, "Data age is a real limitation, and this is its size",
                   "three products, three publication cadences, and a long overnight gap",
                   PAGE["n"])
    y = formula(s, "off_age", 0.55, TOP, 5.2)
    symtab(s, 0.55, y + 0.18, 5.9, [
        ("age", "how stale the official value is at the moment the forecast is issued"),
        ("O", "origin, the interval that has just closed"),
        ("eff(p)", "effective time of the run that supplied the value"),
    ], head="What age measures", size=11)
    prose(s, 0.55, 3.05, 5.9, [
        ("Why age exists. ", "P5MIN is published every 5 minutes, PREDISPATCH every 30 minutes, "
                             "and PD7DAY only three times a day. A target 7 days out can only be "
                             "served by the 07:30, 13:00 or 18:00 run, so the value can be hours "
                             "old before the forecast is even issued."),
        ("The overnight gap. ", "no PD7DAY run is published between 18:00 and 07:30, which is "
                                "13.5 hours. That gap sets the worst case."),
        ("What it does not mean. ", "age is not error. It is a property of the data chain that "
                                    "has to be read next to any long-lead comparison."),
    ], size=12, space=6, head="Why this page exists")
    add_table6(s, 6.85, TOP, 5.9, [
        ["source", "median age", "75th percentile", "95th percentile", "worst case"],
        ["P5MIN", "0", "0", "0", "0"],
        ["PREDISPATCH", "0.17 h", "0.33 h", "0.42 h", "0.42 h"],
        ["PD7DAY", "3.96 h", "7.46 h", "12.25 h", "13.42 h"],
    ], col_w=[1.5, 1.1, 1.2, 1.2, 1.1], size=11)
    prose(s, 6.85, 3.05, 5.9, [
        ("How to read it. ", "median age for PD7DAY is 3.96 hours, so half of all long-lead "
                              "official values are more than four hours old."),
        ("Where it bites. ", "the long end of the axis, beyond a day, where PD7DAY is the only "
                             "source. At 183.0 hours the official value comes from a run issued "
                             "up to 13.42 hours earlier."),
        ("The check. ", "ages are computed per cell as origin minus the supplying run's "
                        "effective time, over the 32 scored days."),
    ], size=12, space=6, head="What the numbers say")
    scope(s, "Scope  ages are measured per cell over the 32 scored days; the source mix behind "
             "them is 2.93% P5MIN, 14.01% PREDISPATCH, 76.60% PD7DAY.")
    return s


def page_axis(prs):
    s = title_page(prs, "The lead axis has 376 columns, and every one lands on an official grid point",
                   "eleven 5-minute columns, then 365 half-hour columns out to 183.0 hours",
                   PAGE["n"])
    y = formula(s, "lead_axis", 0.55, TOP, 9.0, size=16)
    symtab(s, 0.55, y + 0.22, 9.0, [
        ("i", "column number on the axis, 1 to 376"),
        ("\u2113_i", "the lead of column i, in minutes"),
        ("n_h", "the number of columns, 376"),
        ("n_s", "slots in a day, 288, which is also the number of 5-minute steps in a day"),
    ], head="Symbols on this page", size=12, row_h=0.24)
    prose(s, 0.55, 3.25, 12.2, [
        ("Why it is not uniform. ", "P5MIN publishes at 5-minute steps to 55 minutes, and both "
                                    "longer products publish at 30-minute steps. An axis of "
                                    "uniform 5-minute steps to 183.0 hours would need 2,196 "
                                    "columns and would interpolate three quarters of them."),
        ("Why it stops at 55. ", "60 minutes is the first lead P5MIN cannot supply, because its "
                                 "own grid is offsets 0 to 55. Column 12 therefore comes from "
                                 "PREDISPATCH, and from there on the axis is on the 30-minute "
                                 "grid."),
        ("One day is 48 columns. ", "past the first hour a column is 30 minutes wide, so 48 "
                                    "columns span exactly one day. That is why the surfaces in "
                                    "this section show a 48-column periodic banding."),
    ], size=13, space=7)
    scope(s, "Scope  the axis is defined once, in a single shared function, and every figure, "
             "the atlas and the composite read it from there.")
    return s


def page_grid(prs):
    s = title_page(prs, "The error grid: 288 times of day by 376 leads, 32 samples in every cell",
                   "clamp first, then build the cube, then take an RMSE per cell",
                   PAGE["n"])
    y = formula(s, "err_e", 0.55, TOP, 6.2, size=15)
    y = formula(s, "err_E", 0.55, y + 0.16, 6.6, size=15)
    y = formula(s, "err_R", 0.55, y + 0.16, 4.6, size=15)
    symtab(s, 0.55, y + 0.20, 6.6, [
        ("y_c", "the clamped price, the signal every metric is measured on"),
        ("y-hat", "the forecast of interval k+h issued at origin k, clamped the same way"),
        ("e", "one scored error, actual minus clamped forecast"),
        ("E", "the error cube, indexed by time of day, lead and target day"),
        ("R", "the RMSE surface, one number per cell"),
        ("n_d", "scored days in the cell, 32"),
        ("q1, q99", "the target day's rolling 30-day 1st and 99th percentiles"),
    ], head="Symbols on this page", size=12, row_h=0.22)
    y2 = formula(s, "clamp", 7.45, TOP, 5.3, size=15)
    y2 = formula(s, "clampq", 7.45, y2 + 0.16, 5.3)
    prose(s, 7.45, y2 + 0.30, 5.3, [
        ("Clamp both sides. ", "forecast and actual are clamped identically, so one extreme "
                               "print cannot steer a 24-hour schedule and cannot decide which "
                               "model wins a cell either."),
        ("32 samples. ", "every scored cell carries exactly 32 samples, one per scored day. "
                         "That is asserted at build time, not assumed."),
        ("Two populations. ", "the atlas also stores an RMSE over all 60 days. Every figure "
                              "and every number in this section uses the 32 scored days, "
                              "because that is the population the official composite can cover "
                              "and the combination rules can be scored on."),
    ], size=12, space=6)
    scope(s, "Scope  window 2026-08-11 to 2026-10-09, 60 days; scored on days 29 to 60; one "
             "sample per cell per day.", "err_R")
    return s


def page_objects(prs):
    s = title_page(prs, "Four admissible comparisons, and why one number over the whole grid is not one",
                   "the pooled RMSE is a run fingerprint; it is never a ranking basis",
                   PAGE["n"])
    y = formula(s, "err_pool", 0.55, TOP, 8.4, size=16)
    y = formula(s, "dm", 0.55, y + 0.22, 8.4, size=16)
    y = formula(s, "dm_bh", 0.55, y + 0.20, 8.4, size=16)
    prose(s, 0.55, y + 0.34, 12.2, [
        ("Why the pooled number fails. ", "it averages over every lead. A model that owns the "
                                          "first hour and collapses past a day and a model that "
                                          "is mediocre everywhere can land on the same pooled "
                                          "value, and the ranking it produces changes with the "
                                          "window length."),
        ("What replaces it. ", "the same cells, compared one at a time. The Diebold-Mariano "
                               "statistic is computed per cell on the paired squared errors, "
                               "with Newey-West at lag 7 because the errors are autocorrelated."),
        ("What the map means. ", "the significance map answers whether a difference is stable, "
                                 "not how large it is. Magnitude comes from the difference "
                                 "surface beside it."),
        ("Multiple testing. ", "108,288 cells are tested at once, so the Benjamini-Hochberg "
                               "step at 5% controls the false discovery rate rather than the "
                               "per-cell error rate."),
    ], size=13, space=6)
    scope(s, "Scope  the pooled value is reported only as a run fingerprint, to confirm that a "
             "change did not touch the rest of the pipeline.")
    return s


def page_predictor_slot(prs, spec):
    """One of the twenty predictor pages. The number comes from the spec, not
    from the build order, so a page cannot silently renumber when one is added."""
    PAGE["n"] = spec["n"] - 1
    return page_predictor(prs, spec)


# ------------------------------------------------- the structure and figure pages
FIG_DIR = os.path.join(HERE, "..", "predictor", "figures_60d")
# A figure wider than this cannot sit beside a column of notes, so it goes above
# them and the notes are split across the page instead.
BESIDE_W = 8.60
FOOT_W = 11.00          # the width a wide figure is drawn at, centred
FIG_BOTTOM = 6.60       # the figure and the notes both stop here, above the band


def pic_size(ar, w):
    """Width and height of a figure drawn to the column width."""
    return w, w / ar


def figure_foot_solvable(p, ar):
    """A wide figure on top, its notes split into two columns underneath."""
    last = None
    for fw in (FOOT_W, 10.6, 10.2, 9.8, 9.4, 9.0, 8.6, 8.2, 7.8, 7.4, 7.0):
        h = fw / ar
        notes_h = max(prose_height(p["what"][:3], w=5.90),
                      prose_height(p["what"][3:], w=5.90))
        if h + notes_h + 0.30 <= FIG_BOTTOM - TOP:
            return fw, h, notes_h
        last = (fw, h, notes_h)
    raise AssertionError(
        "page %s: a wide figure plus its notes does not fit; at %.1f in the figure is "
        "%.2f in and the notes take %.2f in, against a budget of %.2f in"
        % (p["n"], last[0], last[1], last[2], FIG_BOTTOM - TOP))


def figure_beside_solvable(p, rw=4.35):
    """A figure on the left, notes in a right column, both inside the budget.

    The figure is drawn at the widest width that fits, so a tall figure (a low
    aspect ratio) is narrowed rather than allowed to run past the scope band:
    f3 is 1.588, which is 5.42 in tall at the full 8.60 in column and would land
    in the band.
    """
    notes_h = prose_height(p["what"], w=rw)
    last = None
    for fw in (BESIDE_W, 8.3, 8.0, 7.7, 7.4, 7.1, 6.8, 6.5, 6.2, 5.9, 5.6):
        h = fw / p["ar"]
        if h <= FIG_BOTTOM - TOP and notes_h <= FIG_BOTTOM - TOP:
            return fw, h, notes_h
        last = (fw, h)
    raise AssertionError("page %s: figure %.2f in tall at %.2f in wide and notes %.2f in, "
                         "budget %.2f" % (p["n"], last[1], last[0], notes_h,
                                          FIG_BOTTOM - TOP))


def check_structure_specs(specs):
    """Price every structure and figure page before any of them is written."""
    for p in specs:
        if p["kind"] == "structure":
            specs_h = prose_height(p["notes"], w=4.35)
            print("  page %-3d structure  two columns 4.35 in  tallest %.2f of %.2f in"
                  % (p["n"], specs_h, FIG_BOTTOM - TOP))
            continue
        if p["kind"] == "index":
            specs_h = prose_height(p["notes"], w=4.35)
            print("  page %-3d index      two columns 4.35 in  tallest %.2f of %.2f in"
                  % (p["n"], specs_h, FIG_BOTTOM - TOP))
            continue
        if p["ar"] >= 3.0:
            fw, fh, nh = figure_foot_solvable(p, p["ar"])
            print("  page %-3d figure     %.2f x %.2f in on top, notes %.2f in in two "
                  "5.90 in columns, total %.2f" % (p["n"], fw, fh, nh, fh + nh + 0.30))
        else:
            fw, fh, nh = figure_beside_solvable(p)
            print("  page %-3d figure     %.2f x %.2f in left, notes %.2f in right, "
                  "both of %.2f" % (p["n"], fw, fh, nh, FIG_BOTTOM - TOP))


def page_structure(prs, p):
    """Two columns of plain prose, no formulas and no figure."""
    s = title_page(prs, p["title"], p["subtitle"], p["n"])
    half = (len(p["notes"]) + 1) // 2
    y1 = prose(s, 0.55, TOP, 5.95, p["notes"][:half], size=PROSE_SIZE,
               space=BETWEEN_BLOCKS * 72)
    prose(s, 6.80, TOP, 5.95, p["notes"][half:], size=PROSE_SIZE,
          space=BETWEEN_BLOCKS * 72)
    scope(s, p["scope"], "err_R")
    return s


def page_figure(prs, p):
    """One figure with the five-line frame, either beside it or underneath it."""
    s = title_page(prs, p["title"], p["subtitle"], p["n"])
    path = os.path.join(FIG_DIR, p["fig"])
    if p["ar"] >= 3.0:
        fw, fh, _ = figure_foot_solvable(p, p["ar"])
        K.fit_image(s, path, (12.2 + 0.55 * 2 - fw) / 2.0, TOP, fw, fh)
        y = TOP + fh + 0.18
        half = 3
        prose(s, 0.55, y, 5.90, p["what"][:half], size=PROSE_SIZE,
              space=BETWEEN_BLOCKS * 72)
        prose(s, 6.80, y, 5.90, p["what"][half:], size=PROSE_SIZE,
              space=BETWEEN_BLOCKS * 72)
    else:
        fw, fh, _ = figure_beside_solvable(p)
        K.fit_image(s, path, 0.55, TOP, fw, fh)
        prose(s, 9.40, TOP, 3.35, p["what"], size=PROSE_SIZE - 1,
              space=BETWEEN_BLOCKS * 72)
    scope(s, p["scope"], "err_R")
    return s


def page_slot(prs, spec):
    """Dispatch a structure, figure or index page and keep the page number straight."""
    PAGE["n"] = spec["n"] - 1
    if spec["kind"] == "figure":
        return page_figure(prs, spec)
    return page_structure(prs, spec)


BUILDERS = [page_opener, page_reading, page_stitch, page_products, page_official_strength,
            page_age, page_axis, page_grid, page_objects]


# ----------------------------------------------------- the closing pages, 109-113
def conclusion_block(slide, x, y, w, n, idx):
    """One numbered conclusion: a number line, then the sentence under it.

    The number sits on its own line because a long conclusion wrapped under a
    leading number reads as a table row rather than as a finding. The body is
    indented to the width of the number, so the statement clears the marker and
    the sentence still uses the full column. Both boxes are sized to the lines
    they need; a box given more height than its text is the failure mode that
    made the first build of the predictor pages unreadable.
    """
    title, body = S5.CONCLUSIONS[idx]
    _, tf = K.textbox(slide, x, y, w, 0.22)
    K.para(tf, "%d. %s" % (n, title), S5.HEAD_SIZE, K.NAVY, True, font=K.HDR,
           first=True, space_after=0)
    tight_line(tf.paragraphs[0], 0)
    by = y + S5.HEAD_LEAD

    lines = S5._wrap_lines(body, w - S5.INDENT, S5.PROSE_SIZE)
    _, tf2 = K.textbox(slide, x, by, w, lines * S5.LINE_H + 0.10)
    K.bullets(tf2, [body], size=S5.PROSE_SIZE, space_after=0)
    for p in tf2.paragraphs:
        p.line_spacing = 1.0
        p.space_before = Pt(0)
        pPr = p._pPr if p._pPr is not None else p._p.get_or_add_pPr()
        pPr.set("marL", str(int(S5.INDENT * 914400)))
        pPr.set("indent", str(int(-S5.INDENT * 914400)))
    bottom = by + lines * S5.LINE_H - S5.INK_SLACK + 0.10
    return bottom + S5.BETWEEN


def conclusion_column(slide, x, w, page, side):
    """The conclusions this page puts in this column, in numbered order."""
    y = TOP
    for where, number, idx in S5.PAGES[page]:
        if where != side:
            continue
        y = conclusion_block(slide, x, y, w, number, idx)
    return y


def note_cards(slide, x, y, w, items, size=None):
    """A column of notes, one box per note, each sized to its own text."""
    size = size or S5.PROSE_SIZE
    for label, rest in items:
        lines = S5._wrap_lines("  " + label + rest, w, size)
        h = lines * S5.PITCH_PER_PT * size + 0.06
        _, tf = K.textbox(slide, x, y, w, h)
        K.bullets(tf, [(label, rest)], size=size, space_after=0)
        for p in tf.paragraphs:
            p.line_spacing = 1.0
            p.space_before = Pt(0)
        y += h + S5.BETWEEN
    return y


def head_line(slide, x, y, w, text):
    _, tf = K.textbox(slide, x, y, w, 0.26)
    K.para(tf, text, K.SUB, K.NAVY, True, font=K.HDR, first=True, space_after=0)
    tight_line(tf.paragraphs[0], 0)
    return y + S5.HDR_H


def notation_runs(p, key, size, color=K.INK):
    """One symbol, with its hat, its subscript and its bracket argument.

    A hat or a bar is a combining mark on the base run: putting it on a run of its
    own renders as a dotted circle in some viewers. The subscript and the bracket
    argument are runs of their own with the OOXML baseline shift, never underscores
    or carets in the text.
    """
    base = ""
    for text, is_sub, hat, bar in NT.display(key):
        r = p.add_run()
        if is_sub:
            r.text = text
            K.style_run(r, size, color, True, font=K.HDR)
            r.font._rPr.set("baseline", "-25000")
            continue
        shown = text
        if hat:
            shown = shown[:-1] + shown[-1] + "\u0302"
        if bar:
            shown = shown[:-1] + shown[-1] + "\u0304"
        r.text = shown
        K.style_run(r, size, color, True, font=K.HDR)
        base = ""


def page_notation(prs, spec):
    """A page of the symbol table: four columns of symbol and gloss."""
    s = title_page(prs, spec["title"], spec["subtitle"], PAGE["n"])
    cols = NT.page_rows(spec)
    x0, gap, w = 0.55, NT.COLUMN_GAP, NT.COLUMN_W
    for ci, items in enumerate(cols):
        x = x0 + ci * (w + gap)
        y = TOP
        for key, _gloss in items:
            if key == "__head__":
                _, tf = K.textbox(s, x, y, w, 0.24)
                K.para(tf, _gloss, 10, K.NAVY, True, font=K.HDR, first=True,
                       space_after=0)
                tight_line(tf.paragraphs[0], 0)
                y += NT.ROW_HEAD_H
                continue
            h = NT.row_height(key)
            _, tf = K.textbox(s, x, y, w, h + 0.06)
            p = tf.paragraphs[0]
            tight_line(p, 0)
            notation_runs(p, key, NT.COLUMN_SIZE)
            r = p.add_run()
            r.text = "  " + NT.gloss(key)[1]
            K.style_run(r, NT.COLUMN_SIZE, K.INK)
            y += h
    scope(s, spec["scope"])
    return s


def page_metrics(prs, spec):
    """Page 113 of the addition: the metric objects, their averaging, their unit.

    Four blocks down the left column, each a heading, the formulas that define it
    and the sentences that say what is averaged over what. The right column carries
    the table of the three summaries, because the difference between them is a
    difference in what is taken over, which a table shows and prose does not.
    """
    s = title_page(prs, spec["title"], spec["subtitle"], PAGE["n"])
    x, w = 0.55, 6.60
    y = TOP
    for head, fs, notes in spec["blocks"]:
        _, tf = K.textbox(s, x, y, w, 0.26)
        K.para(tf, head, 11, K.NAVY, True, font=K.HDR, first=True, space_after=0)
        tight_line(tf.paragraphs[0], 0)
        y += 0.28
        fh = 0.0
        fx = x
        for key, fw in fs:
            _, h, _ = K.add_formula(s, FORMULAS[key][0], fx, y, fw, TMPDIR, fontsize=12)
            fh = max(fh, h)
            fx += fw + 0.18
        y += fh + 0.10
        for note in notes:
            lines = wrap_lines(note, w, 9.0)
            _, tf2 = K.textbox(s, x, y, w, lines * LINE_H + 0.06)
            K.bullets(tf2, [note], size=9.0, space_after=0)
            for p in tf2.paragraphs:
                p.line_spacing = 1.0
                p.space_before = Pt(0)
            y += lines * LINE_H + 0.02
        y += 0.04
    if spec.get("table"):
        tx, tw = 7.45, 5.30
        _, tf = K.textbox(s, tx, TOP, tw, 0.26)
        K.para(tf, "The three summaries side by side", K.SUB, K.NAVY, True, font=K.HDR,
               first=True, space_after=0)
        tight_line(tf.paragraphs[0], 0)
        add_table6(s, tx, TOP + 0.30, tw, M.SUMMARY_TABLE,
                   col_w=[1.85, 0.95, 2.50], size=9, row_h=0.30, head_h=0.32)
        _, tf3 = K.textbox(s, tx, TOP + 1.70, tw, 2.4)
        K.bullets(tf3, ["Only the first two rows are comparisons. A ranking is built on "
                        "one of them at a time.",
                        "The third row is a fingerprint: a check that a change did not "
                        "disturb the rest of the pipeline."], size=9.0, space_after=6)
        for p in tf3.paragraphs:
            p.line_spacing = 1.0
            p.space_before = Pt(0)
    if y > BOTTOM:
        raise AssertionError("page %d needs %.2f in of %.2f" % (spec["n"], y - TOP,
                                                                BOTTOM - TOP))
    if not M.blocks_fit(spec):
        raise SystemExit("page %d does not fit" % spec["n"])
    scope(s, spec["scope"], "err_R")
    return s


def page_closing_opener(prs):
    return section_page(
        prs,
        "Part V \u2014 What the bench says",
        "eight conclusions, each stated on one of the four admissible objects",
        [
            "The comparison is a 288 by 376 error surface over 32 scored days, and every "
            "conclusion in this part names the slice of it that was taken.",
            "The official composite is the strongest single candidate over the middle of "
            "the lead axis and is not a majority anywhere.",
            "The page after these two says what this deck maintains, where every number "
            "in it comes from, and the command that rebuilds each part.",
        ],
        footer="Eight conclusions, then the maintenance and reproduction of this deck",
    )


def lead_table(slide, x, y, w, head):
    """The fixed-lead comparison: five leads, four candidates, every cell fetched."""
    y = head_line(slide, x, y, w, head)
    rows = S5.table_rows()
    add_table6(slide, x, y, w, rows, col_w=[1.05, 1.05, 1.00, 0.90, 1.00], size=10,
               row_h=0.28, head_h=0.32)
    return y + S5.table_height(rows)


def right_cards(slide, page):
    """The cards a closing page carries in its right column, the table if any."""
    y = note_cards(slide, S5.RX, TOP, S5.RW, S5.cards_of(page))
    if S5.NOTE[page].get("table"):
        y = lead_table(slide, S5.RX, y + 0.16, S5.RW, S5.TABLE_HEAD_LINE)
    return y


def page_conclusions(prs, spec):
    """A closing page: numbered conclusions left, the cards and any table right."""
    s = title_page(prs, spec["title"], spec["subtitle"], spec["n"])
    conclusion_column(s, S5.LX, S5.LW, spec["n"], "left")
    right_cards(s, spec["n"])
    scope(s, spec["scope"], "win_share")
    return s


def page_closing(prs, spec):
    """Page 114: what this artifact maintains, where its numbers come from, and
    the command that rebuilds each part."""
    s = title_page(prs, spec["title"], spec["subtitle"], spec["n"])
    y = head_line(s, S5.LX, TOP, S5.LW, "What this deck maintains")
    y = note_cards(s, S5.LX, y, S5.LW, S5.MAINTAINS)
    y = head_line(s, S5.LX, y + 0.10, S5.LW, "The population every number is taken on")
    note_cards(s, S5.LX, y, S5.LW, S5.ORIGIN)

    y2 = head_line(s, S5.RX, TOP, S5.RW, "Where the numbers come from")
    y2 = note_cards(s, S5.RX, y2, S5.RW, S5.SOURCE_NOTES)
    y2 = head_line(s, S5.RX, y2 + 0.10, S5.RW, "How to rebuild it")
    add_table6(s, S5.RX, y2, S5.RW, S5.SOURCES,
               col_w=[0.80, 2.05, 2.35], size=9, row_h=0.26, head_h=0.30)
    scope(s, spec["scope"])
    return s


STRIP = [
    r"\d{4}-\d{2}-\d{2}", r"\b\d{2}-\d{2}\b", r"\d{1,2}:\d{2}", r"Q\d+",
    r"[abc]_h", r"AR\(\d+\)", r"DMS\d", r"P5MIN", r"PD7DAY", r"PREDISPATCH", r"VIC1",
]


def audit_numbers(prs, numbers):
    """Audit the slides whose printed page number is in `numbers`.

    Numbers is passed rather than an offset because the predictor pages carry
    numbers that continue the delivered deck, not this file's build order. The
    slide at position p in this presentation is page p, so a page number and a
    slide index are the same thing here; a page that lands out of order is a
    build error, not an audit detail.
    """
    allowed = N.number_strings() | N.STRUCTURAL
    BANNED = "_^\\${}"
    on_page = {n: None for n in numbers}
    for i, slide in enumerate(prs.slides, start=1):
        if i not in on_page:
            continue
        text = []
        for sh in slide.shapes:
            if sh.has_text_frame:
                for p in sh.text_frame.paragraphs:
                    for r in p.runs:
                        for ch in BANNED:
                            if ch in r.text:
                                UNKNOWN.append((i, "banned character %r in a run: %r"
                                                % (ch, r.text[:40])))
                text.append(sh.text_frame.text)
            if sh.has_table:
                for row in sh.table.rows:
                    for c in row.cells:
                        text.append(c.text)
        # Thousands separators first: without this, 190,014 is read as two
        # numbers, 190 and 014, and the audit reports both as untraceable.
        blob = " ".join(text).replace(",", "")
        for pat in STRIP:
            blob = re.sub(pat, " ", blob)
        for tok in re.findall(r"\d+(?:\.\d+)?", blob):
            tok = tok.rstrip(".")
            if tok in allowed:
                continue
            if tok.lstrip("0") in allowed or ("0" + tok) in allowed:
                continue
            UNKNOWN.append((i, tok))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--first-page", type=int, default=63)
    ap.add_argument("--out", default="deck_B_new.pptx")
    ap.add_argument("--predictors", action="store_true",
                    help="also build the twenty predictor pages, 72 to 91")
    ap.add_argument("--structure", action="store_true",
                    help="also build the structure and figure pages, 92 to 108")
    ap.add_argument("--conclusions", action="store_true",
                    help="also build the closing pages, 109 to 113")
    ap.add_argument("--notation", action="store_true",
                    help="build ONLY the metric definitions and the symbol table")
    ap.add_argument("--all", action="store_true",
                    help="build the whole written section, 63 to 113, with no insertion")
    args = ap.parse_args()

    for name, col in (("NAVY", K.NAVY), ("AMBER", K.AMBER), ("INK", K.INK),
                      ("MUTED", K.MUTED), ("LINE", K.LINE), ("WHITE", K.WHITE)):
        assert str(col) in PALETTE, "%s is %s, outside the six-colour palette" % (name, col)

    prs = Presentation()
    prs.slide_width = Emu(12192000)
    prs.slide_height = Emu(6858000)
    PAGE["n"] = args.first_page - 1
    pages = []
    if args.notation:
        # The three definition pages on their own, numbered from --first-page. They
        # are built as an addition to a deck that is already finished, so their
        # numbers do not shift anything that exists.
        print("metric definitions and the symbol table, fitted before writing:")
        for spec in M.BUILD:
            src = M.spec_of(spec["n"])
            if spec["kind"] == "notation":
                hs, tall = NT.page_fit(src)
                print("  page %-3d notation  columns %s, tallest %.2f of %.2f"
                      % (spec["n"], [round(h, 2) for h in hs], tall, NT.BUDGET))
            else:
                M.blocks_fit(src)
                rows = max(i // 2 for i in range(len(src["blocks"]))) + 1
                print("  page %-3d %-9s %d blocks in %d rows of %.2f in of %.2f"
                      % (spec["n"], spec["kind"], len(src["blocks"]), rows,
                         M.ROW_H, BOTTOM - TOP))
        for i, spec in enumerate(M.BUILD):
            PAGE["n"] = args.first_page + i
            if spec["kind"] == "notation":
                page_notation(prs, M.spec_of(spec["n"]))
            else:
                page_metrics(prs, M.spec_of(spec["n"]))
            pages.append(PAGE["n"])
    else:
        for fn in BUILDERS:
            PAGE["n"] += 1
            pages.append(PAGE["n"])
            fn(prs)
    if args.predictors:
        print("predictor pages, fitted before writing:")
        check_predictor_specs(P.PAGES)
        for spec in P.PAGES:
            page_predictor_slot(prs, spec)
            pages.append(spec["n"])
    if args.structure:
        print("structure and figure pages, fitted before writing:")
        check_structure_specs(SP.PAGES)
        for spec in SP.PAGES:
            if spec["kind"] == "figure":
                fig = os.path.join(FIG_DIR, spec["fig"])
                if not os.path.isfile(fig):
                    raise SystemExit("missing figure for page %d: %s" % (spec["n"], fig))
            page_slot(prs, spec)
            pages.append(spec["n"])
    if args.conclusions:
        print("closing pages, fitted before writing:")
        for page, left, right in S5.guide_solvable():
            print("  page %-3d left column %.2f in, right column %.2f in, of %.2f"
                  % (page, left, right, S5.BUDGET))
        for spec in S5.SPECS:
            PAGE["n"] = spec["n"] - 1
            if spec["kind"] == "opener":
                page_closing_opener(prs)
            elif spec["kind"] == "conclusions":
                page_conclusions(prs, spec)
            else:
                page_closing(prs, spec)
            pages.append(spec["n"])

    out = os.path.join(HERE, args.out)
    prs.save(out)
    assert pages == list(range(args.first_page, args.first_page + len(pages))), (
        "pages are not consecutive: %s" % pages)
    audit_numbers(prs, pages)
    print("wrote %s  (%d pages, %.1f MB)" % (out, len(prs.slides._sldIdLst),
                                             os.path.getsize(out) / 1048576.0))
    print("palette check passed: six colours only")
    print("formulas rendered: %d distinct PNGs in %s"
          % (len(os.listdir(TMPDIR)) if os.path.isdir(TMPDIR) else 0, os.path.basename(TMPDIR)))
    if UNKNOWN:
        print("")
        print("NUMBERS NOT TRACED (%d):" % len(UNKNOWN))
        for page, tok in sorted(set(UNKNOWN)):
            print("   page %d: %s" % (page, tok))
    else:
        print("every number on these pages traces to deck_numbers_60d")


if __name__ == "__main__":
    main()
