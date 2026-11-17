# Read the AEMO registration list and emit the DUID to region map.
#
# The list is the authoritative register of every unit in the market, including
# scheduled loads and semi-scheduled plant that the PASA file omits. Two columns
# matter: DUID and Region. Sheets are inspected rather than assumed, because
# AEMO reshuffles them.

import csv
from openpyxl import load_workbook

SRC = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\AEMO_Data\_probe_offers\nem_registration.xlsx"
OUT = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\AEMO_Data\duid_region_registration.csv"

wb = load_workbook(SRC, read_only=True, data_only=True)
print("sheets:", wb.sheetnames)

found = {}
for name in wb.sheetnames:
    ws = wb[name]
    di = ri = None
    count = 0
    for r in ws.iter_rows(values_only=True):
        cells = [("" if c is None else str(c).strip()) for c in (r or ())]
        if not any(cells):
            continue
        low = [c.lower() for c in cells]
        if di is None:
            if "duid" in low and "region" in low:
                di = low.index("duid")
                ri = low.index("region")
                print(f"[{name}] DUID at {di}, Region at {ri}")
            continue
        duid = cells[di] if di < len(cells) else ""
        region = cells[ri] if ri < len(cells) else ""
        if duid and region:
            count += 1
            if duid in found and found[duid] != region:
                print(f"  conflict {duid}: {found[duid]} vs {region}")
            found[duid] = region
    if di is not None:
        print(f"  {count} rows with both fields")

print(f"\ndistinct DUID {len(found)}")
by = {}
for r in found.values():
    by[r] = by.get(r, 0) + 1
print("regions:", sorted(by.items(), key=lambda kv: -kv[1]))

with open(OUT, "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh)
    w.writerow(["DUID", "REGIONID"])
    for d in sorted(found):
        w.writerow([d, found[d]])
print("wrote", OUT)
