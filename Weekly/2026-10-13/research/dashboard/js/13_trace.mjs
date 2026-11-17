import { readFileSync } from 'node:fs'

const text = readFileSync('C:\\Ash\\_research_20261013\\dashboard\\raw\\index-DzwJm2qq.js', 'utf8')
const show = (label, re, before = 260, after = 420, max = 6) => {
   console.log(`\n########## ${label} ##########`)
   let n = 0
   for (const m of text.matchAll(re)) {
      if (n >= max) break
      n += 1
      console.log(`--- @${m.index} ---`)
      console.log(text.slice(Math.max(0, m.index - before), m.index + after).replace(/\s+/g, ' '))
   }
   if (n === 0) console.log('未命中')
}

show('downloadCSVFile', /downloadCSVFile\(/g)
show('sevenDayOutlook', /sevenDayOutlook/g, 200, 300, 4)
show('periodType', /periodType/g, 220, 320, 8)
show('FORECAST 字面量', /FORECAST/g, 150, 200, 8)
show('小时运算', /addHours|subHours|differenceInHours|setHours|startOfDay|endOfDay|addDays/g, 120, 200, 12)
