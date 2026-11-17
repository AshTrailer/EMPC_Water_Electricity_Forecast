const headers = { 'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0.0.0 Safari/537.36' }
const candidates = [
   'https://visualisations.aemo.com.au/aemo/nemweb/mmsdatamodelreport/electricity/mms%20data%20model%20report_files/MMS%20Data%20Model%20Report.htm',
   'https://nemweb.com.au/Reports/CURRENT/MMSDataModelReport/Electricity/Electricity%20Data%20Model%20Report_files/Elec%20Data%20Model%20Report.htm',
   'https://nemweb.com.au/Reports/CURRENT/MMSDataModelReport/Electricity/Electricity%20Data%20Model%20Report.htm',
]
for (const url of candidates) {
   const res = await fetch(url, { headers })
   const text = await res.text()
   console.log(`\n=== HTTP ${res.status} ${text.length} 字符 ${url}`)
   console.log(text.slice(0, 400).replace(/\s+/g, ' '))
   const links = [...text.matchAll(/href="([^"]+\.html?)"[^>]*>([^<]{0,80})/gi)].map((m) => ({ href: m[1], text: m[2].trim() }))
   console.log(`链接 ${links.length} 条`)
   for (const want of ['PD7DAY', 'PREDISPATCH', 'P5MIN']) {
      const hits = links.filter((l) => new RegExp(want, 'i').test(`${l.href} ${l.text}`))
      for (const h of hits.slice(0, 12)) console.log(`   [${want}] ${h.text} -> ${h.href}`)
   }
}
