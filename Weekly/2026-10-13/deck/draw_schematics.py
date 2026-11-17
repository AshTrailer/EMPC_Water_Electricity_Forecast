# -*- coding: utf-8 -*-
"""The two schematics the new section needs, drawn in the deck's six colours.

  s1_official_chain.png  the three official products: what each one declares,
                         how often it is published, and what the composite
                         actually manages to fill along the lead axis
  s2_reading_grid.png    the four admissible comparison objects, drawn on the
                         same 288 x 376 grid

Both are drawn here rather than in Predicitor/report_figures.m: the predictor
figure pipeline is frozen and these are deck furniture, not analysis.

All annotation is placed in AXES coordinates at fixed fractions, because data
coordinates on a log lead axis put the labels on top of the bars. The first
version of this file had the PD7DAY label printed across its own bar and all
four grid captions outside their axes, which is why the placement is now
fractional.

Run: python draw_schematics.py
"""

import json
import os
import sys

os.environ.setdefault("MPLCONFIGDIR", os.path.join(os.path.dirname(os.path.abspath(__file__)), "_mplcache"))
import matplotlib                        # noqa: E402
matplotlib.use("Agg")
import matplotlib.pyplot as plt          # noqa: E402
import numpy as np                       # noqa: E402
from matplotlib.patches import Rectangle  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "schematics")

INK = "#1B2430"
NAVY = "#1E2761"
AMBER = "#E9A820"
MUTED = "#5A6B7B"
LINE = "#C9D4DE"
GREY = "#7C8AA8"
WHITE = "#FFFFFF"

plt.rcParams.update({
    "font.family": "Calibri",
    "text.color": INK,
    "axes.labelcolor": INK,
    "axes.edgecolor": LINE,
    "xtick.color": MUTED,
    "ytick.color": MUTED,
    "axes.titlesize": 10,
    "axes.titlecolor": NAVY,
    "axes.titleweight": "bold",
    "font.size": 8.5,
    "figure.facecolor": WHITE,
})

LEAD_MIN = np.concatenate([np.arange(5, 56, 5), np.arange(60, 10981, 30)])
assert LEAD_MIN.size == 376, LEAD_MIN.size


def with_numbers():
    with open(os.path.join(HERE, "deck_numbers_60d.json"), encoding="utf-8") as fh:
        return json.load(fh)


def lead_ticks(ax):
    ticks = [5, 60, 360, 1440, 4320, 10980]
    labels = ["5 min", "1 h", "6 h", "24 h", "3 d", "183 h"]
    ax.set_xscale("log")
    ax.set_xticks(ticks)
    ax.set_xticklabels(labels)
    ax.set_xlim(4, 15000)


def s1_chain(num):
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(11.6, 3.6), sharex=True,
                                   gridspec_kw={"height_ratios": [1.0, 1.05]})
    fig.subplots_adjust(left=0.105, right=0.995, top=0.86, bottom=0.115, hspace=0.40)

    ax1.set_title("what each product declares, and how often it is published", loc="left", pad=4)
    lead_ticks(ax1)
    ax1.set_ylim(0, 4.05)
    for s in ("top", "right", "left"):
        ax1.spines[s].set_visible(False)
    ax1.grid(axis="x", color=LINE, lw=0.6)
    ax1.set_axisbelow(True)

    # Rows are named by the y tick labels, which sit outside the axes, and each
    # row's wording goes ABOVE its own bar. Placing the wording on the bar put
    # the PD7DAY line across a full-width navy rectangle in the first version,
    # and putting two wordings on one row printed one over the other.
    rows = [
        (2.90, 5, 55, NAVY, "12 columns, published every 5 minutes, forwards to 55 minutes"),
        (1.70, 60, 930, NAVY, "to 15.5 h guaranteed, and to 39.0 h when the run's horizon is long"),
        (1.70, 930, 2340, LINE, None),
        (0.55, 60, 10980, NAVY, "three runs a day at 07:30, 13:00 and 18:00, forwards to 183.0 h"),
    ]
    for y, lo, hi, col, _ in rows:
        ax1.add_patch(Rectangle((lo, y), hi - lo, 0.34, facecolor=col, edgecolor="none"))
    for y, lo, hi, col, text in rows:
        if text:
            ax1.text(0.012, y + 0.40, text, transform=ax1.get_yaxis_transform(),
                     fontsize=8.5, color=INK, va="bottom", ha="left")
    ax1.set_yticks([3.07, 1.87, 0.72])
    ax1.set_yticklabels(["P5MIN", "PREDISPATCH", "PD7DAY"], fontsize=9, color=NAVY)
    for lab in ax1.get_yticklabels():
        lab.set_fontweight("bold")
    ax1.axvline(57.5, color=AMBER, lw=1.2, ls="--")
    ax1.text(0.012, 0.02, "column 11 | 12: the cadence changes from 5 minutes to 30 minutes",
             transform=ax1.get_yaxis_transform(), fontsize=8, color=AMBER,
             va="bottom", ha="left")

    ax2.set_title("what the composite actually fills, over the 60-day window", loc="left")
    present = np.array(num["coverage"]["present_by_lead_60d"], dtype=float)
    ax2.plot(LEAD_MIN, present, color=NAVY, lw=1.4)
    ax2.fill_between(LEAD_MIN, 0, present, color=LINE, alpha=0.5)
    ax2.set_ylim(0, 340)
    ax2.set_yticks([0, 100, 200, 300])
    ax2.set_ylabel("times of day present, of 288")
    for s in ("top", "right"):
        ax2.spines[s].set_visible(False)
    ax2.grid(axis="x", color=LINE, lw=0.6)
    ax2.set_axisbelow(True)
    ax2.annotate("every column is full out to 171 h",
                 xy=(8000, 288), xytext=(720, 300), fontsize=8.5, color=INK, va="center",
                 arrowprops=dict(arrowstyle="->", color=MUTED, lw=0.9))
    ax2.annotate("52 of 288 at 183.0 h: only runs whose own horizon\nreaches the end can serve that column",
                 xy=(10980, 52), xytext=(1900, 130), fontsize=8.5, color=INK, va="center",
                 arrowprops=dict(arrowstyle="->", color=MUTED, lw=0.9))
    lead_ticks(ax2)
    ax2.set_xlabel("forecast lead")

    out = os.path.join(OUT, "s1_official_chain.png")
    fig.savefig(out, dpi=200, facecolor=WHITE)
    plt.close(fig)
    print("wrote", out)


def s2_grid(num):
    fig = plt.figure(figsize=(8.6, 5.0))
    rows, cols = 16, 24

    def mesh(ax, title, caption):
        for r in range(rows):
            for c in range(cols):
                ax.add_patch(Rectangle((c, r), 0.94, 0.94, facecolor=LINE,
                                       edgecolor=WHITE, lw=0.4))
        ax.set_xlim(-0.6, cols + 0.6)
        ax.set_ylim(-0.6, rows + 0.6)
        ax.set_xticks([])
        ax.set_yticks([])
        for s in ("top", "right", "bottom", "left"):
            ax.spines[s].set_visible(False)
        ax.set_title(title, loc="left", pad=14)
        ax.text(0.0, 1.035, caption, transform=ax.transAxes, fontsize=8, color=MUTED,
                va="bottom", ha="left")

    def cell(ax, c, r, col):
        ax.add_patch(Rectangle((c, r), 0.94, 0.94, facecolor=col, edgecolor=WHITE, lw=0.4))

    gs = fig.add_gridspec(2, 2, hspace=0.46, wspace=0.16,
                          left=0.045, right=0.985, top=0.885, bottom=0.045)

    ax = fig.add_subplot(gs[0, 0])
    mesh(ax, "1  the whole surface  R(slot, lead)",
         "one number per cell, RMSE over the 32 scored days")
    for r in range(rows):
        for c in range(cols):
            cell(ax, c, r, NAVY)

    ax = fig.add_subplot(gs[0, 1])
    mesh(ax, "2  one lead: 288 times of day",
         "a row of R, one curve across the day")
    for c in range(cols):
        cell(ax, c, 10, AMBER)

    ax = fig.add_subplot(gs[1, 0])
    mesh(ax, "3  one time of day: 376 leads",
         "a column of R, one curve across the lead")
    for r in range(rows):
        cell(ax, 6, r, AMBER)

    ax = fig.add_subplot(gs[1, 1])
    mesh(ax, "4  a census: who wins each cell",
         "counted, never averaged, over all 108,288 cells")
    pal = [NAVY, AMBER, MUTED, INK, GREY, "#D8C08A"]
    rng = np.random.default_rng(7)
    for r in range(rows):
        for c in range(cols):
            y = r / rows
            x = c / cols
            p = np.array([0.06 + 0.50 * y, 0.09 + 0.25 * (1 - y), 0.18, 0.05, 0.08, 0.04])
            if x < 0.25:
                p = np.array([0.45, 0.13, 0.12, 0.08, 0.12, 0.10])
            p = p / p.sum()
            cell(ax, c, r, pal[rng.choice(len(pal), p=p)])

    # No figure title here: the page that carries this schematic already states
    # it, and printing it twice on one slide was the first version's defect.
    out = os.path.join(OUT, "s2_reading_grid.png")
    fig.savefig(out, dpi=200, facecolor=WHITE)
    plt.close(fig)
    print("wrote", out)


def main():
    os.makedirs(OUT, exist_ok=True)
    num = with_numbers()
    s1_chain(num)
    s2_grid(num)


if __name__ == "__main__":
    main()
