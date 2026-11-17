"""Conditional-template test, raw and clamped, plus a day-of-week-conditioned template.

Read-only on AEMO_Data. One 288-step forecast per day issued at the 24:00 origin of the
previous day, scored on all 288 slots. Every coefficient is refitted causally on a
rolling window that ends before the target day, so no future information is used.
"""

import os
import warnings
import numpy as np
import pandas as pd

warnings.filterwarnings("ignore", category=RuntimeWarning)

DATA = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\AEMO_Data"
OUT = r"C:\Ash\_research_20261013"
PD = os.path.join(DATA, "window_120d_20260201_20260601", "predispatch_30min_VIC1.csv")
N_SLOTS, WIN, FIT, CLAMP_DAYS, DOW_WIN = 288, 28, 56, 30, 56
RUN = (23, 30) if (len(__import__("sys").argv) > 1 and __import__("sys").argv[1] == "2330") else (0, 0)

KEYS = ["persist", "T", "Tdow", "L_ar1", "L_fcdem", "L_both", "shape_fcdem", "full",
        "full_dow", "oracle_L", "oracle_shape"]


def prev_mean(cube, i, win):
    return np.nanmean(cube[max(0, i - win):i], axis=0)


def ols(X, y):
    ok = np.isfinite(y) & np.all(np.isfinite(X), axis=1)
    if ok.sum() < 10:
        return None
    X, y = X[ok], y[ok]
    return np.linalg.lstsq(X, y, rcond=None)[0]


def load_forecast_demand(days, day_ix):
    # which pre-dispatch run is used as the information set.  RUN=(0,0) takes the
    # 00:00 run of the target day; RUN=(23,30) is the strictly-causal choice, since
    # that run is already published when the 24:00 origin of the previous day is hit.
    rh, rm = RUN
    fc30 = np.full((len(days), 48), np.nan)
    usecols = ["effective_time", "region_id", "target_datetime", "total_demand"]
    for chunk in pd.read_csv(PD, usecols=usecols, chunksize=400000):
        chunk = chunk[chunk["region_id"] == "VIC1"]
        eff = pd.to_datetime(chunk["effective_time"], format="%Y-%m-%d %H:%M:%S")
        chunk = chunk[(eff.dt.hour == rh) & (eff.dt.minute == rm)]
        if chunk.empty:
            continue
        tgt = pd.to_datetime(chunk["target_datetime"], format="%Y-%m-%d %H:%M:%S")
        dd = (tgt - pd.Timedelta(minutes=30)).dt.normalize()
        k = (((tgt - dd).dt.total_seconds() // 1800) - 1).to_numpy().astype(int)
        ii = np.array([day_ix.get(x, -1) for x in dd])
        keep = (k >= 0) & (k < 48) & (ii >= 0)
        fc30[ii[keep], k[keep]] = chunk["total_demand"].to_numpy()[keep]
    return fc30


def apply_clamp(y, days):
    """Predictor rule: rolling 30 complete days of RAW prices, global Q1/Q99, once per day."""
    yc = np.empty_like(y)
    for i in range(len(days)):
        lo = max(0, i - CLAMP_DAYS)
        win = y[lo:i]
        q = np.percentile(win if win.size else y[i], [1, 99])
        yc[i] = np.clip(y[i], q[0], q[1])
    return yc


def evaluate(y, dem, fc, fc30, days, day_ix, tag):
    n = len(days)
    L = np.nanmean(y, axis=1)
    A = y - L[:, None]
    Ld = np.nanmean(dem, axis=1)
    Lf = np.nanmean(fc, axis=1)
    dow = np.array([d.dayofweek for d in days])

    rms = lambda x: float(np.sqrt(np.nanmean(x ** 2)))
    err = {k: np.full((n, N_SLOTS), np.nan) for k in KEYS}
    coef, scored = [], []

    t0 = day_ix[pd.Timestamp("2026-02-01")]
    t1 = day_ix[pd.Timestamp("2026-06-01")]

    for i in range(t0, t1):
        if not np.isfinite(fc30[i]).all():
            continue
        T = prev_mean(y, i, WIN)
        Abar = prev_mean(A, i, WIN)
        Lbar = np.nanmean(L[max(0, i - WIN):i])
        Dbar = prev_mean(dem, i, WIN)
        same = [j for j in range(max(0, i - DOW_WIN), i) if dow[j] == dow[i]]
        Tdow = np.nanmean(y[same], axis=0) if same else T
        Abar_dow = np.nanmean(A[same], axis=0) if same else Abar

        jj = [j for j in range(max(WIN, i - FIT), i) if np.isfinite(fc30[j]).all()]
        if len(jj) < 20:
            continue
        tgt_L = np.array([L[j] for j in jj])
        x_ar = np.array([L[j - 1] for j in jj])
        x_fc = np.array([Lf[j] for j in jj])
        x_ac = np.array([Ld[j] for j in jj])
        c_ar = ols(np.c_[np.ones(len(x_ar)), x_ar], tgt_L)
        c_fc = ols(np.c_[np.ones(len(x_fc)), x_fc], tgt_L)
        c_bo = ols(np.c_[np.ones(len(x_ar)), x_ar, x_fc], tgt_L)
        c_or = ols(np.c_[np.ones(len(x_ac)), x_ac], tgt_L)
        if any(c is None for c in (c_ar, c_fc, c_bo, c_or)):
            continue
        num = den = 0.0
        for j in jj:
            dx = dem[j] - prev_mean(dem, j, WIN)
            dy = A[j] - prev_mean(A, j, WIN)
            num += np.nansum(dx * dy)
            den += np.nansum(dx * dx)
        g = num / den if den > 0 else 0.0

        Lhat_ar = c_ar[0] + c_ar[1] * L[i - 1]
        Lhat_bo = c_bo[0] + c_bo[1] * L[i - 1] + c_bo[2] * Lf[i]
        Lhat_or = c_or[0] + c_or[1] * Ld[i]
        shp = g * (fc[i] - Dbar)
        coef.append((c_ar[1], c_fc[1], c_bo[1], c_bo[2], c_or[1], g))

        err["persist"][i] = y[i] - y[i - 1]
        err["T"][i] = y[i] - T
        err["Tdow"][i] = y[i] - Tdow
        err["L_ar1"][i] = y[i] - (T + (Lhat_ar - Lbar))
        err["L_fcdem"][i] = y[i] - (T + (c_fc[0] + c_fc[1] * Lf[i] - Lbar))
        err["L_both"][i] = y[i] - (T + (Lhat_bo - Lbar))
        err["shape_fcdem"][i] = y[i] - (T + shp)
        err["full"][i] = y[i] - (T + (Lhat_bo - Lbar) + shp)
        err["full_dow"][i] = y[i] - (Tdow + (Lhat_bo - Lbar) + (Abar_dow - Abar) + shp)
        err["oracle_L"][i] = y[i] - (T + (L[i] - Lbar))
        err["oracle_shape"][i] = y[i] - (T + (A[i] - Abar))
        scored.append(i)

    print(f"\n########## {tag} ##########")
    print(f"scored days {len(scored)}  information set: pre-dispatch run at {RUN[0]:02d}:{RUN[1]:02d}")
    base = rms(err["T"])
    print(f"  {'model':16s} {'RMSE':>8s}   vs T")
    for k in KEYS:
        print(f"  {k:16s} {rms(err[k]):8.2f}   {100 * (1 - rms(err[k]) / base):+7.1f}%")

    wk = np.array([dow[i] < 5 for i in scored])
    d_T = np.sqrt(np.nanmean(err["T"][scored] ** 2, axis=1))
    d_F = np.sqrt(np.nanmean(err["full"][scored] ** 2, axis=1))
    print(f"  daily RMSE: full beats T on {int((d_F < d_T).sum())} of {len(scored)} days"
          f"   median daily RMSE  T {np.median(d_T):.1f}  full {np.median(d_F):.1f}")
    print(f"  weekday RMSE  T {rms(err['T'][scored][wk]):7.2f}  full {rms(err['full'][scored][wk]):7.2f}"
          f"   | weekend  T {rms(err['T'][scored][~wk]):7.2f}  full {rms(err['full'][scored][~wk]):7.2f}")

    print("  lead profile in 2 h blocks (RMSE $/MWh):")
    print(f"    {'hours':9s} {'T':>7s} {'Tdow':>7s} {'L_ar1':>7s} {'full':>7s} {'full_dow':>9s} {'oracleL':>8s}")
    for b in range(12):
        sl = slice(b * 24, (b + 1) * 24)
        v = [rms(err[k][:, sl]) for k in ["T", "Tdow", "L_ar1", "full", "full_dow", "oracle_L"]]
        print(f"    {b*2:02d}-{b*2+2:02d}h  " + "".join(f"{x:8.1f}" for x in v))
    cl = np.array(coef)
    print(f"  mean coefs: b1(L-1)={cl[:,0].mean():.3f}  b1(fcdem)={cl[:,1].mean():.4f}"
          f"  b1(L-1)={cl[:,2].mean():.3f} b2={cl[:,3].mean():.4f}  g={cl[:,5].mean():.6f}")
    return err, scored


def main():
    days = [pd.Timestamp(s) for s in open(os.path.join(OUT, "days.txt"), encoding="utf-8").read().split()]
    day_ix = {d: i for i, d in enumerate(days)}
    y_raw = np.load(os.path.join(OUT, "y_cube.npy"))
    dem = np.load(os.path.join(OUT, "dem_cube.npy"))
    fc30 = load_forecast_demand(days, day_ix)
    fc = np.repeat(fc30, 6, axis=1)
    print(f"forecast demand cells {int(np.isfinite(fc30).sum())}")

    yc = apply_clamp(y_raw, days)
    for tag, series in [("RAW", y_raw), ("CLAMPED (predictor scoring rule)", yc)]:
        err, scored = evaluate(series, dem, fc, fc30, days, day_ix, tag)
        np.save(os.path.join(OUT, f"errset_{tag.split()[0]}.npy"),
                np.array([err[k] for k in KEYS]))


if __name__ == "__main__":
    main()
