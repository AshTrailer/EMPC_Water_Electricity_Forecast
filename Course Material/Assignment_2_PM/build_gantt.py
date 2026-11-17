"""Build the single-page project schedule: charter baseline against actual progress.

Design goals, in the order they were set:
  one page, readable without explanation;
  baseline and actual in two distinct colours on the same row;
  milestones for both the plan and what was delivered;
  a today marker, and short annotations only where the reading is not obvious.
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.dates as mdates
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import FancyBboxPatch, Rectangle
from datetime import date

OUT = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Assignment_2_PM\gantt_v1_vs_v2.png"

INK = "#1B2430"
TITLE = "#1E2761"
MUTED = "#5A6B7B"
GRID = "#DCE3EA"
PLAN = "#B9C6D4"       # charter baseline
PLAN_EDGE = "#8B9BAE"
DONE = "#0E7C7B"       # finished
ACTIVE = "#E9A820"     # running now
TODO = "#C3CCD6"       # not started
SLIP = "#C0392B"

# name, baseline start, baseline end, actual start, actual end, state, note
ROWS = [
    ("Literature review", date(2026, 8, 7), date(2026, 8, 12),
     date(2026, 8, 7), date(2026, 8, 12), "done", ""),
    ("AEMO data collection and pipeline", date(2026, 8, 7), date(2026, 8, 14),
     date(2026, 8, 7), date(2026, 9, 15), "done", "themes ran long"),
    ("Baseline level control running", date(2026, 8, 10), date(2026, 8, 14),
     date(2026, 8, 10), date(2026, 8, 14), "done", ""),
    ("Predictor development", date(2026, 8, 17), date(2026, 8, 25),
     date(2026, 8, 17), date(2026, 9, 15), "done", "scope grew"),
    ("Predictor testing", date(2026, 8, 26), date(2026, 8, 31),
     date(2026, 8, 26), date(2026, 10, 9), "done", ""),
    ("Data and method audit", date(2026, 9, 21), date(2026, 9, 25),
     date(2026, 9, 23), date(2026, 9, 24), "done", "came forward"),
    ("MPC development", date(2026, 8, 26), date(2026, 9, 10),
     date(2026, 8, 26), date(2026, 10, 8), "done", ""),
    ("Predictor to controller link", date(2026, 9, 4), date(2026, 9, 10),
     date(2026, 10, 8), date(2026, 10, 14), "done", "delivered late"),
    ("Forecast benchmark and surfaces", date(2026, 9, 28), date(2026, 10, 9),
     date(2026, 10, 8), date(2026, 10, 15), "done", ""),
    ("Cost comparison against AEMO", date(2026, 9, 11), date(2026, 9, 21),
     date(2026, 10, 9), date(2026, 10, 16), "active", ""),
    ("Report and oral assessment", date(2026, 9, 22), date(2026, 11, 13),
     date(2026, 10, 12), date(2026, 11, 13), "active", ""),
]

PLAN_MILESTONES = [
    (date(2026, 8, 14), "baseline\noperational"),
    (date(2026, 8, 31), "predictor\nvalidated"),
    (date(2026, 9, 21), "EMPC framework\noperational"),
    (date(2026, 11, 13), "mid-semester\nreview"),
]

DONE_MILESTONES = [
    (date(2026, 10, 8), "controller built"),
    (date(2026, 10, 14), "forecaster linked"),
    (date(2026, 10, 15), "last weekly report"),
]

NOTES = {
    "AEMO data collection and pipeline": "extended to 14 months of history",
    "Predictor development": "nine predictors then twenty",
    "Predictor to controller link": "baseline ended 10 Sep, delivered 14 Oct",
    "Data and method audit": "five capture defects found and fixed",
}


def bar(ax, y, start, end, color, height=0.30, edge=None, alpha=1.0, dashed=False, zorder=3):
    left = mdates.date2num(start)
    width = max(mdates.date2num(end) - left, 1.0)
    rect = Rectangle((left, y - height / 2), width, height,
                     facecolor=color, edgecolor=edge or color, linewidth=0.8,
                     alpha=alpha, zorder=zorder)
    if dashed:
        rect.set_linestyle((0, (3, 2)))
        rect.set_facecolor("none")
        rect.set_edgecolor(edge or color)
        rect.set_linewidth(1.2)
    ax.add_patch(rect)


def main():
    fig, ax = plt.subplots(figsize=(15.2, 8.1), dpi=170)
    fig.patch.set_facecolor("white")
    ax.set_facecolor("white")

    n = len(ROWS)
    ax.set_ylim(-0.9, n - 0.1)
    ax.invert_yaxis()
    ax.set_yticks(range(n))
    ax.set_yticklabels([r[0] for r in ROWS], fontsize=10.5, color=INK)
    ax.tick_params(axis="y", length=0, pad=8)

    start = date(2026, 8, 3)
    end = date(2026, 11, 20)
    ax.set_xlim(mdates.date2num(start), mdates.date2num(end))
    ax.xaxis.set_major_locator(mdates.MonthLocator())
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%B"))
    ax.xaxis.set_minor_locator(mdates.WeekdayLocator(byweekday=mdates.MO, interval=2))
    ax.tick_params(axis="x", which="major", labelsize=11.5, colors=INK, length=0, pad=6)
    ax.tick_params(axis="x", which="minor", length=3, colors=GRID)

    for x in range(n):
        if x % 2 == 0:
            ax.axhspan(x - 0.5, x + 0.5, color="#F7F9FB", zorder=0)
    for month in (9, 10, 11):
        ax.axvline(mdates.date2num(date(2026, month, 1)), color=GRID, linewidth=0.8, zorder=1)

    for i, (name, bs, be, as_, ae, state, _) in enumerate(ROWS):
        bar(ax, i - 0.20, bs, be, PLAN, height=0.26, edge=PLAN_EDGE, zorder=3)
        if state == "done":
            bar(ax, i + 0.20, as_, ae, DONE, height=0.30, zorder=4)
        elif state == "active":
            bar(ax, i + 0.20, as_, ae, "none", height=0.30, edge=ACTIVE, dashed=True, zorder=4)
            bar(ax, i + 0.20, as_, date(2026, 10, 16), ACTIVE, height=0.30, zorder=5)
        else:
            bar(ax, i + 0.20, as_, ae, "none", height=0.30, edge=TODO, dashed=True, zorder=4)
        if as_ > be:
            days = (as_ - be).days
            ax.annotate("", xy=(mdates.date2num(as_), i + 0.20),
                        xytext=(mdates.date2num(be), i + 0.20),
                        arrowprops=dict(arrowstyle="-|>", color=SLIP, linewidth=1.0,
                                        shrinkA=1, shrinkB=1), zorder=6)
            ax.text(mdates.date2num(be) + (mdates.date2num(as_) - mdates.date2num(be)) / 2,
                    i + 0.50, f"+{days}d", fontsize=8.5, color=SLIP,
                    ha="center", va="center", zorder=7)

    for when, label in PLAN_MILESTONES:
        ax.scatter([mdates.date2num(when)], [n - 0.55], marker="D", s=62,
                   facecolor="white", edgecolor=PLAN_EDGE, linewidth=1.4, zorder=8, clip_on=False)
    for when, label in DONE_MILESTONES:
        ax.scatter([mdates.date2num(when)], [n - 0.55], marker="D", s=62,
                   facecolor=DONE, edgecolor="white", linewidth=1.0, zorder=9, clip_on=False)

    today = mdates.date2num(date(2026, 10, 16))
    ax.axvline(today, color=ACTIVE, linewidth=1.6, zorder=10)
    ax.text(today + 1.2, -0.72, "today, 16 October", fontsize=9.5, color=ACTIVE,
            fontweight="bold", va="center", zorder=11)

    for i, (name, *_rest) in enumerate(ROWS):
        note = NOTES.get(name)
        if note:
            ax.text(mdates.date2num(end) - 2, i, note, fontsize=8.5, color=MUTED,
                    ha="right", va="center", style="italic", zorder=11)

    ax.set_title("Project schedule: charter baseline against actual progress",
                 fontsize=17, color=TITLE, fontweight="bold", pad=26, loc="left", x=0.075)
    ax.text(0.075, 1.045,
            "Top bar of each row is the charter plan. Bottom bar is what was delivered. "
            "Red arrow marks a late finish.",
            transform=ax.transAxes, fontsize=10, color=MUTED)

    legend = [
        Line2D([0], [0], color=PLAN, lw=9, label="Charter baseline"),
        Line2D([0], [0], color=DONE, lw=9, label="Delivered"),
        Line2D([0], [0], color=ACTIVE, lw=9, label="In progress at 16 October"),
        Line2D([0], [0], color="none", marker="D", markersize=7, markerfacecolor="white",
               markeredgecolor=PLAN_EDGE, label="Planned milestone"),
        Line2D([0], [0], color="none", marker="D", markersize=7, markerfacecolor=DONE,
               markeredgecolor="white", label="Milestone reached"),
    ]
    ax.legend(handles=legend, loc="lower left", bbox_to_anchor=(0.075, -0.145), ncol=5,
              frameon=False, fontsize=10.5, handletextpad=0.7, columnspacing=1.6)

    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_visible(False)
    ax.spines["bottom"].set_color(GRID)

    plt.tight_layout(rect=(0, 0.035, 1, 1))
    fig.savefig(OUT, facecolor="white", bbox_inches="tight", pad_inches=0.28)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
