import { writeFileSync } from 'node:fs'

const headers = { 'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0.0.0 Safari/537.36' }
const res = await fetch('https://dashboards.public.aemo.com.au/assets/index-DzwJm2qq.js', { headers })
const text = await res.text()
writeFileSync('C:\\Ash\\_research_20261013\\dashboard\\raw\\index-DzwJm2qq.js', text)
console.log(`bundle ${res.status} ${text.length} 字符`)

const paths = new Set()
for (const m of text.matchAll(/["'`](\/[A-Za-z0-9_\-./{}?=&$:]{4,120})["'`]/g)) paths.add(m[1])
const api = [...paths].filter((p) => /NEM\/v1|PWS|api|Dashboard|csv|download|export/i.test(p)).sort()
console.log('=== 候选接口路径 ===')
for (const p of api) console.log(`  ${p}`)

const urls = new Set()
for (const m of text.matchAll(/https?:\/\/[A-Za-z0-9_\-.:/?=&%{}]+/g)) urls.add(m[0])
console.log('=== 绝对 URL ===')
for (const u of [...urls].sort()) if (!/w3\.org|schema|googleapis|gstatic|youtube|facebook|hotjar/i.test(u)) console.log(`  ${u}`)

console.log('=== 含 timescale / x-api-key / csv 的片段 ===')
for (const key of ['timescale', 'x-api-key', 'xApiKey', 'csv', 'Csv', 'download']) {
   const idx = text.indexOf(key)
   if (idx >= 0) console.log(`  [${key}] ...${text.slice(Math.max(0, idx - 160), idx + 160).replace(/\s+/g, ' ')}...`)
   else console.log(`  [${key}] 未命中`)
}
