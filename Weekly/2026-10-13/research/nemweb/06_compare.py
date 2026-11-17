# -*- coding: utf-8 -*-
"""Compare horizon behaviour across products and against the delivered 120-day CSVs.

Three things:
  A. the slot -> period-count map for the audited day (2026-10-12), so it can be
     compared with the 2026-02-01..06-01 pattern in the delivered data
  B. the horizon distribution of the delivered 120-day PREDISPATCH CSVs, measured
     from those files, to see whether any of it was truncated
  C. the PD7Day horizon, which is the only 30-minute-granularity region price
     series that exceeds 40 hours

Usage: python 06_compare.py --root <research dir> --emc <120d dir> --out <json>
"""

import argparse
import collections
import glob
import json
import os

import pandas as pd

DT = "%Y-%m-%d %H:%M:%S"
REGIONS = ["NSW1", "QLD1", "SA1", "TAS1", "VIC1"]


def say(fmt="", *args):
   print(fmt % args if args else fmt, flush=True)


def main():
   ap = argparse.ArgumentParser()
   ap.add_argument("--root", required=True)
   ap.add_argument("--emc", required=True)
   ap.add_argument("--pd7", required=True)
   ap.add_argument("--out", required=True)
   args = ap.parse_args()

   result = {}

   # ---- A. audited day, slot -> periods, from the RAW horizon json ----------
   for kind, path in (("predispatchis", os.path.join(args.root,
                                                     "horizon_predispatchis.json")),
                      ("predispatch", os.path.join(args.root,
                                                   "horizon_predispatch.json"))):
      with open(path, "r", encoding="utf-8") as fh:
         recs = json.load(fh)
      ok = [r for r in recs if r.get("horizon_hours") is not None]
      say("")
      say("=== %s : %d files", kind, len(ok))
      per = []
      for r in ok:
         eff = pd.Timestamp(r["effective_time"])
         reg = r["regions"].get("VIC1") or next(iter(r["regions"].values()))
         per.append({"eff": eff, "slot": eff.strftime("%H:%M"),
                     "periods": reg["periods"],
                     "horizon_hours": r["horizon_hours"],
                     "end_tod": r.get("horizon_end_tod"),
                     "max_target": reg["max_target"]})
      df = pd.DataFrame(per).sort_values("eff")
      tbl = df.groupby("slot").agg(periods=("periods", "min"),
                                   horizon_hours=("horizon_hours", "min"),
                                   end_tod=("end_tod", lambda s: sorted(set(s))[0]),
                                   n=("periods", "size"))
      say("slot -> periods / horizon_h")
      for slot, row in tbl.iterrows():
         say("   %s -> %3d periods  %5.1f h  end=%s  n=%d", slot,
             int(row["periods"]), row["horizon_hours"], row["end_tod"],
             int(row["n"]))
      result[kind] = {
         "files": len(ok),
         "periods_min": int(df["periods"].min()),
         "periods_max": int(df["periods"].max()),
         "horizon_min": float(df["horizon_hours"].min()),
         "horizon_median": float(df["horizon_hours"].median()),
         "horizon_max": float(df["horizon_hours"].max()),
         "files_over_40h": int((df["horizon_hours"] > 40).sum()),
         "files_ge_48h": int((df["horizon_hours"] >= 48).sum()),
         "end_tod_set": sorted(set(df["end_tod"])),
         "slots": {k: [int(v["periods"]), float(v["horizon_hours"]), int(v["n"])]
                   for k, v in tbl.iterrows()},
      }

   # ---- B. delivered 120-day CSVs, horizon measured from the files ---------
   say("")
   say("=== delivered 120-day PREDISPATCH, horizon measured from the CSVs")
   rows = []
   for region in REGIONS:
      path = os.path.join(args.emc, "predispatch_30min_%s.csv" % region)
      if not os.path.exists(path):
         say("   %-5s MISSING", region)
         continue
      f = pd.read_csv(path, dtype=str, usecols=["effective_time",
                                                "target_datetime", "period_id"])
      f["eff"] = pd.to_datetime(f["effective_time"], format=DT)
      f["tgt"] = pd.to_datetime(f["target_datetime"], format=DT)
      g = f.groupby("eff").agg(periods=("tgt", "nunique"), last=("tgt", "max"),
                               first=("tgt", "min"))
      g["horizon_h"] = (g["last"] - g.index).dt.total_seconds() / 3600.0
      say("   %-5s runs=%d  periods %d..%d  horizon %.1f..%.1f h  end_tod=%s",
          region, len(g), g["periods"].min(), g["periods"].max(),
          g["horizon_h"].min(), g["horizon_h"].max(),
          sorted(set(g["last"].dt.strftime("%H:%M"))))
      g = g.reset_index()
      g["region"] = region
      rows.append(g)
   allg = pd.concat(rows, ignore_index=True)
   result["delivered_120d"] = {
      "runs_total": int(len(allg)),
      "runs_per_region": int(len(allg) / len(REGIONS)),
      "periods_min": int(allg["periods"].min()),
      "periods_max": int(allg["periods"].max()),
      "horizon_min": float(allg["horizon_h"].min()),
      "horizon_median": float(allg["horizon_h"].median()),
      "horizon_max": float(allg["horizon_h"].max()),
      "runs_over_40h": int((allg["horizon_h"] > 40).sum()),
      "runs_ge_48h": int((allg["horizon_h"] >= 48).sum()),
      "end_tod_set": sorted(set(allg["last"].dt.strftime("%H:%M"))),
   }
   say("   overall: runs=%d  periods %d..%d  horizon %.1f..%.1f h (median %.1f)",
       len(allg), allg["periods"].min(), allg["periods"].max(),
       allg["horizon_h"].min(), allg["horizon_h"].max(),
       allg["horizon_h"].median())
   say("   runs over 40 h: %d ; runs at or above 48 h: %d",
       int((allg["horizon_h"] > 40).sum()), int((allg["horizon_h"] >= 48).sum()))

   # compare the slot maps
   say("")
   say("=== slot -> periods: audited day vs delivered 120 days")
   a = result.get("predispatchis", {}).get("slots", {})
   allg["slot"] = allg["eff"].dt.strftime("%H:%M")
   b = allg.groupby("slot")["periods"].agg(["min", "max", "size"])
   bad = 0
   for slot in sorted(set(a) | set(b.index)):
      av = a.get(slot, [None])[0]
      bv = int(b.loc[slot, "min"]) if slot in b.index else None
      flag = "" if av == bv else "   <== DIFFERS"
      if av != bv:
         bad += 1
      say("   %s  audited=%-6s delivered=%-6s%s", slot, av, bv, flag)
   result["slot_map_differences"] = bad

   # ---- C. PD7Day horizon -------------------------------------------------
   say("")
   say("=== PD7DAY horizon (the only 30-min-granularity region price product > 40h)")
   p7 = {}
   for region in REGIONS:
      path = os.path.join(args.pd7, "pd7day_30min_%s.csv" % region)
      if not os.path.exists(path):
         continue
      f = pd.read_csv(path, dtype=str, usecols=["effective_time",
                                                "target_datetime"])
      f["eff"] = pd.to_datetime(f["effective_time"], format=DT)
      f["tgt"] = pd.to_datetime(f["target_datetime"], format=DT)
      g = f.groupby("eff").agg(periods=("tgt", "nunique"), last=("tgt", "max"))
      g["horizon_h"] = (g["last"] - g.index).dt.total_seconds() / 3600.0
      p7[region] = g
   ref = p7["VIC1"]
   say("   VIC1 runs=%d periods %d..%d horizon %.1f..%.1f h end_tod=%s",
       len(ref), ref["periods"].min(), ref["periods"].max(),
       ref["horizon_h"].min(), ref["horizon_h"].max(),
       sorted(set(ref["last"].dt.strftime("%H:%M"))))
   result["pd7day"] = {
      "runs": int(len(ref)),
      "periods_min": int(ref["periods"].min()),
      "periods_max": int(ref["periods"].max()),
      "horizon_min": float(ref["horizon_h"].min()),
      "horizon_max": float(ref["horizon_h"].max()),
      "end_tod_set": sorted(set(ref["last"].dt.strftime("%H:%M"))),
   }

   with open(args.out, "w", encoding="utf-8") as fh:
      json.dump(result, fh, indent=1, default=str)
   say("")
   say("wrote %s", args.out)


if __name__ == "__main__":
   main()
