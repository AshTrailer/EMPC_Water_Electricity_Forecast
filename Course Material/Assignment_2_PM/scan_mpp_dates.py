"""Scan every stream of the .mpp for plausible FILETIME values, to date the file's content."""

import struct
import importlib.util
from datetime import datetime, timedelta

PATH = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Gantt Plot\Capstone Project.mpp"
spec = importlib.util.spec_from_file_location(
    "mpptree", r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Assignment_2_PM\read_mpp_tree.py")
mpptree = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mpptree)


def main():
    with open(PATH, "rb") as handle:
        ole = mpptree.Ole(handle.read())

    print("=== plausible FILETIME values per stream (2000..2100) ===")
    for path, blob in sorted(ole.tree.items()):
        hits = {}
        for off in range(0, len(blob) - 8, 2):
            value = struct.unpack_from("<Q", blob, off)[0]
            if value == 0:
                continue
            try:
                dt = datetime(1601, 1, 1) + timedelta(microseconds=value / 10)
            except OverflowError:
                continue
            if 2000 <= dt.year <= 2100:
                key = dt.strftime("%Y-%m-%d")
                hits[key] = hits.get(key, 0) + 1
        if hits:
            top = sorted(hits.items(), key=lambda kv: -kv[1])[:8]
            print(f"\n  {path}")
            for day, count in top:
                print(f"     {day}  x{count}")

    print("\n=== earliest and latest plausible dates overall ===")
    found = []
    for path, blob in ole.tree.items():
        for off in range(0, len(blob) - 8, 2):
            value = struct.unpack_from("<Q", blob, off)[0]
            if value == 0:
                continue
            try:
                dt = datetime(1601, 1, 1) + timedelta(microseconds=value / 10)
            except OverflowError:
                continue
            if 2025 <= dt.year <= 2027:
                found.append((dt, path, off))
    found.sort()
    if found:
        for dt, path, off in found[:6]:
            print(f"  EARLIEST {dt}  {path} @0x{off:X}")
        for dt, path, off in found[-6:]:
            print(f"  LATEST   {dt}  {path} @0x{off:X}")
    else:
        print("  no dates in the 2025..2027 range found by this scan")


if __name__ == "__main__":
    main()
