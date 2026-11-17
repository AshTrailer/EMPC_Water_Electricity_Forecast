"""Does the AEMO rooftop-PV forecast add anything on top of the demand forecast?

Same protocol as conditional_T.py: one 288-step forecast per day from the 23:30 origin
of the previous day, strictly causal refits, clamped scoring. PV is taken from the
23:30 snapshot of the same pre-dispatch cycle.
"""

import os
import warnings
import numpy as np
import pandas as pd

warnings.filterwarnings("ignore", category=RuntimeWarning)

DATA = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\AEMO_Data"
OUT = r"C:\Ash\_research_20261013"
PD = os.path.join(DATA, "window_120d_20260201_20260601", "predispatch_30min_VIC1.csv")
PVCSV = os.path.join(OUT, "rtpv", "rooftop_pv_forecast_vic1.csv")
N_SLOTS, WIN, FIT, CLAMP_DAYS = 288, 28, 56, 30
KEYS = ["T", "L_ar1", "L_fcdem", "L_both", "full_dem", "full_dem_pv", "pv_only", "oracle_L"]


def prev_mean(cube, i, win):
    return np.nanmean(cube[max(0, i - win):i], axis=0)


def ols(X, y):
    ok = np.isfinite(y) & np.all(np.isfinite(X), axis=1)
    if ok.sum() < 10:
        return None
    return np.linalg.lstsq(X[ok], y[ok], rcond=None)[0]


def bucket_index(dt_series):
    """30-min interval ending at dt belongs to the day starting 30 min earlier."""
    dd = (dt_series - pd.Timedelta(minutes=30)).dt.normalize()
    k = (((dt_series - dd).dt.total_seconds() // 1800) - 1).to_numpy().astype(int)
    return dd, k


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
        dd, k = bucket_index(tgt)
        ii = np.array([day_ix.get(x, -1) for x in dd])
        keep = (k >= 0) & (k < 48) & (ii >= 0)
        fc30[ii[keep], k[keep]] = chunk["total_demand"].to_numpy()[keep]
    return fc30


def load_pv(days, day_ix):
    pv30 = np.full((len(days), 48), np.nan)
    df = pd.read_csv(PVCSV, usecols=["version_datetime", "interval_datetime", "power_mean"])
    ver = pd.to_datetime(df["version_datetime"], format="%Y/%m/%d %H:%M:%S")
    df = df[(ver.dt.hour == 23) & (ver.dt.minute == 30)]
    tgt = pd.to_datetime(df["interval_datetime"], format="%Y/%m/%d %H:%M:%S")
    dd, k = bucket_index(tgt)
    ii = np.array([day_ix.get(x, -1) for x in dd])
    keep = (k >= 0) & (k < 48) & (ii >= 0)
    pv30[ii[keep], k[keep]] = df["power_mean"].to_numpy()[keep]
    return pv30


def apply_clamp(y, days):
    yc = np.empty_like(y)
    for i in range(len(days)):
        win = y[max(0, i - CLAMP_DAYS):i]
        q = np.percentile(win if win.size else y[i], [1, 99])
        yc[i] = np.clip(y[i], q[0], q[1])
    return yc


def main():
    days = [pd.Timestamp(s) for s in open(os.path.join(OUT, "days.txt"), encoding="utf-8").read().split()]
    day_ix = {d: i for i, d in enumerate(days)}
    y_raw = np.load(os.path.join(OUT, "y_cube.npy"))
    dem = np.load(os.path.join(OUT, "dem_cube.npy"))
    fc30 = load_fc(days, day_ix)
    pv30 = load_pv(days, day_ix)
    print(f"forecast demand cells {int(np.isfinite(fc30).sum())} / {fc30.size}")
    print(f"rooftop PV cells     {int(np.isfinite(pv30).sum())} / {pv30.size}")
    ok = np.isfinite(pv30).all(axis=1)
    print(f"days with a full PV day: {int(ok.sum())}")
    print(f"PV daily peak  mean {np.nanmax(pv30, axis=1)[ok].mean():.0f} MW   max {np.nanmax(pv30):.0f} MW")
    fc = np.repeat(fc30, 6, axis=1)
    pv = np.repeat(pv30, 6, axis=1)
    y = apply_clamp(y_raw, days)

    L = np.nanmean(y, axis=1)
    A = y - L[:, None]
    Ld = np.nanmean(dem, axis=1)
    Lf = np.nanmean(fc, axis=1)
    Lp = np.nanmean(pv, axis=1)

    rms = lambda x: float(np.sqrt(np.nanmean(x ** 2)))
    err = {k: np.full((len(days), N_SLOTS), np.nan) for k in KEYS}
    coef, scored = [], []
    t0 = day_ix[pd.Timestamp("2026-02-01")]
    t1 = day_ix[pd.Timestamp("2026-06-01")]

    for i in range(t0, t1):
        if not (np.isfinite(fc30[i]).all() and np.isfinite(pv30[i]).all()):
            continue
        T = prev_mean(y, i, WIN)
        Abar = prev_mean(A, i, WIN)
        Lbar = np.nanmean(L[max(0, i - WIN):i])
        Dbar = prev_mean(dem, i, WIN)
        Pbar = prev_mean(pv, i, WIN)

        jj = [j for j in range(max(WIN, i - FIT), i)
              if np.isfinite(fc30[j]).all() and np.isfinite(pv30[j]).all()]
        if len(jj) < 20:
            continue
        tgt_L = np.array([L[j] for j in jj])
        x1 = np.array([L[j - 1] for j in jj])
        x2 = np.array([Lf[j] for j in jj])
        x3 = np.array([Lp[j] for j in jj])
        xa = np.array([Ld[j] for j in jj])
        c_ar = ols(np.c_[np.ones(len(x1)), x1], tgt_L)
        c_fc = ols(np.c_[np.ones(len(x2)), x2], tgt_L)
        c_bo = ols(np.c_[np.ones(len(x1)), x1, x2], tgt_L)
        c_or = ols(np.c_[np.ones(len(xa)), xa], tgt_L)

        # pooled shape slopes on demand deviation and PV deviation
        n1 = d11 = n2 = d22 = n12 = 0.0
        for j in jj:
            dx = dem[j] - prev_mean(dem, j, WIN)
            dp = pv[j] - prev_mean(pv, j, WIN)
            dy = A[j] - prev_mean(A, j, WIN)
            n1 += np.nansum(dx * dy); d11 += np.nansum(dx * dx)
            n2 += np.nansum(dp * dy); d22 += np.nansum(dp * dp)
            n12 += np.nansum(dx * dp)
        M = np.array([[d11, n12], [n12, d22]])
        try:
            g = np.linalg.solve(M, np.array([n1, n2]))
        except np.linalg.LinAlgError:
            g = np.array([0.0, 0.0])
        coef.append((c_ar[1], c_fc[1], c_bo[1], c_bo[2], c_or[1], g[0], g[1]))

        Lhat_ar = c_ar[0] + c_ar[1] * L[i - 1]
        Lhat_fc = c_fc[0] + c_fc[1] * Lf[i]
        Lhat_bo = c_bo[0] + c_bo[1] * L[i - 1] + c_bo[2] * Lf[i]
        Lhat_or = c_or[0] + c_or[1] * Ld[i]
        shp_d = g[0] * (fc[i] - Dbar)
        shp_p = g[1] * (pv[i] - Pbar)

        err["T"][i] = y[i] - T
        err["L_ar1"][i] = y[i] - (T + (Lhat_ar - Lbar))
        err["L_fcdem"][i] = y[i] - (T + (Lhat_fc - Lbar))
        err["L_both"][i] = y[i] - (T + (Lhat_bo - Lbar))
        err["full_dem"][i] = y[i] - (T + (Lhat_bo - Lbar) + shp_d)
        err["full_dem_pv"][i] = y[i] - (T + (Lhat_bo - Lbar) + shp_d + shp_p)
        err["pv_only"][i] = y[i] - (T + shp_p)
        err["oracle_L"][i] = y[i] - (T + (L[i] - Lbar))
        scored.append(i)

    print(f"scored days {len(scored)}")
    print(f"  {'model':16s} {'RMSE':>8s}   vs T")
    base = rms(err["T"])
    for k in KEYS:
        print(f"  {k:16s} {rms(err[k]):8.2f}   {100 * (1 - rms(err[k]) / base):+7.1f}%")
    cl = np.array(coef)
    print(f"  mean coefs: b(L-1)={cl[:,0].mean():.3f}  b(fcdem)={cl[:,1].mean():.4f}"
          f"  b1={cl[:,2].mean():.3f} b2={cl[:,3].mean():.4f}"
          f"  g_demand={cl[:,5].mean():.6f}  g_pv={cl[:,6].mean():.6f}")
    print()
    print("  lead profile in 2 h blocks (RMSE $/MWh):")
    print(f"    {'hours':9s} {'T':>7s} {'full_dem':>9s} {'full_dem_pv':>12s} {'pv_only':>8s}")
    for b in range(12):
        sl = slice(b * 24, (b + 1) * 24)
        v = [rms(err[k][:, sl]) for k in ["T", "full_dem", "full_dem_pv", "pv_only"]]
        print(f"    {b*2:02d}-{b*2+2:02d}h  " + "".join(f"{x:9.1f}" if idx < 2 else f"{x:12.1f}" if idx == 2 else f"{x:9.1f}" for idx, x in enumerate(v)))
    np.save(os.path.join(OUT, "err_full_dem_pv.npy"), err["full_dem_pv"])


if __name__ == "__main__":
    main()
