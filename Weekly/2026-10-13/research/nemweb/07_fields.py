# -*- coding: utf-8 -*-
"""Pull the requested field lists out of inventory_samples.json.

The brief asks specifically for the demand / solar-PV / wind / available-generation
/ reserve fields of ROOFTOP_PV_FORECAST and of the PREDISPATCH and DISPATCH region
summary tables. This prints those column lists verbatim, plus the full list for
every other sample table, and flags which of them actually carry a price.

UNITS: NEMWEB report CSVs contain no unit metadata at all. Units below are taken
from AEMO's MMS data model naming conventions and are labelled as such; the column
NAMES are measured from the files.

Usage: python 07_fields.py --inv <inventory_samples.json> --out <fields.json>
"""

import argparse
import json
import re

# tables whose full field list the brief wants
WANTED = {
   "rooftop_forecast_current": ["FORECAST"],
   "rooftop_forecast_area_current": ["FORECAST"],
   "rooftop_forecast_archive": ["FORECAST"],
   "rooftop_forecast_area_archive": ["FORECAST"],
   "rooftop_actual_current": ["ACTUAL"],
   "rooftop_actual_area_current": ["ACTUAL"],
   "dispatchis_current": ["REGIONSUM"],
   "predispatchfcst_current": ["FCAS_REQ_CONSTRAINT", "FCAS_REQ_RUN"],
   "pd7day_current": ["PRICESOLUTION"],
   "pdpasa_current": ["REGIONSOLUTION"],
   "sevenday_full_current": ["PEAK"],
   "mtpasa_current": ["REGIONRESULT", "REGIONSUMMARY"],
   "p5min_current": ["REGIONSOLUTION"],
   "public_prices_current": ["DREGION"],
   "histdemand_current": ["HISTORIC"],
   "intermittent_current": ["INTERMITTENT_GEN_SCADA"],
   "dispatchfcst_current": ["PRICE", "REGIONSUM"],
   "p5minfcst_current": ["REGIONSUM"],
}
# the 120-day / 60-day delivered PREDISPATCH uses REGION_PRICES + REGION_SOLUTION
PREDISPATCHIS = ["predispatchis (53-file audit inventory)"]

GROUPS = {
   "price": re.compile(r"(RRP|PRICE|COST|MARGINALVALUE)", re.I),
   "demand": re.compile(r"DEMAND", re.I),
   "solar_pv": re.compile(r"(SOLAR|ROOFTOP|_PV\b|^PV|PV_)", re.I),
   "wind": re.compile(r"WIND", re.I),
   "available_gen": re.compile(r"(AVAIL|CAPACITY|UIGF|CLEAREDMW|DISPATCHABLE)", re.I),
   "reserve": re.compile(r"(RESERVE|REGULATION|FCAS|RAISE|LOWER|\bLOR\b|LCR)", re.I),
}

UNITS = {
   "rrp": "$/MWh (AEMO MMS: regional reference price)",
   "price_cols": "$/MWh for the *RRP columns; the FCAS RRP columns are $/MW",
   "demand_cols": "MW",
   "solar_wind_cols": "MW",
   "capacity_cols": "MW",
   "reserve_cols": "MW for MW-denominated fields, $/MW for the *RRP fields",
   "percentage_cols": "% where the name ends in PERCENTAGE or is a compliance share",
}


def say(fmt="", *args):
   print(fmt % args if args else fmt, flush=True)


def main():
   ap = argparse.ArgumentParser()
   ap.add_argument("--inv", required=True)
   ap.add_argument("--pred", required=True, help="inventory_predispatchis.json")
   ap.add_argument("--out", required=True)
   args = ap.parse_args()

   with open(args.inv, "r", encoding="utf-8") as fh:
      inv = json.load(fh)
   with open(args.pred, "r", encoding="utf-8") as fh:
      pred_inv = json.load(fh)

   out = {"units_note": UNITS, "tables": {}}

   say("=" * 78)
   say("PREDISPATCHIS report tables (from the 53-file audit)")
   for tname, cols in pred_inv.items():
      say("")
      say("  TABLE %s  (%d columns)", tname, len(cols))
      say("    %s", cols)
      out["tables"]["predispatchis/" + tname] = {"columns": cols,
                                                 "source": "audit"}
   # REGION_PRICES is the price table of PREDISPATCHIS
   for tname in ("REGION_PRICES", "REGION_SOLUTION", "CASE_SOLUTION",
                 "LOCAL_PRICE"):
      if tname in pred_inv:
         cols = pred_inv[tname]
         say("")
         say("  --- PREDISPATCHIS/%s : fields matching the requested families ---", tname)
         for gname, rx in GROUPS.items():
            hits = [c for c in cols if rx.search(c)]
            if hits:
               say("      %-14s %s", gname, hits)
         out.setdefault("predispatchis_families", {})[tname] = {
            g: [c for c in cols if rx.search(c)] for g, rx in GROUPS.items()}

   for label, tables in WANTED.items():
      if label not in inv:
         say("")
         say("=== %s : NOT IN INVENTORY", label)
         continue
      entry = inv[label]
      say("")
      say("=" * 78)
      say("%s   file=%s  bytes=%s", label, entry.get("file"), entry.get("bytes"))
      for tname in tables:
         t = entry.get("tables", {}).get(tname)
         if not t:
            say("   table %s : MISSING", tname)
            continue
         cols = t["columns"]
         say("   TABLE %-24s rows=%d cols=%d", tname, t["rows"], len(cols))
         say("      full columns: %s", cols)
         for gname, st in t.get("time", {}).items():
            say("      time %s : %s .. %s span=%.1fh steps=%s", gname, st["min"],
                st["max"], st["span_hours"], st["step_minutes_top"])
         fam = {g: [c for c in cols if rx.search(c)] for g, rx in GROUPS.items()}
         for gname, hits in fam.items():
            if hits:
               say("      %-14s %s", gname, hits)
         out["tables"]["%s/%s" % (label, tname)] = {
            "rows": t["rows"], "columns": cols, "families": fam,
            "time": t.get("time", {})}

   with open(args.out, "w", encoding="utf-8") as fh:
      json.dump(out, fh, indent=1, default=str)
   say("")
   say("wrote %s", args.out)


if __name__ == "__main__":
   main()
