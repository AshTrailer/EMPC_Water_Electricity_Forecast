import { readFileSync, readdirSync } from 'node:fs'

const RAW = 'C:\\Ash\\_research_20261013\\dashboard\\raw'
const files = readdirSync(RAW).filter((f) => f.endsWith('.CSV'))
console.log(`raw 下的 CSV: ${files.join(' , ')}`)

for (const file of files) {
   const text = readFileSync(`${RAW}\\${file}`, 'latin1')
   console.log(`\n================ ${file} ================`)
   const seen = new Set()
   let shown = 0
   const first = {}
   for (const line of text.split('\n')) {
      if (line.length < 3) continue
      const f = line.split(',')
      const key = `${f[1]}|${f[2]}`
      if (f[0] === 'I' && !seen.has(key)) {
         seen.add(key)
         console.log(`[I] ${key}  列(${f.length - 4}): ${f.slice(4).map((s) => s.replace(/"/g, '')).join(',')}`)
      }
      if (f[0] === 'D' && first[key] === undefined) {
         first[key] = f.slice(4).join(' | ')
         shown += 1
      }
   }
   console.log('--- 每表首条 D 行 ---')
   for (const [key, row] of Object.entries(first)) console.log(`[D] ${key}: ${row}`)
}
