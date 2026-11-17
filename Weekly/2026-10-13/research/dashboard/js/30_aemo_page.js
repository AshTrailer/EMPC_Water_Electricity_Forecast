const urls = [
   'https://www.aemo.com.au/energy-systems/electricity/national-electricity-market-nem/system-operations/dispatch-and-pre-dispatch',
]
const out = []
for (const u of urls) {
   try {
      const res = await fetch(u, { credentials: 'include' })
      const html = await res.text()
      const doc = new DOMParser().parseFromString(html, 'text/html')
      for (const bad of doc.querySelectorAll('script,style,nav,footer,header')) bad.remove()
      const text = (doc.body?.innerText ?? doc.body?.textContent ?? '').replace(/\n{2,}/g, '\n').trim()
      const lower = text.toLowerCase()
      const hits = []
      for (const kw of ['hour', 'pre-dispatch', 'predispatch', '40', '48', 'five minute', '5-minute', 'seven day', 'forecast']) {
         let i = lower.indexOf(kw)
         let guard = 0
         while (i >= 0 && guard < 6) {
            hits.push(`[${kw}] ...${text.slice(Math.max(0, i - 200), i + 260).replace(/\s+/g, ' ')}...`)
            i = lower.indexOf(kw, i + 1)
            guard += 1
         }
      }
      out.push({ url: u, status: res.status, chars: text.length, head: text.slice(0, 1200), hits: hits.slice(0, 30) })
   } catch (e) {
      out.push({ url: u, error: String(e).slice(0, 200) })
   }
}
return out
