const HEADERS = { 'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0.0.0 Safari/537.36' }
const candidates = [
   'https://www.nemweb.com.au/Reports/CURRENT/PredispatchIS_Reports/',
   'https://www.nemweb.com.au/Reports/CURRENT/PREDISPATCHIS_Reports/',
   'https://www.nemweb.com.au/Reports/CURRENT/PD7Day/',
   'https://www.nemweb.com.au/Reports/CURRENT/PD7DAY_Reports/',
   'https://www.nemweb.com.au/Reports/CURRENT/SEVENDAYOUTLOOK_FULL/',
   'https://www.nemweb.com.au/Reports/CURRENT/P5_Reports/',
   'https://www.nemweb.com.au/Reports/CURRENT/DispatchIS_Reports/',
]
for (const url of candidates) {
   try {
      const res = await fetch(url, { headers: HEADERS })
      const html = await res.text()
      const zips = [...html.matchAll(/href="([^"]+\.zip)"/gi)].map((m) => m[1])
      zips.sort()
      console.log(`${res.status}  zip=${String(zips.length).padStart(4)}  ${url}`)
      if (zips.length > 0) console.log(`        最新: ${zips[zips.length - 1]}`)
      else if (res.status !== 200) console.log(`        体 ${html.length} 字符`)
   } catch (error) {
      console.log(`ERR  ${url}  ${String(error).slice(0, 120)}`)
   }
}
