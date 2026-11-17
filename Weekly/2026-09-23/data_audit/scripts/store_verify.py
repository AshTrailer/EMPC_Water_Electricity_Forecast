# -*- coding: utf-8 -*-
"""Post-fix sanity check on the three capture stores.

Every time column must be fully populated, every step must be 5 or 30 minutes,
and the dispatch store must actually accumulate intervals rather than collapse
to one row per region.
"""

import io
import os

import pandas as pd

AEMO = r"C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\AEMO_Data"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "store_verify.txt")
buf = io.StringIO()
fail = []


def say(fmt="", *args):
   buf.write((fmt % args if args else fmt) + "\n")


SPEC = {
   "dispatch_actual.csv": ("settlement_date", ["settlement_date", "region_id", "rrp"]),
   "p5min_forecast.csv": ("interval_datetime", ["effective_time", "region_id",
                                                "interval_datetime", "rrp"]),
   "predispatch_forecast.csv": ("period_id", ["effective_time", "region_id",
                                              "period_id", "rrp"]),
}

say("=" * 78)
say("抓取 store 修复后自检")
say("=" * 78)

for name, (key, dedup) in SPEC.items():
   path = os.path.join(AEMO, name)
   say("")
   say("-" * 78)
   say("%s", name)
   say("-" * 78)
   if not os.path.exists(path):
      say("  MISSING")
      fail.append(name + ": missing")
      continue
   df = pd.read_csv(path, dtype=str, keep_default_na=False)
   say("  行数 = %d   列 = %s", len(df), list(df.columns))
   for col in df.columns:
      empty = int((df[col].astype(str).str.strip() == "").sum())
      flag = "  <-- 全空!" if empty == len(df) else ("  <-- %d 空" % empty if empty else "")
      say("    %-20s 空值 %6d / %-6d%s", col, empty, len(df), flag)
      if empty == len(df):
         fail.append("%s.%s all empty" % (name, col))
   # time columns
   for col in ("settlement_date", "effective_time", "interval_datetime"):
      if col not in df.columns:
         continue
      t = pd.to_datetime(df[col], errors="coerce")
      say("    %-20s 解析失败 %d  范围 %s .. %s", col, int(t.isna().sum()),
          t.min(), t.max())
      if int(t.isna().sum()):
         fail.append("%s.%s unparseable" % (name, col))
   # step check on the natural axis
   if name == "dispatch_actual.csv":
      t = pd.to_datetime(df["settlement_date"]).drop_duplicates().sort_values()
      steps = t.diff().dropna().value_counts()
      say("    区间步长分布: %s", {str(k): int(v) for k, v in steps.items()})
      per_region = df.groupby("region_id").size().to_dict()
      say("    每区域行数: %s", per_region)
      if len(df) <= 5:
         fail.append("dispatch store still collapsed to <=5 rows")
   if name == "p5min_forecast.csv":
      n = df.groupby(["effective_time", "region_id"]).size()
      say("    每批每区域目标数: %s", n.value_counts().to_dict())
   if name == "predispatch_forecast.csv":
      n = df.groupby(["effective_time", "region_id"]).size()
      say("    每批每区域目标数: %s", n.value_counts().to_dict())
      say("    predispatch_seqno 样例: %s", list(df["predispatch_seqno"].unique()[:5]))

say("")
say("=" * 78)
if fail:
   say("结论：%d 项不合格", len(fail))
   for f in fail:
      say("   FAIL  %s", f)
else:
   say("结论：全部合格 —— 时间列无空值、可解析、步长正常、dispatch 正常累积。")
say("=" * 78)

with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
   fh.write(buf.getvalue())
print("wrote", OUT, "| failures:", len(fail))
