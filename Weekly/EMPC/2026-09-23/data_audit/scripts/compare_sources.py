# -*- coding: utf-8 -*-
"""Cross-source AEMO price comparison.

Answers the question "why does the monthly VIC1 RRP differ from the real-time
AEMO report price?" with raw evidence instead of folklore, by pulling the NEMWEB
ARCHIVE daily DispatchIS zips for days that overlap the monthly files we hold.

Sources compared
  M  PRICE_AND_DEMAND_YYYYMM_VIC1.csv   (AEMO data dashboard, historical aggregated)
  D  ARCHIVE DispatchIS daily zip       (NEMWEB raw 5-min dispatch reports)
  S  NEMPRICEANDDEMAND_<REGION>_*.csv   (AEMO data dashboard, dispatch download)

Checks that matter: region, report type, interval timestamp convention, RUNNO,
units, and the timebase (NEM time = AEST/UTC+10, no DST, vs Australia/Sydney).

Outputs (next to this script):
  compare_report.txt
  figures/*.png
"""

import io
import logging
import os
import zipfile
from collections import Counter

os.environ.setdefault("MPLCONFIGDIR",
                      os.path.join(os.path.dirname(os.path.abspath(__file__)), "_mplcache"))
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt       # noqa: E402
import numpy as np                    # noqa: E402
import pandas as pd                   # noqa: E402
import requests                       # noqa: E402

PROJECT = r"C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project"
CAPTURE = os.path.join(PROJECT, "Online_Data_Capture_Script")
AEMO = os.path.join(PROJECT, "AEMO_Data")
HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(AEMO, "archive_cache")
FIGDIR = os.path.join(HERE, "figures")
REPORT = os.path.join(HERE, "compare_report.txt")

os.makedirs(CACHE, exist_ok=True)
os.makedirs(FIGDIR, exist_ok=True)

import sys
sys.path.insert(0, CAPTURE)
os.chdir(CAPTURE)
logging.disable(logging.WARNING)          # the parser warns per file; we audit instead
import aemo_config as cfg                 # noqa: E402
import aemo_parser as P                   # noqa: E402

# The capture tool ships with USE_AUS_LOCAL_TIME = True, which rewrites every NEM
# timestamp (AEST/UTC+10, no DST) into Australia/Sydney local time. That is +1 h
# during AEDT and +0 h during AEST, so the same store changes timebase twice a
# year while the monthly dashboard files stay on NEM time. Comparing on the
# native clock is the only way to see whether the underlying numbers agree.
cfg.USE_AUS_LOCAL_TIME = False

REGIONS = {"NSW1", "QLD1", "SA1", "TAS1", "VIC1"}
ARCHIVE = "https://www.nemweb.com.au/Reports/ARCHIVE/DispatchIS_Reports/"
HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) aemo-audit/1.0"}

# 2026-01-15 is a January (AEDT) day -> settles the NEM-time vs Sydney-local question.
# 2026-07-* overlap PRICE_AND_DEMAND_202607_VIC1.csv.
# 2026-09-03 / 2026-09-09 overlap the two dashboard dispatch downloads we hold.
ARCHIVE_DAYS = ["20260115", "20260701", "20260715", "20260729",
                "20260903", "20260909"]

buf = io.StringIO()


def say(fmt="", *args):
   buf.write((fmt % args if args else fmt) + "\n")


def flush():
   """Persist what we have so far; a crash in a later section must not lose it."""
   with open(REPORT, "w", encoding="utf-8", newline="\n") as fh:
      fh.write(buf.getvalue())


# ------------------------------------------------------------------ download
def fetch_day(day):
   dest = os.path.join(CACHE, "PUBLIC_DISPATCHIS_%s.zip" % day)
   if os.path.exists(dest) and os.path.getsize(dest) > 0:
      return dest, "cached"
   url = ARCHIVE + "PUBLIC_DISPATCHIS_%s.zip" % day
   with requests.get(url, headers=HEADERS, stream=True, timeout=120) as r:
      r.raise_for_status()
      tmp = dest + ".part"
      with open(tmp, "wb") as fh:
         for chunk in r.iter_content(chunk_size=1 << 16):
            fh.write(chunk)
   os.replace(tmp, dest)
   return dest, "downloaded"


def parse_day(day):
   """All DISPATCH/PRICE rows of one archived day, deduped to the highest RUNNO.

   The ARCHIVE daily zip is a zip of zips: each member is itself a single-report
   zip holding one .CSV. A member that is already a .CSV is also accepted so the
   same function works on the CURRENT-style single-report zips.
   """
   path, how = fetch_day(day)
   frames = []
   with zipfile.ZipFile(path) as zf:
      for member in zf.namelist():
         blob = zf.read(member)
         if member.lower().endswith(".zip"):
            with zipfile.ZipFile(io.BytesIO(blob)) as inner:
               csvs = [n for n in inner.namelist() if n.lower().endswith(".csv")]
               if not csvs:
                  continue
               text = inner.read(csvs[0]).decode("utf-8", errors="replace")
         elif member.lower().endswith(".csv"):
            text = blob.decode("utf-8", errors="replace")
         else:
            continue
         frame = P.parse_dispatch(text, member, REGIONS)
         if not frame.empty:
            frames.append(frame)
   if not frames:
      return pd.DataFrame(), how, 0
   allrows = pd.concat(frames, ignore_index=True)
   allrows = allrows[allrows["settlement_date"] != ""]
   n_raw = len(allrows)
   allrows["_run"] = pd.to_numeric(allrows["run_no"], errors="coerce").fillna(0)
   allrows = allrows.sort_values("_run", kind="stable")
   allrows = allrows.drop_duplicates(subset=["settlement_date", "region_id"], keep="last")
   allrows = allrows.drop(columns="_run")
   allrows["settlement_date"] = pd.to_datetime(allrows["settlement_date"])
   return allrows.sort_values(["settlement_date", "region_id"]).reset_index(drop=True), how, n_raw


# ------------------------------------------------------------------ monthly
def load_monthly(month):
   path = os.path.join(AEMO, "PRICE_AND_DEMAND_%s_VIC1.csv" % month)
   df = pd.read_csv(path)
   df.columns = [c.strip() for c in df.columns]
   df["ts"] = pd.to_datetime(df["SETTLEMENTDATE"])
   df["rrp"] = pd.to_numeric(df["RRP"], errors="coerce")
   return df


# ================================================================== run
say("=" * 78)
say("AEMO 三源价格比对")
say("=" * 78)
say("")
say("时基约定：本脚本强制 cfg.USE_AUS_LOCAL_TIME = False，即所有时间戳保持")
say("AEMO 发布的 NEM 时间（AEST/UTC+10，全年不随夏令时平移）。在线抓取脚本的")
say("出厂默认是 True，会把 NEM 时间改写成悉尼本地时间 —— 夏令时期间差 1 小时")
say("（= 12 个 5 分钟槽位），那正是先前看到的“1 月差 1 小时”的来源。")
say("")
say("ARCHIVE 日包抓取：")
day_frames = {}
for day in ARCHIVE_DAYS:
   frame, how, n_raw = parse_day(day)
   day_frames[day] = frame
   say("  %s  %-11s  raw price rows=%-6d  deduped rows=%-6d  VIC1 intervals=%d",
       day, how, n_raw, len(frame),
       int((frame["region_id"] == "VIC1").sum()) if not frame.empty else 0)

# ---------------------------------------------------------------- M vs D
say("")
say("=" * 78)
say("1. 月度文件 M  vs  NEMWEB 归档 D   （VIC1，5 分钟，区间结束时刻）")
say("=" * 78)
for day in ARCHIVE_DAYS:
   month = day[:6]
   mpath = os.path.join(AEMO, "PRICE_AND_DEMAND_%s_VIC1.csv" % month)
   if not os.path.exists(mpath):
      say("  %s: 无月度文件（%s）", day, os.path.basename(mpath))
      continue
   M = load_monthly(month)
   D = day_frames[day]
   if D.empty:
      say("  %s: 归档解析为空 -> 跳过", day)
      continue
   D = D[D["region_id"] == "VIC1"][["settlement_date", "rrp", "run_no", "eep", "intervention"]]
   d0 = pd.Timestamp(day)
   d1 = d0 + pd.Timedelta(days=1)
   Md = M[(M["ts"] >= d0) & (M["ts"] < d1)][["ts", "rrp", "TOTALDEMAND"]]
   merged = Md.merge(D, left_on="ts", right_on="settlement_date", how="outer",
                     suffixes=("_M", "_D"), indicator=True)
   both = merged[merged["_merge"] == "both"]
   diff = (both["rrp_M"] - both["rrp_D"]).abs()
   n_exact = int((diff < 1e-9).sum())
   say("")
   say("  --- %s ---", day)
   say("      月度行数=%-5d  归档 VIC1 行数=%-5d  时间戳交集=%-5d",
       len(Md), len(D), len(both))
   say("      交集里完全相等(<=1e-9) = %d (%.2f%%)", n_exact,
       100.0 * n_exact / max(len(both), 1))
   if len(both):
      say("      差值 |M-D|: max=%.6f  mean=%.6f  p99=%.6f",
          diff.max(), diff.mean(), diff.quantile(0.99))
      say("      月度独有=%d  归档独有=%d",
          int((merged["_merge"] == "left_only").sum()),
          int((merged["_merge"] == "right_only").sum()))
      say("      归档 RUNNO 分布（去重后）: %s", D["run_no"].value_counts().to_dict())
      say("      归档 INTERVENTION 分布: %s", D["intervention"].value_counts().to_dict())
      worst = merged.loc[diff.idxmax()] if len(diff) and diff.max() > 1e-9 else None
      if worst is not None:
         say("      最大差异样本: ts=%s  M=%.5f  D=%.5f", worst["ts"],
             worst["rrp_M"], worst["rrp_D"])

# 时区检验：把月度时间整体平移一小时再看匹配率
say("")
say("=" * 78)
say("2. 时基检验：月度时间戳平移 ±1h 后的匹配率")
say("=" * 78)
say("   本脚本已关闭 NEM->悉尼本地 转换，因此预期三个月都在 shift 0 对齐；")
say("   若某月需要 ±60 才对齐，那就是该月两侧不同源。")
for day in ("20260115", "20260715"):
   month = day[:6]
   M = load_monthly(month)
   D = day_frames[day]
   if D.empty:
      say("  %s: 归档为空 -> 跳过", day)
      continue
   D = D[D["region_id"] == "VIC1"][["settlement_date", "rrp"]]
   d0 = pd.Timestamp(day)
   d1 = d0 + pd.Timedelta(days=1)
   Md = M[(M["ts"] >= d0 - pd.Timedelta(hours=2)) & (M["ts"] < d1 + pd.Timedelta(hours=2))]
   say("")
   say("  --- %s ---", day)
   for shift in (-60, 0, 60):
      sh = Md.copy()
      sh["ts"] = sh["ts"] + pd.Timedelta(minutes=shift)
      mg = sh.merge(D, left_on="ts", right_on="settlement_date", how="inner",
                    suffixes=("_M", "_D"))
      if len(mg) == 0:
         say("      平移 %+4d 分钟: 无交集", shift)
         continue
      dd = (mg["rrp_M"] - mg["rrp_D"]).abs()
      say("      平移 %+4d 分钟: 交集=%-5d  完全相等=%d (%.1f%%)  平均|差|=%.4f",
          shift, len(mg), int((dd < 1e-9).sum()), 100.0 * (dd < 1e-9).mean(), dd.mean())

# ---------------------------------------------------------------- S vs D
say("")
say("=" * 78)
say("3. 数据看板 dispatch 下载 S  vs  NEMWEB 归档 D")
say("=" * 78)
dash_files = [f for f in os.listdir(AEMO) if f.startswith("NEMPRICEANDDEMAND_")]
for fname in sorted(dash_files):
   region = fname.split("_")[1]
   S = pd.read_csv(os.path.join(AEMO, fname))
   S.columns = [c.strip() for c in S.columns]
   S["ts"] = pd.to_datetime(S["Settlement Date"], format="%d/%m/%Y %H:%M", errors="coerce")
   S["rrp"] = pd.to_numeric(S["Spot Price ($/MWh)"], errors="coerce")
   say("")
   say("  --- %s ---", fname)
   say("      region=%s  行数=%d  Type=%s", region, len(S), S["Type"].value_counts().to_dict())
   say("      时间范围 %s .. %s  步长=%s",
       S["ts"].min(), S["ts"].max(), S["ts"].diff().dropna().value_counts().to_dict())
   say("      S 列: %s", [c for c in S.columns if c not in ("ts",)])
   days = sorted({d.strftime("%Y%m%d") for d in S["ts"].dropna()})
   hit_days = [d for d in days if d in day_frames]
   if not hit_days:
      say("      可用归档日不含 S 的日期 %s -> 跳过逐点比对", days)
      continue
   D = pd.concat([day_frames[d] for d in hit_days if not day_frames[d].empty],
                 ignore_index=True)
   if D.empty:
      say("      归档解析为空 -> 跳过")
      continue
   D = D[D["region_id"] == region][["settlement_date", "rrp", "total_demand",
                                    "intervention", "run_no"]]
   # S has no seconds -> compare on the minute; D is always on :00/:05 boundaries
   mg = S.merge(D, left_on="ts", right_on="settlement_date", how="inner",
                suffixes=("_S", "_D"))
   if mg.empty:
      say("      与归档无交集")
      continue
   dd = (mg["rrp_S"] - mg["rrp_D"]).abs()
   say("      与归档交集=%d  (归档覆盖日 %s)", len(mg), hit_days)
   say("      完全相等=%d (%.1f%%)  平均|差|=%.6f  max|差|=%.6f",
       int((dd < 1e-9).sum()), 100.0 * (dd < 1e-9).mean(), dd.mean(), dd.max())
   save_col = "Scheduled Demand (MW)"
   if save_col in mg.columns:
      say("      S 的 demand 列名对照: Scheduled Demand vs D.total_demand 平均|差|=%.4f",
          (mg[save_col] - mg["total_demand"]).abs().mean())
   else:
      say("      D 里没有 total_demand 列，跳过需求对照")
flush()

# ---------------------------------------------------------------- figures
plt.rcParams.update({
   "figure.dpi": 130, "savefig.dpi": 130, "font.size": 9,
   "axes.grid": True, "grid.alpha": 0.3, "axes.spines.top": False,
   "axes.spines.right": False, "legend.frameon": False,
})

COL_M = "#c0392b"
COL_D = "#2c3e50"

# F1: monthly vs archive over one July day, plus the residual
day = "20260715"
M = load_monthly(day[:6])
d0 = pd.Timestamp(day)
d1 = d0 + pd.Timedelta(days=1)
Md = M[(M["ts"] >= d0) & (M["ts"] < d1)]
Dv = day_frames[day]
Dv = Dv[Dv["region_id"] == "VIC1"] if not Dv.empty else Dv

if not Dv.empty and not Md.empty:
   mg = Md.merge(Dv, left_on="ts", right_on="settlement_date", how="inner",
                 suffixes=("_M", "_D"))
   fig, axes = plt.subplots(3, 1, figsize=(11, 8.5), sharex=False,
                            gridspec_kw={"height_ratios": [2.2, 1.4, 2.2]})
   axes[0].plot(Md["ts"], Md["rrp"], "-", color=COL_M, lw=1,
                label="Monthly file (RRP)")
   axes[0].plot(Dv["settlement_date"], Dv["rrp"], "--", color=COL_D, lw=1,
                label="NEMWEB archive DISPATCH/PRICE (max RUNNO)")
   axes[0].set_ylabel("RRP ($/MWh)")
   axes[0].set_title("VIC1, 2026-07-15: monthly aggregated file vs raw 5-min dispatch reports")
   axes[0].legend(loc="upper left")

   resid = mg["rrp_M"] - mg["rrp_D"]
   axes[1].plot(mg["ts"], resid, "-", color="#8e44ad", lw=1)
   axes[1].set_ylabel("M - D ($/MWh)")
   axes[1].set_title("Signed difference at identical timestamps (n=%d, %d exactly equal)"
                     % (len(mg), int((resid.abs() < 1e-9).sum())))

   axes[2].scatter(mg["rrp_D"], mg["rrp_M"], s=4, alpha=0.4, color="#16a085")
   lim = [float(min(mg["rrp_D"].min(), mg["rrp_M"].min())),
          float(max(mg["rrp_D"].max(), mg["rrp_M"].max()))]
   axes[2].plot(lim, lim, "--", color="0.4", lw=1)
   axes[2].set_xlabel("Archive RRP ($/MWh)")
   axes[2].set_ylabel("Monthly RRP ($/MWh)")
   axes[2].set_title("Identity plot: max |M-D| = %.6f $/MWh" % resid.abs().max())
   axes[2].set_xlim(lim)
   axes[2].set_ylim(lim)
   fig.tight_layout()
   fig.savefig(os.path.join(FIGDIR, "F1_monthly_vs_archive_vic1.png"))
   plt.close(fig)
   say("")
   say("[figure] F1_monthly_vs_archive_vic1.png")

# F2: dashboard S vs archive D for the two dashboard exports
if dash_files:
   fig, axes = plt.subplots(len(dash_files), 1, figsize=(11, 3.4 * len(dash_files)),
                            squeeze=False)
   for ax, fname in zip(axes[:, 0], sorted(dash_files)):
      region = fname.split("_")[1]
      S = pd.read_csv(os.path.join(AEMO, fname))
      S.columns = [c.strip() for c in S.columns]
      S["ts"] = pd.to_datetime(S["Settlement Date"], format="%d/%m/%Y %H:%M",
                               errors="coerce")
      S["rrp"] = pd.to_numeric(S["Spot Price ($/MWh)"], errors="coerce")
      days = sorted({d.strftime("%Y%m%d") for d in S["ts"].dropna()})
      hit = [d for d in days if d in day_frames and not day_frames[d].empty]
      ax.plot(S["ts"], S["rrp"], "-", color=COL_M, lw=1,
              label="Dashboard export: Spot Price ($/MWh)")
      if hit:
         D = pd.concat([day_frames[d] for d in hit], ignore_index=True)
         D = D[D["region_id"] == region]
         ax.plot(D["settlement_date"], D["rrp"], "--", color=COL_D, lw=1,
                 label="NEMWEB archive DISPATCH/PRICE")
      ax.set_title("%s - %s (Type=%s, %d rows)"
                   % (region, fname, ",".join(S["Type"].unique()), len(S)))
      ax.set_ylabel("$/MWh")
      ax.legend(loc="upper left", fontsize=8)
   fig.tight_layout()
   fig.savefig(os.path.join(FIGDIR, "F2_dashboard_vs_archive.png"))
   plt.close(fig)
   say("[figure] F2_dashboard_vs_archive.png")

# F3: timebase - January (AEDT) vs July (AEST) on the native NEM clock
fig, axes = plt.subplots(2, 1, figsize=(11, 6.5))
for ax, day in zip(axes, ("20260115", "20260715")):
   M = load_monthly(day[:6])
   d0 = pd.Timestamp(day)
   d1 = d0 + pd.Timedelta(days=1)
   Md = M[(M["ts"] >= d0) & (M["ts"] < d1)]
   D = day_frames[day]
   Dv = D[D["region_id"] == "VIC1"] if not D.empty else D
   label = "January - Sydney on AEDT" if day.endswith("0115") else "July - Sydney on AEST"
   if Md.empty or Dv.empty:
      ax.set_title("%s - no data" % day)
      continue
   mg = Md.merge(Dv, left_on="ts", right_on="settlement_date", how="inner",
                 suffixes=("_M", "_D"))
   resid = (mg["rrp_M"] - mg["rrp_D"]).abs()
   ax.plot(Md["ts"], Md["rrp"], "-", color=COL_M, lw=1.5, label="Monthly dashboard file")
   ax.plot(Dv["settlement_date"], Dv["rrp"], "--", color=COL_D, lw=1,
           label="NEMWEB archive (native NEM time)")
   ax.set_title("%s  %s - n=%d, mean|diff|=%.5f $/MWh" %
                (day, label, len(mg), resid.mean()))
   ax.set_ylabel("RRP ($/MWh)")
   ax.legend(loc="upper left", fontsize=8)
fig.tight_layout()
fig.savefig(os.path.join(FIGDIR, "F3_timebase_check.png"))
plt.close(fig)
say("[figure] F3_timebase_check.png")

flush()
plt.close(fig)

with open(REPORT, "w", encoding="utf-8", newline="\n") as fh:
   fh.write(buf.getvalue())
print("wrote", REPORT)
