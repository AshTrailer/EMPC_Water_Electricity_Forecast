# -*- coding: utf-8 -*-
"""Backfill AEMO actuals + P5 forecasts from the NEMWEB ARCHIVE.

The CURRENT listings only carry the last ~2 days, which is far too short to fit
an AEMO-forecast-error model. The ARCHIVE carries one zip per day per product:
  DispatchIS_Reports/PUBLIC_DISPATCHIS_YYYYMMDD.zip   realised 5-min prices
  P5_Reports/PUBLIC_P5MIN_YYYYMMDD.zip                5-min forecast, 1 h ahead

Each ARCHIVE daily zip is a zip of zips: 288 single-report zips, each holding one
.CSV. Both are parsed with the project's own parser (Online_Data_Capture_Script),
so the fixes made there apply here too.

Output (append-only, one file per product, one row set per day):
  <out>/dispatch_5min.csv     settlement_date, region_id, rrp, total_demand,
                              run_no, intervention
  <out>/p5min.csv             effective_time, region_id, interval_datetime,
                              rrp, total_demand, intervention
  <out>/_days_done.json       resumability bookkeeping

Usage:
  python backfill_archive.py --start 20260901 --end 20260907 --regions VIC1
"""

import argparse
import io
import json
import logging
import os
import sys
import time
import zipfile

import pandas as pd
import requests

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = r"C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project"
CAPTURE = os.path.join(PROJECT, "Online_Data_Capture_Script")
ZIP_CACHE = os.path.join(PROJECT, "AEMO_Data", "archive_cache")

sys.path.insert(0, CAPTURE)
os.chdir(CAPTURE)
logging.disable(logging.WARNING)
import aemo_config as cfg                        # noqa: E402
cfg.USE_AUS_LOCAL_TIME = False                   # everything stays on NEM time
import aemo_parser as P                          # noqa: E402

BASE = "https://www.nemweb.com.au/Reports/ARCHIVE/"
URLS = {
   "DISPATCHIS": BASE + "DispatchIS_Reports/PUBLIC_DISPATCHIS_%s.zip",
   "P5MIN": BASE + "P5_Reports/PUBLIC_P5MIN_%s.zip",
}
HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) aemo-backfill/1.0"}

LOG = logging.getLogger("backfill")


def say(fmt="", *args):
   print(fmt % args if args else fmt, flush=True)


def fetch(product, day):
   """Download one ARCHIVE daily zip (cached) and return its path."""
   dest = os.path.join(ZIP_CACHE, "PUBLIC_%s_%s.zip" % (product, day))
   if os.path.exists(dest) and os.path.getsize(dest) > 0:
      return dest, False
   url = URLS[product] % day
   tmp = dest + ".part"
   for attempt in range(3):
      try:
         with requests.get(url, headers=HEADERS, stream=True, timeout=300) as r:
            r.raise_for_status()
            with open(tmp, "wb") as fh:
               for chunk in r.iter_content(chunk_size=1 << 18):
                  fh.write(chunk)
         os.replace(tmp, dest)
         return dest, True
      except Exception as exc:                   # noqa: BLE001
         say("      download attempt %d failed: %r", attempt + 1, exc)
         time.sleep(5.0)
   raise RuntimeError("could not download " + url)


def iter_reports(path):
   """Yield the decoded CSV text of every single-report zip inside a daily zip.

   Accepts a plain .CSV member too, so this also works on the CURRENT-style zips.
   """
   with zipfile.ZipFile(path) as zf:
      for member in zf.namelist():
         blob = zf.read(member)
         if member.lower().endswith(".zip"):
            try:
               with zipfile.ZipFile(io.BytesIO(blob)) as inner:
                  csvs = [n for n in inner.namelist() if n.lower().endswith(".csv")]
                  if not csvs:
                     continue
                  yield member, inner.read(csvs[0]).decode("utf-8", errors="replace")
            except zipfile.BadZipFile:
               continue
         elif member.lower().endswith(".csv"):
            yield member, blob.decode("utf-8", errors="replace")


def parse_day(product, day, regions):
   path, fresh = fetch(product, day)
   frames = []
   for member, text in iter_reports(path):
      # member name carries the batch effective time, same shape as the CURRENT feed
      if product == "DISPATCHIS":
         frame = P.parse_dispatch(text, member, regions)
      else:
         stem = os.path.basename(member)
         eff = None
         for part in stem.replace(".zip", "").replace(".CSV", "").replace(".csv", "").split("_"):
            if len(part) == 12 and part.isdigit():
               eff = "%s-%s-%s %s:%s:00" % (part[0:4], part[4:6], part[6:8],
                                            part[8:10], part[10:12])
               break
         if eff is None:
            continue
         frame = P.parse_p5min(text, member, regions, eff)
      if not frame.empty:
         frames.append(frame)
   if not frames:
      return pd.DataFrame(), fresh
   return pd.concat(frames, ignore_index=True), fresh


def main():
   ap = argparse.ArgumentParser(description="Backfill AEMO actuals + P5 forecasts")
   ap.add_argument("--start", required=True, help="YYYYMMDD inclusive")
   ap.add_argument("--end", required=True, help="YYYYMMDD inclusive")
   ap.add_argument("--regions", default="VIC1", help="comma separated")
   ap.add_argument("--out", default=os.path.join(PROJECT, "AEMO_Data", "forecast_actual"))
   ap.add_argument("--products", default="DISPATCHIS,P5MIN")
   ap.add_argument("--purge-zips", action="store_true",
                   help="delete the daily zips once parsed (P5MIN is ~57 MB/day)")
   args = ap.parse_args()

   regions = {r.strip().upper() for r in args.regions.split(",") if r.strip()}
   products = [p.strip().upper() for p in args.products.split(",") if p.strip()]
   os.makedirs(args.out, exist_ok=True)
   os.makedirs(ZIP_CACHE, exist_ok=True)
   days = [d.strftime("%Y%m%d")
           for d in pd.date_range(pd.Timestamp(args.start), pd.Timestamp(args.end))]
   done_path = os.path.join(args.out, "_days_done.json")
   done = {}
   if os.path.exists(done_path):
      with open(done_path, "r", encoding="utf-8") as fh:
         done = json.load(fh)

   say("backfill %s .. %s  (%d days)  regions=%s  products=%s",
       args.start, args.end, len(days), sorted(regions), products)

   for product in products:
      store = os.path.join(args.out, "%s.csv" % ("dispatch_5min" if product == "DISPATCHIS"
                                                 else "p5min"))
      for day in days:
         key = "%s:%s" % (product, day)
         if done.get(key):
            say("  %-11s %s  already done (%s rows)", product, day, done[key])
            continue
         t0 = time.time()
         try:
            frame, fresh = parse_day(product, day, regions)
         except Exception as exc:                # noqa: BLE001
            say("  %-11s %s  FAILED: %r", product, day, exc)
            continue
         if frame.empty:
            say("  %-11s %s  parsed 0 rows", product, day)
            continue
         if product == "DISPATCHIS":
            frame = frame[frame["settlement_date"] != ""]
            frame["_run"] = pd.to_numeric(frame["run_no"], errors="coerce").fillna(0)
            frame = frame.sort_values("_run", kind="stable")
            frame = frame.drop_duplicates(subset=["settlement_date", "region_id"],
                                          keep="last")
            frame = frame.drop(columns="_run")
            cols = ["settlement_date", "region_id", "rrp", "total_demand",
                    "run_no", "intervention"]
         else:
            frame = frame[frame["interval_datetime"] != ""]
            frame = frame.drop_duplicates(subset=["effective_time", "region_id",
                                                  "interval_datetime"], keep="last")
            cols = ["effective_time", "region_id", "interval_datetime", "rrp",
                    "total_demand", "intervention"]
         frame = frame[cols].sort_values(cols[:3]).reset_index(drop=True)
         header = not os.path.exists(store)
         frame.to_csv(store, mode="a", header=header, index=False)
         done[key] = int(len(frame))
         with open(done_path, "w", encoding="utf-8") as fh:
            json.dump(done, fh, indent=1)
         say("  %-11s %s  +%6d rows  %s  (%.1f s, zip %s)",
             product, day, len(frame), store.split(os.sep)[-1],
             time.time() - t0, "downloaded" if fresh else "cached")
   say("")
   say("done. stores in %s", args.out)
   for f in sorted(os.listdir(args.out)):
      p = os.path.join(args.out, f)
      if os.path.isfile(p):
         say("  %-24s %10d bytes", f, os.path.getsize(p))
   if args.purge_zips:
      freed = 0
      for product in products:
         for day in days:
            p = os.path.join(ZIP_CACHE, "PUBLIC_%s_%s.zip" % (product, day))
            if os.path.exists(p):
               freed += os.path.getsize(p)
               os.remove(p)
      say("purged daily zips: %.1f MB freed", freed / 1e6)


if __name__ == "__main__":
   main()
