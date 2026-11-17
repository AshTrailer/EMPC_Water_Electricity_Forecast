# Render the E09 premise figure.
#
# Four panels. First, the five regional prices by hour, which shows Victoria
# tracks Tasmania and South Australia rather than New South Wales. Second, the
# offer stack read the other way round: the dispatch the settled price implies,
# minus regional demand. That surplus is bracketed, once with every unit in the
# stack and once with the semi scheduled plant removed, because a semi scheduled
# offer is a bid curve the unit cannot exceed its availability. Third, the same
# surplus against the gap to the cheapest neighbour. Fourth, how much of the sub
# zero volume is semi scheduled.

import json
from datetime import date
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = Path(r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast")
DATA = ROOT / "AEMO_Data"

COLS = ["end_min", "demand", "price", "price_at_demand", "price_at_demand_plus_2000",
        "q_low", "q_high", "mw_total", "mw_le0", "mw_le0_semi", "mw_semi_at_demand", "edge_flag"]

# scored window is day 29 to 60 of the atlas, 2026-09-08 to 2026-10-09
S0 = (date(2026, 9, 8) - date(1970, 1, 1)).days * 1440
S1 = S0 + 32 * 1440

REG = ["VIC1", "NSW1", "SA1", "QLD1", "TAS1"]


def q(x, p):
    x = np.asarray(x, float)
    x = x[np.isfinite(x)]
    return float(np.quantile(x, p)) if x.size else float("nan")


def load(stem):
    meta = json.loads((HERE / f"{stem}.json").read_text(encoding="utf-8"))
    raw = np.fromfile(HERE / f"{stem}.bin", dtype="<f8")
    assert raw.size % len(COLS) == 0, f"{stem}: not a whole number of rows"
    L = raw.reshape(-1, len(COLS))
    assert L.shape[0] == meta["rows"], f"{stem}: {L.shape[0]} rows against {meta['rows']}"
    return meta, {c: L[:, i] for i, c in enumerate(COLS)}


# ---------------------------------------------------------- neighbour prices
px = {}
for region in REG:
    acc = {}
    for month in ("202608", "202609", "202610"):
        txt = (DATA / f"PRICE_AND_DEMAND_{month}_{region}.csv").read_text(encoding="utf-8")
        for line in txt.splitlines()[1:]:
            if not line:
                continue
            c = line.split(",")
            acc[(int(c[1][0:4]), int(c[1][5:7]), int(c[1][8:10]), int(c[1][11:13]), int(c[1][14:16]))] = float(c[3])
    px[region] = acc


def stamp_key(minutes):
    t = int(round(minutes))
    days, rem = divmod(t, 1440)
    hh, mm = divmod(rem, 60)
    z = days + 719468
    era = z // 146097
    doe = z - era * 146097
    yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    y = yoe + era * 400
    doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    mp = (5 * doy + 2) // 153
    d = doy - (153 * mp + 2) // 5 + 1
    m = mp + 3 if mp < 10 else mp - 9
    return (y + (1 if m <= 2 else 0), m, d, hh, mm)


def neighbour_state(end_min, price):
    """Rank of Victoria among the five, and the cheapest neighbour's price."""
    n = len(end_min)
    rank = np.full(n, -1)
    lo_of = np.full(n, np.nan)
    for i in range(n):
        key = stamp_key(end_min[i])
        others = [px[r].get(key) for r in REG[1:]]
        if any(v is None for v in others):
            continue
        lo_of[i] = min(others)
        v = price[i]
        if v < min(others) - 0.1:
            rank[i] = 0
        elif v > max(others) + 0.1:
            rank[i] = 2
        else:
            rank[i] = 1
    return rank, lo_of


variants = []
for label, stem in (("every unit in the stack", "e09_ladder_VIC1"),
                    ("semi scheduled removed", "e09_ladder_VIC1_nosemi")):
    meta, D = load(stem)
    keep = (D["end_min"] > S0) & (D["end_min"] <= S1)
    D = {k: v[keep] for k, v in D.items()}
    surplus = D["q_low"] - D["demand"]
    err_at_d = D["price_at_demand"] - D["price"]
    semi_share = np.where(D["mw_le0"] > 0, D["mw_le0_semi"] / np.maximum(D["mw_le0"], 1e-9), np.nan)
    at_export = D["price_at_demand_plus_2000"] - D["price"]
    rank, lo_of = neighbour_state(D["end_min"], D["price"])
    variants.append({
        "label": label, "stem": stem, "meta": meta, "D": D, "surplus": surplus,
        "err_at_demand": err_at_d, "at_export": at_export, "semi_share": semi_share,
        "rank": rank, "spread": D["price"] - lo_of,
    })

base = variants[0]
intervals = [("Victoria cheapest", base["rank"] == 0), ("in between", base["rank"] == 1),
             ("Victoria dearest", base["rank"] == 2), ("all", base["rank"] >= 0)]

print(f"scored intervals {len(base['D']['end_min'])}, classified {int((base['rank'] >= 0).sum())}")
out = {"scored_intervals": int(len(base["D"]["end_min"])), "variants": {}}
for V in variants:
    D = V["D"]
    inside = D["edge_flag"] == 0
    print(f"\n=== {V['label']} ===")
    short = 100 * float(np.mean(~np.isfinite(D["price_at_demand"])))
    print(f"demand above the whole stack in {short:.1f}% of intervals, "
          f"median total offered {q(D['mw_total'], 0.5):.0f} MW, "
          f"median demand {q(D['demand'], 0.5):.0f} MW")
    fin = np.isfinite(V["at_export"])
    print(f"stack at demand plus {meta['extra_mw']:.0f} MW minus the settled price: "
          f"median {q(V['at_export'][fin], 0.5):.1f} $/MWh, "
          f"within 5 $ in {100 * float(np.mean(np.abs(V['at_export'][fin]) <= 5)):.1f}% of {fin.sum()} intervals")
    print(f"{'group':20s} {'n':>6s} | {'below':>6s} {'inside':>6s} {'above':>6s} | "
          f"{'surplus':>8s} {'p10':>7s} {'p90':>7s} {'in range':>8s} | {'err@D':>7s}")
    rows = []
    for label, m in intervals:
        mm = m & inside
        ss = V["surplus"][mm]
        row = {
            "group": label,
            "n": int(m.sum()),
            "below_pct": 100 * float(np.mean(D["edge_flag"][m] == 2)),
            "inside_pct": 100 * float(np.mean(D["edge_flag"][m] == 0)),
            "above_pct": 100 * float(np.mean(D["edge_flag"][m] == 1)),
            "surplus_n": int(mm.sum()),
            "surplus_median": q(ss, 0.5),
            "surplus_p10": q(ss, 0.1),
            "surplus_p90": q(ss, 0.9),
            "inside_envelope_pct": 100 * float(np.mean((ss >= -1500) & (ss <= 2500))) if ss.size else float("nan"),
            "err_at_demand_median": q(V["err_at_demand"][mm], 0.5),
            "semi_share_median": q(V["semi_share"][mm], 0.5),
        }
        rows.append(row)
        print(f"{label:20s} {row['n']:6d} | {row['below_pct']:5.1f}% {row['inside_pct']:5.1f}% "
              f"{row['above_pct']:5.1f}% | {row['surplus_median']:8.0f} {row['surplus_p10']:7.0f} "
              f"{row['surplus_p90']:7.0f} {row['inside_envelope_pct']:7.1f}% | "
              f"{row['err_at_demand_median']:7.1f}")
    out["variants"][V["label"]] = {
        "demand_above_stack_pct": short,
        "mw_total_median": q(D["mw_total"], 0.5),
        "demand_median": q(D["demand"], 0.5),
        "at_export_median": q(V["at_export"][fin], 0.5),
        "at_export_within_5_pct": 100 * float(np.mean(np.abs(V["at_export"][fin]) <= 5)),
        "rows": rows,
    }

by_hour = []
hour = ((base["D"]["end_min"] % 1440) // 60).astype(int)
for h in range(24):
    m = (hour == h) & np.isfinite(base["semi_share"])
    by_hour.append(q(base["semi_share"][m], 0.5) if m.sum() else np.nan)
by_hour = np.array(by_hour)
out["semi_share_by_hour"] = [None if not np.isfinite(x) else float(x) for x in by_hour]

# --------------------------------------------------------------- the figure
fig, ax = plt.subplots(2, 2, figsize=(15.4, 9.6))

# a. hourly median price by region, medians because the spikes are not the point
def hour_index(key):
    y, m, d, hh, mm = key
    if not (2026, 8, 11) <= (y, m, d) < (2026, 10, 10):
        return None
    day = (date(y, m, d) - date(2026, 8, 11)).days
    return day * 24 + hh


buckets = {}
for key in px["VIC1"]:
    h = hour_index(key)
    if h is None:
        continue
    vals = [px[r].get(key) for r in REG]
    if any(v is None for v in vals):
        continue
    hod = h % 24
    buckets.setdefault(hod, [[] for _ in REG])
    for j, v in enumerate(vals):
        buckets[hod][j].append(v)
col = {"VIC1": "#1f4e79", "NSW1": "#c00000", "SA1": "#548235", "QLD1": "#7f6000", "TAS1": "#7030a0"}
for j, r in enumerate(REG):
    med = np.array([np.median(buckets[h][j]) for h in range(24)])
    ax[0, 0].plot(range(24), med, color=col[r], lw=1.6, marker="o", ms=3, label=r)
ax[0, 0].set_xlim(-0.5, 23.5)
ax[0, 0].set_xticks(range(0, 24, 3))
ax[0, 0].set_xlabel("hour of day, NEM time")
ax[0, 0].set_ylabel("median RRP, $/MWh")
ax[0, 0].set_title("a. Victoria and Tasmania move together through the day;\nSouth Australia sits above, New South Wales and Queensland higher", fontsize=11)
ax[0, 0].legend(loc="upper left", fontsize=8, frameon=False, ncol=5)
ax[0, 0].grid(alpha=0.25)

bins = np.arange(-4000, 8001, 250)
for V, c in ((variants[0], "#c00000"), (variants[1], "#1f4e79")):
    v = V["surplus"][V["D"]["edge_flag"] == 0]
    v = v[np.isfinite(v)]
    ax[0, 1].hist(v, bins=bins, histtype="step", lw=1.7, color=c,
                  label=f"{V['label']}  median {q(v, 0.5):.0f} MW", density=True)
ax[0, 1].axvspan(-1500, 2500, color="#548235", alpha=0.10)
ax[0, 1].axvline(0, color="black", lw=0.8)
ax[0, 1].set_xlabel("dispatch the settled price implies, minus demand, MW")
ax[0, 1].set_ylabel("density")
ax[0, 1].set_title("b. dropping the semi scheduled offers moves the implied\ndispatch from 6.4 GW above demand to 0.2 GW below", fontsize=11)
ax[0, 1].legend(loc="upper right", fontsize=8, frameon=False)
ax[0, 1].grid(alpha=0.25)

# c. the level error at demand, both brackets
for V, c in ((variants[0], "#c00000"), (variants[1], "#1f4e79")):
    e = V["err_at_demand"]
    e = e[np.isfinite(e)]
    ax[1, 0].hist(np.clip(e, -900, 900), bins=np.arange(-900, 901, 30), histtype="step",
                  lw=1.7, color=c, density=True,
                  label=f"{V['label']}  median {q(e, 0.5):.0f} $/MWh")
ax[1, 0].axvline(0, color="black", lw=0.9)
ax[1, 0].set_xlabel("stack price at demand minus the settled price, $/MWh, clipped at 900")
ax[1, 0].set_ylabel("density")
ax[1, 0].set_title("c. the level error collapses by a factor of ten,\nbut 85 $/MWh of it survives", fontsize=11)
ax[1, 0].legend(loc="upper left", fontsize=8, frameon=False)
ax[1, 0].grid(alpha=0.25)

ax[1, 1].bar(np.arange(24), 100 * by_hour, color="#548235", width=0.78)
ax[1, 1].axhline(50, color="#c00000", lw=1.0, ls="--")
ax[1, 1].set_xlim(-0.6, 23.6)
ax[1, 1].set_xticks(range(0, 24, 3))
ax[1, 1].set_xlabel("hour of the target interval")
ax[1, 1].set_ylabel("per cent of the sub zero MW")
ax[1, 1].set_title("d. six of every ten sub zero megawatts are offered by\nsemi scheduled plant, at every hour", fontsize=11)
ax[1, 1].grid(alpha=0.25, axis="y")

fig.suptitle("E09 premise: the offer stack counts capacity the dispatch never uses, and Victoria's price moves with Tasmania",
             fontsize=12)
fig.tight_layout(rect=(0, 0, 1, 0.965))
out_png = HERE / "fig_e09_structure.png"
fig.savefig(out_png, dpi=140)
plt.close(fig)
print(f"\nwrote {out_png}")

json.dump(out, open(HERE / "e09_structure.json", "w", encoding="utf-8"), indent=2)
print(f"wrote {HERE / 'e09_structure.json'}")
