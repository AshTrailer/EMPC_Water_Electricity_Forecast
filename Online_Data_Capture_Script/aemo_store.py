# ============================== aemo_store.py ==============================
"""Store management: append-only actuals and batch-retention forecasts."""

import json
import logging
from datetime import datetime, timedelta

import pandas as pd

from aemo_common import parse_report_filename

LOG = logging.getLogger("aemo")

DISPATCH_COLUMNS = [
   "settlement_date", "region_id", "rrp", "eep", "total_demand",
   "run_no", "dispatch_interval", "intervention", "source_file",
]
PREDISPATCH_COLUMNS = [
   "effective_time", "predispatch_seqno", "run_no", "region_id",
   "period_id", "rrp", "eep", "total_demand", "intervention", "source_file",
]
P5MIN_COLUMNS = [
   "effective_time", "region_id", "interval_datetime",
   "rrp", "total_demand", "intervention", "source_file",
]


def read_store(path, columns):
   """Read a store csv; return an empty frame with the right columns if absent."""
   if path.exists():
      try:
         return pd.read_csv(path, dtype=str, keep_default_na=False)
      except pd.errors.EmptyDataError:
         pass
   return pd.DataFrame(columns=columns)


def write_store(path, frame):
   path.parent.mkdir(parents=True, exist_ok=True)
   frame.to_csv(path, index=False, na_rep="")


def append_dispatch(path, new_rows):
   """Append realised-price rows; dedup keeps the highest RUNNO per interval/region."""
   old = read_store(path, DISPATCH_COLUMNS)
   combined = pd.concat([old, new_rows[DISPATCH_COLUMNS]], ignore_index=True)
   combined["_run_sort"] = pd.to_numeric(combined["run_no"], errors="coerce").fillna(0)
   combined = combined.sort_values(["settlement_date", "_run_sort"], kind="stable")
   combined = combined.drop_duplicates(subset=["settlement_date", "region_id"], keep="last")
   combined = combined.drop(columns="_run_sort")
   combined = combined.sort_values(["settlement_date", "region_id"],
                                   kind="stable").reset_index(drop=True)
   write_store(path, combined)
   return combined


def merge_forecast_batch(path, columns, new_rows, batch_time, keep_batches, sort_cols):
   """Replace the rows of one batch, then evict anything older than the last N batches."""
   old = read_store(path, columns)
   old = old[old["effective_time"] != batch_time]
   combined = pd.concat([old, new_rows[columns]], ignore_index=True)
   kept, evicted = _keep_latest_batches(combined, keep_batches)
   kept = kept.sort_values(sort_cols, kind="stable").reset_index(drop=True)
   write_store(path, kept)
   return evicted


def enforce_forecast_eviction(path, columns, keep_batches, sort_cols):
   """Shrink a forecast store to its latest N batches (for manual N reductions)."""
   frame = read_store(path, columns)
   if frame.empty:
      return
   kept, evicted = _keep_latest_batches(frame, keep_batches)
   if evicted:
      kept = kept.sort_values(sort_cols, kind="stable").reset_index(drop=True)
      write_store(path, kept)
      LOG.info("%s: evicted %d old batch(es): %s",
               path.name, len(evicted), ", ".join(evicted[:3]))


def _keep_latest_batches(frame, keep_batches):
   batch_times = sorted(frame["effective_time"].unique())
   keep_times = set(batch_times[-keep_batches:]) if batch_times else set()
   evicted = [t for t in batch_times if t not in keep_times]
   return frame[frame["effective_time"].isin(keep_times)], evicted


def existing_batch_times(path, columns, key_column):
   frame = read_store(path, columns)
   return set(frame[key_column]) if not frame.empty else set()


def load_state(state_path):
   if state_path.exists():
      try:
         with open(state_path, "r", encoding="utf-8") as handle:
            return json.load(handle)
      except (OSError, ValueError):
         LOG.warning("state file unreadable, starting fresh: %s", state_path)
   return {"processed": {}, "last_gen": {}}


def save_state(state_path, state):
   state_path.parent.mkdir(parents=True, exist_ok=True)
   tmp_path = state_path.with_suffix(".tmp")
   with open(tmp_path, "w", encoding="utf-8") as handle:
      json.dump(state, handle, indent=2)
   tmp_path.replace(state_path)


def last_generation(state, report_key, effective_str):
   return state.get("last_gen", {}).get(report_key, {}).get(effective_str)


def mark_processed(state, report_key, filename, effective_str, generation_str):
   state.setdefault("processed", {}).setdefault(report_key, {})[filename] = effective_str
   state.setdefault("last_gen", {}).setdefault(report_key, {})[effective_str] = generation_str


def prune_state(state, keep_days):
   """Drop bookkeeping entries older than keep_days (they can never matter again)."""
   cutoff = datetime.now() - timedelta(days=keep_days)
   processed = state.get("processed", {})
   for report_key in list(processed.keys()):
      for filename in list(processed[report_key].keys()):
         info = parse_report_filename(filename, report_key)
         if info is None:
            continue
         if info[0] < cutoff:
            processed[report_key].pop(filename, None)
   last_gen = state.get("last_gen", {})
   for report_key in list(last_gen.keys()):
      for effective_str in list(last_gen[report_key].keys()):
         effective_dt = _parse_effective_str(effective_str)
         if effective_dt is not None and effective_dt < cutoff:
            last_gen[report_key].pop(effective_str, None)


def _parse_effective_str(text):
   try:
      return datetime.strptime(text, "%Y-%m-%d %H:%M:%S")
   except (TypeError, ValueError):
      return None


def prune_zip_cache(cache_dir, report_keys, keep_days):
   """Delete cached zips older than keep_days."""
   cutoff = datetime.now() - timedelta(days=keep_days)
   for report_key in report_keys:
      folder = cache_dir / report_key
      if not folder.exists():
         continue
      for path in folder.glob("*.zip"):
         info = parse_report_filename(path.name, report_key)
         if info is None:
            continue
         if info[0] < cutoff:
            path.unlink(missing_ok=True)
            LOG.debug("removed stale cached zip: %s", path.name)