"""Render the E02 figure from research/verify/e02_sens.json.

A  the demand-to-price slope the ladder reports, by hour of day. It is a real
   object with a clean shape: flat and near zero through the middle of the day,
   steep at the evening peak. About a quarter of band cells read exactly zero,
   which is the region taking its price from the interconnector.
B  the same slope against our band error, column by column. It clears the 1 per
   cent gate only between six and twelve hours and is insignificant pooled.
C  what the slope adds once a demand surprise is known. Alone it is the weakest
   of the four, and in the two-regressor fit its coefficient is not significant,
   so the channel is not independent of the demand channel.
"""

import json
import os

import matplotlib
import matplotlib.colors as mcolors  # noqa: F401  (kept for the shared style)

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Patch

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "e02_sens.json")

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

with open(SRC, encoding="utf-8") as fh:
    D = json.load(fh)


def obj(x):
    """MATLAB writes a scalar struct nested in a struct as an array of objects."""
    while isinstance(x, list) and x and isinstance(x[0], dict):
        x = x[0]
    return x


if isinstance(D, list):
    D = D[0]
D = {k: obj(v) for k, v in D.items()}
print("top level:", {k: type(v).__name__ for k, v in D.items()})

b2 = obj(D["b2"])
gate = obj(D["gate"])
gcol = obj(D["gate_col"])
GATE = 0.01

fig = plt.figure(figsize=(14.6, 4.7))
gs = fig.add_gridspec(1, 3, width_ratios=[1.0, 1.55, 1.05], wspace=0.30,
                      left=0.055, right=0.985, top=0.84, bottom=0.145)

# ---- A: slope by hour of day -------------------------------------------
ax = fig.add_subplot(gs[0, 0])
med = b2["by_hour_100"]
lo = b2["by_hour_p25"]
hi = b2["by_hour_p75"]
hrs = list(range(24))
ax.fill_between(hrs, lo, hi, color=BAND, zorder=1, label="interquartile range")
ax.plot(hrs, med, color=NAVY, lw=1.9, marker="o", ms=3.2, zorder=3,
        label="median over band cells")
ax.axhline(0, color=MUTED, lw=0.7, zorder=2)
ax.set_xlim(0, 23)
ax.set_ylim(min(0, min(lo)) - 0.15, max(hi) * 1.10)
ax.set_xticks([0, 6, 12, 18, 23])
ax.set_xlabel("hour of the target, AEST")
ax.set_ylabel("$ per MWh, per 100 MW of VIC1 demand")
ax.set_title("A  the slope is a real object", fontsize=9.5, color=INK, loc="left", pad=8)
ax.legend(loc="upper left", fontsize=7.4, frameon=False)
ax.text(0.04, 0.72, "zero in %.0f%% of band cells\n(price set by the interconnector)"
        % (100.0 * b2["zero"] / b2["n"]), transform=ax.transAxes, fontsize=7.6,
        color=MUTED, va="top", linespacing=1.45)
for s in ("top", "right"):
    ax.spines[s].set_visible(False)

# ---- B: gate by column --------------------------------------------------
ax = fig.add_subplot(gs[0, 1])
lead = gcol["lead_h"]
r2b = gcol["r2_b2"]
r2c = gcol["r2_curv"]
ax.axhspan(0, GATE, color=BAND, zorder=0)
ax.plot(lead, r2b, color=NAVY, lw=1.6, marker="o", ms=2.6, zorder=4,
        label="slope at the operating point")
ax.plot(lead, r2c, color=AMBER, lw=1.3, marker="s", ms=2.2, zorder=3,
        label="up side curvature")
ax.axhline(GATE, color=RED, lw=1.0, ls=(0, (5, 3)), zorder=5)
ax.text(lead[-1], GATE, "gate 1%", color=RED, fontsize=8, va="bottom", ha="right")
top = max(max(r2b), max(r2c)) * 1.18
ax.set_ylim(0, max(top, GATE * 4.2))
ax.set_xlim(lead[0], lead[-1])
ax.set_xlabel("lead (hours)")
ax.set_ylabel("share of band error explained")
ax.set_title("B  it does not explain the band error", fontsize=9.5, color=INK,
             loc="left", pad=8)
ax.legend(loc="upper right", fontsize=7.5, frameon=False)
ax.text(0.02, 0.955, "pooled over the band: R2 %.4f   t %.2f"
        % (gate["r2_b2"], gate["t_b2"]), transform=ax.transAxes, fontsize=8,
        color=INK, va="top")
for s in ("top", "right"):
    ax.spines[s].set_visible(False)

# ---- C: what the slope adds --------------------------------------------
ax = fig.add_subplot(gs[0, 2])
labs = ["demand\nalone", "slope\nalone", "slope x\ndemand", "both"]
vals = [gate["r2_a"], gate["r2_b2"], gate["r2_ba"], gate["r2_ab"]]
cols = [AMBER, NAVY, TEAL, RED]
xpos = [0, 1, 2, 3]
ax.bar(xpos, vals, color=cols, width=0.62, zorder=3)
ax.axhline(GATE, color=RED, lw=1.0, ls=(0, (5, 3)), zorder=4)
for x, v in zip(xpos, vals):
    # A bar shorter than the gate line would put its label inside the tick text.
    y = v + 0.0035 if v > GATE else GATE * 1.22
    ax.text(x, y, "%.4f" % v, ha="center", va="bottom", fontsize=7.4, color=INK)
ax.set_xticks(xpos)
ax.set_xticklabels(labs, fontsize=7.8)
ax.set_ylim(0, max(vals) * 1.48)
ax.set_ylabel("share of band error explained")
ax.set_title("C  and adds nothing to demand", fontsize=9.5, color=INK, loc="left",
             pad=8)
ax.text(0.03, 0.985, "dashed line: 1% gate", transform=ax.transAxes, fontsize=7.6,
        color=RED, ha="left", va="top")
ax.text(0.03, 0.895, "in the joint fit the slope t = %.2f, so the channel is not\n"
        "independent of the demand channel" % gate["t_b22"], transform=ax.transAxes,
        fontsize=7.6, color=MUTED, ha="left", va="top", linespacing=1.45)
for s in ("top", "right"):
    ax.spines[s].set_visible(False)

fig.suptitle("E02  does the published demand to price slope carry band information we lack",
             fontsize=11, color=INK, x=0.055, ha="left", y=0.965)

out = os.path.join(HERE, "fig_e02_sens.png")
fig.savefig(out, dpi=220, facecolor="white")
print("wrote", out)
