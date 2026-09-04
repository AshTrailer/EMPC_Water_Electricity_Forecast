# ============================== aemo_common.py ==============================
"""Shared helpers: time handling, listing parsing, download, zip extraction."""

import logging
import re
import time
import zipfile
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import requests

import aemo_config as cfg

LOG = logging.getLogger("aemo")

# NEM market time is AEST (UTC+10) and never shifts for daylight saving
NEM_TZ = timezone(timedelta(hours=10), "AEST")
LOCAL_TZ = ZoneInfo("Australia/Sydney")

_HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) aemo-capture/1.0"}

_EXCEL_EPOCH = datetime(1899, 12, 30)

_DT_FORMATS = (
   "%Y/%m/%d %H:%M:%S",
   "%Y/%m/%d %H:%M",
   "%Y-%m-%d %H:%M:%S",
   "%Y-%m-%d %H:%M",
   "%d/%m/%Y %H:%M:%S",
   "%d/%m/%Y %H:%M",
   "%Y%m%d%H%M%S",
   "%Y%m%d%H%M",
)


def parse_nem_datetime(value):
   """Parse a NEMWEB timestamp (string or Excel serial) into a naive datetime."""
   if value is None:
      return None
   if isinstance(value, datetime):
      return value.replace(tzinfo=None)
   if isinstance(value, (int, float)) and not isinstance(value, bool):
      try:
         return _EXCEL_EPOCH + timedelta(days=float(value))
      except (OverflowError, ValueError):
         return None
   text = str(value).strip()
   if not text or text.lower() in {"nan", "none", "null", "nat"}:
      return None
   for fmt in _DT_FORMATS:
      try:
         return datetime.strptime(text, fmt)
      except ValueError:
         continue
   LOG.debug("unrecognised datetime value: %r", text)
   return None


def format_output_time(dt_naive):
   """Naive NEM time -> output string, optionally converted to AU eastern local time."""
   if dt_naive is None:
      return ""
   aware = dt_naive.replace(tzinfo=NEM_TZ)
   if cfg.USE_AUS_LOCAL_TIME:
      aware = aware.astimezone(LOCAL_TZ)
   return aware.strftime("%Y-%m-%d %H:%M:%S")


def parse_report_filename(filename, report_key):
   """Return (effective_dt, generation_str) from a report zip filename, or None."""
   pattern = cfg.REPORT_FILENAME_PATTERNS[report_key]
   match = pattern.match(filename)
   if not match:
      return None
   effective_dt = datetime.strptime(match.group(1), "%Y%m%d%H%M")
   generation_str = match.group(2)
   return effective_dt, generation_str


# 原来的精确 href 匹配在 IIS 目录列表上匹配不到任何链接，
# 改为直接提取所有形如 PUBLIC_*.zip 的纯文本 token（IIS 列表里文件名唯一）。
_ZIP_TOKEN_RE = re.compile(r'PUBLIC_[A-Z0-9]+_\d{12}_\d+(?:\.zip)?', re.IGNORECASE)


def list_remote_zips(listing_url):
   """Return all zip filenames visible on a NEMWEB current listing page.

   NEMWEB uses an IIS directory listing whose links are not reliably
   matched by an href= regex, so we scan the raw HTML for the literal
   'PUBLIC_*.zip' filename tokens instead.
   """
   for attempt in range(cfg.HTTP_RETRIES):
      try:
         response = requests.get(listing_url, headers=_HEADERS, timeout=cfg.HTTP_TIMEOUT_SECONDS)
         response.raise_for_status()
         raw_tokens = _ZIP_TOKEN_RE.findall(response.text)
         names = sorted({t if t.lower().endswith(".zip") else t + ".zip"
                         for t in raw_tokens})
         LOG.debug("listing %s -> %d zips", listing_url, len(names))
         return names
      except requests.RequestException as exc:
         LOG.warning("listing attempt %d/%d failed (%s): %s",
                     attempt + 1, cfg.HTTP_RETRIES, listing_url, exc)
         time.sleep(cfg.HTTP_RETRY_BACKOFF_SECONDS)
   raise RuntimeError("could not fetch listing: " + listing_url)


def download_file(url, dest_path):
   """Download url to dest_path with retries; returns the file size in bytes."""
   dest_path.parent.mkdir(parents=True, exist_ok=True)
   if dest_path.exists() and dest_path.stat().st_size > 0:
      try:
         with zipfile.ZipFile(dest_path) as archive:
            if archive.namelist():
               LOG.debug("using cached zip %s", dest_path.name)
               return dest_path.stat().st_size
      except zipfile.BadZipFile:
         LOG.warning("cached zip corrupt, re-downloading: %s", dest_path.name)
         dest_path.unlink(missing_ok=True)
   tmp_path = dest_path.with_name(dest_path.name + ".part")
   for attempt in range(cfg.HTTP_RETRIES):
      try:
         with requests.get(url, headers=_HEADERS, stream=True,
                           timeout=cfg.HTTP_TIMEOUT_SECONDS) as response:
            response.raise_for_status()
            with open(tmp_path, "wb") as handle:
               for chunk in response.iter_content(chunk_size=1 << 16):
                  handle.write(chunk)
         tmp_path.replace(dest_path)
         size = dest_path.stat().st_size
         LOG.info("downloaded %s (%d bytes)", dest_path.name, size)
         return size
      except requests.RequestException as exc:
         LOG.warning("download attempt %d/%d failed (%s): %s",
                     attempt + 1, cfg.HTTP_RETRIES, url, exc)
         time.sleep(cfg.HTTP_RETRY_BACKOFF_SECONDS)
   raise RuntimeError("could not download: " + url)


def extract_csv_text(zip_path):
   """Return the decoded text of the single csv inside a report zip."""
   with zipfile.ZipFile(zip_path) as archive:
      csv_names = [name for name in archive.namelist() if name.lower().endswith(".csv")]
      if not csv_names:
         raise ValueError("no csv inside zip: " + zip_path.name)
      raw = archive.read(csv_names[0])
   for encoding in ("utf-8", "latin-1"):
      try:
         return raw.decode(encoding)
      except UnicodeDecodeError:
         continue
   return raw.decode("latin-1", errors="replace")