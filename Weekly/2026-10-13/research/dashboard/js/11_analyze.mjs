import { readFileSync } from 'node:fs'

function load(path) {
   const text = readFileSync(path, 'utf8')
   const json = JSON.parse(text.replace(/^\uFEFF/, ''))
   return { text, json }
}

const NEM_TZ = 'Australia/Brisbane' // NEM 时间基准，UTC+10 无夏令时

for (const scale of ['30MIN', '5MIN']) {
   const path = `C:\\Ash\\_research_20261013\\dashboard\\raw\\priceAndDemand_${scale}.json`
   const { json } = load(path)
   const items = json?.data?.items ?? []
   console.log(`\n================ timescale=${scale} ================`)
   console.log(`顶层键: ${Object.keys(json).join(', ')} | data 键: ${Object.keys(json.data).join(', ')} | 记录数: ${items.length}`)
   console.log(`字段: ${Object.keys(items[0]).join(', ')}`)
   const byType = {}
   for (const it of items) byType[it.periodType] = (byType[it.periodType] ?? 0) + 1
   console.log(`periodType 分布: ${JSON.stringify(byType)}`)
   const regions = [...new Set(items.map((it) => it.regionId))]
   console.log(`regionId: ${regions.join(', ')}`)

   for (const region of regions) {
      for (const type of Object.keys(byType)) {
         const rows = items.filter((it) => it.regionId === region && it.periodType === type)
         if (rows.length === 0) continue
         const ts = rows.map((r) => new Date(r.settlementDate).getTime())
         const uniq = [...new Set(ts)].sort((a, b) => a - b)
         const diffs = {}
         for (let i = 1; i < uniq.length; i += 1) {
            const d = (uniq[i] - uniq[i - 1]) / 60000
            diffs[d] = (diffs[d] ?? 0) + 1
         }
         const fmt = (t) => new Date(t).toLocaleString('sv-SE', { timeZone: NEM_TZ })
         console.log(`  ${region} ${type}: n=${rows.length} 去重时刻=${uniq.length} 首=${fmt(uniq[0])} 末=${fmt(uniq[uniq.length - 1])} 步长(分钟)分布=${JSON.stringify(diffs)}`)
      }
   }
   console.log(`顶层其他键: ${JSON.stringify(Object.entries(json.data).filter(([k]) => k !== 'items').map(([k, v]) => [k, Array.isArray(v) ? `array(${v.length})` : typeof v]))}`)
}
