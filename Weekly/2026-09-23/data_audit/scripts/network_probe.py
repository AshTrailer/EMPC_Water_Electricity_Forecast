# -*- coding: utf-8 -*-
"""Read-only network probe: is NEMWEB reachable, and how big are the archives?

Answers three questions before we commit to a comparison design:
  1. can this machine reach nemweb.com.au at all (env-facts says curl is broken
     by schannel, so we test Python requests and report the failure mode);
  2. what does the CURRENT listing look like right now (how stale is our cache);
  3. does the ARCHIVE carry per-day DispatchIS zips for a month we already have
     monthly data for (2026-07), and how large are they.
"""

import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "network_probe_report.txt")
buf = io.StringIO()


def say(fmt="", *args):
   buf.write((fmt % args if args else fmt) + "\n")


say("python: %s", sys.version.replace("\n", " "))
try:
   import requests
   say("requests: %s", requests.__version__)
except Exception as exc:                       # noqa: BLE001
   say("requests MISSING: %r", exc)
   with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
      fh.write(buf.getvalue())
   raise SystemExit(0)

HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) aemo-audit/1.0"}
TO = 45

TARGETS = [
   ("CURRENT listing", "https://www.nemweb.com.au/Reports/CURRENT/DispatchIS_Reports/"),
   ("ARCHIVE listing (root)", "https://www.nemweb.com.au/Reports/ARCHIVE/DispatchIS_Reports/"),
]

for label, url in TARGETS:
   say("")
   say("=" * 74)
   say("%s", label)
   say("  %s", url)
   say("=" * 74)
   try:
      r = requests.get(url, headers=HEADERS, timeout=TO)
      say("  HTTP %s  %d bytes  content-type=%s",
          r.status_code, len(r.content), r.headers.get("content-type"))
      tokens = re.findall(r"PUBLIC_[A-Za-z0-9_]+?\.zip", r.text, re.IGNORECASE)
      names = sorted(set(tokens))
      say("  PUBLIC_*.zip tokens: %d distinct", len(names))
      for n in names[:6]:
         say("      %s", n)
      if len(names) > 6:
         say("      ...")
         for n in names[-3:]:
            say("      %s", n)
      m = re.findall(r"PUBLIC_DISPATCHIS_(\d{8})\.zip", r.text, re.IGNORECASE)
      if m:
         days = sorted(set(m))
         say("  daily DispatchIS zips: %d days, %s .. %s", len(days), days[0], days[-1])
   except Exception as exc:                     # noqa: BLE001
      say("  FAILED: %r", exc)

# how big is one archived daily zip? HEAD it, do not download the body.
say("")
say("=" * 74)
say("ARCHIVE 单个日包体积（只发 HEAD，不下载正文）")
say("=" * 74)
for day in ("20260701", "20260715"):
   url = ("https://www.nemweb.com.au/Reports/ARCHIVE/DispatchIS_Reports/"
          "PUBLIC_DISPATCHIS_%s.zip" % day)
   try:
      r = requests.head(url, headers=HEADERS, timeout=TO, allow_redirects=True)
      say("  %s -> HTTP %s  content-length=%s", day, r.status_code,
          r.headers.get("content-length"))
   except Exception as exc:                     # noqa: BLE001
      say("  %s -> FAILED: %r", day, exc)

with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
   fh.write(buf.getvalue())
print("wrote", OUT)
