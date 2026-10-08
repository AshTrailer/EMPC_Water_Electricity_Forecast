# -*- coding: utf-8 -*-
"""Diagnose the three capture stores + the PREDISPATCH table selection.

Read-only. Answers, with raw evidence:
  * what the stores actually contain now (key fields, distinct values);
  * which PREDISPATCH table the parser picks and whether that table carries
    RRP / TOTALDEMAND at all;
  * what the raw PREDISPATCHSEQNO / PERIODID values look like before parsing.
"""

import io
import os
import zipfile
from collections import Counter

import pandas as pd

BASE = r"C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\AEMO_Data"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "store_diagnosis.txt")
buf = io.StringIO()


def say(fmt="", *args):
   buf.write((fmt % args if args else fmt) + "\n")


def read_store(name):
   p = os.path.join(BASE, name)
   if not os.path.exists(p):
      say("%s: MISSING", name)
      return None
   df = pd.read_csv(p, dtype=str, keep_default_na=False)
   say("%s: %d rows, %d cols", name, len(df), len(df.columns))
   say("  columns: %s", list(df.columns))
   return df


pd.set_option("display.width", 200)
pd.set_option("display.max_columns", 40)

say("=" * 78)
say("1. dispatch_actual.csv")
say("=" * 78)
d = read_store("dispatch_actual.csv")
if d is not None:
   for c in d.columns:
      vals = d[c].unique()
      say("  %-18s distinct=%-4d  %s", c, len(vals), list(vals[:6]))

say("")
say("=" * 78)
say("2. p5min_forecast.csv")
say("=" * 78)
p5 = read_store("p5min_forecast.csv")
if p5 is not None:
   for c in p5.columns:
      vals = p5[c].unique()
      say("  %-18s distinct=%-5d  %s", c, len(vals), list(vals[:5]))
   say("  empty-field counts: %s", {c: int((p5[c] == "").sum()) for c in p5.columns})
   say("  rows per (effective_time, region): %s",
       p5.groupby(["effective_time", "region_id"]).size().value_counts().to_dict())

say("")
say("=" * 78)
say("3. predispatch_forecast.csv")
say("=" * 78)
pd_ = read_store("predispatch_forecast.csv")
if pd_ is not None:
   for c in pd_.columns:
      vals = pd_[c].unique()
      say("  %-20s distinct=%-5d  %s", c, len(vals), list(vals[:5]))
   say("  empty-field counts: %s", {c: int((pd_[c] == "").sum()) for c in pd_.columns})
   say("  predispatch_seqno x effective_time (head 12):")
   grp = pd_.groupby(["effective_time", "predispatch_seqno"]).size().reset_index(name="rows")
   say("%s", grp.head(12).to_string(index=False))

# ------------------------------------------------- raw PREDISPATCHIS tables
say("")
say("=" * 78)
say("4. 原始 PREDISPATCHIS 表结构与字段（最新一个 zip）")
say("=" * 78)
zc = os.path.join(BASE, "zip_cache", "PREDISPATCHIS")
zips = sorted(f for f in os.listdir(zc) if f.lower().endswith(".zip"))
zpath = os.path.join(zc, zips[-1])
say("zip = %s", zips[-1])
with zipfile.ZipFile(zpath) as zf:
   member = zf.namelist()[0]
   text = zf.read(member).decode("utf-8", errors="replace")
lines = [ln for ln in text.splitlines() if ln.strip()]
tables = {}
order = []
for ln in lines:
   parts = ln.split(",")
   if ln.startswith("I,"):
      if parts[2].isdigit():
         key = (parts[1], parts[1]); cols = parts[3:]
      else:
         key = (parts[1], parts[2]); cols = parts[4:]
      tables[key] = {"cols": cols, "rows": []}
      order.append(key)
   elif ln.startswith("D,"):
      if parts[2].isdigit():
         key = (parts[1], parts[1]); payload = parts[3:]
      else:
         key = (parts[1], parts[2]); payload = parts[4:]
      if key in tables:
         tables[key]["rows"].append(payload)

for key in order:
   t = tables[key]
   cols = t["cols"]
   say("")
   say("  [%s / %s]  D-rows=%d  cols=%d", key[0], key[1], len(t["rows"]), len(cols))
   say("    has RRP=%s  has TOTALDEMAND=%s  has REGIONID=%s  has PERIODID=%s",
       "RRP" in cols, "TOTALDEMAND" in cols, "REGIONID" in cols, "PERIODID" in cols)
   if cols:
      row = t["rows"][0] if t["rows"] else []
      say("    sample (first 14 fields):")
      for name, val in list(zip(cols, row))[:14]:
         say("        %-26s = %r", name, val)
   # which table would _find_table pick?
req_strict = {"REGIONID", "PERIODID", "RRP", "TOTALDEMAND"}
req_loose = {"REGIONID", "PERIODID", "RRP"}
say("")
say("  _find_table simulation:")
for key in order:
   cols = set(tables[key]["cols"])
   if req_strict <= cols:
      say("    STRICT match -> %s / %s   (has RRP+TOTALDEMAND)", key[0], key[1])
      break
else:
   for key in order:
      cols = set(tables[key]["cols"])
      if req_loose <= cols:
         say("    no STRICT match; LOOSE match -> %s / %s  (TOTALDEMAND absent!)", key[0], key[1])
         break
   else:
      say("    NO match at all")

# ------------------------------------------------------------- P5MIN 抽检
say("")
say("=" * 78)
say("5. 原始 P5MIN REGIONSOLUTION 关键字段")
say("=" * 78)
zc5 = os.path.join(BASE, "zip_cache", "P5MIN")
z5 = sorted(f for f in os.listdir(zc5) if f.lower().endswith(".zip"))[-1]
with zipfile.ZipFile(os.path.join(zc5, z5)) as zf:
   text5 = zf.read(zf.namelist()[0]).decode("utf-8", errors="replace")
lines5 = [ln for ln in text5.splitlines() if ln.strip()]
for ln in lines5:
   if ln.startswith("I,P5MIN,REGIONSOLUTION"):
      cols5 = [c.strip() for c in ln.split(",")[4:]]
      say("  zip = %s", z5)
      say("  REGIONSOLUTION cols (first 8): %s", cols5[:8])
      break
n = 0
for ln in lines5:
   if ln.startswith("D,P5MIN,REGIONSOLUTION"):
      say("  D> %s", ln[:220])
      n += 1
      if n >= 3:
         break
say("  (note: datetime fields above are double-quoted in the raw file)")

with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
   fh.write(buf.getvalue())
print("wrote", OUT)
