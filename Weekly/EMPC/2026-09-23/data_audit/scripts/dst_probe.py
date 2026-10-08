# -*- coding: utf-8 -*-
"""Decide which of {monthly dashboard file, NEMWEB archive} is on a DST-aware clock.

The July comparison matched to within rounding while January needed a +1 h shift,
so exactly one of the two is on Sydney local time. A fixed-offset timebase (NEM
time = AEST/UTC+10) produces a clean 5-minute ladder across a DST transition,
whereas a DST-aware clock shows a REPEATED or a MISSING hour.

So: list the report labels of the ARCHIVE daily zips covering
  2026-04-05  (Sydney DST ends, 03:00 AEDT -> 02:00 AEST)
  2026-10-04  (Sydney DST starts, 02:00 AEST -> 03:00 AEDT)
and look for a duplicated or skipped hour.
"""

import io
import os
import re
import zipfile
from collections import Counter

import requests

PROJECT = r"C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project"
CACHE = os.path.join(PROJECT, "AEMO_Data", "archive_cache")
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "dst_probe.txt")
os.makedirs(CACHE, exist_ok=True)
buf = io.StringIO()


def say(fmt="", *args):
   buf.write((fmt % args if args else fmt) + "\n")


HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) aemo-audit/1.0"}
ARCHIVE = "https://www.nemweb.com.au/Reports/ARCHIVE/DispatchIS_Reports/"


def fetch(day):
   dest = os.path.join(CACHE, "PUBLIC_DISPATCHIS_%s.zip" % day)
   if os.path.exists(dest) and os.path.getsize(dest) > 0:
      return dest
   url = ARCHIVE + "PUBLIC_DISPATCHIS_%s.zip" % day
   with requests.get(url, headers=HEADERS, stream=True, timeout=180) as r:
      r.raise_for_status()
      tmp = dest + ".part"
      with open(tmp, "wb") as fh:
         for chunk in r.iter_content(chunk_size=1 << 16):
            fh.write(chunk)
   os.replace(tmp, dest)
   return dest


for day, note in (("20260404", "Sydney still AEDT all day"),
                  ("20260405", "Sydney DST ends 03:00 (03:00 AEDT -> 02:00 AEST)"),
                  ("20260406", "Sydney on AEST all day"),
                  ("20261004", "Sydney DST starts 02:00 (02:00 AEST -> 03:00 AEDT)")):
   say("=" * 78)
   say("ARCHIVE %s   (%s)", day, note)
   say("=" * 78)
   try:
      path = fetch(day)
   except Exception as exc:                     # noqa: BLE001
      say("  download failed: %r", exc)
      continue
   with zipfile.ZipFile(path) as zf:
      names = zf.namelist()
   stamps = []
   for n in names:
      m = re.search(r"PUBLIC_DISPATCHIS_(\d{12})_", n)
      if m:
         stamps.append(m.group(1))
   stamps.sort()
   say("  members = %d, labelled intervals = %d", len(names), len(stamps))
   say("  first=%s  last=%s", stamps[0], stamps[-1])
   hhmm = [s[8:12] for s in stamps]
   dup = [k for k, v in Counter(hhmm).items() if v > 1]
   say("  duplicated HHMM labels: %s", dup if dup else "none")
   # a full day has 288 labels; walk them and report the largest gap
   def to_min(s):
      return int(s[8:10]) * 60 + int(s[10:12])
   days = sorted({s[:8] for s in stamps})
   say("  calendar dates present: %s", days)
   mins = [to_min(s) for s in stamps]
   gaps = [(mins[i + 1] - mins[i], stamps[i], stamps[i + 1])
           for i in range(len(mins) - 1)]
   odd = [g for g in gaps if g[0] != 5]
   say("  non-5-minute steps: %d", len(odd))
   for g in odd[:6]:
      say("      step=%d min   %s -> %s", g[0], g[1], g[2])

   # what the file's own C record says, for the first and last member
   with zipfile.ZipFile(path) as zf:
      for member in (names[0], names[-1]):
         blob = zf.read(member)
         try:
            with zipfile.ZipFile(io.BytesIO(blob)) as inner:
               text = inner.read(inner.namelist()[0]).decode("utf-8", errors="replace")
         except zipfile.BadZipFile:
            text = blob.decode("utf-8", errors="replace")
         head = text.splitlines()[0]
         say("      member %s", member)
         say("        C> %s", head[:120])

say("")
say("=" * 78)
say("判读")
say("=" * 78)
say("  固定偏移时基（NEM time, AEST/UTC+10）在夏令时切换日仍是干净的 5 分钟阶梯；")
say("  悉尼本地时基会在切换日出现重复的一小时（4 月）或缺失的一小时（10 月）。")
say("  看上面 'non-5-minute steps' 与 'duplicated HHMM labels' 两行即可判定。")

with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
   fh.write(buf.getvalue())
print("wrote", OUT)
