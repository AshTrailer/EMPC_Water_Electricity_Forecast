import json
R = r"C:\Ash\_research_20261013\nemweb"
c = json.load(open(R + r"\compare.json", encoding="utf-8"))
print("compare.json keys:", list(c.keys()))
for k in ("predispatchis", "predispatch", "delivered_120d", "pd7day"):
    v = c.get(k, {})
    print("--", k)
    for kk in ("files", "runs_total", "runs_per_region", "runs", "periods_min", "periods_max",
               "horizon_min", "horizon_median", "horizon_max", "files_over_40h", "runs_over_40h",
               "files_ge_48h", "runs_ge_48h", "end_tod_set"):
        if kk in v:
            print("     %-18s %s" % (kk, v[kk]))
print("slot_map_differences:", c.get("slot_map_differences"))
for k in ("predispatchis", "predispatch"):
    print(k, "files_over_40h =", c[k]["files_over_40h"], " files_ge_48h =", c[k]["files_ge_48h"])