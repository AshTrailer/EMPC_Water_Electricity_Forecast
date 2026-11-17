# -*- coding: utf-8 -*-
"""Full table/column inventory and time-shape of every downloaded sample.

Streams each zip member line by line, so the 225 MB STPASA ARCHIVE sample cannot
exhaust memory. Per table it records:
  * row count (all D rows, streaming)
  * the complete column list, from the 'I,' header line
  * for datetime-ish columns, min/max/count over up to DATETIME_CAP rows, and the
    distinct step in minutes over that sample
  * flags for price / demand / solar-PV / wind / available-generation / reserve
    looking columns

NEMWEB CSVs carry no unit metadata. Units are therefore reported separately and
labelled as coming from AEMO's MMS data model, not from the file.

Usage: python 05_inventory.py --root <research dir> --out <json>
"""

import argparse
import glob
import io
import json
import os
import re
import sys
import types
import zipfile
from datetime import datetime

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

DATETIME_CAP = 100_000

FLAGS = {
   "price": re.compile(r"(RRP|PRICE|COST)", re.I),
   "demand": re.compile(r"DEMAND", re.I),
   "solar_pv": re.compile(r"(SOLAR|ROOFTOP|_PV|PV_)", re.I),
   "wind": re.compile(r"WIND", re.I),
   "available_gen": re.compile(r"(AVAIL|CAPACITY|UIGF|CLEAREDMW)", re.I),
   "reserve": re.compile(r"(RESERVE|REGULATION|FCAS|RAISE|LOWER|LOR|LCR)", re.I),
   "interchange": re.compile(r"INTERCHANGE", re.I),
}
TIME_COL = re.compile(r"(DATETIME|_DATE$|^DATE$|PERIODID|SETTLEMENTDATE)", re.I)
DT_FORMATS = ("%Y/%m/%d %H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y/%m/%d %H:%M", "%Y%m%d%H%M%S")


def say(fmt="", *args):
   print(fmt % args if args else fmt, flush=True)


def table_name(parts):
   if len(parts) < 3:
      return None
   second = parts[2]
   if second and not second.isdigit():
      return second
   return parts[1]


def parse_dt(text):
   text = text.strip()
   if not text:
      return None
   for f in DT_FORMATS:
      try:
         return datetime.strptime(text, f)
      except ValueError:
         continue
   return None


def scan_member(fh, name):
   """Stream one CSV member; return {table: {...}}."""
   tables = {}
   current = None
   for raw in fh:
      line = raw.decode("utf-8", errors="replace").rstrip("\r\n")
      if not line:
         continue
      tag = line[0]
      if tag == "I":
         parts = P._split_record(line)
         tname = table_name(parts)
         cols = parts[4:] if (parts[2] and not parts[2].isdigit()) else parts[3:]
         if tname and cols:
            current = tname
            tables.setdefault(tname, {"columns": cols, "rows": 0, "time": {},
                                      "note": ""})
         else:
            current = None
         continue
      if tag != "D" or current is None or current not in tables:
         continue
      t = tables[current]
      t["rows"] += 1
      if t["rows"] > DATETIME_CAP:
         t["note"] = "datetime stats cover the first %d rows only" % DATETIME_CAP
         continue
      parts = P._split_record(line)
      payload = parts[4:] if (parts[2] and not parts[2].isdigit()) else parts[3:]
      for idx, col in enumerate(t["columns"]):
         if not TIME_COL.search(col) or idx >= len(payload):
            continue
         dt = parse_dt(payload[idx])
         if dt is None:
            continue
         st = t["time"].setdefault(col, {"min": dt, "max": dt, "n": 0,
                                         "vals": set()})
         st["min"] = min(st["min"], dt)
         st["max"] = max(st["max"], dt)
         st["n"] += 1
         if len(st["vals"]) < 8000:
            st["vals"].add(dt)
   # compress the datetime stats
   for tname, t in tables.items():
      for col, st in list(t["time"].items()):
         vals = sorted(st["vals"])
         steps = {}
         for a, b in zip(vals, vals[1:]):
            m = int((b - a).total_seconds() // 60)
            steps[m] = steps.get(m, 0) + 1
         t["time"][col] = {
            "min": st["min"].strftime("%Y-%m-%d %H:%M:%S"),
            "max": st["max"].strftime("%Y-%m-%d %H:%M:%S"),
            "n_parsed": st["n"],
            "distinct_within_cap": len(vals),
            "step_minutes_top": sorted(steps.items(), key=lambda kv: -kv[1])[:4],
            "span_hours": round((st["max"] - st["min"]).total_seconds() / 3600.0, 3),
         }
   return tables


def inventory_zip(path, max_members=0):
   out = {"file": os.path.basename(path), "bytes": os.path.getsize(path),
          "members": [], "tables": {}}
   with zipfile.ZipFile(path) as zf:
      names = zf.namelist()
      out["members"] = names
      out["members_total"] = len(names)
      scanned = names if not max_members else names[:max_members]
      out["members_scanned"] = len(scanned)
      if max_members and len(names) > max_members:
         out["note"] = ("only the first %d of %d members were scanned; this is a "
                        "multi-member ARCHIVE zip" % (max_members, len(names)))
      for m in scanned:
         if m.lower().endswith(".zip"):
            with zf.open(m) as fh:
               blob = fh.read()
            with zipfile.ZipFile(io.BytesIO(blob)) as inner:
               csvs = [n for n in inner.namelist() if n.lower().endswith(".csv")]
               for c in csvs:
                  with inner.open(c) as fh:
                     tabs = scan_member(fh, c)
                  for k, v in tabs.items():
                     out["tables"].setdefault(k, v)
         elif m.lower().endswith(".csv"):
            with zf.open(m) as fh:
               tabs = scan_member(fh, m)
            for k, v in tabs.items():
               out["tables"].setdefault(k, v)
   return out


def main():
   ap = argparse.ArgumentParser()
   ap.add_argument("--root", required=True)
   ap.add_argument("--out", required=True)
   ap.add_argument("--skip", default="", help="comma separated sample labels to skip")
   ap.add_argument("--only", default="", help="comma separated sample labels to do")
   ap.add_argument("--max-members", type=int, default=0,
                   help="cap members scanned per zip (0 = all)")
   args = ap.parse_args()

   skip = {s.strip() for s in args.skip.split(",") if s.strip()}
   only = {s.strip() for s in args.only.split(",") if s.strip()}
   samples = sorted(glob.glob(os.path.join(args.root, "samples", "*", "*.zip")))
   samples = [p for p in samples
              if os.path.basename(os.path.dirname(p)) not in skip
              and (not only or os.path.basename(os.path.dirname(p)) in only)]
   say("samples to scan: %d (skipped %d)", len(samples), len(skip))
   result = {}
   for path in samples:
      label = os.path.basename(os.path.dirname(path))
      say("")
      say("=== %s  (%s, %.1f MB)", label, os.path.basename(path),
          os.path.getsize(path) / 1e6)
      try:
         inv = inventory_zip(path, max_members=args.max_members)
      except Exception as exc:                           # noqa: BLE001
         say("    FAILED %r", exc)
         result[label] = {"file": os.path.basename(path), "error": repr(exc)}
         continue
      result[label] = inv
      if inv.get("note"):
         say("    note: %s", inv["note"])
      for tname, t in inv["tables"].items():
         cols = t["columns"]
         flags = [k for k, rx in FLAGS.items() if any(rx.search(c) for c in cols)]
         say("    %-28s rows=%-8d cols=%-3d  flags=%s", tname, t["rows"],
             len(cols), ",".join(flags) or "-")
         for col, st in t["time"].items():
            say("        %-20s %s .. %s  span=%.1fh steps=%s", col, st["min"],
                st["max"], st["span_hours"], st["step_minutes_top"])
         if t["rows"] and t["rows"] <= 4000:
            say("        columns: %s", cols)
         else:
            say("        columns (first 40): %s", cols[:40])

   with open(args.out, "w", encoding="utf-8") as fh:
      json.dump(result, fh, indent=1, default=str)
   say("")
   say("wrote %s (%d samples)", args.out, len(result))


if __name__ == "__main__":
   main()
