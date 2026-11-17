const HEADERS = {
   'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
   'x-api-key': '0ae2748cec08449bb5b3b31b577f71e2',
}

/* 1) 7 天展望接口到底给什么 */
const url7 = 'https://dashboards.public.aemo.com.au/NEM/v1/PWS/NEMDashboard/sevenDayOutlook'
const r7 = await fetch(url7, { headers: HEADERS })
const j7 = await r7.json()
const items7 = j7?.data?.items ?? []
console.log(`sevenDayOutlook HTTP ${r7.status} | 记录 ${items7.length}`)
if (items7.length > 0) {
   console.log(`字段: ${Object.keys(items7[0]).join(', ')}`)
   const vic = items7.filter((r) => r.regionId === 'VIC1' || r.regionid === 'VIC1')
   console.log(`VIC1 记录 ${vic.length}`)
   const dates = [...new Set(items7.map((r) => r.prettyDate ?? r.intervalDateTime ?? r.settlementDate ?? r.dateTime))].sort()
   console.log(`时刻字段样值: ${JSON.stringify(items7[0])}`.slice(0, 400))
   console.log(`去重时刻 ${dates.length} | 首 ${dates[0]} | 末 ${dates[dates.length - 1]}`)
   const types = [...new Set(items7.map((r) => r.dataType))]
   console.log(`dataType 取值: ${types.join(', ')}`)
}
console.log(`warnings: ${JSON.stringify(j7.warnings)} | infos: ${JSON.stringify(j7.infos)}`)

/* 2) 引用验活 */
const urls = [
   'https://www.aemo.com.au/energy-systems/electricity/national-electricity-market-nem/data-nem/data-dashboard-nem',
   'https://dashboards.public.aemo.com.au/price-and-demand',
   'https://dashboards.public.aemo.com.au/config.json',
   'https://www.nemweb.com.au/Reports/CURRENT/PredispatchIS_Reports/',
   'https://www.nemweb.com.au/Reports/CURRENT/PD7Day/',
   'https://www.nemweb.com.au/Reports/CURRENT/P5_Reports/',
   'https://visualisations.aemo.com.au/aemo/nemweb/mmsdatamodelreport/electricity/mms%20data%20model%20report_files/MMS_276.htm',
   'https://visualisations.aemo.com.au/aemo/nemweb/MMSDataModelReport/Electricity/MMS%20Data%20Model%20Report_files/MMS_240.htm',
   'https://www.aemc.gov.au/sites/default/files/2023-06/Final%20consolidated%20rule.pdf',
   'https://aemo.com.au/-/media/files/stakeholder_consultation/consultations/nem-consultations/2023/reliability-forecasting-guidelines-and-methodology-consultation/final/spot-market-operations-timetable.pdf',
   'https://www.aemo.com.au/Energy%20systems/Electricity/National%20Electricity%20Market%20NEM/Data%20NEM/Market%20Management%20System%20MMS%20data/Pre%20dispatch',
]
console.log('\n================ 引用验活 ================')
for (const u of urls) {
   try {
      const res = await fetch(u, { headers: { 'user-agent': HEADERS['user-agent'] }, redirect: 'follow' })
      console.log(`${String(res.status).padEnd(4)} ${res.headers.get('content-type')} | ${u}`)
   } catch (error) {
      console.log(`ERR  ${u} | ${String(error).slice(0, 90)}`)
   }
}
