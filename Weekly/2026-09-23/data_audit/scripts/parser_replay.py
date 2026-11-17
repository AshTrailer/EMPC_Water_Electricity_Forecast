# -*- coding: utf-8 -*-
"""Run the CURRENT capture parsers against raw zips and show exactly what they emit.

Read-only: imports the capture modules, feeds them real zip payloads, prints the
frames. This is the end-to-end evidence for the quoting bug (and for whatever the
predispatch seqno field turns out to be).
"""

import io
import os
import sys
import zipfile

import pandas as pd

CAPTURE = r"C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\Online_Data_Capture_Script"
BASE = r"C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\AEMO_Data"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "parser_replay.txt")
buf = io.StringIO()


def say(fmt="", *args):
   buf.write((fmt % args if args else fmt) + "\n")


sys.path.insert(0, CAPTURE)
os.chdir(CAPTURE)

import aemo_config as cfg                     # noqa: E402
import aemo_parser as P                       # noqa: E402
from aemo_common import parse_nem_datetime    # noqa: E402

REGIONS = {"NSW1", "QLD1", "SA1", "TAS1", "VIC1"}
pd.set_option("display.width", 250)
pd.set_option("display.max_columns", 40)


def payload(report, name):
   path = os.path.join(BASE, "zip_cache", report, name)
   with zipfile.ZipFile(path) as zf:
      return zf.read(zf.namelist()[0]).decode("utf-8", errors="replace")


def newest(report):
   folder = os.path.join(BASE, "zip_cache", report)
   return sorted(f for f in os.listdir(folder) if f.lower().endswith(".zip"))[-1]


say("=" * 78)
say("0. parse_nem_datetime 对照：带引号 vs 不带引号")
say("=" * 78)
for raw in ('"2026/09/04 03:55:00"', "2026/09/04 03:55:00", "2026091515",
            "2026091506", "01", "20260901050006"):
   say("  %-26r -> %r", raw, parse_nem_datetime(raw))

say("")
say("=" * 78)
say("1. parse_dispatch  on %s", newest("DISPATCHIS"))
say("=" * 78)
f = P.parse_dispatch(payload("DISPATCHIS", newest("DISPATCHIS")), "probe.zip", REGIONS)
say("  rows=%d", len(f))
if not f.empty:
   say("  empty per column: %s", {c: int((f[c].astype(str) == "").sum()) for c in f.columns})
   say("%s", f.head(6).to_string(index=False))

say("")
say("=" * 78)
say("2. parse_p5min  on %s", newest("P5MIN"))
say("=" * 78)
f5 = P.parse_p5min(payload("P5MIN", newest("P5MIN")), "probe.zip", REGIONS, "2026-09-15 11:30:00")
say("  rows=%d", len(f5))
if not f5.empty:
   say("  empty per column: %s", {c: int((f5[c].astype(str) == "").sum()) for c in f5.columns})
   say("%s", f5.head(6).to_string(index=False))

say("")
say("=" * 78)
say("3. parse_predispatch  on %s", newest("PREDISPATCHIS"))
say("=" * 78)
pp = P.parse_predispatch(payload("PREDISPATCHIS", newest("PREDISPATCHIS")),
                         "probe.zip", REGIONS, "2026-09-15 11:30:00")
say("  rows=%d", len(pp))
if not pp.empty:
   say("  empty per column: %s", {c: int((pp[c].astype(str) == "").sum()) for c in pp.columns})
   say("%s", pp.head(8).to_string(index=False))

say("")
say("=" * 78)
say("4. 原始 REGION_PRICES 的 PREDISPATCHSEQNO / PERIODID 原样值")
say("=" * 78)
txt = payload("PREDISPATCHIS", newest("PREDISPATCHIS"))
for ln in txt.splitlines():
   if ln.startswith("D,PREDISPATCH,REGION_PRICES"):
      parts = ln.split(",")
      say("  raw head: %s", ",".join(parts[:7]))
      break
say("")
say("  CASE_SOLUTION 行:")
for ln in txt.splitlines():
   if ln.startswith("D,PREDISPATCH,CASE_SOLUTION"):
      say("  raw head: %s", ",".join(ln.split(",")[:4]))
      break

say("")
say("=" * 78)
say("5. 结论")
say("=" * 78)
say("  - aemo_parser._split_record 用 line.split(',')，D 记录里的时间字段带双引号")
say("    （\"2026/09/04 03:55:00\"），引号未剥离 -> parse_nem_datetime 返回 None")
say("    -> format_output_time(None) = ''，于是 settlement_date / interval_datetime")
say("    / period_id 全空。")
say("  - dispatch 的 dedup 键是 (settlement_date, region_id)；settlement_date 全空后，")
say("    每次 5 分钟观测都把上一分钟挤掉，dispatch_actual.csv 永远只剩 5 行。")
say("  - _find_table 在 PREDISPATCHIS 上选 REGION_PRICES（有 RRP、无 TOTALDEMAND），")
say("    该表没有 TOTALDEMAND -> total_demand 全空。")

with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
   fh.write(buf.getvalue())
print("wrote", OUT)
