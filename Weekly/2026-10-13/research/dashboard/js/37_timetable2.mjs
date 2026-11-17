import { readFileSync } from 'node:fs'

const RAW = 'C:\\Ash\\_research_20261013\\dashboard\\raw'
const text = readFileSync(`${RAW}\\spot-market-operations-timetable.txt`, 'latin1')
const flat = text.replace(/\s+/g, '')

/* 只取关键词附近一小段，避开 PDF 二进制垃圾。 */
for (const kw of ['pre-dispatchschedule', 'Publishpre-dispatch', 'Publish30-minute', '30-minutepre-dispatch']) {
   const windows = []
   let i = flat.indexOf(kw)
   while (i >= 0 && windows.length < 12) {
      const w = flat.slice(Math.max(0, i - 120), i + 240).replace(/en-(AU|GB|US)/g, '|')
      if (!/[\u0000-\u0008\u000e-\u001f]/.test(w)) windows.push(w)
      i = flat.indexOf(kw, i + 1)
   }
   console.log(`\n################ ${kw}: 干净窗口 ${windows.length} 个 ################`)
   for (const w of windows) console.log(`  ...${w}...`)
}
