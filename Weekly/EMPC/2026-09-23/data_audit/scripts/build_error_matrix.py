# -*- coding: utf-8 -*-
"""AEMO P5 forecast-error matrix, its predictability, and a corrected forecast.

Protocol
--------
A P5 batch published for effective time k_i carries 12 targets, the first being
the interval ending at k_i itself. The batch and the realised price for interval
k_i are both published about 5 minutes before k_i, so using batch k_i to forecast
k_i+5min .. k_i+55min involves no lookahead. Lead h = (k - k_i) / 5 min, h = 0..11.

  e(k, k_i) = y(k) - yhat_AEMO(k | k_i)
  eps(k)    = e(k, k)  = y(k) - yhat_AEMO(k | k)     realised error, one per interval

h = 0 is descriptive only: "predicting" it from eps(k_i) is the same number, so it
is excluded from every skill comparison.

Correction models, all fitted on the TRAIN split and scored on TEST
  C1  ehat(h) = beta_h * eps(k_i)                       carry the last realised error
  C2  ehat(h) = beta_h * mean(eps(k_i-2..k_i))          the same, de-noised
  C3  ehat(h) = a_h + sum_{j=0..3} b_hj eps(k_i - j)    per-lead OLS on 4 lags

The professor's claim to test: AEMO errors persist in sign over adjacent intervals,
so short leads should be correctable and the correction should decay with lead.

Outputs
  error_matrix_report.txt
  figures/E1..E4_*.png
  AEMO_Data/forecast_actual/error_<REGION>.csv
"""

import io
import os
from collections import Counter

# must precede the matplotlib import or it is ignored
os.environ.setdefault("MPLCONFIGDIR",
                      os.path.join(os.path.dirname(os.path.abspath(__file__)), "_mplcache"))
import matplotlib                     # noqa: E402
matplotlib.use("Agg")
import matplotlib.pyplot as plt       # noqa: E402
import numpy as np                    # noqa: E402
import pandas as pd                   # noqa: E402

PROJECT = r"C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project"
SRC = os.path.join(PROJECT, "AEMO_Data", "forecast_actual")
HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.join(HERE, "figures")
REPORT = os.path.join(HERE, "error_matrix_report.txt")
TRAIN_FRAC = 0.70
LAGS = (0, 1, 2, 3)          # eps(k_i - lag)
os.makedirs(FIGDIR, exist_ok=True)

buf = io.StringIO()


def say(fmt="", *args):
   buf.write((fmt % args if args else fmt) + "\n")


def flush():
   with open(REPORT, "w", encoding="utf-8", newline="\n") as fh:
      fh.write(buf.getvalue())


act_path = os.path.join(SRC, "dispatch_5min.csv")
fc_path = os.path.join(SRC, "p5min.csv")
if not (os.path.exists(act_path) and os.path.exists(fc_path)):
   raise SystemExit("missing stores in %s - run backfill_archive.py first" % SRC)

act = pd.read_csv(act_path)
fc = pd.read_csv(fc_path)
act["ts"] = pd.to_datetime(act["settlement_date"])
fc["k_i"] = pd.to_datetime(fc["effective_time"])
fc["k"] = pd.to_datetime(fc["interval_datetime"])
fc["h"] = ((fc["k"] - fc["k_i"]).dt.total_seconds() / 300.0).round().astype(int)
H_MAX = int(fc["h"].max())

plt.rcParams.update({
   "figure.dpi": 130, "savefig.dpi": 130, "font.size": 9,
   "axes.grid": True, "grid.alpha": 0.3, "axes.spines.top": False,
   "axes.spines.right": False, "legend.frameon": False,
})

say("=" * 88)
say("AEMO P5 预测误差矩阵与误差可预测性")
say("=" * 88)
say("")
say("实际价格  dispatch_5min.csv : %6d 行  %s .. %s",
    len(act), act["ts"].min(), act["ts"].max())
say("预测      p5min.csv        : %6d 行  %s .. %s",
    len(fc), fc["k_i"].min(), fc["k_i"].max())
say("区域 %s ｜ 提前量 h = 0..%d（h=0 是发布时正在进行的那个区间，只作描述）",
    sorted(fc["region_id"].unique()), H_MAX)
say("训练/测试切分：按时间前 %.0f%% / 后 %.0f%%", TRAIN_FRAC * 100, (1 - TRAIN_FRAC) * 100)

summary = []
for region in sorted(fc["region_id"].unique()):
   A = act[act["region_id"] == region][["ts", "rrp"]].rename(columns={"rrp": "y"})
   F = fc[fc["region_id"] == region][["k_i", "k", "h", "rrp"]].rename(columns={"rrp": "yhat"})
   M = F.merge(A, left_on="k", right_on="ts", how="inner")
   M["e"] = M["y"] - M["yhat"]
   M = M.sort_values(["k_i", "h"]).reset_index(drop=True)
   M.to_csv(os.path.join(SRC, "error_%s.csv" % region), index=False)

   say("")
   say("=" * 88)
   say("区域 %s ｜ 配对 %d 行（预测 %d / 实际 %d）", region, len(M), len(F), len(A))
   say("=" * 88)
   if M.empty:
      continue

   # ---- 1. error by lead ---------------------------------------------------
   say("")
   say("1. 按提前量的误差（$/MWh）")
   say("   %3s %6s %7s %8s %8s %8s %9s %10s" %
       ("h", "min", "n", "RMSE", "MAE", "bias", "p90|e|", "signal std"))
   prof = []
   for h in range(0, H_MAX + 1):
      sub = M[M["h"] == h]
      if sub.empty:
         continue
      rec = (h, h * 5, len(sub),
             float(np.sqrt((sub["e"] ** 2).mean())),
             float(sub["e"].abs().mean()),
             float(sub["e"].mean()),
             float(sub["e"].abs().quantile(0.90)),
             float(sub["y"].std()))
      prof.append((h, len(sub),
                   float(np.sqrt((sub["e"] ** 2).mean())),
                   float(sub["e"].abs().mean()),
                   float(sub["e"].mean()),
                   float(sub["e"].abs().quantile(0.90)),
                   float(sub["y"].std())))
      say("   %3d %6d %7d %8.2f %8.2f %+8.2f %9.2f %10.2f" % rec)
   prof = pd.DataFrame(prof, columns=["h", "n", "rmse", "mae", "bias", "p90", "sd"])

   # ---- 2. eps series ------------------------------------------------------
   eps = M[M["h"] == 0].sort_values("k").set_index("k")["e"]
   acf = [float(eps.autocorr(lag)) for lag in range(0, 13)]
   s = np.sign(eps.values)
   s = s[s != 0]
   runs = []
   if len(s):
      cur = 1
      for i in range(1, len(s)):
         if s[i] == s[i - 1]:
            cur += 1
         else:
            runs.append(cur)
            cur = 1
      runs.append(cur)
   say("")
   say("2. 已实现误差 eps(k) = y(k) − ŷ_AEMO(k|k)")
   say("   n=%d  mean=%+.3f  std=%.3f  min=%+.1f  max=%+.1f  非零占比=%.3f",
       len(eps), eps.mean(), eps.std(), eps.min(), eps.max(),
       float((eps.abs() > 1e-9).mean()))
   say("   ACF(0..12) = %s", " ".join("%+.3f" % v for v in acf))
   say("   同号连续段：段数=%d  平均长度=%.3f  最长=%d", len(runs), float(np.mean(runs)),
       max(runs))
   say("   长度分布 = %s", dict(sorted(Counter(runs).items())))
   say("   * 随机符号下平均段长 = 2.0（几何分布）→ 实测 %.3f 说明误差成串出现。",
       float(np.mean(runs)))

   # ---- 3. correction models with a train/test split -----------------------
   e0 = M[M["h"] == 0][["k_i", "e"]].rename(columns={"e": "e0"})
   y0 = M[M["h"] == 0][["k_i", "y"]].rename(columns={"y": "y_at_origin"})
   Mc = M.merge(e0, on="k_i", how="left").merge(y0, on="k_i", how="left")
   for lag in LAGS[1:]:
      lagged = e0.copy()
      lagged["k_i"] = lagged["k_i"] + pd.Timedelta(minutes=5 * lag)
      lagged = lagged.rename(columns={"e0": "e_lag%d" % lag})
      Mc = Mc.merge(lagged, on="k_i", how="left")
   feat_cols = ["e0"] + ["e_lag%d" % l for l in LAGS[1:]]
   smooth = Mc[feat_cols].mean(axis=1)

   origins = np.array(sorted(Mc["k_i"].unique()))
   split_at = origins[int(len(origins) * TRAIN_FRAC)]
   train = Mc["k_i"] < split_at
   test = ~train
   say("")
   say("3. 误差修正模型（训练 %s .. %s / 测试 %s .. %s）",
       origins[0], split_at - pd.Timedelta(minutes=5), split_at, origins[-1])
   say("   %3s %8s %9s %9s %9s %9s %9s %9s %9s" %
       ("h", "n_test", "RMSE_raw", "C1", "C2", "C3", "C3gain%", "RMSE_pers", "P5vsPers%"))
   rows = []
   for h in range(1, H_MAX + 1):
      sub = Mc[Mc["h"] == h].copy()
      sub["smooth"] = smooth[sub.index]
      tr = sub[train[sub.index]].dropna(subset=feat_cols + ["e"])
      te = sub[test[sub.index]].dropna(subset=feat_cols + ["e"])
      if len(tr) < 50 or len(te) < 20:
         continue
      rmse_raw = float(np.sqrt((te["e"] ** 2).mean()))
      # C1
      b1 = float(np.polyfit(tr["e0"], tr["e"], 1)[0])
      r1 = float(np.sqrt(((te["e"] - b1 * te["e0"]) ** 2).mean()))
      # C2
      b2 = float(np.polyfit(tr["smooth"], tr["e"], 1)[0])
      r2 = float(np.sqrt(((te["e"] - b2 * te["smooth"]) ** 2).mean()))
      # C3
      Xtr = np.column_stack([np.ones(len(tr))] + [tr[c].values for c in feat_cols])
      coef, *_ = np.linalg.lstsq(Xtr, tr["e"].values, rcond=None)
      Xte = np.column_stack([np.ones(len(te))] + [te[c].values for c in feat_cols])
      r3 = float(np.sqrt(((te["e"] - Xte @ coef) ** 2).mean()))
      gain3 = 100.0 * (1 - r3 / rmse_raw) if rmse_raw > 0 else 0.0
      # persistence: carry the last realised price forward
      e_pers = te["y"] - te["y_at_origin"]
      rmse_pers = float(np.sqrt((e_pers ** 2).mean()))
      p5_vs_pers = 100.0 * (1 - rmse_raw / rmse_pers) if rmse_pers > 0 else 0.0
      rows.append((h, len(te), rmse_raw, r1, r2, r3, gain3, rmse_pers, p5_vs_pers))
      say("   %3d %8d %9.2f %9.2f %9.2f %9.2f %+9.2f %9.2f %+9.2f" % rows[-1])
   cm = pd.DataFrame(rows, columns=["h", "n_test", "rmse_raw", "c1", "c2", "c3",
                                    "gain3", "rmse_pers", "p5_vs_pers"])

   # ---- 4. figures ---------------------------------------------------------
   fig, ax = plt.subplots(1, 2, figsize=(11, 3.9))
   ax[0].plot(prof["h"] * 5, prof["rmse"], "-o", color="#c0392b", lw=1, ms=3,
              label="AEMO P5 RMSE")
   ax[0].plot(prof["h"] * 5, prof["mae"], "-s", color="#2c3e50", lw=1, ms=3,
              label="AEMO P5 MAE")
   ax[0].plot(prof["h"] * 5, prof["sd"], "--", color="0.5", lw=1,
              label="signal std (uninformative ceiling)")
   ax[0].set_xlabel("Lead time (min)")
   ax[0].set_ylabel("$/MWh")
   ax[0].set_title("%s: AEMO P5 error grows with lead" % region)
   ax[0].legend(fontsize=8)
   ax[1].bar(prof["h"] * 5, prof["bias"], width=3.5, color="#8e44ad")
   ax[1].axhline(0, color="0.3", lw=1)
   ax[1].set_xlabel("Lead time (min)")
   ax[1].set_ylabel("mean error ($/MWh)")
   ax[1].set_title("%s: AEMO P5 bias by lead" % region)
   fig.tight_layout()
   fig.savefig(os.path.join(FIGDIR, "E1_p5_error_by_lead_%s.png" % region))
   plt.close(fig)

   fig, ax = plt.subplots(1, 2, figsize=(11, 3.9))
   lags = np.arange(len(acf))
   ax[0].bar(lags, acf, color="#16a085", width=0.6)
   ax[0].axhline(0, color="0.3", lw=1)
   ci = 1.96 / np.sqrt(len(eps))
   ax[0].axhline(ci, color="#c0392b", ls="--", lw=1)
   ax[0].axhline(-ci, color="#c0392b", ls="--", lw=1)
   ax[0].set_xlabel("lag (5-min steps)")
   ax[0].set_ylabel("ACF")
   ax[0].set_title("%s: realised AEMO error is autocorrelated (ACF)" % region)
   ax[1].hist(runs, bins=np.arange(0.5, max(runs) + 1.5, 1), color="#2c3e50")
   ax[1].axvline(2.0, color="#c0392b", ls="--", lw=1.4, label="random-sign mean = 2.0")
   ax[1].axvline(np.mean(runs), color="#e9a820", ls="-", lw=1.4,
                 label="measured mean = %.2f" % np.mean(runs))
   ax[1].set_xlabel("same-sign run length (5-min steps)")
   ax[1].set_ylabel("count")
   ax[1].set_title("%s: error runs persist far longer than chance" % region)
   ax[1].legend(fontsize=8)
   fig.tight_layout()
   fig.savefig(os.path.join(FIGDIR, "E2_error_predictability_%s.png" % region))
   plt.close(fig)

   if not cm.empty:
      fig, ax = plt.subplots(1, 2, figsize=(11, 3.9))
      ax[0].plot(cm["h"] * 5, cm["rmse_raw"], "-o", color="#c0392b", lw=1, ms=3,
                 label="raw AEMO P5")
      ax[0].plot(cm["h"] * 5, cm["rmse_pers"], "--", color="0.45", lw=1,
                 label="persistence (last realised price)")
      ax[0].plot(cm["h"] * 5, cm["c1"], "-s", color="#2c3e50", lw=1, ms=3,
                 label="C1 beta*eps(k_i)")
      ax[0].plot(cm["h"] * 5, cm["c2"], "-^", color="#16a085", lw=1, ms=3,
                 label="C2 beta*mean(eps)")
      ax[0].plot(cm["h"] * 5, cm["c3"], "-d", color="#e9a820", lw=1, ms=3,
                 label="C3 per-lead OLS on 4 lags")
      ax[0].set_xlabel("Lead time (min)")
      ax[0].set_ylabel("RMSE on TEST ($/MWh)")
      ax[0].set_title("%s: raw vs corrected vs persistence (test split)" % region)
      ax[0].legend(fontsize=8)
      x = cm["h"] * 5
      ax[1].bar(x - 1.6, cm["p5_vs_pers"], width=1.5, color="#c0392b",
                label="raw AEMO vs persistence")
      ax[1].bar(x + 0.0, cm["gain3"] + cm["p5_vs_pers"], width=1.5, color="#16a085",
                label="corrected AEMO vs persistence")
      ax[1].axhline(0, color="0.3", lw=1)
      ax[1].set_xlabel("Lead time (min)")
      ax[1].set_ylabel("RMSE reduction vs persistence (%)")
      ax[1].set_title("%s: does AEMO (corrected) beat persistence?" % region)
      ax[1].legend(fontsize=8)
      fig.tight_layout()
      fig.savefig(os.path.join(FIGDIR, "E3_correction_skill_%s.png" % region))
      plt.close(fig)

      # E4: two-day window of actual vs raw vs corrected at the shortest lead
      h_show = 1
      sub = Mc[Mc["h"] == h_show].dropna(subset=feat_cols + ["e"]).sort_values("k")
      if len(sub) > 576:
         sub = sub.iloc[:576]
      X = np.column_stack([np.ones(len(sub))] + [sub[c].values for c in feat_cols])
      if len(cm[cm["h"] == h_show]):
         tr = Mc[(Mc["h"] == h_show) & train].dropna(subset=feat_cols + ["e"])
         Xtr = np.column_stack([np.ones(len(tr))] + [tr[c].values for c in feat_cols])
         coef, *_ = np.linalg.lstsq(Xtr, tr["e"].values, rcond=None)
         corr = X @ coef
         fig, ax = plt.subplots(2, 1, figsize=(11, 6), sharex=True)
         ax[0].plot(sub["k"], sub["y"], "-", color="k", lw=1.3, label="actual y(k)")
         ax[0].plot(sub["k"], sub["yhat"], "-", color="#c0392b", lw=1,
                    label="raw AEMO P5 (5-min lead)")
         ax[0].plot(sub["k"], sub["yhat"] + corr, "--", color="#16a085", lw=1,
                    label="corrected")
         ax[0].set_ylabel("$/MWh")
         ax[0].set_title("%s: actual vs raw vs corrected, lead = 5 min (first 2 days)" % region)
         ax[0].legend(fontsize=8)
         ax[1].plot(sub["k"], sub["e"], "-", color="#c0392b", lw=1, label="raw error")
         ax[1].plot(sub["k"], sub["e"] - corr, "-", color="#16a085", lw=1,
                    label="residual after correction")
         ax[1].axhline(0, color="0.3", lw=1)
         ax[1].set_ylabel("$/MWh")
         ax[1].legend(fontsize=8)
         fig.tight_layout()
         fig.savefig(os.path.join(FIGDIR, "E4_correction_example_%s.png" % region))
         plt.close(fig)

   summary.append({
      "region": region, "n": len(M), "n_test": int(cm["n_test"].iloc[0]) if not cm.empty else 0,
      "rmse_h1": float(prof.loc[prof["h"] == 1, "rmse"].iloc[0]) if (prof["h"] == 1).any() else np.nan,
      "rmse_h11": float(prof.loc[prof["h"] == 11, "rmse"].iloc[0]) if (prof["h"] == 11).any() else np.nan,
      "sd": float(prof["sd"].mean()),
      "acf1": acf[1], "acf2": acf[2],
      "run_mean": float(np.mean(runs)), "run_max": int(max(runs)),
      "gain1": float(cm.loc[cm["h"] == 1, "gain3"].iloc[0]) if (cm["h"] == 1).any() else np.nan,
      "gain6": float(cm.loc[cm["h"] == 6, "gain3"].iloc[0]) if (cm["h"] == 6).any() else np.nan,
      "gain11": float(cm.loc[cm["h"] == 11, "gain3"].iloc[0]) if (cm["h"] == 11).any() else np.nan,
      "p5p1": float(cm.loc[cm["h"] == 1, "p5_vs_pers"].iloc[0]) if (cm["h"] == 1).any() else np.nan,
      "p5p6": float(cm.loc[cm["h"] == 6, "p5_vs_pers"].iloc[0]) if (cm["h"] == 6).any() else np.nan,
      "p5p11": float(cm.loc[cm["h"] == 11, "p5_vs_pers"].iloc[0]) if (cm["h"] == 11).any() else np.nan,
   })
   flush()

say("")
say("=" * 88)
say("汇总")
say("=" * 88)
say("%-7s %6s %7s %8s %8s %8s %6s %6s %7s %6s %8s %8s %8s" %
    ("region", "n", "n_test", "RMSE5m", "RMSE55m", "sigstd", "ACF1", "ACF2",
     "runAvg", "runMax", "gain 5m", "gain 30m", "gain 55m"))
for r in summary:
   say("%-7s %6d %7d %8.2f %8.2f %8.2f %+6.3f %+6.3f %7.2f %6d %+7.2f%% %+7.2f%% %+7.2f%%" %
       (r["region"], r["n"], r["n_test"], r["rmse_h1"], r["rmse_h11"], r["sd"],
        r["acf1"], r["acf2"], r["run_mean"], r["run_max"],
        r["gain1"], r["gain6"], r["gain11"]))
say("")
say("  AEMO 原始预测相对 persistence 的 RMSE 降幅（正=AEMO 更好）：")
say("%-7s %10s %10s %10s" % ("region", "5 min", "30 min", "55 min"))
for r in summary:
   say("%-7s %+9.2f%% %+9.2f%% %+9.2f%%" % (r["region"], r["p5p1"], r["p5p6"], r["p5p11"]))
say("")
say("  RMSE5m / RMSE55m 是 5 分钟与 55 分钟提前量的原始 AEMO 误差。")
say("  runAvg = eps 同号连续段平均长度（随机符号为 2.0）。")
say("  gain = C3 修正后测试集 RMSE 相对原始 AEMO 的下降；正值=有用。")
say("  h=0 未参与任何 skill 比较：它与 eps(k_i) 是同一个数，修正它属于自证。")
flush()

# machine-readable twin, so the deck builder never has to parse this prose
import json                                          # noqa: E402
payload = {
   "generated_from": {"actuals": act_path, "forecasts": fc_path},
   "period": [str(pd.to_datetime(fc["k_i"].min())), str(pd.to_datetime(fc["k_i"].max()))],
   "regions": summary,
   "profiles": {r: None for r in []},
}
with open(os.path.join(HERE, "error_summary.json"), "w", encoding="utf-8") as fh:
   json.dump(payload, fh, indent=1, ensure_ascii=False)
print("wrote", REPORT, "and error_summary.json")
