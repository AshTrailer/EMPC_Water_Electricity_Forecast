# -*- coding: utf-8 -*-
"""Is the 1-hour offset real, or did our own parser create it?

aemo_common.format_output_time() converts NEM time (AEST/UTC+10) to
Australia/Sydney whenever aemo_config.USE_AUS_LOCAL_TIME is True - which is the
shipped default. That conversion is +1 h exactly during AEDT and +0 h during
AEST, i.e. it would reproduce the Jan/Feb/Mar +60 / May..Aug 0 pattern all by
itself.

This script re-runs the comparison with the conversion OFF, so the archive is
compared on its native NEM clock.
"""

import io
import logging
import os
import sys
import zipfile

import pandas as pd

PROJECT = r"C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project"
CAPTURE = os.path.join(PROJECT, "Online_Data_Capture_Script")
AEMO = os.path.join(PROJECT, "AEMO_Data")
CACHE = os.path.join(AEMO, "archive_cache")
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "timebase_verdict.txt")

sys.path.insert(0, CAPTURE)
os.chdir(CAPTURE)
logging.disable(logging.WARNING)
import aemo_config as cfg                        # noqa: E402
import aemo_common as common                     # noqa: E402
import aemo_parser as P                          # noqa: E402

REGIONS = {"NSW1", "QLD1", "SA1", "TAS1", "VIC1"}
DAYS = ["20260115", "20260215", "20260315", "20260404", "20260406",
        "20260515", "20260715", "20260805"]

buf = io.StringIO()


def say(fmt="", *args):
   buf.write((fmt % args if args else fmt) + "\n")


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
   return allrows[allrows["region_id"] == "VIC1"]


def one_pass(day):
   month = day[:6]
   M = pd.read_csv(os.path.join(AEMO, "PRICE_AND_DEMAND_%s_VIC1.csv" % month))
   M.columns = [c.strip() for c in M.columns]
   M["ts"] = pd.to_datetime(M["SETTLEMENTDATE"])
   M["rrp"] = pd.to_numeric(M["RRP"], errors="coerce")
   M["dem"] = pd.to_numeric(M["TOTALDEMAND"], errors="coerce")
   D = archive_day(day)
   d0 = pd.Timestamp(day)
   win = M[(M["ts"] >= d0 - pd.Timedelta(hours=2)) &
           (M["ts"] < d0 + pd.Timedelta(days=1) + pd.Timedelta(hours=2))]
   out = {}
   for shift in (-60, 0, 60):
      sh = win.copy()
      sh["ts"] = sh["ts"] + pd.Timedelta(minutes=shift)
      mg = sh.merge(D, left_on="ts", right_on="settlement_date", how="inner",
                    suffixes=("_M", "_A"))
      out[shift] = (mg["rrp_M"] - mg["rrp_A"]).abs().mean() if len(mg) else float("nan")
   return out


say("=" * 92)
say("时基判定：把解析器的 NEM->悉尼本地 转换关掉后再比一次")
say("=" * 92)
say("")
say("  aemo_config.USE_AUS_LOCAL_TIME 当前值 = %s", cfg.USE_AUS_LOCAL_TIME)
say("")
say("%-10s %14s %14s %14s  %s" % ("day", "shift -60", "shift 0", "shift +60", "best"))
say("-" * 92)

for label, flag in (("USE_AUS_LOCAL_TIME = True  (shipped default)", True),
                    ("USE_AUS_LOCAL_TIME = False (native NEM time)", False)):
   cfg.USE_AUS_LOCAL_TIME = flag
   say("")
   say("[%s]", label)
   for day in DAYS:
      res = one_pass(day)
      best = min((-60, 0, 60), key=lambda s: res[s])
      say("%-10s %14.5f %14.5f %14.5f  %+d min" %
          (day, res[-60], res[0], res[60], best))

cfg.USE_AUS_LOCAL_TIME = True
say("")
say("=" * 92)
say("判读")
say("=" * 92)
say("  若第二段（False）所有月份的最佳平移都是 0，则：")
say("    * 月度文件与 NEMWEB 归档本来就同在 NEM 时间（AEST，无夏令时）；")
say("    * 之前看到的 1 小时偏移，是 Online_Data_Capture_Script 默认开启的")
say("      USE_AUS_LOCAL_TIME 把归档时间戳转成悉尼本地时间造成的，不是 AEMO 数据的问题。")

with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
   fh.write(buf.getvalue())
print("wrote", OUT)
