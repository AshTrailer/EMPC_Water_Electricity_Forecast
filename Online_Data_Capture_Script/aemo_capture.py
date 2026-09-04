# ============================== aemo_capture.py ==============================
"""AEMO price & demand capture tool (NEMWEB current reports).

Maintains three csv stores under the configured output directory:
   dispatch_actual.csv      realised 5-min prices, appended forever
   predispatch_forecast.csv 30-min predispatch forecasts, last N runs kept
   p5min_forecast.csv       5-min P5 forecasts, last N runs kept

Run once for a quick check:   python aemo_capture.py --once
Run continuously:             python aemo_capture.py
"""

import argparse
import logging
import time
from datetime import datetime, timedelta
from pathlib import Path

import aemo_config as cfg
import aemo_parser as parser_mod
import aemo_store as store_mod
from aemo_common import (download_file, extract_csv_text, format_output_time,
                         list_remote_zips, parse_report_filename)

LOG = logging.getLogger("aemo")


def collect_listing(report_key):
   """Fetch the current listing and parse each zip into a small info dict."""
   url = cfg.REPORT_URLS[report_key]
   infos = []
   for filename in list_remote_zips(url):
      parsed = parse_report_filename(filename, report_key)
      if parsed is None:
         continue
      effective_dt, generation_str = parsed
      infos.append({
         "filename": filename,
         "url": url + filename,
         "effective_dt": effective_dt,
         "effective_str": format_output_time(effective_dt),
         "generation_str": generation_str,
      })
   infos.sort(key=lambda info: info["effective_dt"])
   return infos


def needs_fetch(info, report_key, existing, state):
   """True if this zip is missing from the store or carries a newer revision."""
   last_gen = store_mod.last_generation(state, report_key, info["effective_str"])
   if info["effective_str"] in existing and last_gen and info["generation_str"] <= last_gen:
      return False
   return True


def fetch_and_extract(report_key, info):
   """Download (cached) and return the csv text of one report zip."""
   dest = cfg.ZIP_CACHE_DIR / report_key / info["filename"]
   download_file(info["url"], dest)
   return extract_csv_text(dest)


def update_dispatch(state):
   """Fill any gaps of the last N days in dispatch_actual.csv."""
   infos = collect_listing("DISPATCHIS")
   cutoff = datetime.now() - timedelta(days=cfg.DISPATCH_BACKFILL_DAYS)
   infos = [i for i in infos if i["effective_dt"] >= cutoff]
   existing = store_mod.existing_batch_times(
      cfg.DISPATCH_CSV_PATH, store_mod.DISPATCH_COLUMNS, "settlement_date")
   to_fetch = [i for i in infos if needs_fetch(i, "DISPATCHIS", existing, state)]
   if not to_fetch:
      LOG.info("dispatch: up to date (%d intervals in store)", len(existing))
      return
   for info in to_fetch:
      try:
         csv_text = fetch_and_extract("DISPATCHIS", info)
         rows = parser_mod.parse_dispatch(csv_text, info["filename"], cfg.REGIONS)
         if rows.empty:
            LOG.warning("dispatch %s: parsed 0 rows, marking processed", info["filename"])
            store_mod.mark_processed(state, "DISPATCHIS", info["filename"],
                                     info["effective_str"], info["generation_str"])
            continue
         combined = store_mod.append_dispatch(cfg.DISPATCH_CSV_PATH, rows)
         store_mod.mark_processed(state, "DISPATCHIS", info["filename"],
                                  info["effective_str"], info["generation_str"])
         LOG.info("dispatch: +%d rows @ %s (store now %d rows)",
                  len(rows), info["effective_str"], len(combined))
      except Exception as exc:
         LOG.error("dispatch %s failed: %s", info["filename"], exc)


def update_forecast(report_key, state, store_path, columns, keep_batches, sort_cols):
   """Fetch missing/new forecast batches and keep only the latest N in the store."""
   infos = collect_listing(report_key)
   if not infos:
      LOG.warning("%s: no zips found in listing", report_key)
      return
   candidates = infos[-keep_batches:]
   existing = store_mod.existing_batch_times(store_path, columns, "effective_time")
   to_fetch = [i for i in candidates if needs_fetch(i, report_key, existing, state)]
   if not to_fetch:
      LOG.info("%s: up to date (%d batches in store)", report_key, len(existing))
      return
   for info in to_fetch:
      try:
         csv_text = fetch_and_extract(report_key, info)
         if report_key == "PREDISPATCHIS":
            rows = parser_mod.parse_predispatch(
               csv_text, info["filename"], cfg.REGIONS, info["effective_str"])
         else:
            rows = parser_mod.parse_p5min(
               csv_text, info["filename"], cfg.REGIONS, info["effective_str"])
         if rows.empty:
            LOG.warning("%s %s: parsed 0 rows, marking processed",
                        report_key, info["filename"])
            store_mod.mark_processed(state, report_key, info["filename"],
                                     info["effective_str"], info["generation_str"])
            continue
         evicted = store_mod.merge_forecast_batch(
            store_path, columns, rows, info["effective_str"], keep_batches, sort_cols)
         store_mod.mark_processed(state, report_key, info["filename"],
                                  info["effective_str"], info["generation_str"])
         LOG.info("%s: batch %s +%d rows, evicted %d old batch(es)",
                  report_key, info["effective_str"], len(rows), len(evicted))
      except Exception as exc:
         LOG.error("%s batch %s failed: %s", report_key, info["filename"], exc)


def run_pass(state):
   LOG.info("---- capture pass @ %s ----", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
   update_dispatch(state)
   update_forecast("PREDISPATCHIS", state, cfg.PREDISPATCH_CSV_PATH,
                   store_mod.PREDISPATCH_COLUMNS, cfg.PREDISPATCH_KEEP_BATCHES,
                   ["effective_time", "region_id", "period_id"])
   update_forecast("P5MIN", state, cfg.P5MIN_CSV_PATH,
                   store_mod.P5MIN_COLUMNS, cfg.P5MIN_KEEP_BATCHES,
                   ["effective_time", "region_id", "interval_datetime"])
   # enforce retention in case the keep counts were lowered manually
   store_mod.enforce_forecast_eviction(
      cfg.PREDISPATCH_CSV_PATH, store_mod.PREDISPATCH_COLUMNS,
      cfg.PREDISPATCH_KEEP_BATCHES, ["effective_time", "region_id", "period_id"])
   store_mod.enforce_forecast_eviction(
      cfg.P5MIN_CSV_PATH, store_mod.P5MIN_COLUMNS,
      cfg.P5MIN_KEEP_BATCHES, ["effective_time", "region_id", "interval_datetime"])
   store_mod.prune_zip_cache(cfg.ZIP_CACHE_DIR, tuple(cfg.REPORT_URLS),
                             cfg.ZIP_CACHE_KEEP_DAYS)
   store_mod.prune_state(state, cfg.PROCESSED_KEEP_DAYS)
   store_mod.save_state(cfg.STATE_JSON_PATH, state)


def parse_args():
   parser = argparse.ArgumentParser(
      description="Capture AEMO price & demand data into csv stores")
   parser.add_argument("--once", action="store_true",
                       help="run a single pass and exit")
   parser.add_argument("--output-dir", type=Path, default=None,
                       help="override the output directory")
   parser.add_argument("--predispatch-keep", type=int, default=None,
                       help="override the predispatch keep count")
   parser.add_argument("--p5min-keep", type=int, default=None,
                       help="override the p5min keep count")
   parser.add_argument("--poll-seconds", type=int, default=None,
                       help="override the loop interval (seconds)")
   parser.add_argument("--debug", action="store_true", help="verbose logging")
   return parser.parse_args()


def main():
   args = parse_args()
   if args.output_dir is not None:
      cfg.OUTPUT_DIR = Path(args.output_dir)
   if args.predispatch_keep is not None:
      cfg.PREDISPATCH_KEEP_BATCHES = args.predispatch_keep
   if args.p5min_keep is not None:
      cfg.P5MIN_KEEP_BATCHES = args.p5min_keep
   if args.poll_seconds is not None:
      cfg.LOOP_INTERVAL_SECONDS = args.poll_seconds
   # re-derive the paths after a possible output-dir override
   cfg.ZIP_CACHE_DIR = cfg.OUTPUT_DIR / "zip_cache"
   cfg.DISPATCH_CSV_PATH = cfg.OUTPUT_DIR / "dispatch_actual.csv"
   cfg.PREDISPATCH_CSV_PATH = cfg.OUTPUT_DIR / "predispatch_forecast.csv"
   cfg.P5MIN_CSV_PATH = cfg.OUTPUT_DIR / "p5min_forecast.csv"
   cfg.STATE_JSON_PATH = cfg.OUTPUT_DIR / "capture_state.json"
   logging.basicConfig(
      level=logging.DEBUG if args.debug else logging.INFO,
      format="%(asctime)s [%(levelname)s] %(message)s")
   if cfg.PREDISPATCH_KEEP_BATCHES < 1 or cfg.P5MIN_KEEP_BATCHES < 1:
      raise SystemExit("keep counts must be >= 1")
   cfg.OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
   LOG.info("output dir: %s", cfg.OUTPUT_DIR)
   LOG.info("retention: predispatch=%d batches, p5min=%d batches",
            cfg.PREDISPATCH_KEEP_BATCHES, cfg.P5MIN_KEEP_BATCHES)
   LOG.info("regions: %s", ", ".join(sorted(cfg.REGIONS)))
   state = store_mod.load_state(cfg.STATE_JSON_PATH)
   while True:
      try:
         run_pass(state)
      except KeyboardInterrupt:
         LOG.info("stopped by user")
         break
      except Exception as exc:
         LOG.exception("capture pass failed: %s", exc)
      if args.once:
         break
      LOG.info("sleeping %d s", cfg.LOOP_INTERVAL_SECONDS)
      time.sleep(cfg.LOOP_INTERVAL_SECONDS)


if __name__ == "__main__":
   main()