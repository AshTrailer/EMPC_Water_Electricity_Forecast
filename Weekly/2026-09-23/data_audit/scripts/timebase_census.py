# -*- coding: utf-8 -*-
"""Month-by-month census of the monthly-file vs NEMWEB-archive timebase offset.

Established already:
  * VIC1 prices agree to the last published decimal (the monthly file is the raw
    5-min dispatch RRP rounded to 2 dp);
  * the ARCHIVE is on a fixed NEM-time (AEST/UTC+10) clock - its daily zips show
    a clean 5-minute ladder across the 2026-04-05 DST boundary;
  * the January monthly file matches the archive only after a +60 min shift.

This script walks one day per month to see exactly which months carry the offset
and whether it flips at the DST boundary (2026-04-05).
"""

import io
import logging
import os
import sys
import zipfile

import pandas as pd
import requests

PROJECT = r"C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project"
CAPTURE = os.path.join(PROJECT, "Online_Data_Capture_Script")
AEMO = os.path.join(PROJECT, "AEMO_Data")
CACHE = os.path.join(AEMO, "archive_cache")
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "timebase_census.txt")

sys.path.insert(0, CAPTURE)
os.chdir(CAPTURE)
logging.disable(logging.WARNING)
import aemo_parser as P                          # noqa: E402

REGIONS = {"NSW1", "QLD1", "SA1", "TAS1", "VIC1"}
HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) aemo-audit/1.0"}
ARCHIVE = "https://www.nemweb.com.au/Reports/ARCHIVE/DispatchIS_Reports/"

# one day per month; April gets three to bracket the DST switch (2026-04-05)
DAYS = ["20260115", "20260215", "20260315", "20260404", "20260406",
        "20260420", "20260515", "20260615", "20260701", "20260805"]

buf = io.StringIO()


def say(fmt="", *args):
   buf.write((fmt % args if args else fmt) + "\n")


def fetch(day):
   dest = os.path.join(CACHE, "PUBLIC_DISPATCHIS_%s.zip" % day)
   if os.path.exists(dest) and os.path.getsize(dest) > 0:
      return dest, "cached"
   with requests.get(ARCHIVE + "PUBLIC_DISPATCHIS_%s.zip" % day,
                     headers=HEADERS, stream=True, timeout=180) as r:
      r.raise_for_status()
      tmp = dest + ".part"
      with open(tmp, "wb") as fh:
         for chunk in r.iter_content(chunk_size=1 << 16):
            fh.write(chunk)
   os.replace(tmp, dest)
   return dest, "downloaded"


def archive_day(day):
   path, how = fetch(day)
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
   return allrows[allrows["region_id"] == "VIC1"], how


say("=" * 100)
say("月度文件 vs NEMWEB 归档：逐月时基普查（VIC1，逐点比价格与需求）")
say("=" * 100)
say("")
say("%-10s %-9s %8s %8s %8s %10s %10s %10s  %s" %
    ("day", "archive", "n_M", "n_A", "n_both", "s0 mean", "s+60 mean",
     "s-60 mean", "best shift"))
say("-" * 100)

summary = []
for day in DAYS:
   month = day[:6]
   mpath = os.path.join(AEMO, "PRICE_AND_DEMAND_%s_VIC1.csv" % month)
   if not os.path.exists(mpath):
      say("%-10s  月度文件缺失" % day)
      continue
   M = pd.read_csv(mpath)
   M.columns = [c.strip() for c in M.columns]
   M["ts"] = pd.to_datetime(M["SETTLEMENTDATE"])
   M["rrp"] = pd.to_numeric(M["RRP"], errors="coerce")
   M["dem"] = pd.to_numeric(M["TOTALDEMAND"], errors="coerce")
   D, how = archive_day(day)
   d0 = pd.Timestamp(day)

   win = M[(M["ts"] >= d0 - pd.Timedelta(hours=2)) &
           (M["ts"] < d0 + pd.Timedelta(days=1) + pd.Timedelta(hours=2))].copy()
   row = {"day": day}
   for shift in (-60, 0, 60):
      sh = win.copy()
      sh["ts"] = sh["ts"] + pd.Timedelta(minutes=shift)
      mg = sh.merge(D, left_on="ts", right_on="settlement_date", how="inner",
                    suffixes=("_M", "_A"))
      if len(mg):
         row[shift] = ((mg["rrp_M"] - mg["rrp_A"]).abs().mean(),
                       (mg["dem"] - pd.to_numeric(mg["total_demand"],
                                                  errors="coerce")).abs().mean())
      else:
         row[shift] = (float("nan"), float("nan"))
   best = min((-60, 0, 60), key=lambda s: row[s][0])
   summary.append((day, best, row[best][0]))
   say("%-10s %-9s %8d %8d %8d %10.5f %10.5f %10.5f  %+d min" %
       (day, how, len(win), len(D),
        len(win), row[0][0], row[60][0], row[-60][0], best))

say("")
say("=" * 100)
say("结论")
say("=" * 100)
say("  'best shift' 是把月度文件的时间戳整体平移后、与归档对齐误差最小的那个平移量。")
say("  +60 表示：同一物理时段，月度文件的标签比归档早 1 小时。")
say("")
say("  受影响月份：%s", sorted({d[:6] for d, b, _ in summary if b == 60}))
say("  不受影响月份：%s", sorted({d[:6] for d, b, _ in summary if b == 0}))

with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
   fh.write(buf.getvalue())
print("wrote", OUT)
