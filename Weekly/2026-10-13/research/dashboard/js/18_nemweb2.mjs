import { inflateRawSync } from 'node:zlib'
import { writeFileSync, mkdirSync } from 'node:fs'

const RAW = 'C:\\Ash\\_research_20261013\\dashboard\\raw'
mkdirSync(RAW, { recursive: true })
const HEADERS = { 'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0.0.0 Safari/537.36' }
const NEM = '+10:00'
const stamp = (s) => new Date(s.replace(' ', 'T') + NEM).getTime()

function unzipFirst(buffer) {
   let eocd = -1
   for (let i = buffer.length - 22; i >= 0 && i > buffer.length - 70000; i -= 1) {
      if (buffer.readUInt32LE(i) === 0x06054b50) { eocd = i; break }
   }
   if (eocd < 0) throw new Error('没有 EOCD')
   const count = buffer.readUInt16LE(eocd + 10)
   const cdOffset = buffer.readUInt32LE(eocd + 16)
   const entries = []
   let p = cdOffset
   for (let i = 0; i < count; i += 1) {
      if (buffer.readUInt32LE(p) !== 0x02014b50) throw new Error(`中央目录项 ${i} 签名不对`)
      const method = buffer.readUInt16LE(p + 10)
      const compSize = buffer.readUInt32LE(p + 20)
      const nameLen = buffer.readUInt16LE(p + 28)
      const extraLen = buffer.readUInt16LE(p + 30)
      const commentLen = buffer.readUInt16LE(p + 32)
      const localOffset = buffer.readUInt32LE(p + 42)
      const name = buffer.toString('latin1', p + 46, p + 46 + nameLen)
      const dataStart = localOffset + 30 + buffer.readUInt16LE(localOffset + 26) + buffer.readUInt16LE(localOffset + 28)
      const body = buffer.subarray(dataStart, dataStart + compSize)
      const data = method === 8 ? inflateRawSync(body) : body
      entries.push({ name, bytes: data.length, text: data.toString('latin1') })
      p += 46 + nameLen + extraLen + commentLen
   }
   return entries
}

/**
 * 单遍扫描 MMS 扁平 CSV：I 行给列名，D 行给数据。
 * 只保留 VIC1 且 INTERVENTION=0 的行，避免把千万行物化进内存。
 */
function scan(text, wantedRegion) {
   const cols = new Map()
   const keep = new Map()
   const counts = new Map()
   let fileHeader = null
   let n = 0
   let start = 0
   while (start < text.length) {
      let end = text.indexOf('\n', start)
      if (end < 0) end = text.length
      const line = text.slice(start, end)
      start = end + 1
      n += 1
      if (line.length < 3) continue
      const f = line.split(',')
      const kind = f[0]
      if (kind === 'C') { if (fileHeader === null) fileHeader = f.slice(1); continue }
      const key = `${f[1]}|${f[2]}`
      if (kind === 'I') { cols.set(key, f.slice(4).map((s) => s.replace(/"/g, ''))); continue }
      if (kind !== 'D') continue
      counts.set(key, (counts.get(key) ?? 0) + 1)
      const header = cols.get(key)
      if (header === undefined) continue
      const iRegion = header.indexOf('REGIONID')
      const iDate = ['SETTLEMENTDATE', 'INTERVAL_DATETIME', 'DATETIME'].map((c) => header.indexOf(c)).find((i) => i >= 0) ?? -1
      const iInter = header.indexOf('INTERVENTION')
      if (iRegion < 0 || iDate < 0) continue
      const vals = f.slice(4).map((s) => s.replace(/"/g, ''))
      if (wantedRegion !== null && vals[iRegion] !== wantedRegion) continue
      if (iInter >= 0 && vals[iInter] !== '0') continue
      if (!keep.has(key)) keep.set(key, { header, rows: [] })
      keep.get(key).rows.push({ date: vals[iDate], vals })
   }
   return { cols, keep, counts, fileHeader, lines: n }
}

function report(label, scanned, iPriceNames) {
   const { keep, cols, counts, fileHeader } = scanned
   console.log(`文件头 C 行: ${fileHeader === null ? '无' : fileHeader.join(' | ')}`)
   console.log('全部 表|子表 与 D 行数:')
   for (const [key, c] of [...counts.entries()].sort()) console.log(`   ${key}: ${c} 行${cols.has(key) ? '' : '（无列头）'}`)
   for (const [key, { header, rows }] of keep) {
      const iDate = ['SETTLEMENTDATE', 'INTERVAL_DATETIME', 'DATETIME'].map((c) => header.indexOf(c)).find((i) => i >= 0) ?? -1
      const iP = iPriceNames.map((c) => header.indexOf(c)).find((i) => i >= 0) ?? -1
      const iPer = header.indexOf('PERIODID')
      const stamps = [...new Set(rows.map((r) => r.date))].sort()
      console.log(`\n--- ${key} | VIC1 INTERVENTION=0 行 ${rows.length} | 去重时刻 ${stamps.length}`)
      console.log(`    首 ${stamps[0]} | 末 ${stamps[stamps.length - 1]}`)
      const diffs = {}
      for (let i = 1; i < stamps.length; i += 1) {
         const d = (stamp(stamps[i]) - stamp(stamps[i - 1])) / 60000
         diffs[d] = (diffs[d] ?? 0) + 1
      }
      console.log(`    相邻步长(分钟) ${JSON.stringify(diffs)}`)
      if (iP >= 0) {
         console.log(`    RRP 抽样: ${stamps.slice(0, 3).map((s) => `${s}=${rows.find((r) => r.date === s).vals[iP]}`).join(' , ')} ... ${stamps.slice(-2).map((s) => `${s}=${rows.find((r) => r.date === s).vals[iP]}`).join(' , ')}`)
      }
      if (iPer >= 0) console.log(`    PERIODID 范围 ${Math.min(...rows.map((r) => Number(r.vals[iPer])))} 到 ${Math.max(...rows.map((r) => Number(r.vals[iPer])))}`)
   }
}

async function newestZip(dir) {
   const res = await fetch(dir, { headers: HEADERS })
   const html = await res.text()
   const names = [...html.matchAll(/href="([^"]+\.zip)"/gi)].map((m) => m[1]).map((n) => (n.startsWith('http') ? n : new URL(n, dir).href))
   names.sort()
   return { count: names.length, newest: names[names.length - 1] }
}

for (const [label, dir] of [
   ['PredispatchIS_Reports', 'https://www.nemweb.com.au/Reports/CURRENT/PredispatchIS_Reports/'],
   ['PD7Day', 'https://www.nemweb.com.au/Reports/CURRENT/PD7Day/'],
]) {
   console.log(`\n================ ${label} ================`)
   const listing = await newestZip(dir)
   const res = await fetch(listing.newest, { headers: HEADERS })
   const buf = Buffer.from(await res.arrayBuffer())
   const entries = unzipFirst(buf)
   const csv = entries[0]
   writeFileSync(`${RAW}\\${csv.name}`, csv.text)
   console.log(`zip 数 ${listing.count} | 最新 ${listing.newest.split('/').pop()}`)
   console.log(`HTTP ${res.status} ${buf.length} 字节 | 服务端 Date ${res.headers.get('date')} | ${csv.name} ${csv.bytes} 字符`)
   const scanned = scan(csv.text, 'VIC1')
   console.log(`总行数 ${scanned.lines}`)
   report(label, scanned, ['RRP', 'PRICE', 'RRP_ENERGY'])
}
