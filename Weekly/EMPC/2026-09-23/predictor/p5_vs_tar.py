# -*- coding: utf-8 -*-
"""Four-way short-lead comparison: raw AEMO P5, corrected AEMO, persistence, T+AR(4).

The professor asked for exactly this: "比较原始AEMO预测、修正后AEMO预测、Persistence
和现有最佳短期模型"，按提前量分别报告 RMSE/MAE，而不是拿 288 维矩阵的最小值当总体准确率。

Inputs
  AEMO_Data/forecast_actual/error_VIC1.csv     from build_error_matrix.py
  predictor/tar_p5_forecasts.csv               from weekly_p5_compare.m

Outputs
  predictor/p5_vs_tar_report.txt
  predictor/figures/C1..C2.png
"""

import io
import json
import os

os.environ.setdefault("MPLCONFIGDIR",
                      os.path.join(os.path.dirname(os.path.abspath(__file__)), "_mplcache"))
import matplotlib                       # noqa: E402
matplotlib.use("Agg")
import matplotlib.pyplot as plt         # noqa: E402
import numpy as np                      # noqa: E402
import pandas as pd                     # noqa: E402

PROJECT = r"C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project"
FA = os.path.join(PROJECT, "AEMO_Data", "forecast_actual")
PRED = os.path.join(PROJECT, "Weekly", "EMPC", "2026-09-23", "predictor")
FIGDIR = os.path.join(PRED, "figures")
REPORT = os.path.join(PRED, "p5_vs_tar_report.txt")
TRAIN_FRAC = 0.70
LAGS = (0, 1, 2, 3)
os.makedirs(FIGDIR, exist_ok=True)

buf = io.StringIO()


def say(fmt="", *args):
   buf.write((fmt % args if args else fmt) + "\n")


def flush():
   with open(REPORT, "w", encoding="utf-8", newline="\n") as fh:
      fh.write(buf.getvalue())


err_path = os.path.join(FA, "error_VIC1.csv")
tar_path = os.path.join(PRED, "tar_p5_forecasts.csv")
if not os.path.exists(tar_path):
   raise SystemExit("missing %s - run weekly_p5_compare.m first" % tar_path)

E = pd.read_csv(err_path, parse_dates=["k_i", "k"])
T = pd.read_csv(tar_path, parse_dates=["origin", "target"])

say("=" * 88)
say("四路对照：原始 AEMO P5 / 修正后 AEMO / Persistence / Template+AR(4)")
say("=" * 88)
say("")
say("误差矩阵 %d 行 ｜ T+AR 结果 %d 行", len(E), len(T))

# ---- realised error series and its lags ------------------------------------
eps = E[E["h"] == 0][["k_i", "e"]].rename(columns={"e": "eps"}).sort_values("k_i")
eps = eps.set_index("k_i")["eps"]

M = T.copy()
M["origin"] = pd.to_datetime(M["origin"])
M["h"] = M["h"].astype(int)
M["eps0"] = M["origin"].map(eps)
for lag in LAGS[1:]:
   shifted = eps.copy()
   shifted.index = shifted.index + pd.Timedelta(minutes=5 * lag)
   M["eps_lag%d" % lag] = M["origin"].map(shifted)
feat = ["eps0"] + ["eps_lag%d" % l for l in LAGS[1:]]
M = M.dropna(subset=feat + ["y", "y_aemo", "y_tar", "y_pers"])

origins = np.array(sorted(M["origin"].unique()))
split_at = origins[int(len(origins) * TRAIN_FRAC)]
train = M["origin"] < split_at
test = ~train
say("配对成功 %d 行 ｜ 训练起源 %s .. %s ｜ 测试起源 %s .. %s",
    len(M), origins[0], split_at - pd.Timedelta(minutes=5), split_at, origins[-1])
say("测试集 %d 行", int(test.sum()))

say("")
say("按提前量的 RMSE（$/MWh，测试集）")
say("%3s %6s %7s %10s %10s %10s %10s %10s %9s %9s" %
    ("h", "min", "n", "rawAEMO", "corrected", "persist", "T+AR(4)", "template",
     "corr vs raw", "TAR vs raw"))
rows = []
for h in sorted(M["h"].unique()):
   tr = M[(M["h"] == h) & train]
   te = M[(M["h"] == h) & test]
   if len(tr) < 80 or len(te) < 30:
      continue
   Xtr = np.column_stack([np.ones(len(tr))] + [tr[c].values for c in feat])
   coef, *_ = np.linalg.lstsq(Xtr, (tr["y"] - tr["y_aemo"]).values, rcond=None)
   Xte = np.column_stack([np.ones(len(te))] + [te[c].values for c in feat])
   y_corr = te["y_aemo"].values + Xte @ coef

   def rmse(a):
      return float(np.sqrt(np.mean((te["y"].values - a) ** 2)))

   r_raw, r_cor = rmse(te["y_aemo"].values), rmse(y_corr)
   r_per, r_tar = rmse(te["y_pers"].values), rmse(te["y_tar"].values)
   r_tpl = rmse(te["y_tpl"].values)
   mae = lambda a: float(np.mean(np.abs(te["y"].values - a)))      # noqa: E731
   rows.append((h, len(te), r_raw, r_cor, r_per, r_tar, r_tpl,
                100.0 * (1 - r_cor / r_raw), 100.0 * (1 - r_tar / r_raw),
                mae(te["y_aemo"].values), mae(y_corr), mae(te["y_pers"].values),
                mae(te["y_tar"].values)))
   r = rows[-1]
   say("%3d %6d %7d %10.2f %10.2f %10.2f %10.2f %10.2f %+9.2f%% %+9.2f%%" %
       (r[0], r[0] * 5, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8]))
cm = pd.DataFrame(rows, columns=["h", "n", "raw", "corr", "pers", "tar", "tpl",
                                 "corr_gain", "tar_gain", "mae_raw", "mae_corr",
                                 "mae_pers", "mae_tar"])
if not cm.empty:
   say("")
   say("按提前量的 MAE（$/MWh，测试集）")
   say("%3s %6s %10s %10s %10s %10s" % ("h", "min", "rawAEMO", "corrected",
                                        "persist", "T+AR(4)"))
   for _, r in cm.iterrows():
      say("%3d %6d %10.2f %10.2f %10.2f %10.2f" %
          (r["h"], r["h"] * 5, r["mae_raw"], r["mae_corr"], r["mae_pers"], r["mae_tar"]))

if not cm.empty:
   plt.rcParams.update({
      "figure.dpi": 130, "savefig.dpi": 130, "font.size": 9,
      "axes.grid": True, "grid.alpha": 0.3, "axes.spines.top": False,
      "axes.spines.right": False, "legend.frameon": False,
   })
   x = cm["h"] * 5
   fig, ax = plt.subplots(1, 2, figsize=(11, 3.9))
   ax[0].plot(x, cm["raw"], "-o", color="#c0392b", lw=1, ms=3, label="raw AEMO P5")
   ax[0].plot(x, cm["corr"], "-s", color="#16a085", lw=1, ms=3, label="corrected AEMO")
   ax[0].plot(x, cm["pers"], "--", color="0.45", lw=1, label="persistence (carry forward)")
   ax[0].plot(x, cm["tar"], "-^", color="#1e2761", lw=1, ms=3, label="Template + AR(4)")
   ax[0].plot(x, cm["tpl"], ":", color="#8e44ad", lw=1, label="rolling template")
   ax[0].set_xlabel("Lead time (min)")
   ax[0].set_ylabel("RMSE ($/MWh)")
   ax[0].set_title("Short-lead skill, VIC1 (test split)")
   ax[0].legend(fontsize=8)
   ax[1].bar(x - 1.1, cm["corr_gain"], width=1.7, color="#16a085",
             label="corrected AEMO vs raw AEMO")
   ax[1].bar(x + 0.7, cm["tar_gain"], width=1.7, color="#1e2761",
             label="T+AR(4) vs raw AEMO")
   ax[1].axhline(0, color="0.3", lw=1)
   ax[1].set_xlabel("Lead time (min)")
   ax[1].set_ylabel("RMSE change vs raw AEMO (%)")
   ax[1].set_title("Who beats AEMO's own forecast?")
   ax[1].legend(fontsize=8)
   fig.tight_layout()
   fig.savefig(os.path.join(FIGDIR, "C1_four_way_short_lead.png"))
   plt.close(fig)

   # best model per lead
   say("")
   say("每个提前量的赢家：")
   for _, r in cm.iterrows():
      cand = {"raw AEMO": r["raw"], "corrected AEMO": r["corr"],
              "persistence": r["pers"], "T+AR(4)": r["tar"],
              "template": r["tpl"]}
      best = min(cand, key=cand.get)
      say("   %2d min : %-16s %.2f $/MWh", r["h"] * 5, best, cand[best])

   with open(os.path.join(PRED, "p5_vs_tar.json"), "w", encoding="utf-8") as fh:
      json.dump({"n_test": int(test.sum()),
                 "train_period": [str(origins[0]), str(split_at)],
                 "test_period": [str(split_at), str(origins[-1])],
                 "by_lead": cm.to_dict(orient="records")}, fh,
                indent=1, ensure_ascii=False)
flush()
print("wrote", REPORT)
