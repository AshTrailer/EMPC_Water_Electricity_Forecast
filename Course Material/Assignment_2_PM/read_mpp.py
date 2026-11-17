"""Read an MS Project .mpp OLE2 compound file: list streams, then extract UTF-16LE strings.

The .mpp container is a standard OLE2 compound document. Stream names are UTF-16LE and the
task/property data inside the big streams is mostly UTF-16LE too, so a string scan recovers
the task names, durations and dates without a proprietary parser.
"""

import struct
import sys

PATH = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Gantt Plot\Capstone Project.mpp"
SECTOR = 512
FREESECT = 0xFFFFFFFF
ENDOFCHAIN = 0xFFFFFFFE


def load(path):
    with open(path, "rb") as handle:
        return handle.read()


def u32(buf, off):
    return struct.unpack_from("<I", buf, off)[0]


def list_sectors(msat, start, size):
    """Follow a sector chain of `size` bytes, returning the raw bytes."""
    out = bytearray()
    sector = start
    guard = 0
    while sector not in (ENDOFCHAIN, FREESECT) and guard < 200000:
        offset = 512 + sector * SECTOR
        out += msat[offset:offset + SECTOR]
        sector = u32(msat, sector * 4)
        guard += 1
    return bytes(out[:size]) if size else bytes(out)


def parse_ole(data):
    if data[:8] != b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1":
        raise SystemExit("not an OLE2 compound document")

    sector_shift = struct.unpack_from("<H", data, 30)[0]
    mini_shift = struct.unpack_from("<H", data, 32)[0]
    num_fat = u32(data, 44)
    dir_start = u32(data, 48)
    mini_cutoff = u32(data, 56)
    mini_fat_start = u32(data, 60)
    num_mini_fat = u32(data, 64)
    difat_start = u32(data, 68)
    num_difat = u32(data, 72)

    difat = list(struct.unpack_from("<109I", data, 76))
    sector = difat_start
    for _ in range(num_difat):
        if sector in (ENDOFCHAIN, FREESECT):
            break
        block = data[512 + sector * SECTOR: 512 + (sector + 1) * SECTOR]
        entries = struct.unpack_from("<128I", block, 0)
        difat.extend(entries[:127])
        sector = entries[127]
    difat = [s for s in difat[:num_fat] if s not in (FREESECT, ENDOFCHAIN)]

    fat = []
    for s in difat:
        block = data[512 + s * SECTOR: 512 + (s + 1) * SECTOR]
        fat.extend(struct.unpack_from("<128I", block, 0))

    def chain(start):
        out, sector, guard = [], start, 0
        while sector not in (ENDOFCHAIN, FREESECT) and sector < len(fat) and guard < 200000:
            out.append(sector)
            sector = fat[sector]
            guard += 1
        return out

    def read_chain(start, size=None):
        blob = b"".join(data[512 + s * SECTOR: 512 + (s + 1) * SECTOR] for s in chain(start))
        return blob[:size] if size else blob

    root = read_chain(dir_start)
    entries = []
    for off in range(0, len(root), 128):
        name_len = struct.unpack_from("<H", root, off + 64)[0]
        if name_len == 0:
            continue
        etype = root[off + 66]
        name = root[off: off + max(0, name_len - 2)].decode("utf-16-le", "replace")
        size = u32(root, off + 120)
        start = u32(root, off + 116)
        entries.append({"name": name, "type": etype, "size": size, "start": start})

    root_entry = next(e for e in entries if e["type"] == 5)
    mini_stream = read_chain(root_entry["start"], root_entry["size"])
    mini_fat = []
    for s in chain(mini_fat_start):
        mini_fat.extend(struct.unpack_from("<128I", data, 512 + s * SECTOR))

    def read_mini(start, size):
        out, sector, guard = bytearray(), start, 0
        while sector not in (ENDOFCHAIN, FREESECT) and sector < len(mini_fat) and guard < 200000:
            out += mini_stream[sector * (1 << mini_shift): (sector + 1) * (1 << mini_shift)]
            sector = mini_fat[sector]
            guard += 1
        return bytes(out[:size])

    streams = {}
    for entry in entries:
        if entry["type"] != 2:
            continue
        if entry["size"] < mini_cutoff:
            streams[entry["name"]] = read_mini(entry["start"], entry["size"])
        else:
            streams[entry["name"]] = read_chain(entry["start"], entry["size"])
    return entries, streams


def strings_utf16(blob, min_len=3):
    """Yield (offset, text) for runs of printable UTF-16LE characters."""
    out = []
    run = []
    start = 0
    for i in range(0, len(blob) - 1, 2):
        lo, hi = blob[i], blob[i + 1]
        ch = None
        if hi == 0 and 32 <= lo < 127:
            ch = chr(lo)
        elif hi == 0 and lo in (9,):
            ch = "\t"
        if ch:
            if not run:
                start = i
            run.append(ch)
        else:
            if len(run) >= min_len:
                out.append((start, "".join(run)))
            run = []
    if len(run) >= min_len:
        out.append((start, "".join(run)))
    return out


def main():
    data = load(PATH)
    entries, streams = parse_ole(data)
    print("=== OLE directory entries ===")
    for entry in entries:
        kind = {1: "storage", 2: "stream", 5: "root"}.get(entry["type"], f"type{entry['type']}")
        if entry["type"] in (2, 5):
            print(f"  {kind:8s} {entry['name']!r:34s} size={entry['size']}")

    print("\n=== UTF-16LE strings per stream (streams over 1 KB) ===")
    for name, blob in sorted(streams.items(), key=lambda kv: -len(kv[1])):
        if len(blob) < 1024:
            continue
        found = strings_utf16(blob, min_len=4)
        if not found:
            continue
        print(f"\n--- {name}  ({len(blob)} bytes, {len(found)} strings) ---")
        for offset, text in found[:200]:
            print(f"   0x{offset:06X}  {text}")


if __name__ == "__main__":
    sys.exit(main())
