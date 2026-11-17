import { inflateRawSync } from 'node:zlib'
import { writeFileSync, mkdirSync, readFileSync } from 'node:fs'

const RAW = 'C:\\Ash\\_research_20261013\\dashboard\\raw'
mkdirSync(RAW, { recursive: true })
const HEADERS = { 'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0.0.0 Safari/537.36' }

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
      const lhNameLen = buffer.readUInt16LE(localOffset + 26)
      const lhExtraLen = buffer.readUInt16LE(localOffset + 28)
      const dataStart = localOffset + 30 + lhNameLen + lhExtraLen
      const body = buffer.subarray(dataStart, dataStart + compSize)
      const data = method === 8 ? inflateRawSync(body) : body
      entries.push({ name, bytes: data.length, text: data.toString('latin1') })
      p += 46 + nameLen + extraLen + commentLen
   }
   return entries
}

function parseMms(text) {
   const cols = new Map()
   const rows = []
   for (const line of text.split(/\r?\n/)) {
      if (line.length < 3) continue
      const f = line.split(',')
      if (f[0] === 'C') cols.set(`${f[1]}|${f[3]}`, f.slice(4).map((s) => s.replace(/"/g, '')))
      else if (f[0] === 'D') rows.push({ key: `${f[1]}|${f[3]}`, vals: f.slice(4).map((s) => s.replace(/"/g, '')) })
      else if (f[0] === 'I') rows.push({ info: f.slice(1) })
   }
   return { cols, rows }
}

async function newestZip(dir) {
   const res = await fetch(dir, { headers: HEADERS })
   const html = await res.text()
   const names = [...html.matchAll(/href="([^"]+\.zip)"/gi)].map((m) => m[1])
   const full = names.map((n) => (n.startsWith('http') ? n : new URL(n, dir).href))
   full.sort()
   return { count: full.length, newest: full[full.length - 1] }
}

const stamp = (s) => new Date(s.replace(' ', 'T') + '+10:00')

async function analyse(label, dir) {
   console.log(`\n================ ${label} ================`)
   const listing = await newestZip(dir)
   const res = await fetch(listing.newest, { headers: HEADERS })
   const buf = Buffer.from(await res.arrayBuffer())
   const entries = unzipFirst(buf)
   const csv = entries[0]
   writeFileSync(`${RAW}\\${csv.name}`, csv.text)
   console.log(`目录 ${dir}`)
   console.log(`目录里 zip 数 ${listing.count} | 取最新 ${listing.newest.split('/').pop()}`)
   console.log(`HTTP ${res.status} ${buf.length} 字节 | 服务端 Date ${res.headers.get('date')} | 解出 ${csv.name} ${csv.bytes} 字符`)
   const { cols, rows } = parseMms(csv.text)
   const info = rows.find((r) => r.info !== undefined)
   if (info !== undefined) console.log(`I 行: ${info.info.slice(0, 9).join(' | ')}`)
   for (const [key, header] of cols) {
      const data = rows.filter((r) => r.key === key)
      if (data.length === 0) continue
      const iRegion = header.indexOf('REGIONID')
      const iDate = header.indexOf('SETTLEMENTDATE')
      const iInter = header.indexOf('INTERVENTION')
      const iP = ['RRP', 'PRICE', 'RRP_ENERGY'].map((c) => header.indexOf(c)).find((i) => i >= 0) ?? -1
      console.log(`\n--- ${key}: ${data.length} 行 | 列 ${header.join(',')}`)
      if (iRegion < 0 || iDate < 0) { console.log('    （没有 REGIONID/SETTLEMENTDATE，跳过）'); continue }
      const vic = data.filter((r) => r.vals[iRegion] === 'VIC1' && (iInter < 0 || r.vals[iInter] === '0'))
      const stamps = [...new Set(vic.map((r) => r.vals[iDate]))].sort()
      console.log(`   VIC1 INTERVENTION=0: 行 ${vic.length} 去重时刻 ${stamps.length}`)
      if (stamps.length === 0) continue
      console.log(`   首 ${stamps[0]} | 末 ${stamps[stamps.length - 1]}`)
      const diffs = {}
      for (let i = 1; i < stamps.length; i += 1) {
         const d = (stamp(stamps[i]) - stamp(stamps[i - 1])) / 60000
         diffs[d] = (diffs[d] ?? 0) + 1
      }
      console.log(`   相邻步长(分钟) ${JSON.stringify(diffs)}`)
      if (iP >= 0) {
         const probe = vic.filter((r) => r.vals[iDate] === stamps[0] || r.vals[iDate] === stamps[stamps.length - 1])
         console.log(`   首末 RRP 抽样 ${probe.map((r) => `${r.vals[iDate]}=${r.vals[iP]}`).join(' , ')}`)
      }
   }
}

await analyse('PredispatchIS_Reports', 'https://www.nemweb.com.au/Reports/CURRENT/PredispatchIS_Reports/')
await analyse('PD7Day', 'https://www.nemweb.com.au/Reports/CURRENT/PD7Day/')

// 与面板接口对账：同一时刻的 VIC1 RRP 是否一致
const dash = JSON.parse(readFileSync(`${RAW}\\priceAndDemand_30MIN.json`, 'utf8').replace(/^\uFEFF/, ''))
const vicDash = dash.data.items.filter((r) => r.regionId === 'VIC1' && r.periodType === 'FORECAST')
console.log(`\n================ 面板接口对账 ================`)
console.log(`面板接口 VIC1 FORECAST: ${vicDash.length} 点 | ${vicDash.map((r) => r.settlementDate).sort()[0]} → ${vicDash.map((r) => r.settlementDate).sort().slice(-1)[0]}`)
console.log(`面板接口 VIC1 前 4 个预测点: ${vicDash.slice(0, 4).map((r) => `${r.settlementDate}=${r.rrp}`).join(' , ')}`)
