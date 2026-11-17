const out = {}
out.href = location.href
out.title = document.title
out.bodyText = document.body.innerText.slice(0, 4000)
out.selects = [...document.querySelectorAll('select')].map((s) => ({ id: s.id, name: s.name, cls: s.className, opts: [...s.options].map((o) => `${o.value}|${o.text}`).slice(0, 20), n: s.options.length }))
out.buttons = [...document.querySelectorAll('button,[role=button],[role=tab],a.btn,li[role=tab]')].map((b) => ({ tag: b.tagName, txt: (b.innerText || b.getAttribute('aria-label') || '').trim().slice(0, 40), id: b.id, cls: String(b.className).slice(0, 60) })).filter((r) => r.txt).slice(0, 80)
out.svgCount = document.querySelectorAll('svg').length
out.canvasCount = document.querySelectorAll('canvas').length
out.scripts = [...document.querySelectorAll('script[src]')].map((s) => s.src)
out.links = [...document.querySelectorAll('link[href]')].map((l) => l.href).slice(0, 40)
out.windowKeys = Object.keys(window).filter((k) => /echart|powerbi|chart|plotly|d3|vue|react|app|config|store/i.test(k)).slice(0, 60)
return out
