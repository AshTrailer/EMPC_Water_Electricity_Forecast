"""Long-horizon error decomposition for the VIC1 price predictor.

Read-only on AEMO_Data. Builds the 5-min series, the rolling per-slot template T,
and splits the 24 h-ahead squared error into a daily-level part and an intraday-shape
part, which is exactly orthogonal because the shape has zero mean inside every day.

y(d, s) = L(d) + A(d, s)          L = daily mean, sum_s A(d, s) = 0
T(d, s) = Lbar_28 + Abar_28(s)    rolling 28-day per-slot mean
y - T   = [L(d) - Lbar_28]  +  [A(d, s) - Abar_28(s)]
sum_s (L-Lbar)(A-Abar) = (L-Lbar) * (0 - 0) = 0
"""

import glob
import os
import numpy as np
import pandas as pd

DATA = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\AEMO_Data"
OUT = r"C:\Ash\_research_20261013"

N_SLOTS = 288
WIN_DAYS = 28
CLAMP_DAYS = 30


def load_series():
    rows = []
    for f in sorted(glob.glob(os.path.join(DATA, "PRICE_AND_DEMAND_2026*_VIC1.csv"))):
        df = pd.read_csv(f)
        rows.append(df)
    df = pd.concat(rows, ignore_index=True)
    df["ts"] = pd.to_datetime(df["SETTLEMENTDATE"], format="%Y/%m/%d %H:%M:%S")
    df = df.sort_values("ts").drop_duplicates("ts", keep="last").reset_index(drop=True)
    return df


def to_days(df):
    """Assign every 5-min row to its trading-style day D: slots 00:05..24:00 of D."""
    ts = df["ts"]
    day = (ts - pd.Timedelta(minutes=5)).dt.normalize()
    slot = ((ts.dt.hour * 60 + ts.dt.minute) // 5).to_numpy()  # 00:05 -> 1, 24:00 -> 0
    slot = np.where(slot == 0, N_SLOTS, slot)
    df = df.assign(day=day, slot=slot)
    return df


def build_cube(df, col):
    days = sorted(df["day"].unique())
    day_ix = {d: i for i, d in enumerate(days)}
    cube = np.full((len(days), N_SLOTS), np.nan)
    i = df["day"].map(day_ix).to_numpy()
    j = df["slot"].to_numpy() - 1
    cube[i, j] = df[col].to_numpy()
    return days, cube


def rolling_template(cube, win=WIN_DAYS):
    """T[i, s] = mean of cube[i-win : i, s] (causal, strictly past days)."""
    n = cube.shape[0]
    T = np.full_like(cube, np.nan)
    for i in range(win, n):
        T[i] = np.nanmean(cube[i - win:i], axis=0)
    return T


def main():
    df = load_series()
    df = to_days(df)
    days, y = build_cube(df, "RRP")
    _, dem = build_cube(df, "TOTALDEMAND")
    n_days = len(days)
    print(f"rows {len(df)}  days {n_days}  {days[0].date()} .. {days[-1].date()}")
    print(f"missing price cells {int(np.isnan(y).sum())}  demand cells {int(np.isnan(dem).sum())}")

    # predictor window: warm-up Jan (31 days), scored 2026-02-01 .. 2026-06-01
    test0 = [i for i, d in enumerate(days) if d >= pd.Timestamp("2026-02-01")][0]
    test1 = [i for i, d in enumerate(days) if d >= pd.Timestamp("2026-06-01")][0]
    print(f"warm-up days 0..{test0-1}  scored days {test0}..{test1-1}  ({test1-test0} days)")

    T = rolling_template(y)
    L = np.nanmean(y, axis=1)
    A = y - L[:, None]

    idx = np.arange(test0, test1)
    Lbar = np.array([np.nanmean(L[i - WIN_DAYS:i]) for i in idx])
    Abar = np.array([np.nanmean(A[i - WIN_DAYS:i], axis=0) for i in idx])

    # forecasts issued at 24:00 of day i-1, targeting all 288 slots of day i
    yt = y[idx]
    Tt = np.array([np.nanmean(y[i - WIN_DAYS:i], axis=0) for i in idx])
    lev_err = (L[idx] - Lbar)[:, None]
    shp_err = A[idx] - Abar
    tot_err = yt - Tt

    rms = lambda x: float(np.sqrt(np.nanmean(x ** 2)))
    print()
    print("=== 24 h-ahead RMSE, clamped=false, all 288 slots x 120 days ===")
    print(f"  T alone                     {rms(tot_err):8.2f} $/MWh")
    print(f"  level component  sqrt E[(L-Lbar)^2]  {rms(lev_err):8.2f}")
    print(f"  shape component  sqrt E[(A-Abar)^2]  {rms(shp_err):8.2f}")
    print(f"  check  sqrt(lev^2+shp^2)         {np.sqrt(rms(lev_err)**2 + rms(shp_err)**2):8.2f}")
    print(f"  persistence (same slot, day-1)   {rms(yt - y[idx - 1]):8.2f}")
    print(f"  oracle: level known, shape=T     {rms(shp_err):8.2f}")
    print(f"  oracle: shape known, level=T     {rms(lev_err):8.2f}")
    print(f"  signal std (day-to-day, all)     {float(np.nanstd(yt)):8.2f}")

    print()
    print("=== how much of the level is predictable from the daily mean alone ===")
    Ls = L[idx]
    Llag = L[idx - 1]
    ok = np.isfinite(Ls) & np.isfinite(Llag)
    print(f"  daily mean price: mean {np.nanmean(Ls):.1f}  std {np.nanstd(Ls):.1f}  "
          f"min {np.nanmin(Ls):.1f}  max {np.nanmax(Ls):.1f}")
    print(f"  AR(1) corr(L(d), L(d-1)) = {np.corrcoef(Ls[ok], Llag[ok])[0, 1]:.3f}")
    print(f"  AR(7) corr(L(d), L(d-7)) = {np.corrcoef(Ls[7:], Ls[:-7])[0, 1]:.3f}")

    # demand
    Ld = np.nanmean(dem, axis=1)
    print()
    print("=== demand as an explanatory variable for the level ===")
    ok2 = np.isfinite(Ls) & np.isfinite(Ld[idx])
    print(f"  corr(L(d), mean demand(d))        = {np.corrcoef(Ls[ok2], Ld[idx][ok2])[0, 1]:.3f}")
    ok3 = ok & np.isfinite(Ld[idx])
    print(f"  corr(L(d), mean demand(d-1))      = {np.corrcoef(Ls[ok3], Ld[idx - 1][ok3])[0, 1]:.3f}")

    np.save(os.path.join(OUT, "y_cube.npy"), y)
    np.save(os.path.join(OUT, "dem_cube.npy"), dem)
    with open(os.path.join(OUT, "days.txt"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(str(pd.Timestamp(d).date()) for d in days))
    print()
    print(f"saved cubes to {OUT}")


if __name__ == "__main__":
    main()
