# ============================== aemo_config.py ==============================
"""Central configuration for the AEMO data capture tool.

Edit the values in this file instead of touching the other modules.
All paths, retention counts and poll intervals live here.
"""

import re
from pathlib import Path

# ---------------------------------------------------------------------------
# output location
# ---------------------------------------------------------------------------
OUTPUT_DIR = Path(r"C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\AEMO_Data")
ZIP_CACHE_DIR = OUTPUT_DIR / "zip_cache"

DISPATCH_CSV_PATH = OUTPUT_DIR / "dispatch_actual.csv"
PREDISPATCH_CSV_PATH = OUTPUT_DIR / "predispatch_forecast.csv"
P5MIN_CSV_PATH = OUTPUT_DIR / "p5min_forecast.csv"
STATE_JSON_PATH = OUTPUT_DIR / "capture_state.json"

# ---------------------------------------------------------------------------
# retention: how many forecast runs (batches) are kept in each forecast file
# change these at any time; eviction adapts on the next run
# ---------------------------------------------------------------------------
PREDISPATCH_KEEP_BATCHES = 10   # 30-min predispatch runs (10 runs ~ 5 h coverage)
P5MIN_KEEP_BATCHES = 60         # 5-min P5 runs; kept far larger than the predispatch
                                # count so both files cover a similar time span
                                # (60 runs ~ 5 h, aligned with the predispatch window)

# ---------------------------------------------------------------------------
# data scope
# ---------------------------------------------------------------------------
REGIONS = {"NSW1", "QLD1", "SA1", "TAS1", "VIC1"}
DISPATCH_BACKFILL_DAYS = 2      # NEMWEB keeps ~2 days of current dispatch zips;
                                # gaps inside this window are refilled on startup

# ---------------------------------------------------------------------------
# remote listings (AEMO NEMWEB public current reports)
# ---------------------------------------------------------------------------
NEMWEB_BASE_URL = "https://www.nemweb.com.au/Reports/CURRENT/"
REPORT_URLS = {
   "DISPATCHIS": NEMWEB_BASE_URL + "DispatchIS_Reports/",
   "PREDISPATCHIS": NEMWEB_BASE_URL + "PredispatchIS_Reports/",
   "P5MIN": NEMWEB_BASE_URL + "P5_Reports/",
}

# The first timestamp in the filename is the effective time and acts as the
# batch key for eviction; the second part identifies the file generation.
REPORT_FILENAME_PATTERNS = {
   "DISPATCHIS": re.compile(r"PUBLIC_DISPATCHIS_(\d{12})_(\d+)\.zip$", re.IGNORECASE),
   "PREDISPATCHIS": re.compile(r"PUBLIC_PREDISPATCHIS_(\d{12})_(\d{14})\.zip$", re.IGNORECASE),
   "P5MIN": re.compile(r"PUBLIC_P5MIN_(\d{12})_(\d{14})\.zip$", re.IGNORECASE),
}

# ---------------------------------------------------------------------------
# scheduling / http
# ---------------------------------------------------------------------------
LOOP_INTERVAL_SECONDS = 60      # one full pass over all three listings per minute
HTTP_TIMEOUT_SECONDS = 60
HTTP_RETRIES = 3
HTTP_RETRY_BACKOFF_SECONDS = 5.0

# ---------------------------------------------------------------------------
# housekeeping
# ---------------------------------------------------------------------------
ZIP_CACHE_KEEP_DAYS = 3         # delete cached zips older than this
PROCESSED_KEEP_DAYS = 4         # prune processed-file bookkeeping older than this

# ---------------------------------------------------------------------------
# time handling
# ---------------------------------------------------------------------------
# NEMWEB timestamps are NEM standard time (AEST, UTC+10, no DST shift).
# If True they are converted to Australia/Sydney local time (DST aware) for
# all *_csv outputs; set False to keep the published NEM time unchanged.
USE_AUS_LOCAL_TIME = True