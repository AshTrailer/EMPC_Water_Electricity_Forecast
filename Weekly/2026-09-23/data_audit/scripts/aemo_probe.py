# -*- coding: utf-8 -*-
"""AEMO_Data raw structure probe (read-only).

Inventories every file under AEMO_Data, classifies it by producer, and dumps
the record layout (C / I / D) of one sample zip per NEMWEB report type so the
field names and quoting conventions are on record rather than assumed.

Writes a plain-text report next to this script (aemo_probe_report.txt) because
this machine's sandbox eats native stdout when it is piped.
"""

import io
import json
import os
import re
import sys
import zipfile
from collections import Counter

BASE = r"C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\AEMO_Data"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "aemo_probe_report.txt")

buf = io.StringIO()


def say(fmt="", *args):
   buf.write((fmt % args if args else fmt) + "\n")


def head(path, n=2):
   """First n non-empty lines of a text file, trying utf-8 then latin-1."""
   for enc in ("utf-8", "latin-1"):
      try:
         with open(path, "r", encoding=enc, newline="") as fh:
            lines = []
            for line in fh:
               line = line.rstrip("\r\n")
               if line.strip():
                  lines.append(line)
               if len(lines) >= n:
                  break
            return enc, lines
      except UnicodeDecodeError:
         continue
   return None, []


def count_lines(path):
   n = 0
   with open(path, "rb") as fh:
      for _ in fh:
         n += 1
   return n


# ---------------------------------------------------------------- inventory
say("=" * 78)
say("AEMO_Data 文件清点（%s）", BASE)
say("=" * 78)

files = []
for root, dirs, names in os.walk(BASE):
   for name in names:
      full = os.path.join(root, name)
      rel = os.path.relpath(full, BASE)
      files.append((rel.replace("\\", "/"), full, os.path.getsize(full)))

files.sort()
by_dir = {}
for rel, full, size in files:
   d = rel.rsplit("/", 1)[0] if "/" in rel else "(root)"
   by_dir.setdefault(d, []).append((rel, size))

for d in sorted(by_dir):
   entries = by_dir[d]
   total = sum(s for _, s in entries)
   say("")
   say("--- %s : %d files, %.1f MB ---", d, len(entries), total / 1e6)
   if len(entries) <= 20:
      for rel, size in entries:
         say("    %-70s %10d", rel.rsplit("/", 1)[-1], size)
   else:
      # name families: strip the 12-digit timestamp and the 16-digit serial
      fam = Counter()
      for rel, size in entries:
         base = rel.rsplit("/", 1)[-1]
         key = re.sub(r"\d{8,}", "<N>", base)
         fam[key] += 1
      for key, cnt in sorted(fam.items()):
         say("    %-70s x%d", key, cnt)


# ------------------------------------------------------- header of each root csv
say("")
say("=" * 78)
say("AEMO_Data 根目录每个 CSV 的表头 / 行数")
say("=" * 78)
for rel, full, size in files:
   if "/" in rel or not rel.lower().endswith(".csv"):
      continue
   enc, lines = head(full, 2)
   try:
      nlines = count_lines(full)
   except OSError as exc:
      nlines = -1
   say("")
   say("* %s  (%d bytes, %d lines, encoding=%s)", rel, size, nlines, enc)
   for line in lines:
      say("    %s", line[:400])


# ------------------------------------------------- NEMWEB raw record structures
say("")
say("=" * 78)
say("NEMWEB 原始报表记录结构（每个 report 取一个样本）")
say("=" * 78)

samples = {
   "DISPATCHIS": os.path.join(BASE, "PUBLIC_DISPATCHIS_202609040355_0000000535967869.CSV"),
   "P5MIN": os.path.join(BASE, "PUBLIC_P5MIN_202609040400_20260904035533.CSV"),
   "PREDISPATCHIS": os.path.join(BASE, "PUBLIC_PREDISPATCH_202609040400_20260904033205_LEGACY.CSV"),
}

for key, path in samples.items():
   say("")
   say("-" * 78)
   say("%s  sample = %s", key, os.path.basename(path))
   say("-" * 78)
   if not os.path.exists(path):
      say("    MISSING")
      continue
   enc, first = head(path, 1)
   say("    encoding=%s  first line:", enc)
   say("      %s", (first[0] if first else "")[:400])

   seen_i = {}
   d_counts = Counter()
   quoted_fields = Counter()
   with open(path, "r", encoding=enc, newline="") as fh:
      for line in fh:
         line = line.rstrip("\r\n")
         if not line:
            continue
         if line.startswith("I,"):
            parts = line.split(",")
            if parts[2].isdigit():
               rtype, tname, cols = parts[1], parts[1], parts[3:]
            else:
               rtype, tname, cols = parts[1], parts[2], parts[4:]
            seen_i[(rtype, tname)] = cols
         elif line.startswith("D,"):
            parts = line.split(",")
            if parts[2].isdigit():
               rtype, tname = parts[1], parts[1]
               payload = parts[3:]
            else:
               rtype, tname = parts[1], parts[2]
               payload = parts[4:]
            d_counts[(rtype, tname)] += 1
            for field in payload:
               if field.startswith('"') and field.endswith('"') and len(field) > 1:
                  quoted_fields[field] += 1

   say("    tables (I records = %d):", len(seen_i))
   for (rtype, tname), cols in seen_i.items():
      say("      [%s / %s]  D-rows=%d  cols=%d", rtype, tname,
          d_counts.get((rtype, tname), 0), len(cols))
      say("        columns: %s", ", ".join(cols))
   say("    quoted payload fields seen in D records: %d distinct", len(quoted_fields))
   for field, cnt in quoted_fields.most_common(6):
      say("      %-34s x%d", field, cnt)


# ------------------------------------------------------------- zip_cache probes
say("")
say("=" * 78)
say("zip_cache 内容探针（每类一个 zip）")
say("=" * 78)
zc = os.path.join(BASE, "zip_cache")
for key in sorted(os.listdir(zc)) if os.path.isdir(zc) else []:
   folder = os.path.join(zc, key)
   if not os.path.isdir(folder):
      continue
   zips = sorted(f for f in os.listdir(folder) if f.lower().endswith(".zip"))
   if not zips:
      say("%s: no zips", key)
      continue
   zpath = os.path.join(folder, zips[0])
   say("")
   say("%s: %d zips, first=%s", key, len(zips), zips[0])
   try:
      with zipfile.ZipFile(zpath) as zf:
         for info in zf.infolist():
            say("    member %-60s %10d bytes", info.filename, info.file_size)
         member = zf.namelist()[0]
         raw = zf.read(member).decode("utf-8", errors="replace")
      lines = [ln for ln in raw.splitlines() if ln.strip()]
      say("    first line : %s", lines[0][:300])
      i_lines = [ln for ln in lines if ln.startswith("I,")]
      d_lines = [ln for ln in lines if ln.startswith("D,")]
      say("    I records  : %d, D records: %d", len(i_lines), len(d_lines))
      for ln in i_lines[:12]:
         say("      I> %s", ln[:300])
      for ln in d_lines[:3]:
         say("      D> %s", ln[:300])
   except Exception as exc:      # noqa: BLE001 - probe must never crash
      say("    ERROR: %r", exc)


# --------------------------------------------------------------- capture state
say("")
say("=" * 78)
say("capture_state.json 摘要")
say("=" * 78)
sp = os.path.join(BASE, "capture_state.json")
try:
   with open(sp, "r", encoding="utf-8") as fh:
      state = json.load(fh)
   processed = state.get("processed", {})
   last_gen = state.get("last_gen", {})
   for key in sorted(set(list(processed) + list(last_gen))):
      eff = sorted(last_gen.get(key, {}).keys())
      say("%-14s processed=%-5d last_gen=%-5d  effective range: %s .. %s",
          key, len(processed.get(key, {})), len(last_gen.get(key, {})),
          eff[0] if eff else "-", eff[-1] if eff else "-")
except Exception as exc:      # noqa: BLE001
   say("ERROR: %r", exc)

with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
   fh.write(buf.getvalue())
print("wrote", OUT, len(buf.getvalue()), "chars")
