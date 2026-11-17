# Build the unit class map from the registration list.
#
# The offer file treats every unit the same way, but a semi-scheduled unit's
# offer is a bid curve it cannot exceed its availability, so its volume must not
# enter the supply curve as if it were dispatchable capacity. This writes the
# classification, the fuel and the registered capacity per DUID so the curve can
# be rebuilt with that distinction.

import csv
from openpyxl import load_workbook

SRC = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\AEMO_Data\_probe_offers\nem_registration.xlsx"
OUT = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\AEMO_Data\duid_unit_class.csv"

WANT = [
    "DUID", "Region", "Dispatch Type", "Category", "Classification",
    "Fuel Source - Primary", "Fuel Source - Descriptor",
    "Technology Type - Primary", "Reg Cap generation (MW)",
]

wb = load_workbook(SRC, read_only=True, data_only=True)
rows = []
for name in wb.sheetnames:
    ws = wb[name]
    header = None
    idx = None
    for r in ws.iter_rows(values_only=True):
        cells = [("" if c is None else str(c).strip()) for c in (r or ())]
        if not any(cells):
            continue
        if header is None:
            low = [c.lower() for c in cells]
            if "duid" in low and "region" in low:
                header = cells
                idx = {}
                for w in WANT:
                    key = w.lower()
                    if key in low:
                        idx[w] = low.index(key)
                print(f"[{name}] found DUID header with {sorted(idx)}")
            continue
        rec = {w: (cells[i] if i < len(cells) else "") for w, i in idx.items()}
        if rec.get("DUID"):
            rows.append(rec)
    if idx is not None:
        print(f"[{name}] rows {sum(1 for x in rows if x)}")

# Later sheets override earlier ones only if they carry the same DUID with a
# non-empty classification.
seen = {}
for rec in rows:
    d = rec["DUID"]
    if d not in seen or (not seen[d].get("Classification") and rec.get("Classification")):
        seen[d] = rec

print(f"distinct DUID {len(seen)}")
by_region = {}
by_class = {}
for rec in seen.values():
    by_region[rec.get("Region", "")] = by_region.get(rec.get("Region", ""), 0) + 1
    by_class[rec.get("Classification", "")] = by_class.get(rec.get("Classification", ""), 0) + 1
print("region:", sorted(by_region.items(), key=lambda kv: -kv[1]))
print("class:", sorted(by_class.items(), key=lambda kv: -kv[1]))

with open(OUT, "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh)
    w.writerow(["DUID", "REGIONID", "DISPATCH_TYPE", "CATEGORY", "CLASS", "FUEL", "FUEL_DESC", "TECH", "REGCAP_MW"])
    for d in sorted(seen):
        rec = seen[d]
        w.writerow([
            d, rec.get("Region", ""), rec.get("Dispatch Type", ""), rec.get("Category", ""),
            rec.get("Classification", ""), rec.get("Fuel Source - Primary", ""),
            rec.get("Fuel Source - Descriptor", ""), rec.get("Technology Type - Primary", ""),
            rec.get("Reg Cap generation (MW)", ""),
        ])
print("wrote", OUT)

vic = [r for r in seen.values() if r.get("Region") == "VIC1"]
print(f"VIC1 {len(vic)}")
for k in ("Classification", "Fuel Source - Primary"):
    c = {}
    for r in vic:
        c[r.get(k, "")] = c.get(r.get(k, ""), 0) + 1
    print(f"  {k}: {sorted(c.items(), key=lambda kv: -kv[1])}")
