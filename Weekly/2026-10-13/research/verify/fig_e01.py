"""Render the E01 figure from research/verify/e01_demand.json.

A  the share of band error the demand anomaly explains, column by column, for the
   forecast we can actually use at the origin, against the same measurement made
   with the demand that actually happened at the target. The forecast now clears
   the 1 per cent gate in all thirty-seven columns and tracks the ceiling, which
   is what an input of the official forecast looks like.
B  the same regressor against every model in the pool. Fifteen of sixteen clear
   the gate, so this is a property of the price history and not of the anchor.
C  the seven ways of turning the channel into a correction, out of sample. V6
   refits on the scoring days and is a ceiling rather than a candidate; even it
   gains only 0.4 on the band median, because the 8 per cent the gate reports is
   variance weighted and lives in a few extreme days, while the criterion is a
   median of medians and barely sees them. V7 keeps the frozen slope and swaps in
   the demand that actually happened, and still loses.
"""

import json
import os

import matplotlib
import matplotlib.colors as mcolors

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "e01_demand.json")

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
    RAW = json.load(fh)


def obj(x):
    """MATLAB writes a scalar struct nested in a struct as an array of objects."""
    while isinstance(x, list) and x and isinstance(x[0], dict):
        x = x[0]
    return x


if isinstance(RAW, list):
    RAW = RAW[0]
D = {k: obj(v) for k, v in RAW.items()}
# The variant list is a genuine list of four, not a wrapped scalar struct.
VAR = RAW["variants"]
print("top level:", {k: type(v).__name__ for k, v in RAW.items()})

gate = obj(D["gate"])
prof = obj(D["profile"])
base = obj(D["baseline"])
GATE = 0.01
lead = [h / 60 for h in prof["lead_min"]]

fig = plt.figure(figsize=(14.6, 4.7))
gs = fig.add_gridspec(1, 3, width_ratios=[1.60, 1.20, 1.00], wspace=0.30,
                      left=0.055, right=0.985, top=0.84, bottom=0.145)

# ---- A: gate by column -------------------------------------------------
ax = fig.add_subplot(gs[0, 0])
# The realised-side points are read from runs\e01_demand_v8.log, line
# "by lead, realised", because the JSON stores the pooled ceiling only.
ceil_h = [6, 8, 12, 18, 24]
ceil_r2 = [0.0717, 0.1241, 0.0994, 0.1268, 0.0926]
ax.axhspan(0, GATE, color=BAND, zorder=0)
ax.plot(lead, gate["r2_col_anchor"], color=NAVY, lw=1.6, marker="o", ms=2.4, zorder=4,
        label="ours, demand forecast at the origin")
ax.plot(lead, gate["r2_col_official"], color=AMBER, lw=1.4, marker="s", ms=2.2,
        zorder=3, label="official, same regressor")
ax.plot(ceil_h, ceil_r2, color=RED, lw=0, marker="D", ms=5.5, zorder=5,
        label="ours, realised demand at the target")
ax.axhline(GATE, color=RED, lw=1.0, ls=(0, (5, 3)), zorder=2)
ax.text(lead[0] + 0.3, GATE, "gate 1%", color=RED, fontsize=8, va="bottom", ha="left")
ax.set_ylim(0, 0.148)
ax.set_xlim(lead[0], lead[-1])
ax.set_xlabel("lead (hours)")
ax.set_ylabel("share of band error explained")
ax.set_title("A  the forecast clears the gate at every column", fontsize=9.5,
             color=INK, loc="left", pad=8)
ax.text(0.02, 0.975, "pooled over the band   ours R2 %.4f  t %.2f   official R2 %.4f  t %.2f"
        % (gate["r2_anchor"], gate["t_anchor"], gate["r2_official"], gate["t_official"]),
        transform=ax.transAxes, fontsize=7.8, color=INK, va="top")
ax.legend(loc="lower right", fontsize=7.3, frameon=False)
for s in ("top", "right"):
    ax.spines[s].set_visible(False)

# ---- B: the model pool -------------------------------------------------
ax = fig.add_subplot(gs[0, 1])
# model_names arrives from jsonencode as one concatenated string, so the atlas
# order is written out here from model_registry.m; index i is atlas column i + 1.
names = ["Persistence(yest)", "Template T28", "Theta-y tracker", "T28 + AR4",
         "Carry-forward", "T28 + DMS4", "CF + DMS4", "Anchor-mix",
         "T28 + level offset", "Multi-window T", "MW + level offset",
         "MW + level (run state)", "Kalman harmonic SS", "EWMA template",
         "Weekday-class T", "T28 + AR(n per cell)"]
vals_in = gate["r2_model"]
order = sorted(range(len(vals_in)), key=lambda i: vals_in[i])
vals = [vals_in[i] for i in order]
labs = [names[i] for i in order]
cols = [NAVY if names[i] != "Anchor-mix" else AMBER for i in order]
ypos = range(len(vals))
ax.barh(list(ypos), vals, color=cols, height=0.62, zorder=3)
ax.axvline(GATE, color=RED, lw=1.0, ls=(0, (5, 3)), zorder=4)
ax.set_yticks(list(ypos))
ax.set_yticklabels(labs, fontsize=7.4)
ax.set_xlim(0, max(vals) * 1.22)
ax.set_xlabel("share of band error explained")
ax.set_title("B  fifteen of sixteen models, same regressor", fontsize=9.5, color=INK,
             loc="left", pad=8)
ax.text(0.97, 0.99, "dashed line: 1% gate", transform=ax.transAxes, fontsize=7.6,
        color=RED, ha="right", va="top")
ax.text(0.97, 0.06, "the one below is persistence,\nwhich has no level at all",
        transform=ax.transAxes, fontsize=7.4, color=MUTED, ha="right", va="bottom",
        linespacing=1.45)
for s in ("top", "right"):
    ax.spines[s].set_visible(False)

# ---- C: the candidate --------------------------------------------------
ax = fig.add_subplot(gs[0, 2])
var = VAR
labs = [v["label"] for v in var]
vals = [v["band_med"] for v in var]
xpos = list(range(len(vals)))
# V6 fits on the scoring days themselves and is a ceiling, not a candidate.
cols = []
for v in var:
    if v["label"].startswith("V6"):
        cols.append(RED)
    elif v["label"].startswith("V7"):
        cols.append(TEAL)
    else:
        cols.append(NAVY)
ax.bar(xpos, vals, color=cols, width=0.62, zorder=3)
ax.axhline(base["anchor_band"], color=AMBER, lw=1.4, ls=(0, (5, 3)), zorder=4)
ax.axhline(base["official_band"], color=RED, lw=1.4, ls=(0, (2, 3)), zorder=4)
for x, v in zip(xpos, vals):
    ax.text(x, v + 0.8, "%.1f" % v, ha="center", va="bottom", fontsize=7.0, color=INK)
ax.set_xticks(xpos)
ax.set_xticklabels(["V1\nglobal", "V2\nby hour", "V3\nhour x\nlead", "V4\nwithin\nslot",
                    "V5\nwithin\nday", "V6\noracle", "V7\nrealised"], fontsize=7.2)
ax.set_ylim(0, max(vals) * 1.20)
ax.set_ylabel("band median R, days 29 to 60")
ax.set_title("C  every usable version loses", fontsize=9.5, color=INK, loc="left", pad=8)
ax.legend(handles=[
    Line2D([], [], color=AMBER, lw=1.4, ls=(0, (5, 3)),
           label="anchor %.1f" % base["anchor_band"]),
    Line2D([], [], color=RED, lw=1.4, ls=(0, (2, 3)),
           label="official %.1f" % base["official_band"]),
], loc="upper left", fontsize=7.2, frameon=False)
ax.text(0.97, 0.99, "V6 refits on the scoring days, so its\n0.4 gain is the ceiling of the\n"
        "whole family. V7 swaps in realised\ndemand and still loses.",
        transform=ax.transAxes, fontsize=7.0, color=MUTED, ha="right", va="top",
        linespacing=1.42)
for s in ("top", "right"):
    ax.spines[s].set_visible(False)

fig.suptitle("E01  the demand forecast clears the gate at every column, and no version of "
             "the correction beats doing nothing",
             fontsize=11, color=INK, x=0.055, ha="left", y=0.965)

out = os.path.join(HERE, "fig_e01_demand.png")
fig.savefig(out, dpi=220, facecolor="white")
print("wrote", out)
