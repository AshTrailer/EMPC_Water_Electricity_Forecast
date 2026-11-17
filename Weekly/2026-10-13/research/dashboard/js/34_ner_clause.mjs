import { readFileSync } from 'node:fs'

const path = 'C:\\Ash\\_research_20261013\\dashboard\\raw\\NER-v155-chapter3.txt'
const text = readFileSync(path, 'latin1')
/** 抽出正文里无意义的单字符间空格，便于检索。 */
const squeeze = (s) => s.replace(/(?<=\b\w) (?=\w\b)/g, '')
const flat = text.replace(/\s+/g, ' ')

for (const kw of ['3.8.20', 'Pre-dispatch schedule', '3.8.13', '40 hours', '48 hours', 'fourty', 'trading day covered']) {
   const hits = []
   let i = flat.indexOf(kw)
   while (i >= 0 && hits.length < 3) {
      hits.push(flat.slice(Math.max(0, i - 300), i + 1400))
      i = flat.indexOf(kw, i + 1)
   }
   console.log(`\n################ ${kw} （命中 ${hits.length} 处） ################`)
   for (const h of hits) console.log(`---\n${squeeze(h)}`)
}
