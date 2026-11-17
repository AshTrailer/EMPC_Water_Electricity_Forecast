import { inflateRawSync } from 'node:zlib'

const HEADERS = { 'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0.0.0 Safari/537.36' }
const iso = (s) => new Date(s.replace(/\//g, '-').replace(' ', 'T') + '+10:00')
const fmt = (t) => new Date(t + 10 * 3600 * 1000).toISOString().slice(0, 16).replace('T', ' ')

function unzipFirst(buffer) {
   let eocd = -1
   for (let i = buffer.length - 22; i >= 0 && i > buffer.length - 70000; i -= 1) {
      if (buffer.readUInt32LE(i) === 0x06054b50) { eocd = i; break }
   }
   const cdOffset = buffer.readUInt32LE(eocd + 16)
   const nameLen = buffer.readUInt16LE(cdOffset + 28)
   const localOffset = buffer.readUInt32LE(cdOffset + 42)
   const method = buffer.readUInt16LE(cdOffset + 10)
   const compSize = buffer.readUInt32LE(cdOffset + 20)
   const name = buffer.toString('latin1', cdOffset + 46, cdOffset + 46 + nameLen)
   const dataStart = localOffset + 30 + buffer.readUInt16LE(localOffset + 26) + buffer.readUInt16LE(localOffset + 28)
   const body = buffer.subarray(dataStart, dataStart + compSize)
   return { name, text: (method === 8 ? inflateRawSync(body) : body).toString('latin1') }
}

/** 只收 含 REGIONID 且有 RRP/PRICE 列 的表里 VIC1 且 INTERVENTION=0 的行。 */
function harvest(text, wanted) {
   const cols = new Map()
   const counts = new Map()
   const keep = new Map()
   let start = 0
   while (start < text.length) {
      let end = text.indexOf('\n', start)
      if (end < 0) end = text.length
      const line = text.slice(start, end)
      start = end + 1
      if (line.length < 3) continue
      const f = line.split(',')
      const kind = f[0]
      const key = `${f[1]}|${f[2]}`
      if (kind === 'I') { cols.set(key, f.slice(4).map((s) => s.replace(/"/g, ''))); continue }
      if (kind !== 'D') continue
      counts.set(key, (counts.get(key) ?? 0) + 1)
      const header = cols.get(key)
      if (header === undefined) continue
      const iRegion = header.indexOf('REGIONID')
      if (iRegion < 0) continue
      const iP = ['RRP', 'PRICE', 'RRP_ENERGY'].map((c) => header.indexOf(c)).find((i) => i >= 0) ?? -1
      if (iP < 0) continue
      const iDate = ['SETTLEMENTDATE', 'INTERVAL_DATETIME', 'DATETIME'].map((c) => header.indexOf(c)).find((i) => i >= 0) ?? -1
      if (iDate < 0) continue
      const iInter = header.indexOf('INTERVENTION')
      const vals = f.slice(4).map((s) => s.replace(/"/g, ''))
      if (vals[iRegion] !== wanted) continue
      if (iInter >= 0 && vals[iInter] !== '0') continue
      if (!keep.has(key)) keep.set(key, { header, rows: [] })
      keep.get(key).rows.push({ date: vals[iDate], rrp: vals[iP] })
   }
   const out = []
   for (const [key, { header, rows }] of keep) {
      const stamps = [...new Set(rows.map((r) => r.date))].sort()
      const diffs = {}
      for (let i = 1; i < stamps.length; i += 1) {
         const d = (iso(stamps[i]) - iso(stamps[i - 1])) / 60000
         diffs[d] = (diffs[d] ?? 0) + 1
      }
      out.push({ key, header, n: stamps.length, first: stamps[0], last: stamps[stamps.length - 1], diffs, spans: rows.length })
   }
   return { out, counts, cols }
}

for (const [label, dir, stampOf] of [
   ['P5MIN (5 分钟预调度)', 'https://www.nemweb.com.au/Reports/CURRENT/P5_Reports/', (m) => m[2]],
   ['PD7Day (7 天预调度)', 'https://www.nemweb.com.au/Reports/CURRENT/PD7Day/', (m) => m[1]],
]) {
   console.log(`\n================ ${label} ================`)
   const html = await (await fetch(dir, { headers: HEADERS })).text()
   const names = [...html.matchAll(/href="([^"]+\.zip)"/gi)].map((m) => m[1].split('/').pop()).sort()
   console.log(`zip 总数 ${names.length} | 最早 ${names[0]} | 最新 ${names[names.length - 1]}`)
   console.log('最近 10 次发布与相邻间隔:')
   const pubTimes = []
   for (const n of names.slice(-10)) {
      const m = n.match(/PUBLIC_[A-Z0-9]+_(\d{12,14})_(\d{12,14})\.zip/)
      const t = m === null ? null : stampOf(m)
      const d = t === null ? null : new Date(`${t.slice(0, 4)}-${t.slice(4, 6)}-${t.slice(6, 8)}T${t.slice(8, 10)}:${t.slice(10, 12)}:${(t.slice(12, 14) || '00')}+10:00`)
      pubTimes.push(d)
      const prev = pubTimes.length > 1 ? pubTimes[pubTimes.length - 2] : null
      console.log(`  ${n}  发布 ${d === null ? '?' : fmt(d.getTime())}${prev === null ? '' : `  距上次 ${((d - prev) / 3600000).toFixed(2)} h`}`)
   }
   const res = await fetch(`${dir}${names[names.length - 1]}`, { headers: HEADERS })
   const buf = Buffer.from(await res.arrayBuffer())
   const csv = unzipFirst(buf)
   console.log(`最新文件 ${csv.name} | HTTP ${res.status} ${buf.length} 字节 | 服务端 Date ${res.headers.get('date')} | CSV ${csv.text.length} 字符`)
   const { out, counts, cols } = harvest(csv.text, 'VIC1')
   console.log(`表|子表 与 D 行数: ${[...counts.entries()].map(([k, v]) => `${k}=${v}`).join(' , ')}`)
   if (out.length === 0) {
      console.log('没有从任何表提到 VIC1 电价行。各表列名：')
      for (const [k, h] of cols) console.log(`   ${k}: ${h.join(',')}`)
   }
   for (const row of out) {
      console.log(`--- ${row.key} VIC1: 去重时刻 ${row.n} | 首 ${row.first} | 末 ${row.last} | 相邻步长(分钟) ${JSON.stringify(row.diffs)}`)
      const spanH = (iso(row.last) - iso(row.first)) / 3600000
      console.log(`    时间跨度 ${spanH.toFixed(2)} h`)
   }
}
