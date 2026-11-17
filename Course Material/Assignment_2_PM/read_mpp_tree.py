"""Read the MS Project .mpp OLE2 tree, then decode the FixedData / Fixed2Data task tables.

Stage 1 parses the OLE2 directory *tree* so every stream is attributed to its real storage
(the file has five groups all named FixedData / FixedMeta / VarMeta / ...).
Stage 2 reconstructs the fixed-size record tables and pairs them, by index, with the UTF-16
strings held in the matching Var2Data stream, which is where the task names live.
"""

import struct
from datetime import datetime, timedelta

PATH = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Gantt Plot\Capstone Project.mpp"
SECTOR = 512
FREESECT = 0xFFFFFFFF
ENDOFCHAIN = 0xFFFFFFFE
NOSTREAM = 0xFFFFFFFF


def u16(buf, off):
    return struct.unpack_from("<H", buf, off)[0]


def u32(buf, off):
    return struct.unpack_from("<I", buf, off)[0]


def u64(buf, off):
    return struct.unpack_from("<Q", buf, off)[0]


class Ole:
    def __init__(self, data):
        self.data = data
        if data[:8] != b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1":
            raise SystemExit("not an OLE2 compound document")
        self.mini_shift = u16(data, 32)
        self.mini_cutoff = u32(data, 56)
        self.fat = self._build_fat()
        self.entries = self._read_directory()
        self.root = next(e for e in self.entries if e["type"] == 5)
        self.mini_stream = self._read_chain(self.root["start"], self.root["size"])
        self.mini_fat = self._build_mini_fat()
        self._attach_streams()

    def _build_fat(self):
        data = self.data
        num_fat = u32(data, 44)
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
        fat = []
        for s in difat[:num_fat]:
            if s in (FREESECT, ENDOFCHAIN):
                continue
            block = data[512 + s * SECTOR: 512 + (s + 1) * SECTOR]
            fat.extend(struct.unpack_from("<128I", block, 0))
        return fat

    def _chain(self, start):
        out, sector, guard = [], start, 0
        while sector not in (ENDOFCHAIN, FREESECT) and sector < len(self.fat) and guard < 200000:
            out.append(sector)
            sector = self.fat[sector]
            guard += 1
        return out

    def _read_chain(self, start, size=None):
        blob = b"".join(self.data[512 + s * SECTOR: 512 + (s + 1) * SECTOR] for s in self._chain(start))
        return blob[:size] if size else blob

    def _read_directory(self):
        dir_start = u32(self.data, 48)
        raw = self._read_chain(dir_start)
        out = []
        for off in range(0, len(raw), 128):
            name_len = u16(raw, off + 64)
            if name_len == 0:
                continue
            out.append({
                "name": raw[off: off + max(0, name_len - 2)].decode("utf-16-le", "replace"),
                "type": raw[off + 66],
                "left": u32(raw, off + 68),
                "right": u32(raw, off + 72),
                "child": u32(raw, off + 76),
                "start": u32(raw, off + 116),
                "size": u32(raw, off + 120),
            })
        return out

    def _build_mini_fat(self):
        mini_fat_start = u32(self.data, 60)
        fat = []
        for s in self._chain(mini_fat_start):
            fat.extend(struct.unpack_from("<128I", self.data, 512 + s * SECTOR))
        return fat

    def _read_mini(self, start, size):
        out, sector, guard = bytearray(), start, 0
        step = 1 << self.mini_shift
        while sector not in (ENDOFCHAIN, FREESECT) and sector < len(self.mini_fat) and guard < 200000:
            out += self.mini_stream[sector * step: (sector + 1) * step]
            sector = self.mini_fat[sector]
            guard += 1
        return bytes(out[:size])

    def _attach_streams(self):
        """Walk the red-black sibling tree so each stream knows its parent storage."""
        self.tree = {}

        def walk(index, parent_path):
            if index == NOSTREAM or index >= len(self.entries):
                return
            entry = self.entries[index]
            walk(entry["left"], parent_path)
            path = f"{parent_path}/{entry['name']}"
            entry["path"] = path
            if entry["type"] == 2:
                blob = (self._read_mini(entry["start"], entry["size"])
                        if entry["size"] < self.mini_cutoff
                        else self._read_chain(entry["start"], entry["size"]))
                self.tree[path] = blob
            walk(entry["right"], parent_path)
            if entry["type"] in (1, 5) and entry["child"] != NOSTREAM:
                walk(entry["child"], path)

        walk(0, "")

    def stream(self, path):
        return self.tree.get(path)


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


def filetime_to_datetime(value):
    if value == 0:
        return None
    try:
        return datetime(1601, 1, 1) + timedelta(microseconds=value / 10)
    except OverflowError:
        return None


def plausible(value):
    dt = filetime_to_datetime(value)
    if dt and 1990 <= dt.year <= 2100:
        return dt
    return None


def scan_word_fields(blob, name):
    """Report 4-byte and 8-byte fields that decode to plausible calendar dates."""
    hits = []
    for off in range(0, len(blob) - 8, 4):
        dt = plausible(u64(blob, off))
        if dt:
            hits.append((off, "u64", dt))
    for off in range(0, len(blob) - 4, 4):
        dt = plausible(u32(blob, off))
        if dt:
            hits.append((off, "u32", dt))
    if hits:
        print(f"  [{name}] plausible date fields: {len(hits)}")
        for off, kind, dt in hits[:60]:
            print(f"      0x{off:04X} {kind} {dt}")


def main():
    with open(PATH, "rb") as handle:
        ole = Ole(handle.read())

    print("=== storage tree ===")
    for path, blob in sorted(ole.tree.items()):
        print(f"  {path:44s} {len(blob):6d} bytes")

    print("\n=== task-name candidate streams ===")
    for path, blob in sorted(ole.tree.items()):
        found = utf16_strings(blob, min_len=4)
        if len(found) >= 3:
            print(f"\n--- {path} ({len(blob)} bytes) ---")
            for off, text in found[:40]:
                print(f"   0x{off:05X}  {text}")

    print("\n=== date-field scan on every FixedData / FixedMeta stream ===")
    for path, blob in sorted(ole.tree.items()):
        if "Fixed" in path:
            print(f"\n--- {path} ({len(blob)} bytes) ---")
            scan_word_fields(blob, path.split("/")[-1])


if __name__ == "__main__":
    main()
