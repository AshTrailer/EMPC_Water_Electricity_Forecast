if (window.__cap === undefined) {
   window.__cap = []
   const push = (row) => window.__cap.push({ t: Date.now(), ...row })
   const of = window.fetch
   window.fetch = function (...a) {
      const url = typeof a[0] === 'string' ? a[0] : (a[0] && a[0].url)
      push({ kind: 'fetch', url: String(url), body: typeof a[1]?.body === 'string' ? a[1].body.slice(0, 300) : null })
      return of.apply(this, a)
   }
   const oo = XMLHttpRequest.prototype.open
   const os = XMLHttpRequest.prototype.send
   XMLHttpRequest.prototype.open = function (m, u, ...rest) {
      this.__u = String(u)
      this.__m = m
      return oo.call(this, m, u, ...rest)
   }
   XMLHttpRequest.prototype.send = function (b) {
      push({ kind: 'xhr', method: this.__m, url: this.__u, body: typeof b === 'string' ? b.slice(0, 300) : null })
      this.addEventListener('load', () => {
         try {
            const txt = this.responseText
            if (typeof txt === 'string') window.__cap[window.__cap.length - 1].respLen = txt.length
         } catch (e) { /* 非文本响应 */ }
      })
      return os.call(this, b)
   }
}
const modes = [...document.querySelectorAll('*')]
   .filter((e) => e.children.length === 0 && /^(Pre-Dispatch|Dispatch)$/.test((e.textContent || '').trim()))
   .map((e) => {
      const chain = []
      let n = e
      for (let i = 0; i < 4 && n !== null; i += 1) { chain.push(`${n.tagName}.${String(n.className).slice(0, 60)}`); n = n.parentElement }
      return { txt: e.textContent.trim(), tag: e.tagName, chain }
   })
return { hookInstalled: true, capLen: window.__cap.length, modes }
