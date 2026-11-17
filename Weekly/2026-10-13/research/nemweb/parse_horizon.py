# -*- coding: utf-8 -*-
"""Per-file horizon audit of PREDISPATCHIS and PREDISPATCH reports.

For every downloaded zip it records, from the file's own bytes:
  * the table/column inventory (from the 'I,' header lines, cheap and complete)
  * the batch effective time (12-digit filename stamp)
  * the report's own declared run time (RUN_DATETIME / PREDISPATCHSEQNO)
  * per region: period_id min/max, period count, min/max target_datetime
  * horizon_hours = (max target_datetime - effective_time) / 1h
  * the time-of-day at which the horizon ends

Deliberately parses ONLY the region tables: the reports carry a ~65k-row
CONSTRAINT_SOLUTION / PDCONS table that holds no price and would dominate both
runtime and memory. Everything the audit needs lives in the region tables; the
full field inventory comes from the header lines, which need no row parsing.

Usage: python parse_horizon.py --root <research dir> --kind predispatchis|predispatch
"""

import argparse
import collections
import glob
import io
import json
import os
import re
import sys
import types
import zipfile

import pandas as pd

PROJECT = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast"
CAPTURE = os.path.join(PROJECT, "Online_Data_Capture_Script")

stub = types.ModuleType("requests")


class RequestException(IOError):
   pass


def _unavailable(*_a, **_k):
   raise RequestException("requests is not installed")


stub.RequestException = RequestException
stub.get = _unavailable
stub.post = _unavailable
stub.Session = _unavailable
sys.modules["requests"] = stub

sys.path.insert(0, CAPTURE)
import aemo_parser as P                                 # noqa: E402

REGIONS = ["NSW1", "QLD1", "SA1", "TAS1", "VIC1"]
# region tables that can carry a price or a demand and therefore a horizon
KEEP = {"REGION_PRICES", "REGION_SOLUTION", "PDREGION", "PDIREGION",
        "REGIONSUM", "REGIONSOLUTION"}


def say(fmt="", *args):
   print(fmt % args if args else fmt, flush=True)


def table_name(parts):
   if len(parts) < 3:
      return None
   second = parts[2]
   if second and not second.isdigit():
      return second
   return parts[1]


def read_member(path):
   with zipfile.ZipFile(path) as zf:
      for m in zf.namelist():
         blob = zf.read(m)
         if m.lower().endswith(".zip"):
            with zipfile.ZipFile(io.BytesIO(blob)) as inner:
               csvs = [n for n in inner.namelist() if n.lower().endswith(".csv")]
               return inner.read(csvs[0]).decode("utf-8", errors="replace"), m
         if m.lower().endswith(".csv"):
            return blob.decode("utf-8", errors="replace"), m
   raise ValueError("no csv member in " + path)


def header_inventory(text):
   """{table_name: [columns]} from the 'I,' lines, plus how many I lines seen."""
   inv = collections.OrderedDict()
   for raw in text.splitlines():
      if not raw.startswith("I,"):
         continue
      parts = P._split_record(raw)
      name = table_name(parts)
      cols = parts[4:] if (parts[2] and not parts[2].isdigit()) else parts[3:]
      if name and cols:
         inv.setdefault(name, cols)
   return inv


def filter_region_tables(text):
   out = []
   current = None
   for raw in text.splitlines():
      if not raw:
         continue
      h = raw[0]
      if h == "I":
         current = table_name(P._split_record(raw))
         if current in KEEP:
            out.append(raw)
      elif h == "D":
         if current in KEEP:
            out.append(raw)
      elif h == "C":
         out.append(raw)
   return "\n".join(out)


def target_series(frame):
   """Return (target_datetimes, source_description) for a region table."""
   for col in ("DATETIME", "INTERVAL_DATETIME"):
      if col in frame.columns:
         ser = pd.to_datetime(frame[col], format="%Y/%m/%d %H:%M:%S",
                              errors="coerce")
         if ser.notna().any():
            return ser, col
   if "PERIODID" in frame.columns:
      ser = pd.to_datetime(frame["PERIODID"], format="%Y/%m/%d %H:%M:%S",
                           errors="coerce")
      if ser.notna().any():
         return ser, "PERIODID(timestamp)"
   return None, None


def analyse(path):
   stem = os.path.basename(path)
   m = re.search(r"_(\d{12})_", stem)
   eff_stamp = m.group(1) if m else None
   eff = pd.to_datetime(eff_stamp, format="%Y%m%d%H%M") if eff_stamp else None

   text, member = read_member(path)
   inv = header_inventory(text)
   filtered = filter_region_tables(text)
   tables = P.parse_nemweb_tables(filtered)

   rec = {"file": stem, "member": os.path.basename(member),
          "effective_time": str(eff), "tables": {k: v for k, v in inv.items()},
          "n_tables": len(inv), "regions": {}, "horizon_hours": None,
          "target_col": None, "run_datetime": None, "seqno": None,
          "period_id_min": None, "period_id_max": None, "period_count": None}

   # the report's own run time
   for key, tab in tables.items():
      if "RUN_DATETIME" in tab["columns"] and tab["rows"]:
         rec["run_datetime"] = tab["rows"][0][tab["columns"].index("RUN_DATETIME")]
      if "PREDISPATCHSEQNO" in tab["columns"] and tab["rows"]:
         rec["seqno"] = tab["rows"][0][tab["columns"].index("PREDISPATCHSEQNO")]

   # prefer the table that carries RRP
   chosen = None
   for key, tab in tables.items():
      if "REGIONID" in tab["columns"] and "RRP" in tab["columns"]:
         chosen = (key, tab)
         break
   if chosen is None:
      for key, tab in tables.items():
         if "REGIONID" in tab["columns"] and "TOTALDEMAND" in tab["columns"]:
            chosen = (key, tab)
            break
   if chosen is None:
      return rec

   key, tab = chosen
   frame = pd.DataFrame(tab["rows"], columns=tab["columns"])
   rec["price_table"] = "%s/%s" % key
   tgt, tcol = target_series(frame)
   rec["target_col"] = tcol
   if tgt is None:
      return rec
   frame = frame.assign(_tgt=tgt).dropna(subset=["_tgt"])
   if "PERIODID" in frame.columns:
      pid = pd.to_numeric(frame["PERIODID"], errors="coerce")
      if pid.notna().any():
         rec["period_id_min"] = int(pid.min())
         rec["period_id_max"] = int(pid.max())
         rec["period_count"] = int(pid.nunique())

   for region in REGIONS:
      sub = frame[frame["REGIONID"] == region]
      if sub.empty:
         continue
      rec["regions"][region] = {
         "periods": int(sub["_tgt"].nunique()),
         "min_target": sub["_tgt"].min().strftime("%Y-%m-%d %H:%M:%S"),
         "max_target": sub["_tgt"].max().strftime("%Y-%m-%d %H:%M:%S"),
      }
   allmax = frame["_tgt"].max()
   if eff is not None and pd.notna(allmax):
      rec["horizon_hours"] = float((allmax - eff).total_seconds() / 3600.0)
      rec["horizon_end_tod"] = allmax.strftime("%H:%M")
   rec["regions"] = rec["regions"]
   rec["period_count_all_regions"] = int(
      frame.groupby("REGIONID")["_tgt"].nunique().to_dict().__len__())
   return rec


def main():
   ap = argparse.ArgumentParser()
   ap.add_argument("--root", required=True)
   ap.add_argument("--kind", required=True,
                   choices=["predispatchis", "predispatch"])
   ap.add_argument("--report", required=True)
   ap.add_argument("--inventory", required=True,
                   help="where to write the table/column inventory")
   args = ap.parse_args()

   d = os.path.join(args.root, args.kind)
   files = sorted(glob.glob(os.path.join(d, "*.zip")))
   say("%s: %d zips", args.kind, len(files))

   records = []
   inv_all = collections.OrderedDict()
   for i, path in enumerate(files, 1):
      try:
         rec = analyse(path)
      except Exception as exc:                          # noqa: BLE001
         say("  %s FAILED %r", os.path.basename(path), exc)
         records.append({"file": os.path.basename(path), "error": repr(exc)})
         continue
      records.append(rec)
      for tname, cols in rec.get("tables", {}).items():
         inv_all.setdefault(tname, cols)
      if i % 10 == 0 or i == len(files):
         say("  %d/%d parsed", i, len(files))

   with open(args.report, "w", encoding="utf-8") as fh:
      json.dump(records, fh, indent=1)
   with open(args.inventory, "w", encoding="utf-8") as fh:
      json.dump(inv_all, fh, indent=1)

   ok = [r for r in records if r.get("horizon_hours") is not None]
   say("")
   say("parsed with a horizon: %d / %d", len(ok), len(records))
   if ok:
      h = pd.Series([r["horizon_hours"] for r in ok])
      say("horizon_hours: min=%.3f  median=%.3f  max=%.3f  mean=%.3f",
          h.min(), h.median(), h.max(), h.mean())
      say("period counts : %s",
          pd.Series([r["period_count"] for r in ok if r["period_count"]]
                    ).value_counts().sort_index().to_dict())
      say("horizon end time-of-day: %s",
          collections.Counter(r.get("horizon_end_tod") for r in ok).most_common())
      say("files with horizon > 40 h: %d", int((h > 40).sum()))
      say("files with horizon >= 48 h: %d", int((h >= 48).sum()))
      say("max horizon file: %s", max(ok, key=lambda r: r["horizon_hours"])["file"])
   say("tables seen: %s", list(inv_all.keys()))
   say("wrote %s and %s", args.report, args.inventory)


if __name__ == "__main__":
   main()
