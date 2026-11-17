import { inflateSync, inflateRawSync, gunzipSync } from 'node:zlib'
import { writeFileSync, mkdirSync } from 'node:fs'

const RAW = 'C:\\Ash\\_research_20261013\\dashboard\\raw'
mkdirSync(RAW, { recursive: true })
const headers = {
   'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
   accept: 'application/pdf,*/*',
}

/** 极简 PDF 取字：把每个 stream 解开，抓 Tj / TJ 里的字符串。 */
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
      for (const m of chunk.matchAll(/TJ|Tj|Td|TD|T\*/g)) out.push(m[0] === 'TJ' || m[0] === 'Tj' ? '' : '\n')
   }
   return out.join(' ').replace(/[ \t]{2,}/g, ' ')
}

const targets = [
   ['spot-market-operations-timetable', 'https://aemo.com.au/-/media/files/stakeholder_consultation/consultations/nem-consultations/2023/reliability-forecasting-guidelines-and-methodology-consultation/final/spot-market-operations-timetable.pdf'],
   ['so_op_3704-predispatch', 'https://wa.aemo.com.au/-/media/files/stakeholder_consultation/consultations/nem-consultations/2024/iess-rule-terminology-changes-to-ops-planning-documents/so_op_3704---predispatch.pdf'],
   ['NER-v155-chapter3', 'https://www.aemc.gov.au/sites/default/files/2020-11/NER%20-%20v155%20-%20Chapter%203.pdf'],
]

for (const [name, url] of targets) {
   try {
      const res = await fetch(url, { headers, redirect: 'follow' })
      const buf = Buffer.from(await res.arrayBuffer())
      const type = res.headers.get('content-type')
      console.log(`\n================ ${name} ================`)
      console.log(`HTTP ${res.status} | ${type} | ${buf.length} 字节 | 最终地址 ${res.url}`)
      writeFileSync(`${RAW}\\${name}.bin`, buf)
      if (!String(type).includes('pdf')) { console.log(`  不是 PDF，前 300 字符: ${buf.toString('utf8', 0, 300).replace(/\s+/g, ' ')}`); continue }
      const text = pdfText(buf)
      writeFileSync(`${RAW}\\${name}.txt`, text)
      console.log(`取到正文 ${text.length} 字符`)
      const lower = text.toLowerCase()
      let shown = 0
      for (const kw of ['period covered', 'pre-dispatch', 'predispatch', '40 hours', '48 hours', 'seven day', '5 minute pre']) {
         let i = lower.indexOf(kw)
         let guard = 0
         while (i >= 0 && guard < 4 && shown < 40) {
            console.log(`  [${kw}] ...${text.slice(Math.max(0, i - 180), i + 220).replace(/\s+/g, ' ')}...`)
            i = lower.indexOf(kw, i + 1)
            guard += 1
            shown += 1
         }
      }
      if (shown === 0) console.log(`  关键词 0 命中，正文开头: ${text.slice(0, 400)}`)
   } catch (error) {
      console.log(`\n================ ${name} ================\nERR ${String(error).slice(0, 200)}`)
   }
}
