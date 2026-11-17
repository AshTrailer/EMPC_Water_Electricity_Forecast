# List the registration sheet columns and their value domains.
#
# E09 needs to know which units are semi-scheduled, because their offers are a
# bid curve rather than an availability and must be capped before the supply
# curve is built. This prints every column name with a few distinct values so a
# dispatch type and a fuel column can be located without guessing.

from openpyxl import load_workbook

SRC = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\AEMO_Data\_probe_offers\nem_registration.xlsx"

wb = load_workbook(SRC, read_only=True, data_only=True)
print("sheets:", wb.sheetnames)
for name in wb.sheetnames:
    ws = wb[name]
    print(f"\n===== {name} =====")
    header = None
    rows = 0
    domains = {}
    for r in ws.iter_rows(values_only=True):
        cells = [("" if c is None else str(c).strip()) for c in (r or ())]
        if not any(cells):
            continue
        if header is None:
            header = cells
            for i, h in enumerate(cells):
                domains[i] = set()
            print("cols:", len(header))
            for i, h in enumerate(header):
                print(f"  {i:2d}  {h}")
            continue
        rows += 1
        if rows > 3000:
            continue
        for i in range(min(len(cells), len(header))):
            if len(domains[i]) < 24:
                domains[i].add(cells[i])
    print(f"data rows scanned: {min(rows, 3000)} of {rows}")
    for i, h in enumerate(header or ()):
        vals = sorted(domains.get(i, ()))
        if len(vals) <= 24:
            print(f"  {h}: {vals}")
