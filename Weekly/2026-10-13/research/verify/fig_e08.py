# Render the E08 stack displacement figure.
#
# Three panels. The aggregate offer curve at one origin with the demand the
# publication carried and the price it carried, so the two readings of the same
# curve are visible. Then the published price against the curve price by hour,
# which shows the shape is right and the level is not. Then the wedge, the extra
# MW offered at the published price over regional demand.

import json
import os
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

HERE = Path(__file__).resolve().parent
RAW = json.loads((HERE / "e08_stack.json").read_text(encoding="utf-8"))

fig, ax = plt.subplots(1, 3, figsize=(16.2, 5.2))

# ---------------------------------------------------------------- panel one
s = RAW["sample"]
curve = np.array(s["curve"])
price = curve[:, 1]
cum = curve[:, 0]
ax[0].step(cum / 1000.0, price, where="post", color="#1f4e79", lw=1.6, label="aggregate Victoria stack")
ax[0].axhline(s["rrp"], color="#c00000", lw=1.3, ls="--", label=f"published price {s['rrp']:.2f}")
ax[0].axvline(s["demand"] / 1000.0, color="#548235", lw=1.3, ls=":", label=f"forecast demand {s['demand']:.0f} MW")
at_price = cum[price <= s["rrp"]][-1] if np.any(price <= s["rrp"]) else 0.0
ax[0].plot([at_price / 1000.0], [s["rrp"]], "o", color="#c00000", ms=6)
ax[0].annotate(
    f"stack reaches {s['rrp']:.2f} only at\n{at_price:.0f} MW",
    xy=(at_price / 1000.0, s["rrp"]),
    xytext=(at_price / 1000.0 + 1.2, s["rrp"] - 420),
    fontsize=9, color="#c00000",
    arrowprops=dict(arrowstyle="->", color="#c00000", lw=1.0),
)
ax[0].set_xlim(0, cum[-1] / 1000.0 * 1.02)
ax[0].set_ylim(min(-1050, price.min() - 50), 400)
ax[0].set_xlabel("cumulative MW offered, thousands")
ax[0].set_ylabel("offer price, $/MWh")
ax[0].set_title(f"a. one stack, two readings\norigin midday, target {s['target'] % 1440 // 60:.0f}h", fontsize=11)
ax[0].legend(loc="upper left", fontsize=8, frameon=False)
ax[0].grid(alpha=0.25)

# ---------------------------------------------------------------- panel two
hours = [h["hour"] for h in RAW["by_hour"]]
published = [h["published"] for h in RAW["by_hour"]]
capped = [h["curve_capped"] for h in RAW["by_hour"]]
raw = [h["curve_raw"] for h in RAW["by_hour"]]
ax[1].plot(hours, published, color="#c00000", lw=2.0, marker="o", ms=3.5, label="published price")
ax[1].plot(hours, capped, color="#1f4e79", lw=1.6, marker="s", ms=3.0, label="stack at demand, capped")
ax[1].plot(hours, raw, color="#7f7f7f", lw=1.2, ls="--", label="stack at demand, raw bands")
ax[1].axhline(0, color="black", lw=0.7)
ax[1].set_xlim(-0.5, 23.5)
ax[1].set_xticks(range(0, 24, 3))
ax[1].set_xlabel("hour of target")
ax[1].set_ylabel("$/MWh, median")
ax[1].set_title("b. the shape agrees, the level does not", fontsize=11)
ax[1].legend(loc="upper left", fontsize=8, frameon=False)
ax[1].grid(alpha=0.25)

# -------------------------------------------------------------- panel three
wedge = [h["wedge_capped"] for h in RAW["by_hour"]]
ax[2].bar(hours, np.array(wedge) / 1000.0, color="#1f4e79", alpha=0.85, width=0.72)
ax[2].axhline(0, color="black", lw=0.7)
ax[2].set_xlim(-0.5, 23.5)
ax[2].set_xticks(range(0, 24, 3))
ax[2].set_xlabel("hour of target")
ax[2].set_ylabel("thousand MW")
ax[2].set_title(
    "c. MW offered at the published price, less demand\n"
    f"median {RAW['wedge']['capped']['median']} MW, "
    f"{RAW['wedge']['capped']['share_within_500']:.0f}% of cells within 500 MW of zero",
    fontsize=11,
)
ax[2].grid(alpha=0.25, axis="y")

fig.suptitle(
    "E08: the Victorian offer stack, read at the operator's own demand forecast, is displaced from the price the operator published",
    fontsize=12, y=0.985,
)
fig.tight_layout(rect=(0, 0, 1, 0.955))
out = HERE / "fig_e08_stack.png"
fig.savefig(out, dpi=150)
print(f"wrote {out} {os.path.getsize(out)} bytes")
