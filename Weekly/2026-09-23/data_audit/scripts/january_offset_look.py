# -*- coding: utf-8 -*-
"""Eyeball the January 1-hour offset: print both series side by side.

Nothing clever here - just the raw numbers around a sharp feature, so the sign of
the offset can be read off directly instead of inferred from a merge statistic.
"""

import io
import os
import sys
import zipfile

import pandas as pd

PROJECT = r"C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project"
CAPTURE = os.path.join(PROJECT, "Online_Data_Capture_Script")
AEMO = os.path.join(PROJECT, "AEMO_Data")
CACHE = os.path.join(AEMO, "archive_cache")
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "january_offset_look.txt")

sys.path.insert(0, CAPTURE)
os.chdir(CAPTURE)
import logging                                    # noqa: E402
logging.disable(logging.WARNING)
import aemo_parser as P                           # noqa: E402

buf = io.StringIO()


def say(fmt="", *args):
   buf.write((fmt % args if args else fmt) + "\n")


REGIONS = {"NSW1", "QLD1", "SA1", "TAS1", "VIC1"}


def archive_day(day):
   path = os.path.join(CACHE, "PUBLIC_DISPATCHIS_%s.zip" % day)
   rows = []
   with zipfile.ZipFile(path) as zf:
      for member in zf.namelist():
         with zipfile.ZipFile(io.BytesIO(zf.read(member))) as inner:
            text = inner.read(inner.namelist()[0]).decode("utf-8", errors="replace")
         f = P.parse_dispatch(text, member, REGIONS)
         if not f.empty:
            rows.append(f)
   allrows = pd.concat(rows, ignore_index=True)
   allrows = allrows[allrows["settlement_date"] != ""]
   allrows = allrows.drop_duplicates(subset=["settlement_date", "region_id"], keep="last")
   allrows["settlement_date"] = pd.to_datetime(allrows["settlement_date"])
   return allrows


for day, month in (("20260115", "202601"), ("20260715", "202607")):
   say("=" * 78)
   say("%s : 月度文件 vs 归档（VIC1，同一时间标签下的价格）", day)
   say("=" * 78)
   M = pd.read_csv(os.path.join(AEMO, "PRICE_AND_DEMAND_%s_VIC1.csv" % month))
   M.columns = [c.strip() for c in M.columns]
   M["ts"] = pd.to_datetime(M["SETTLEMENTDATE"])
   M["rrp"] = pd.to_numeric(M["RRP"], errors="coerce")
   M["dem"] = pd.to_numeric(M["TOTALDEMAND"], errors="coerce")
   D = archive_day(day)
   D = D[D["region_id"] == "VIC1"][["settlement_date", "rrp", "total_demand"]]
   d0 = pd.Timestamp(day)

   say("")
   say("  月度文件当天价格最高的 5 个时刻：")
   md = M[(M["ts"] >= d0) & (M["ts"] < d0 + pd.Timedelta(days=1))].nlargest(5, "rrp")
   for _, r in md.iterrows():
      say("      %s   RRP=%9.2f   DEM=%8.1f", r["ts"], r["rrp"], r["dem"])
   say("  归档当天价格最高的 5 个时刻：")
   dd = D.nlargest(5, "rrp")
   for _, r in dd.iterrows():
      say("      %s   RRP=%9.5f   DEM=%s", r["settlement_date"], r["rrp"],
          r["total_demand"])

   say("")
   say("  逐点对照（月度 ts 与 归档 ts-1h 与 归档 ts 三者并排）：")
   anchor = d0 + pd.Timedelta(hours=9)
   win = M[(M["ts"] >= anchor) & (M["ts"] <= anchor + pd.Timedelta(minutes=40))]
   for _, r in win.iterrows():
      same = D[D["settlement_date"] == r["ts"]]
      plus = D[D["settlement_date"] == r["ts"] + pd.Timedelta(hours=1)]
      say("      M %s = %9.2f  |  A(ts) = %-12s  |  A(ts+1h) = %-12s",
          r["ts"], r["rrp"],
          ("%.5f" % same["rrp"].iloc[0]) if len(same) else "-",
          ("%.5f" % plus["rrp"].iloc[0]) if len(plus) else "-")

   # daily cost: which alignment is consistent over the whole day?
   for shift in (0, 60):
      mm = M[(M["ts"] >= d0 - pd.Timedelta(hours=1)) &
             (M["ts"] < d0 + pd.Timedelta(days=1) + pd.Timedelta(hours=1))].copy()
      mm["ts"] = mm["ts"] + pd.Timedelta(minutes=shift)
      mg = mm.merge(D, left_on="ts", right_on="settlement_date", how="inner")
      if len(mg):
         say("")
         say("  shift %+3d min : n=%d  mean|dRRP|=%.5f  mean|dDEM|=%.4f  corr=%.6f",
             shift, len(mg),
             (mg["rrp_x"] - mg["rrp_y"]).abs().mean(),
             (mg["dem"] - pd.to_numeric(mg["total_demand"], errors="coerce")).abs().mean(),
             mg["rrp_x"].corr(mg["rrp_y"]))

with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
   fh.write(buf.getvalue())
print("wrote", OUT)
