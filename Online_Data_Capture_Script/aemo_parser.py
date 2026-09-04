# ============================== aemo_parser.py ==============================
"""NEMWEB report parsing.

The csv files use a record-type line layout:
   C ...   report meta / END OF REPORT
   I ...   table header (columns for the D rows that follow)
   D ...   data row of the most recently declared table

Only the few tables needed for region price/demand are extracted here.
"""

import logging

import numpy as np
import pandas as pd

from aemo_common import format_output_time, parse_nem_datetime

LOG = logging.getLogger("aemo")


def _split_record(line):
   return [field.strip() for field in line.split(",")]


def parse_nemweb_tables(csv_text):
   """Parse the report into {table_key: {"columns": [...], "rows": [[...]]}}."""
   tables = {}
   for raw_line in csv_text.splitlines():
      line = raw_line.strip()
      if not line:
         continue
      parts = _split_record(line)
      if len(parts) < 4:
         continue
      flag = parts[0].upper()
      # NEMWEB reports use two header shapes:
      #   I,DISPATCH,PRICE,5,col,...   (record_type, table_name, marker, cols)
      #   I,PDREGION,5,col,...         (table_name == record_type, marker, cols)
      # the marker field is not the column count, so all remaining fields
      # after it are the columns / values
      if parts[2].isdigit():
         record_type = parts[1]
         table_name = parts[1]
         payload = parts[3:]
      else:
         record_type = parts[1]
         table_name = parts[2]
         payload = parts[4:]
      key = (record_type, table_name)
      if flag == "I":
         tables[key] = {"columns": payload, "rows": []}
      elif flag == "D" and key in tables:
         columns = tables[key]["columns"]
         row = payload[:len(columns)]
         row += [""] * (len(columns) - len(row))
         if len(payload) != len(columns):
            LOG.debug("%s: row length %d vs %d columns",
                      table_name, len(payload), len(columns))
         tables[key]["rows"].append(row)
   return tables


def _find_table(tables, required_columns, optional_columns=()):
   """Find the first table containing the required columns; retry relaxed."""
   relaxed = set(required_columns) - set(optional_columns)
   for table in tables.values():
      if set(required_columns) <= set(table["columns"]):
         return table
   for table in tables.values():
      if relaxed <= set(table["columns"]):
         return table
   return None


def _to_frame(table, source_file):
   frame = pd.DataFrame(table["rows"], columns=table["columns"])
   frame["source_file"] = source_file
   return frame


def _keep_max_runno(frame, group_cols):
   """Dedup rows keeping the highest RUNNO (the last successful solve)."""
   if frame.empty or "RUNNO" not in frame.columns:
      return frame
   frame["_runno_num"] = pd.to_numeric(frame["RUNNO"], errors="coerce").fillna(0)
   frame = frame.sort_values("_runno_num", kind="stable")
   frame = frame.drop_duplicates(subset=group_cols, keep="last")
   return frame.drop(columns="_runno_num")


def _format_column(series):
   return series.apply(parse_nem_datetime).apply(format_output_time)


def _optional_column(frame, name):
   if name in frame.columns:
      return frame[name]
   return pd.Series("", index=frame.index, dtype=object)


def _to_int64(series):
   return pd.to_numeric(series, errors="coerce").astype("Int64")


def parse_dispatch(csv_text, source_file, regions):
   """Merge DISPATCH PRICE and REGIONSUM into one realised-price frame."""
   tables = parse_nemweb_tables(csv_text)
   price_table = _find_table(tables, {"SETTLEMENTDATE", "REGIONID", "RRP"})
   if price_table is None:
      LOG.warning("%s: no DISPATCH PRICE table found", source_file)
      return pd.DataFrame()
   price = _to_frame(price_table, source_file)
   price = price[price["REGIONID"].isin(regions)]
   if price.empty:
      return price
   price = _keep_max_runno(price, ["SETTLEMENTDATE", "REGIONID"])
   settlement_str = _format_column(price["SETTLEMENTDATE"])
   demand_map = {}
   region_sum_table = _find_table(tables, {"SETTLEMENTDATE", "REGIONID", "TOTALDEMAND"})
   if region_sum_table is not None:
      region_sum = _to_frame(region_sum_table, source_file)
      region_sum = region_sum[region_sum["REGIONID"].isin(regions)]
      if not region_sum.empty:
         region_sum = _keep_max_runno(region_sum, ["SETTLEMENTDATE", "REGIONID"])
         region_sum["settlement_str"] = _format_column(region_sum["SETTLEMENTDATE"])
         region_sum["demand"] = pd.to_numeric(region_sum["TOTALDEMAND"], errors="coerce")
         demand_map = dict(zip(zip(region_sum["settlement_str"], region_sum["REGIONID"]),
                               region_sum["demand"]))
   out = pd.DataFrame({
      "settlement_date": settlement_str.values,
      "region_id": price["REGIONID"].values,
      "rrp": pd.to_numeric(price["RRP"], errors="coerce").values,
      "eep": pd.to_numeric(_optional_column(price, "EEP"), errors="coerce").values,
      "total_demand": [demand_map.get((sd, rid), np.nan)
                       for sd, rid in zip(settlement_str, price["REGIONID"])],
      "run_no": _to_int64(_optional_column(price, "RUNNO")).values,
      "dispatch_interval": _optional_column(price, "DISPATCHINTERVAL").values,
      "intervention": _optional_column(price, "INTERVENTION").values,
      "source_file": source_file,
   })
   return out


def parse_predispatch(csv_text, source_file, regions, effective_time):
   """Extract the predispatch region table (30-min forecast horizons)."""
   tables = parse_nemweb_tables(csv_text)
   table = _find_table(tables, {"REGIONID", "PERIODID", "RRP"},
                       optional_columns={"TOTALDEMAND"})
   if table is None:
      LOG.warning("%s: no predispatch region table found", source_file)
      return pd.DataFrame()
   frame = _to_frame(table, source_file)
   frame = frame[frame["REGIONID"].isin(regions)]
   if frame.empty:
      return frame
   frame = _keep_max_runno(frame, ["PERIODID", "REGIONID"])
   seqno = _optional_column(frame, "PREDISPATCHSEQNO")
   if (seqno == "").all():
      seqno = pd.Series(effective_time, index=frame.index, dtype=object)
   out = pd.DataFrame({
      "effective_time": effective_time,
      "predispatch_seqno": seqno.apply(parse_nem_datetime).apply(format_output_time).values,
      "run_no": _to_int64(_optional_column(frame, "RUNNO")).values,
      "region_id": frame["REGIONID"].values,
      "period_id": _format_column(frame["PERIODID"]).values,
      "rrp": pd.to_numeric(frame["RRP"], errors="coerce").values,
      "eep": pd.to_numeric(_optional_column(frame, "EEP"), errors="coerce").values,
      "total_demand": pd.to_numeric(_optional_column(frame, "TOTALDEMAND"),
                                    errors="coerce").values,
      "intervention": _optional_column(frame, "INTERVENTION").values,
      "source_file": source_file,
   })
   return out


def parse_p5min(csv_text, source_file, regions, effective_time):
   """Extract the P5MIN REGIONSOLUTION table (5-min forecast horizons)."""
   tables = parse_nemweb_tables(csv_text)
   table = _find_table(tables, {"REGIONID", "INTERVAL_DATETIME", "RRP"},
                       optional_columns={"TOTALDEMAND"})
   if table is None:
      LOG.warning("%s: no P5MIN REGIONSOLUTION table found", source_file)
      return pd.DataFrame()
   frame = _to_frame(table, source_file)
   frame = frame[frame["REGIONID"].isin(regions)]
   if frame.empty:
      return frame
   frame = frame.drop_duplicates(subset=["INTERVAL_DATETIME", "REGIONID"], keep="last")
   out = pd.DataFrame({
      "effective_time": effective_time,
      "region_id": frame["REGIONID"].values,
      "interval_datetime": _format_column(frame["INTERVAL_DATETIME"]).values,
      "rrp": pd.to_numeric(frame["RRP"], errors="coerce").values,
      "total_demand": pd.to_numeric(_optional_column(frame, "TOTALDEMAND"),
                                    errors="coerce").values,
      "intervention": _optional_column(frame, "INTERVENTION").values,
      "source_file": source_file,
   })
   return out