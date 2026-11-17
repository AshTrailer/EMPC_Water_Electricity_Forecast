"""Render the per-lead decay figure from diagnose_official_gap.json.

Panel A: median-over-slots RMSE against lead, official and the price-only pool.
Panel B: ratio to official, so the crossing horizon and the band gap are read directly.
"""

import json
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FixedFormatter, FixedLocator, NullLocator

HERE = os.path.dirname(os.path.abspath(__file__))
DECK = os.path.abspath(os.path.join(HERE, "..", "..", "deck"))
SRC = os.path.join(DECK, "diagnose_official_gap.json")
OUT = os.path.join(HERE, "fig_decay.png")

NAVY = "#1E2761"
AMBER = "#E9A820"
INK = "#1B2430"
MUTED = "#5A6B7B"
LINE = "#C9D4DE"

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 9,
    "axes.edgecolor": LINE,
    "axes.labelcolor": INK,
    "xtick.color": MUTED,
    "ytick.color": MUTED,
    "axes.linewidth": 0.8,
})


def load():
    d = json.load(open(SRC))
    lead = [m / 60.0 for m in d["lead_min"]]
    prof = {n: p for n, p in zip(d["model_names"], d["model_profile"])}
    return d, lead, prof


def setup(ax):
    ax.set_xscale("log")
    ax.xaxis.set_major_locator(FixedLocator([5 / 60, 0.25, 1, 2, 6, 12, 24, 48, 168]))
    ax.xaxis.set_major_formatter(
        FixedFormatter(["5m", "15m", "1h", "2h", "6h", "12h", "24h", "2d", "7d"])
    )
    ax.xaxis.set_minor_locator(NullLocator())
    ax.set_xlim(5 / 60 * 0.94, 183 * 1.25)
    ax.grid(True, which="major", axis="y", color=LINE, lw=0.7, alpha=0.9)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    ax.axvline(2, color=MUTED, lw=0.9, ls=(0, (5, 3)), zorder=1)
    ax.axvline(37.5, color=MUTED, lw=0.9, ls=(0, (5, 3)), zorder=1)


def main():
    d, lead, prof = load()
    off = d["official_profile"]
    env = [min(prof[n][i] for n in prof) for i in range(len(lead))]
    band = d["band_6_24h"]
    b_lo, b_hi = lead[band[0] - 1], lead[band[-1] - 1]

    fig, (ax1, ax2) = plt.subplots(
        1, 2, figsize=(12.4, 4.6), gridspec_kw={"wspace": 0.20}
    )

    for ax in (ax1, ax2):
        setup(ax)
        ax.axvspan(b_lo, b_hi, color=AMBER, alpha=0.11, lw=0, zorder=0)

    ax1.plot(lead, off, color=AMBER, lw=3.0, label="Official AEMO", zorder=6)
    ax1.plot(lead, prof["Anchor-mix"], color=NAVY, lw=2.3, label="Anchor-mix", zorder=5)
    ax1.plot(lead, env, color=INK, lw=1.9, ls=(0, (4, 2)), label="Best of 16 (hindsight)", zorder=4)
    ax1.plot(lead, prof["Template T28"], color=MUTED, lw=1.4, label="Template T28 (climatology)", zorder=3)
    ax1.plot(lead, prof["Persistence(yest)"], color=MUTED, lw=1.2, ls=":", label="Persistence", zorder=3)

    ax1.set_ylabel("median over 288 slots of R(s, h)  [$/MWh]")
    ax1.set_xlabel("lead time")
    ax1.set_title("A. Error against lead", loc="left", color=INK, fontsize=10.5, pad=9)
    ax1.set_ylim(10, 80)
    ax1.legend(frameon=False, fontsize=8, loc="lower right", handlelength=2.4,
               labelspacing=0.45, borderaxespad=0.8)
    ax1.text(2.15, 77, "2 h", color=MUTED, fontsize=7.5, ha="left", va="center")
    ax1.text(39, 77, "37.5 h", color=MUTED, fontsize=7.5, ha="left", va="center")
    ax1.text(6.3, 72.5, "6-24 h band", color=AMBER, fontsize=7.5, ha="left",
             va="center", fontweight="bold")

    ratio = lambda p: [p[i] / off[i] for i in range(len(lead))]  # noqa: E731
    for n in prof:
        ax2.plot(lead, ratio(prof[n]), color=MUTED, lw=0.7, alpha=0.42, zorder=2)
    ax2.plot(lead, ratio(env), color=INK, lw=2.0, ls=(0, (4, 2)), zorder=4,
             label="Best of 16 (hindsight)")
    ax2.plot(lead, ratio(prof["Anchor-mix"]), color=NAVY, lw=2.3, zorder=5,
             label="Anchor-mix")
    ax2.axhline(1.0, color=AMBER, lw=2.4, zorder=6, label="parity with official")

    ax2.yaxis.set_major_locator(FixedLocator([0.8, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0]))
    ax2.yaxis.set_major_formatter(
        FixedFormatter(["0.8", "1.0", "1.25", "1.5", "2.0", "2.5", "3.0"])
    )
    ax2.yaxis.set_minor_locator(NullLocator())
    ax2.set_ylim(0.75, 3.05)
    ax2.set_ylabel("ratio to official   (below 1.0 = we win)")
    ax2.set_xlabel("lead time")
    ax2.set_title("B. Ratio to official, all 16 predictors", loc="left", color=INK,
                  fontsize=10.5, pad=9)
    ax2.legend(frameon=False, fontsize=8, loc="upper left", handlelength=2.4,
               labelspacing=0.45, borderaxespad=0.8)
    ax2.text(0.088, 1.03, "we win", color=AMBER, fontsize=7.5, ha="left", va="bottom")
    ax2.text(2.15, 2.98, "2 h", color=MUTED, fontsize=7.5, ha="left", va="center")
    ax2.text(39, 2.98, "37.5 h", color=MUTED, fontsize=7.5, ha="left", va="center")

    fig.subplots_adjust(left=0.058, right=0.985, top=0.90, bottom=0.135)
    fig.savefig(OUT, dpi=220, facecolor="white")
    print(OUT)
    print("band %.2f .. %.2f h" % (b_lo, b_hi))
    print("band ratio median %.3f" % sorted(ratio(env)[band[0] - 1:band[-1]])[len(band) // 2])


if __name__ == "__main__":
    main()
