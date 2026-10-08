# -*- coding: utf-8 -*-
"""Inventory the NEMWEB ARCHIVE listings we may need for the forecast-error study.

The CURRENT listings only carry the last ~2 days, so any historical
"official forecast vs realised price" pairing has to come from the ARCHIVE.
This probes which products have daily zips and how far back they go.
"""

import io
import os
import re

import requests

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "archive_inventory.txt")
BASE = "https://www.nemweb.com.au/Reports/ARCHIVE/"
HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) aemo-audit/1.0"}

TARGETS = {
   "DispatchIS_Reports": BASE + "DispatchIS_Reports/",
   "P5_Reports": BASE + "P5_Reports/",
   "PredispatchIS_Reports": BASE + "PredispatchIS_Reports/",
   "Predispatch_Reports": BASE + "Predispatch_Reports/",
   "DispatchIS_Reports (nested)": BASE + "DispatchIS_Reports/2026/",
   "P5_Reports (nested)": BASE + "P5_Reports/2026/",
}

buf = io.StringIO()


def say(fmt="", *args):
   buf.write((fmt % args if args else fmt) + "\n")


for name, url in TARGETS.items():
   say("=" * 78)
   say("%s", name)
   say("  %s", url)
   try:
      r = requests.get(url, headers=HEADERS, timeout=60)
      say("  HTTP %s  %d bytes", r.status_code, len(r.content))
      toks = sorted(set(re.findall(r"PUBLIC_[A-Za-z0-9_]+?\.zip", r.text, re.IGNORECASE)))
      say("  PUBLIC_*.zip tokens: %d", len(toks))
      for t in toks[:4]:
         say("      %s", t)
      if len(toks) > 4:
         say("      ...")
         for t in toks[-2:]:
            say("      %s", t)
      # date-shaped tokens tell us the coverage span of this listing
      days = sorted(set(re.findall(r"PUBLIC_[A-Z0-9]+_(\d{8})\.zip", r.text, re.IGNORECASE)))
      months = sorted(set(re.findall(r"PUBLIC_[A-Z0-9]+_(\d{6})\d{2}\.zip", r.text, re.IGNORECASE)))
      say("  daily-style names : %d  %s .. %s",
          len(days), days[0] if days else "-", days[-1] if days else "-")
      say("  months covered    : %s", months if months else "-")
      # subdirectory links (some archives are year/month nested)
      subs = sorted(set(re.findall(r'href="([^"?][^"]*/)"', r.text)))
      subs = [s for s in subs if not s.startswith("/") and s not in ("../",)][:12]
      say("  subdirs           : %s", subs if subs else "-")
   except Exception as exc:                     # noqa: BLE001
      say("  FAILED: %r", exc)

# sizes of one forecast day, to size up a backfill
say("")
say("=" * 78)
say("单个日包体积（HEAD，不下载正文）")
say("=" * 78)
for label, url in (
      ("DispatchIS", BASE + "DispatchIS_Reports/PUBLIC_DISPATCHIS_20260715.zip"),
      ("P5MIN", BASE + "P5_Reports/PUBLIC_P5MIN_20260715.zip"),
      ("PREDISPATCHIS", BASE + "PredispatchIS_Reports/PUBLIC_PREDISPATCHIS_20260715.zip"),
      ("PREDISPATCH", BASE + "Predispatch_Reports/PUBLIC_PREDISPATCH_20260715.zip"),
):
   try:
      h = requests.head(url, headers=HEADERS, timeout=60, allow_redirects=True)
      size = h.headers.get("content-length")
      say("  %-14s HTTP %s  bytes=%s  (%.1f MB)", label, h.status_code, size,
          int(size) / 1e6 if size else 0.0)
   except Exception as exc:                     # noqa: BLE001
      say("  %-14s FAILED: %r", label, exc)

with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
   fh.write(buf.getvalue())
print("wrote", OUT)
