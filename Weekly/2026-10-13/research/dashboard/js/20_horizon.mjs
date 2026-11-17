import { inflateRawSync } from 'node:zlib'

const HEADERS = { 'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0.0.0 Safari/537.36' }
const iso = (s) => new Date(s.replace(/\//g, '-').replace(' ', 'T') + '+10:00')

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

/** 只取 REGION_PRICES 的 VIC1 行，块结束就停，不用扫完整份 9.6M 字符。 */
function vicRegionPrices(text) {
   let header = null
   let dateIdx = -1
   let regionIdx = -1
   let interIdx = -1
   const stamps = []
   let started = false
   let start = 0
   while (start < text.length) {
      let end = text.indexOf('\n', start)
      if (end < 0) end = text.length
      const line = text.slice(start, end)
      start = end + 1
      if (line.length < 3) continue
      const f = line.split(',')
      const kind = f[0]
      if (kind === 'I') {
         if (f[1] === 'PREDISPATCH' && f[2] === 'REGION_PRICES') {
            header = f.slice(4).map((s) => s.replace(/"/g, ''))
            dateIdx = header.indexOf('DATETIME')
            regionIdx = header.indexOf('REGIONID')
            interIdx = header.indexOf('INTERVENTION')
         }
         continue
      }
      if (kind !== 'D') continue
      if (f[1] !== 'PREDISPATCH' || f[2] !== 'REGION_PRICES') { if (started) break; continue }
      started = true
      const vals = f.slice(4).map((s) => s.replace(/"/g, ''))
      if (vals[regionIdx] !== 'VIC1') continue
      if (interIdx >= 0 && vals[interIdx] !== '0') continue
      stamps.push(vals[dateIdx])
   }
   stamps.sort()
   return { n: stamps.length, first: stamps[0], last: stamps[stamps.length - 1] }
}

const dir = 'https://www.nemweb.com.au/Reports/CURRENT/PredispatchIS_Reports/'
const html = await (await fetch(dir, { headers: HEADERS })).text()
const names = [...html.matchAll(/href="([^"]+\.zip)"/gi)].map((m) => m[1]).map((n) => n.split('/').pop())
names.sort()
console.log(`目录内 zip 总数 ${names.length}`)
console.log(`最早 ${names[0]}`)
console.log(`最新 ${names[names.length - 1]}`)

/* 文件名里两段时间：前一个是最早的电价时段，后一个是发布时刻。 */
const parseName = (n) => {
   const m = n.match(/PUBLIC_PREDISPATCHIS_(\d{12})_(\d{14})\.zip/)
   if (m === null) return null
   const p = (s) => new Date(`${s.slice(0, 4)}-${s.slice(4, 6)}-${s.slice(6, 8)}T${s.slice(8, 10)}:${s.slice(10, 12)}:${s.slice(12, 14) || '00'}+10:00`)
   return { firstInterval: p(m[1]), published: p(m[2]) }
}

const latest = parseName(names[names.length - 1])
console.log(`\n最近 12 次发布（相邻间隔小时）:`)
let previous = null
for (const n of names.slice(-12)) {
   const info = parseName(n)
   const gap = previous === null ? '' : `${((info.published - previous) / 3600000).toFixed(2)} h`
   console.log(`  ${n}  发布 ${info.published.toISOString()} 首时段 ${info.firstInterval.toISOString()} 距上次 ${gap}`)
   previous = info.published
}

/* 取最近 40 小时里的发布点，每 ~3 小时抽一个，量最大预测跨度。 */
const cutoff = latest.published.getTime() - 40 * 3600 * 1000
const recent = names.filter((n) => { const i = parseName(n); return i !== null && i.published.getTime() >= cutoff })
console.log(`\n最近 40 小时内的 zip 数 ${recent.length}`)
const picks = []
for (let i = 0; i < recent.length; i += Math.max(1, Math.floor(recent.length / 14))) picks.push(recent[i])
if (picks[picks.length - 1] !== recent[recent.length - 1]) picks.push(recent[recent.length - 1])

console.log(`\n抽样 ${picks.length} 份，量 VIC1 电价预测跨度:`)
console.log('发布时刻(本地) | 首预测时段 | 末预测时段 | 点数 | 最大跨度(小时, 相对发布时刻)')
const rows = []
for (const n of picks) {
   const info = parseName(n)
   const res = await fetch(`${dir}${n}`, { headers: HEADERS })
   const buf = Buffer.from(await res.arrayBuffer())
   const csv = unzipFirst(buf)
   const vic = vicRegionPrices(csv.text)
   const horizon = (iso(vic.last) - info.published) / 3600000
   const span = (iso(vic.last) - iso(vic.first)) / 3600000
   const steps = (iso(vic.first) - info.published) / 60000
   rows.push({ n, published: info.published, n: vic.n, first: vic.first, last: vic.last, horizon, span, steps })
   console.log(`${info.published.toLocaleString('sv-SE')} | ${vic.first} | ${vic.last} | ${vic.n} | ${horizon.toFixed(2)} | 首点滞后发布 ${steps.toFixed(0)} 分 | 跨度 ${span.toFixed(2)}`)
}
const hs = rows.map((r) => r.horizon)
console.log(`\n跨度统计: 最小 ${Math.min(...hs).toFixed(2)} h, 最大 ${Math.max(...hs).toFixed(2)} h, 点数 ${Math.min(...rows.map((r) => r.n))} 到 ${Math.max(...rows.map((r) => r.n))}`)
