// Minimal zip reader for the NEMWEB report zips.
//
// Node has no zip reader, and the daily offer archives unpack to 200 MB of text
// that must never be written to disk sixty times over. Two pieces are enough:
// parse the central directory to find each entry's byte range and method, then
// stream that range through inflateRaw so a caller can read lines with bounded
// memory.
//
// A predispatch week pack nests one zip per report inside another zip, so the
// same two pieces are also offered over an in-memory buffer, which is how a
// nested member is read without ever touching the disk.

import { closeSync, createReadStream, openSync, readFileSync, readSync } from "node:fs";
import { createInflateRaw, inflateRawSync } from "node:zlib";

/** Parse the central directory of a zip held in memory. */
export function listEntriesFromBuffer(buf) {
  // End of central directory: signature 0x06054b50, scanned backwards because
  // an archive comment may follow it.
  let eocd = -1;
  for (let i = buf.length - 22; i >= 0 && i >= buf.length - 22 - 65535; i -= 1) {
    if (buf.readUInt32LE(i) === 0x06054b50) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) throw new Error("not a zip buffer");

  const count = buf.readUInt16LE(eocd + 10);
  let p = buf.readUInt32LE(eocd + 16);
  const out = [];
  for (let i = 0; i < count; i += 1) {
    if (buf.readUInt32LE(p) !== 0x02014b50) throw new Error(`bad central header at ${p}`);
    const method = buf.readUInt16LE(p + 10);
    const compSize = buf.readUInt32LE(p + 20);
    const size = buf.readUInt32LE(p + 24);
    const nameLen = buf.readUInt16LE(p + 28);
    const extraLen = buf.readUInt16LE(p + 30);
    const commentLen = buf.readUInt16LE(p + 32);
    const offset = buf.readUInt32LE(p + 42);
    const name = buf.toString("latin1", p + 46, p + 46 + nameLen);
    out.push({ name, method, compSize, size, offset });
    p += 46 + nameLen + extraLen + commentLen;
  }
  return out;
}

/**
 * Read the central directory of a zip file.
 * @param {string} path absolute path to the zip
 * @returns {Array<{name:string, method:number, compSize:number, size:number, offset:number}>}
 */
export function listEntries(path) {
  return listEntriesFromBuffer(readFileSync(path));
}

/**
 * Stream one entry as decompressed bytes.
 * @param {string} path absolute path to the zip
 * @param {{method:number, compSize:number, offset:number}} entry from listEntries
 * @returns {import("node:stream").Readable}
 */
export function openEntry(path, entry) {
  // Local file header: fixed part is 30 bytes, then the name and extra fields
  // whose lengths are repeated here and must be skipped before the data. Only
  // the header is read here, because a caller opens one entry per member.
  const fd = openSync(path, "r");
  const hdr = Buffer.alloc(30);
  try {
    readSync(fd, hdr, 0, 30, entry.offset);
  } finally {
    closeSync(fd);
  }
  if (hdr.readUInt32LE(0) !== 0x04034b50) throw new Error("bad local header");
  const start = entry.offset + 30 + hdr.readUInt16LE(26) + hdr.readUInt16LE(28);
  const end = start + entry.compSize - 1;

  const raw = createReadStream(path, { start, end });
  if (entry.method === 0) return raw;
  if (entry.method === 8) return raw.pipe(createInflateRaw());
  throw new Error(`unsupported compression method ${entry.method}`);
}

/**
 * Inflate one entry of a zip held in memory.
 * @param {Buffer} buf the whole archive
 * @param {{method:number, compSize:number, offset:number}} entry
 * @returns {Buffer}
 */
export function entryBuffer(buf, entry) {
  const hdr = buf.subarray(entry.offset, entry.offset + 30);
  if (hdr.readUInt32LE(0) !== 0x04034b50) throw new Error("bad local header");
  const start = entry.offset + 30 + hdr.readUInt16LE(26) + hdr.readUInt16LE(28);
  const raw = buf.subarray(start, start + entry.compSize);
  if (entry.method === 0) return Buffer.from(raw);
  if (entry.method === 8) return inflateRawSync(raw);
  throw new Error(`unsupported compression method ${entry.method}`);
}
