const base = 'https://nemweb.com.au/Reports/CURRENT/MMSDataModelReport/Electricity/Electricity%20Data%20Model%20Report_files/'
const headers = { 'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0.0.0 Safari/537.36' }

const index = await (await fetch(`${base}Elec%20Data%20Model%20Report.htm`, { headers })).text()
console.log(`索引页 ${index.length} 字符`)
const links = [...index.matchAll(/href="([^"]+\.htm)"[^>]*>([^<]{0,80})/gi)].map((m) => ({ href: m[1], text: m[2].trim() }))
console.log(`链接数 ${links.length}`)
for (const want of ['PD7DAY', 'PREDISPATCH', 'P5MIN', 'SEVENDAY']) {
   const hits = links.filter((l) => new RegExp(want, 'i').test(`${l.href} ${l.text}`))
   console.log(`\n== 含 ${want} 的链接 ${hits.length} 条 ==`)
   for (const h of hits.slice(0, 25)) console.log(`   ${h.text}  ->  ${h.href}`)
}
