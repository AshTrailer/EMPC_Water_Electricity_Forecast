"""Rolling-origin check: is the daily level recoverable from the part of the day already seen?

The predictor issues a forecast at every 5-min origin, so a level correction cannot be a
once-a-day constant. This measures how much of L(d) is knowable at 6 h, 12 h and 18 h
into the day, and how that compares with what the 28-day template level offers.
"""

import os
import warnings
import numpy as np
import pandas as pd

warnings.filterwarnings("ignore", category=RuntimeWarning)

DATA = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\AEMO_Data"
OUT = r"C:\Ash\_research_20261013"
PD = os.path.join(DATA, "window_120d_20260201_20260601", "predispatch_30min_VIC1.csv")
WIN, CLAMP_DAYS = 28, 30


def ols(X, y):
    ok = np.isfinite(y) & np.all(np.isfinite(X), axis=1)
    if ok.sum() < 10:
        return None
    return np.linalg.lstsq(X[ok], y[ok], rcond=None)[0]


def load_fc(days, day_ix):
    fc30 = np.full((len(days), 48), np.nan)
    usecols = ["effective_time", "region_id", "target_datetime", "total_demand"]
    for chunk in pd.read_csv(PD, usecols=usecols, chunksize=400000):
        chunk = chunk[chunk["region_id"] == "VIC1"]
        eff = pd.to_datetime(chunk["effective_time"], format="%Y-%m-%d %H:%M:%S")
        chunk = chunk[(eff.dt.hour == 23) & (eff.dt.minute == 30)]
        if chunk.empty:
            continue
        tgt = pd.to_datetime(chunk["target_datetime"], format="%Y-%m-%d %H:%M:%S")
        dd = (tgt - pd.Timedelta(minutes=30)).dt.normalize()
        k = (((tgt - dd).dt.total_seconds() // 1800) - 1).to_numpy().astype(int)
        ii = np.array([day_ix.get(x, -1) for x in dd])
        keep = (k >= 0) & (k < 48) & (ii >= 0)
        fc30[ii[keep], k[keep]] = chunk["total_demand"].to_numpy()[keep]
    return fc30


def main():
    days = [pd.Timestamp(s) for s in open(os.path.join(OUT, "days.txt"), encoding="utf-8").read().split()]
    day_ix = {d: i for i, d in enumerate(days)}
    y_raw = np.load(os.path.join(OUT, "y_cube.npy"))
    fc30 = load_fc(days, day_ix)
    fc = np.repeat(fc30, 6, axis=1)

    y = np.empty_like(y_raw)
    for i in range(len(days)):
        win = y_raw[max(0, i - CLAMP_DAYS):i]
        q = np.percentile(win if win.size else y_raw[i], [1, 99])
        y[i] = np.clip(y_raw[i], q[0], q[1])

    L = np.nanmean(y, axis=1)
    Lf = np.nanmean(fc, axis=1)
    t0 = day_ix[pd.Timestamp("2026-02-01")]
    t1 = day_ix[pd.Timestamp("2026-06-01")]

    rms = lambda x: float(np.sqrt(np.nanmean(np.asarray(x, dtype=float) ** 2)))
    print("level RMSE ($/MWh) by how much of the day has already been observed")
    print(f"  {'observed':>10s} {'template only':>14s} {'running mean':>13s} {'runmean+fcdem':>14s} {'n':>5s}")
    for frac in (0.25, 0.5, 0.75):
        k = int(288 * frac)
        e_t, e_r, e_b, n = [], [], [], 0
        for i in range(t0, t1):
            if not np.isfinite(fc30[i]).all():
                continue
            jj = [j for j in range(max(WIN, i - 56), i) if np.isfinite(fc30[j]).all()]
            if len(jj) < 20:
                continue
            tgt = np.array([L[j] for j in jj])
            run_obs = np.array([np.nanmean(y[j][:k]) for j in jj])
            x_f = np.array([Lf[j] for j in jj])
            c_r = ols(np.c_[np.ones(len(run_obs)), run_obs], tgt)
            c_b = ols(np.c_[np.ones(len(run_obs)), run_obs, x_f], tgt)
            if c_r is None or c_b is None:
                continue
            lbar = np.nanmean(L[max(0, i - WIN):i])
            run_now = np.nanmean(y[i][:k])
            e_t.append(L[i] - lbar)
            e_r.append(L[i] - (c_r[0] + c_r[1] * run_now))
            e_b.append(L[i] - (c_b[0] + c_b[1] * run_now + c_b[2] * Lf[i]))
            n += 1
        print(f"  {int(frac*100):>8d} % {rms(e_t):>14.2f} {rms(e_r):>13.2f} {rms(e_b):>14.2f} {n:>5d}")

    print()
    print("same, for the day AFTER the observed day (no running mean available, uses L(d-1))")
    e_t, e_b, n = [], [], 0
    for i in range(t0, t1):
        if not np.isfinite(fc30[i]).all():
            continue
        jj = [j for j in range(max(WIN, i - 56), i) if np.isfinite(fc30[j]).all()]
        if len(jj) < 20:
            continue
        tgt = np.array([L[j] for j in jj])
        x1 = np.array([L[j - 1] for j in jj])
        x2 = np.array([Lf[j] for j in jj])
        c = ols(np.c_[np.ones(len(x1)), x1, x2], tgt)
        if c is None:
            continue
        lbar = np.nanmean(L[max(0, i - WIN):i])
        e_t.append(L[i] - lbar)
        e_b.append(L[i] - (c[0] + c[1] * L[i - 1] + c[2] * Lf[i]))
        n += 1
    print(f"  template only {rms(e_t):.2f}   yesterday+fcdem {rms(e_b):.2f}   n {n}")
    print(f"  reduction {100 * (1 - rms(e_b) / rms(e_t)):.1f} %")


if __name__ == "__main__":
    main()
