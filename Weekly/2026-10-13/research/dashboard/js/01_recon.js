const out = {}
out.href = location.href
out.title = document.title
out.readyState = document.readyState
out.iframes = [...document.querySelectorAll('iframe')].map((f) => ({ src: f.src, id: f.id, cls: f.className, w: f.clientWidth, h: f.clientHeight }))
out.scripts = [...document.querySelectorAll('script[src]')].map((s) => s.src).slice(0, 60)
out.selects = [...document.querySelectorAll('select')].map((s) => ({ id: s.id, name: s.name, cls: s.className, opts: [...s.options].slice(0, 12).map((o) => `${o.value}|${o.text}`) }))
out.buttons = [...document.querySelectorAll('button,[role=button]')].map((b) => (b.innerText || b.getAttribute('aria-label') || '').trim().slice(0, 40)).filter(Boolean).slice(0, 60)
out.bodyTextHead = document.body.innerText.slice(0, 3000)
out.widgetTypes = [...new Set([...document.querySelectorAll('*')].map((e) => e.tagName.toLowerCase()).filter((t) => t.includes('-')))] .slice(0, 80)
return out
