"""Run the project's own aemo_parser against a real CURRENT PREDISPATCHIS file.

Read-only: imports the module with bytecode writing disabled and writes nothing into
the EMPC folder. Reports what parse_predispatch would store, so the online capture
script's behaviour can be checked against the file's actual contents.
"""

import os
import sys
import types

PROJ = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Online_Data_Capture_Script"
CSV = sys.argv[1]
sys.path.insert(0, PROJ)
sys.dont_write_bytecode = True

# aemo_common imports requests at module level; the bundled interpreter has no
# requests and the parser never calls it, so a stub keeps the import side-effect free.
if "requests" not in sys.modules:
    stub = types.ModuleType("requests")
    stub.Session = object
    sys.modules["requests"] = stub

import aemo_parser  # noqa: E402

with open(CSV, "r", encoding="utf-8", errors="replace") as fh:
    text = fh.read()

print(f"module file : {aemo_parser.__file__}")
print(f"csv bytes   : {len(text)}")

REGIONS = {"NSW1", "QLD1", "SA1", "TAS1", "VIC1"}
out = aemo_parser.parse_predispatch(text, "PUBLIC_PREDISPATCHIS_TEST.zip", REGIONS, "2026-10-13 02:00")
print(f"\nparse_predispatch -> shape {out.shape}, columns {list(out.columns)}")
if out.empty:
    print("EMPTY RESULT")
    raise SystemExit(0)

print(f"regions      : {sorted(out.region_id.unique())}")
print(f"period_id    : {out.period_id.min()} .. {out.period_id.max()}   distinct {out.period_id.nunique()}")
print(f"rrp non-null : {out.rrp.notna().sum()} / {len(out)}")
print(f"demand non-null: {out.total_demand.notna().sum()} / {len(out)}")
print(f"seqno sample : {out.predispatch_seqno.iloc[0]!r}")
print()
print("VIC1 head:")
print(out[out.region_id == "VIC1"].head(4).to_string(index=False))
print()
print("VIC1 tail:")
print(out[out.region_id == "VIC1"].tail(3).to_string(index=False))

# cross-check the demand column against the raw table
import pandas as pd  # noqa: E402
tables = aemo_parser.parse_nemweb_tables(text)
print("\ntables the parser sees:")
for k, v in tables.items():
    print(f"  {k[0]}|{k[1]}  cols {len(v['columns'])}  rows {len(v['rows'])}")
