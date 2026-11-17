import json
inv = json.load(open(r"C:\Ash\_research_20261013\nemweb\inventory_samples.json", encoding="utf-8"))
for label in ("dispatchfcst_current", "p5minfcst_current", "constraint_current", "rooftop_forecast_area_current"):
    e = inv.get(label, {})
    print("===", label, e.get("file"), e.get("bytes"))
    for t, v in e.get("tables", {}).items():
        print("   %-26s rows=%-8d cols=%d" % (t, v["rows"], len(v["columns"])))
        print("      %s" % v["columns"])
        for c, st in v.get("time", {}).items():
            print("      time %s: %s .. %s span=%.1fh steps=%s" % (c, st["min"], st["max"], st["span_hours"], st["step_minutes_top"]))
print()
print("=== how many tables does each sample have ===")
for label, e in sorted(inv.items()):
    print("   %-32s %s" % (label, list(e.get("tables", {}).keys())))