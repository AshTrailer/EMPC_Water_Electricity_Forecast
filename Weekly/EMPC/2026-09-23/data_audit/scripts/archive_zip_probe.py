# -*- coding: utf-8 -*-
"""Inspect one NEMWEB ARCHIVE daily DispatchIS zip (download + structure)."""

import io
import os
import sys
import zipfile

import requests

PROJECT = r"C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project"
CAPTURE = os.path.join(PROJECT, "Online_Data_Capture_Script")
CACHE = os.path.join(PROJECT, "AEMO_Data", "archive_cache")
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "archive_zip_probe.txt")
os.makedirs(CACHE, exist_ok=True)
buf = io.StringIO()


def say(fmt="", *args):
   buf.write((fmt % args if args else fmt) + "\n")


HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) aemo-audit/1.0"}
ARCHIVE = "https://www.nemweb.com.au/Reports/ARCHIVE/DispatchIS_Reports/"

for day in ("20260115", "20260715"):
   url = ARCHIVE + "PUBLIC_DISPATCHIS_%s.zip" % day
   dest = os.path.join(CACHE, "PUBLIC_DISPATCHIS_%s.zip" % day)
   say("=" * 74)
   say("day = %s", day)
   say("  url = %s", url)
   if os.path.exists(dest) and os.path.getsize(dest) > 0:
      say("  cached: %d bytes", os.path.getsize(dest))
   else:
      try:
         with requests.get(url, headers=HEADERS, stream=True, timeout=180) as r:
            say("  HTTP %s  content-length=%s", r.status_code, r.headers.get("content-length"))
            r.raise_for_status()
            tmp = dest + ".part"
            with open(tmp, "wb") as fh:
               for chunk in r.iter_content(chunk_size=1 << 16):
                  fh.write(chunk)
         os.replace(tmp, dest)
         say("  downloaded: %d bytes", os.path.getsize(dest))
      except Exception as exc:                  # noqa: BLE001
         say("  DOWNLOAD FAILED: %r", exc)
         continue
   try:
      with zipfile.ZipFile(dest) as zf:
         names = zf.namelist()
         say("  members = %d", len(names))
         for n in names[:5]:
            say("      %s", n)
         say("      ...")
         for n in names[-2:]:
            say("      %s", n)
         member = names[0]
         raw = zf.read(member)
         say("  first member %s : %d bytes", member, len(raw))
         text = raw.decode("utf-8", errors="replace")
         lines = [ln for ln in text.splitlines() if ln.strip()]
         say("  first line : %s", lines[0][:200])
         i_lines = [ln for ln in lines if ln.startswith("I,")]
         d_lines = [ln for ln in lines if ln.startswith("D,")]
         say("  I=%d  D=%d", len(i_lines), len(d_lines))
         for ln in i_lines:
            if "PRICE" in ln.split(",")[2] or "REGIONSUM" in ln.split(",")[2]:
               say("      I> %s", ln[:180])
         for ln in d_lines[:4]:
            say("      D> %s", ln[:180])
   except Exception as exc:                     # noqa: BLE001
      say("  ZIP READ FAILED: %r", exc)

# now try the project parser against it
sys.path.insert(0, CAPTURE)
os.chdir(CAPTURE)
import logging                                   # noqa: E402
logging.basicConfig(level=logging.WARNING)
import aemo_parser as P                          # noqa: E402

for day in ("20260115", "20260715"):
   dest = os.path.join(CACHE, "PUBLIC_DISPATCHIS_%s.zip" % day)
   if not os.path.exists(dest):
      continue
   say("")
   say("=" * 74)
   say("parser on %s", day)
   say("=" * 74)
   total = 0
   ok = 0
   empty = 0
   sample = None
   with zipfile.ZipFile(dest) as zf:
      for member in zf.namelist():
         if not member.lower().endswith(".csv"):
            continue
         total += 1
         text = zf.read(member).decode("utf-8", errors="replace")
         f = P.parse_dispatch(text, member, {"NSW1", "QLD1", "SA1", "TAS1", "VIC1"})
         if f.empty:
            empty += 1
         else:
            ok += 1
            if sample is None:
               sample = f
   say("  csv members=%d  parsed non-empty=%d  empty=%d", total, ok, empty)
   if sample is not None:
      say("%s", sample.to_string(index=False))

with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
   fh.write(buf.getvalue())
print("wrote", OUT)
