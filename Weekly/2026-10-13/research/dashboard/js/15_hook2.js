if (window.__cap2 === undefined) {
   window.__cap2 = []
   const oo = XMLHttpRequest.prototype.open
   const os = XMLHttpRequest.prototype.send
   XMLHttpRequest.prototype.open = function (m, u, ...rest) {
      this.__u2 = String(u)
      return oo.call(this, m, u, ...rest)
   }
   XMLHttpRequest.prototype.send = function (b) {
      const entry = { url: this.__u2, t: new Date().toString() }
      window.__cap2.push(entry)
      this.addEventListener('load', () => {
         try {
            const txt = this.responseText
            entry.httpStatus = this.status
            entry.chars = txt.length
            if (/priceAndDemand/.test(entry.url)) {
               const j = JSON.parse(txt)
               const items = j?.data?.items ?? []
               entry.parsed = items.length
               const vic = items.filter((r) => r.regionId === 'VIC1')
               const fc = vic.filter((r) => r.periodType === 'FORECAST')
               const ac = vic.filter((r) => r.periodType === 'ACTUAL')
               const f = (rows) => rows.map((r) => r.settlementDate).sort()
               entry.vicForecast = { n: fc.length, first: f(fc)[0], last: f(fc)[fc.length - 1] }
               entry.vicActual = { n: ac.length, first: f(ac)[0], last: f(ac)[ac.length - 1] }
               entry.regions = [...new Set(items.map((r) => r.regionId))]
               entry.types = [...new Set(items.map((r) => r.periodType))]
            }
         } catch (e) { entry.err = String(e).slice(0, 200) }
      })
      return os.call(this, b)
   }
}
return { installed: true, cap2: window.__cap2.length }
