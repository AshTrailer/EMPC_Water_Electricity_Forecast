import { readFileSync } from 'node:fs'

const RAW = 'C:\\Ash\\_research_20261013\\dashboard\\raw'
const text = readFileSync(`${RAW}\\spot-market-operations-timetable.txt`, 'latin1')
const flat = text.replace(/\s+/g, '')

function dump(label, keyword, before = 60, after = 5200, max = 1) {
   const out = []
   let i = flat.indexOf(keyword)
   while (i >= 0 && out.length < max) {
      out.push(flat.slice(Math.max(0, i - before), i + after))
      i = flat.indexOf(keyword, i + 1)
   }
   console.log(`\n################ ${label} （命中 ${out.length}）################`)
   for (const h of out) {
      /* 把 en-AU / en-GB 这类语言标记去掉，读起来顺一点。 */
      console.log(h.replace(/en-(AU|GB|US)/g, ' | '))
   }
}

dump('2.3 Dispatch and pre-dispatch 整节', '2.3.Dispatchandpre-dispatch', 0, 5200)
dump('2.1 Bids 节（找 Day-1 12:00 报价截止）', '2.1.Bids', 0, 5200)
