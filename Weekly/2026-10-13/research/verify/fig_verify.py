"""Render the two D-stage verification figures from the JSON the MATLAB probes write.

Figure 1 (fig_d08_bias.png)
  A  mean signed error by target time of day over the 6 to 24 hour band, with the
     10 $/MWh threshold of the D08 criterion drawn. A bias worth an anchor change
     would leave that corridor.
  B  for the anchor model, the same bias read against the night error it sits in:
     the share of night mean squared error a bias removal could take out.

Figure 2 (fig_d10_sources.png)
  A  distribution of the official value within each supplying product, on the scale
     of the realised price. Anything far right of that range is not a price
     forecast, and only the clamp keeps it from setting the benchmark's scale.
  B  the products' share of the band against their share of the cap-scale cells.
"""

import json
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import Patch

HERE = os.path.dirname(os.path.abspath(__file__))
D08 = os.path.join(HERE, "d10_d08.json")
SRC = os.path.join(HERE, "official_sources.json")

NAVY = "#1E2761"
AMBER = "#E9A820"
RED = "#B5322E"
TEAL = "#2A7F73"
INK = "#1B2430"
MUTED = "#5A6B7B"
LINE = "#C9D4DE"
BAND = "#EEF2F6"

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 9,
    "axes.edgecolor": LINE,
    "axes.labelcolor": INK,
    "xtick.color": MUTED,
    "ytick.color": MUTED,
    "axes.linewidth": 0.8,
})


def frame(ax):
    ax.grid(True, which="major", axis="y", color=LINE, lw=0.7, alpha=0.9)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)


def fig_d08():
    d = json.load(open(D08))
    hour = d["clock_hour"]
    names = d["bias_model_names"]
    series = [("official", d["bias_slot_official"], AMBER, 1.9)]
    cols = [NAVY, TEAL, RED]
    for i, n in enumerate(names):
        series.append((n, d["bias_slot_models"][i], cols[i], 1.4))

    fig, (ax1, ax2) = plt.subplots(
        1, 2, figsize=(12.4, 4.8), gridspec_kw={"wspace": 0.28, "width_ratios": [1.55, 1.0]}
    )

    ax1.axvspan(0, 6, color=BAND, zorder=0)
    ax1.axhline(10, color=RED, lw=0.9, ls=(0, (5, 3)))
    ax1.axhline(-10, color=RED, lw=0.9, ls=(0, (5, 3)))
    ax1.axhline(0, color=MUTED, lw=0.8)
    for label, y, c, lw in series:
        ax1.plot(hour, y, color=c, lw=lw, label=label)
    ax1.set_xlim(0, 24)
    ax1.set_ylim(-52, 46)
    ax1.set_xticks([0, 4, 8, 12, 16, 20, 24])
    ax1.set_xlabel("target time of day, hours (NEM)")
    ax1.set_ylabel("mean signed error, actual minus forecast, $/MWh")
    ax1.set_title(
        "A  level error by target time of day, leads 6 to 24 h", loc="left", fontsize=10
    )
    ax1.text(3.0, 43.0, "night", color=MUTED, fontsize=8.5, ha="center")
    handles, labels = ax1.get_legend_handles_labels()
    handles.append(Line2D([0], [0], color=RED, lw=0.9, ls=(0, (5, 3))))
    labels.append("D08 threshold, plus and minus 10")
    ax1.legend(
        handles, labels, loc="lower left", frameon=True, framealpha=0.96,
        edgecolor=LINE, facecolor="white", fontsize=8, ncol=1,
    )
    frame(ax1)

    lead = [d["lead_min"][k - 1] / 60.0 for k in d["band"]]
    bias = d["night_bias_by_lead"]
    rms = d["night_rms_by_lead"]
    share = [100.0 * (b / r) ** 2 if r else 0.0 for b, r in zip(bias, rms)]

    ax2.axhline(0, color=MUTED, lw=0.8)
    ax2.plot(lead, bias, color=NAVY, lw=1.7, label="night bias, $/MWh")
    ax2.axhline(10, color=RED, lw=0.9, ls=(0, (5, 3)))
    ax2.set_xlim(6, 24)
    ax2.set_ylim(-1.5, 13.0)
    ax2.set_xticks([6, 10, 14, 18, 22])
    ax2.set_xlabel("lead, hours")
    ax2.set_ylabel("night bias, $/MWh")
    ax2.set_title(
        "B  anchor model: the bias against the error it sits in", loc="left", fontsize=10
    )

    ax3 = ax2.twinx()
    ax3.plot(lead, share, color=TEAL, lw=1.3, ls=(0, (4, 2)),
             label="share of night MSE, %")
    ax3.set_ylim(0, 4.5)
    ax3.set_ylabel("share of night MSE a bias fix removes, %", color=TEAL, labelpad=7)
    ax3.tick_params(axis="y", colors=TEAL)
    ax3.spines["top"].set_visible(False)
    h2, l2 = ax2.get_legend_handles_labels()
    h3, l3 = ax3.get_legend_handles_labels()
    ax2.legend(h2 + h3, l2 + l3, loc="upper left", frameon=True, framealpha=0.96,
               edgecolor=LINE, facecolor="white", fontsize=8)
    ax2.text(12.4, 10.8, "criterion 10", color=RED, fontsize=7.5, ha="center")
    frame(ax2)

    fig.savefig(os.path.join(HERE, "fig_d08_bias.png"), dpi=220, bbox_inches="tight")
    plt.close(fig)


def fig_d10():
    d = json.load(open(SRC))
    edges = d["hist_edges"]
    names = d["source_names"]
    cells = d["band_source_cells"]
    over = d["band_above_5000"]
    mid = [(edges[i] * edges[i + 1]) ** 0.5 for i in range(len(edges) - 1)]
    lo, hi = d["actual_min"], d["actual_max"]

    fig, (ax1, ax2) = plt.subplots(
        1, 2, figsize=(12.4, 4.8), gridspec_kw={"wspace": 0.26, "width_ratios": [1.6, 1.0]}
    )

    ax1.axvspan(max(lo, 0.9), hi, color=BAND, zorder=0)
    style = {"PREDISPATCH": NAVY, "PD7DAY": RED, "P5MIN": TEAL}
    colours = [style.get(n, MUTED) for n in names]
    bottom = [0.0] * (len(edges) - 1)
    for i, n in enumerate(names):
        c = d["hist_counts"][i]
        if sum(c) == 0:
            continue
        ax1.bar(mid, c, width=[0.92 * (edges[j + 1] - edges[j]) for j in range(len(mid))],
                bottom=bottom, color=colours[i], label=n, linewidth=0)
        bottom = [b + v for b, v in zip(bottom, c)]
    ax1.axvline(5000, color=RED, lw=0.9, ls=(0, (5, 3)))
    ax1.set_xscale("log")
    ax1.set_yscale("log")
    ax1.set_xlim(1, 30000)
    ax1.set_ylim(0.7, 1.6e5)
    ax1.set_xlabel("absolute value of the official figure, $/MWh, log scale")
    ax1.set_ylabel("band cells, log scale")
    ax1.set_title(
        "A  what the official figure looks like, by supplying product", loc="left",
        fontsize=10,
    )
    ax1.legend(loc="upper left", frameon=True, framealpha=0.96, edgecolor=LINE,
               facecolor="white", fontsize=8)
    ax1.text(
        300, 1.15e5,
        "realised price\n%.0f to %.0f $/MWh" % (lo, hi),
        color=MUTED, fontsize=7.5, ha="right", va="top",
    )
    ax1.text(4300, 3.0e4, "5000", color=RED, fontsize=7.5, ha="right")
    frame(ax1)

    # Panel B: two 100 per cent bars, the band and the cap-scale subset.
    keep = [i for i, n in enumerate(names) if n != "none" and cells[i] > 0]
    labels = [names[i] for i in keep]
    tot_c = sum(cells[i] for i in keep)
    tot_o = sum(over[i] for i in keep)
    rows = [
        ("band cells", [100.0 * cells[i] / tot_c for i in keep]),
        ("cells above\n5000 $/MWh", [100.0 * over[i] / tot_o for i in keep]),
    ]
    colours = [NAVY, RED]
    for r, (name, vals) in enumerate(rows):
        left = 0.0
        for i, v in enumerate(vals):
            ax2.barh(r, v, left=left, height=0.52, color=colours[i],
                     edgecolor="white", lw=0.8)
            if v > 6:
                ax2.text(left + v / 2, r, "%.1f%%" % v, ha="center", va="center",
                         color="white", fontsize=9)
            else:
                ax2.text(left + v / 2, r - 0.40, "%.1f%%" % v, ha="center", va="center",
                         color=colours[i], fontsize=8)
            left += v
    ax2.set_yticks([0, 1])
    ax2.set_yticklabels([r[0] for r in rows], color=INK, fontsize=9)
    ax2.set_xlim(0, 100)
    ax2.set_xlabel("share, %")
    ax2.invert_yaxis()
    ax2.set_title(
        "B  share of the band against share of the cap-scale cells", loc="left",
        fontsize=10,
    )
    ax2.legend(handles=[Patch(color=colours[i], label=labels[i]) for i in range(len(keep))],
               loc="lower center", ncol=2, frameon=False, fontsize=8,
               bbox_to_anchor=(0.5, -0.30))
    ax2.grid(True, which="major", axis="x", color=LINE, lw=0.7, alpha=0.9)
    for s in ("top", "right", "left"):
        ax2.spines[s].set_visible(False)
    ax2.text(50, 1.62, "counts %s" % " / ".join(str(over[i]) for i in keep),
             ha="center", fontsize=7.5, color=MUTED)
    ax2.text(50, -0.55, "counts %s" % " / ".join(str(cells[i]) for i in keep),
             ha="center", fontsize=7.5, color=MUTED)

    fig.savefig(os.path.join(HERE, "fig_d10_sources.png"), dpi=220, bbox_inches="tight")
    plt.close(fig)


if __name__ == "__main__":
    fig_d08()
    fig_d10()
    print("wrote fig_d08_bias.png and fig_d10_sources.png")
