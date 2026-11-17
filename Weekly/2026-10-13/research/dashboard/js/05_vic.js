const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
window.__cap.length = 0
const vic = [...document.querySelectorAll('a.p-tabview-nav-link')].find((a) => a.textContent.trim() === 'VIC')
if (vic === undefined) return { error: 'no VIC tab' }
vic.click()
await sleep(2500)
const kpis = [...document.querySelectorAll('*')]
   .filter((e) => e.children.length === 0 && e.textContent.trim() !== '' && e.clientHeight > 0)
   .map((e) => e.textContent.trim())
   .filter((t) => t.length < 80)
const head = kpis.slice(0, 40)
const body = document.body.innerText.slice(0, 1200)
const activeTab = document.querySelector('a.p-tabview-nav-link.p-highlight')?.textContent.trim()
const modeLabel = document.querySelector('.p-dropdown-label')?.textContent.trim()
return { activeTab, modeLabel, head, body, cap: window.__cap.map((r) => r.url) }
