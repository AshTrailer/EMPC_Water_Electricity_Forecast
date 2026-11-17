import { writeFileSync } from 'node:fs'

const base = 'https://dashboards.public.aemo.com.au'
const API_KEY = '0ae2748cec08449bb5b3b31b577f71e2'
const headers = {
   accept: 'application/json, text/plain, */*',
   'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
   referer: 'https://dashboards.public.aemo.com.au/price-and-demand',
   'x-api-key': API_KEY,
}

async function grab(url, save) {
   const t0 = new Date()
   const res = await fetch(url, { headers })
   const text = await res.text()
   const t1 = new Date()
   const row = { url, status: res.status, bytes: Buffer.byteLength(text), fetched_at_local: t1.toString(), fetched_at_iso: t1.toISOString(), content_type: res.headers.get('content-type'), server_date: res.headers.get('date') }
   if (save !== undefined) writeFileSync(save, text)
   return { row, text }
}

const cfg = await grab(`${base}/config.json`)
console.log('=== config.json ===')
console.log(JSON.stringify(cfg.row))
console.log(cfg.text.slice(0, 2500))

for (const scale of ['30MIN', '5MIN']) {
   const { row, text } = await grab(`${base}/NEM/v1/PWS/NEMDashboard/priceAndDemand?timescale=${scale}`, `C:\\Ash\\_research_20261013\\dashboard\\raw\\priceAndDemand_${scale}.json`)
   console.log(`=== priceAndDemand timescale=${scale} ===`)
   console.log(JSON.stringify(row))
   console.log(text.slice(0, 700))
   console.log('...tail:', text.slice(-400))
}
