const urls = [
   'https://www.aemo.com.au/Energy%20systems/Electricity/National%20Electricity%20Market%20NEM/Data%20NEM/Market%20Management%20System%20MMS%20data/Pre%20dispatch',
]
const out = []
for (const u of urls) {
   try {
      const res = await fetch(u, { credentials: 'include', redirect: 'follow' })
      const html = await res.text()
      const doc = new DOMParser().parseFromString(html, 'text/html')
      for (const bad of doc.querySelectorAll('script,style,nav,footer,header')) bad.remove()
      const text = (doc.body?.innerText ?? doc.body?.textContent ?? '').replace(/[ \t]+/g, ' ').replace(/\n{2,}/g, '\n').trim()
      const lower = text.toLowerCase()
      const hits = []
      for (const kw of ['hour', 'pre-dispatch', 'predispatch', '30 minute', 'thirty', '48', 'day ahead', 'forecast']) {
         let i = lower.indexOf(kw)
         let guard = 0
         while (i >= 0 && guard < 5) {
            hits.push(`[${kw}] ...${text.slice(Math.max(0, i - 220), i + 300).replace(/\s+/g, ' ')}...`)
            i = lower.indexOf(kw, i + 1)
            guard += 1
         }
      }
      out.push({ url: u, finalUrl: res.url, status: res.status, chars: text.length, head: text.slice(0, 2500), hits: hits.slice(0, 30) })
   } catch (e) {
      out.push({ url: u, error: String(e).slice(0, 200) })
   }
}
return out
