import { inflateSync, inflateRawSync, gunzipSync } from 'node:zlib'
import { writeFileSync, readFileSync, mkdirSync } from 'node:fs'

const RAW = 'C:\\Ash\\_research_20261013\\dashboard\\raw'
mkdirSync(RAW, { recursive: true })
const headers = { 'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0.0.0 Safari/537.36', accept: 'application/pdf,*/*' }

function pdfText(buffer) {
   const chunks = []
   let p = 0
   while (p < buffer.length) {
      const s = buffer.indexOf('stream', p)
      if (s < 0) break
      const e = buffer.indexOf('endstream', s)
      if (e < 0) break
      let start = s + 6
      while (buffer[start] === 13 || buffer[start] === 10) start += 1
      const body = buffer.subarray(start, e)
      let text = null
      for (const fn of [inflateSync, inflateRawSync, gunzipSync]) {
         try { text = fn(body).toString('latin1'); break } catch (error) { /* 换下一种 */ }
      }
      if (text !== null) chunks.push(text)
      p = e + 9
   }
   const out = []
   for (const chunk of chunks) {
      for (const m of chunk.matchAll(/\((?:\\.|[^\\()])*\)/g)) out.push(m[0].slice(1, -1).replace(/\\([()\\])/g, '$1'))
      out.push(' ')
   }
   return out.join('')
}

/** 把空白全去掉：这份 PDF 抽出来是逐字符带空格的，按原文搜会漏。 */
const despace = (s) => s.replace(/\s+/g, '')

function find(text, keyword, before = 200, after = 900, max = 3) {
   const flat = despace(text)
   const out = []
   let i = flat.toLowerCase().indexOf(keyword.toLowerCase())
   while (i >= 0 && out.length < max) {
      out.push(flat.slice(Math.max(0, i - before), i + after))
      i = flat.toLowerCase().indexOf(keyword.toLowerCase(), i + 1)
   }
   return out
}

console.log('################ AEMO Spot Market Operations Timetable ################')
const timetable = readFileSync(`${RAW}\\spot-market-operations-timetable.txt`, 'latin1')
console.log(`正文 ${timetable.length} 字符，去空白后 ${despace(timetable).length} 字符`)
for (const kw of ['Periodcovered', 'Pre-dispatch', 'Predispatch', 'closingtime', 'bidsclosing', '12:00', '13:00', 'tradingday', 'P5MIN', 'PD7DAY']) {
   const hits = find(timetable, kw, 120, 700, 3)
   console.log(`\n---- [${kw}] 命中 ${hits.length} 处`)
   for (const h of hits) console.log(`   ...${h}...`)
}

console.log('\n\n################ AEMC 2023 合并版 NER ################')
const url = 'https://www.aemc.gov.au/sites/default/files/2023-06/Final%20consolidated%20rule.pdf'
const res = await fetch(url, { headers })
const buf = Buffer.from(await res.arrayBuffer())
console.log(`HTTP ${res.status} | ${res.headers.get('content-type')} | ${buf.length} 字节`)
if (String(res.headers.get('content-type')).includes('pdf')) {
   writeFileSync(`${RAW}\\aemc-consolidated-rule-2023.bin`, buf)
   const text = pdfText(buf)
   writeFileSync(`${RAW}\\aemc-consolidated-rule-2023.txt`, text)
   console.log(`正文 ${text.length} 字符，去空白后 ${despace(text).length} 字符`)
   for (const kw of ['3.8.20', '3.8.13', 'pre-dispatchschedulecoveringeach', '40hours', 'lasttradingdayforwhichallvalid']) {
      const hits = find(text, kw, 100, 1100, 2)
      console.log(`\n---- [${kw}] 命中 ${hits.length} 处`)
      for (const h of hits) console.log(`   ...${h}...`)
   }
} else {
   console.log(`不是 PDF：${buf.toString('utf8', 0, 200).replace(/\s+/g, ' ')}`)
}
