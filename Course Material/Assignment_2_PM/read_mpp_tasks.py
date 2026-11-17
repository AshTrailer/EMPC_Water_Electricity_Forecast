"""Decode the TBkndTask table of the .mpp: task name, duration, work and dates per record.

The task table is a byte-packed table: a fixed-size record area (FixedData) plus a
variable area (Var2Data) holding the strings. Records are 196 bytes; the byte at offset 6
is the record length, which is what the stride was derived from.
"""

import struct
from datetime import datetime, timedelta

PATH = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Gantt Plot\Capstone Project.mpp"
SECTOR = 512
FREESECT = 0xFFFFFFFF
ENDOFCHAIN = 0xFFFFFFFE
NOSTREAM = 0xFFFFFFFF

TASK_STORAGE = "/Root Entry/   114/TBkndTask"
STRIDE = 196


def u16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def u32(b, o):
    return struct.unpack_from("<I", b, o)[0]


def u64(b, o):
    return struct.unpack_from("<Q", b, o)[0]


class Ole:
    def __init__(self, data):
        self.data = data
        self.mini_shift = u16(data, 32)
        self.mini_cutoff = u32(data, 56)
        self.fat = self._fat()
        self.entries = self._dir()
        self.root = next(e for e in self.entries if e["type"] == 5)
        self.mini = self._chain_read(self.root["start"], self.root["size"])
        self.minifat = self._minifat()
        self.tree = {}
        self._walk(0, "")

    def _fat(self):
        d = self.data
        num_fat, difat_start, num_difat = u32(d, 44), u32(d, 68), u32(d, 72)
        difat = list(struct.unpack_from("<109I", d, 76))
        sec = difat_start
        for _ in range(num_difat):
            if sec in (ENDOFCHAIN, FREESECT):
                break
            blk = d[512 + sec * SECTOR: 512 + (sec + 1) * SECTOR]
            ent = struct.unpack_from("<128I", blk, 0)
            difat.extend(ent[:127])
            sec = ent[127]
        fat = []
        for s in difat[:num_fat]:
            if s in (FREESECT, ENDOFCHAIN):
                continue
            fat.extend(struct.unpack_from("<128I", d, 512 + s * SECTOR))
        return fat

    def _chain(self, start):
        out, sec, guard = [], start, 0
        while sec not in (ENDOFCHAIN, FREESECT) and sec < len(self.fat) and guard < 200000:
            out.append(sec)
            sec = self.fat[sec]
            guard += 1
        return out

    def _chain_read(self, start, size=None):
        blob = b"".join(self.data[512 + s * SECTOR: 512 + (s + 1) * SECTOR] for s in self._chain(start))
        return blob[:size] if size else blob

    def _dir(self):
        raw = self._chain_read(u32(self.data, 48))
        out = []
        for o in range(0, len(raw), 128):
            nl = u16(raw, o + 64)
            if nl == 0:
                continue
            out.append({"name": raw[o:o + nl - 2].decode("utf-16-le", "replace"),
                        "type": raw[o + 66], "left": u32(raw, o + 68), "right": u32(raw, o + 72),
                        "child": u32(raw, o + 76), "start": u32(raw, o + 116), "size": u32(raw, o + 120)})
        return out

    def _minifat(self):
        fat = []
        for s in self._chain(u32(self.data, 60)):
            fat.extend(struct.unpack_from("<128I", self.data, 512 + s * SECTOR))
        return fat

    def _read_mini(self, start, size):
        out, sec, guard = bytearray(), start, 0
        step = 1 << self.mini_shift
        while sec not in (ENDOFCHAIN, FREESECT) and sec < len(self.minifat) and guard < 200000:
            out += self.mini[sec * step:(sec + 1) * step]
            sec = self.minifat[sec]
            guard += 1
        return bytes(out[:size])

    def _walk(self, idx, parent):
        if idx == NOSTREAM or idx >= len(self.entries):
            return
        e = self.entries[idx]
        self._walk(e["left"], parent)
        path = f"{parent}/{e['name']}"
        e["path"] = path
        if e["type"] == 2:
            self.tree[path] = (self._read_mini(e["start"], e["size"]) if e["size"] < self.mini_cutoff
                               else self._chain_read(e["start"], e["size"]))
        self._walk(e["right"], parent)
        if e["type"] in (1, 5) and e["child"] != NOSTREAM:
            self._walk(e["child"], path)


def utf16_strings(blob, min_len=2):
    out, run, start = [], [], 0
    for i in range(0, len(blob) - 1, 2):
        lo, hi = blob[i], blob[i + 1]
        if hi == 0 and 32 <= lo < 127:
            if not run:
                start = i
            run.append(chr(lo))
        else:
            if len(run) >= min_len:
                out.append((start, "".join(run)))
            run = []
    if len(run) >= min_len:
        out.append((start, "".join(run)))
    return out


def maybe_filetime(v):
    if v == 0:
        return None
    try:
        dt = datetime(1601, 1, 1) + timedelta(microseconds=v / 10)
    except OverflowError:
        return None
    return dt if 2000 <= dt.year <= 2100 else None


def main():
    with open(PATH, "rb") as handle:
        ole = Ole(handle.read())

    fixed = ole.tree[f"{TASK_STORAGE}/FixedData"]
    var2 = ole.tree[f"{TASK_STORAGE}/Var2Data"]
    fixed2 = ole.tree.get(f"{TASK_STORAGE}/Fixed2Data", b"")

    print(f"FixedData {len(fixed)} bytes, Var2Data {len(var2)} bytes, Fixed2Data {len(fixed2)} bytes")
    print(f"stride {STRIDE}: {len(fixed) // STRIDE} records, remainder {len(fixed) % STRIDE}")

    # strings, in file order, paired with the record that owns them
    strings = utf16_strings(var2, min_len=4)
    print(f"\n{len(strings)} strings in Var2Data")

    print("\n=== field sweep over the first 40 bytes of every record ===")
    header = "  rec  " + "".join(f"{o:>4}" for o in range(0, 40, 4))
    print(header)
    for n in range(min(12, len(fixed) // STRIDE)):
        base = n * STRIDE
        vals = [u32(fixed, base + o) for o in range(0, 40, 4)]
        print(f"  {n:3d}  " + "".join(f"{v:>4}" if v < 10000 else f"{v:>4x}"[-4:] for v in vals))

    print("\n=== records with name, duration and any 8-byte timestamp ===")
    for n in range(len(fixed) // STRIDE):
        base = n * STRIDE
        # duration candidate: minutes in a u32 field
        dur = u32(fixed, base + 24)
        stamps = []
        for o in range(0, 120, 4):
            dt = maybe_filetime(u64(fixed, base + o))
            if dt:
                stamps.append((o, dt))
        name = strings[n][1] if n < len(strings) else "?"
        print(f"  [{n:2d}] u24={dur:7d}  {name[:52]:54s} stamps={[(o, str(d)) for o, d in stamps]}")


if __name__ == "__main__":
    main()
