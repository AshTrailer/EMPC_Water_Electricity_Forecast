const btn = [...document.querySelectorAll('a.p-tabview-nav-link')].find((a) => a.textContent.trim() === 'SA')
if (btn === undefined) return { error: 'no SA tab' }
btn.click()
return { clicked: 'SA', t: new Date().toString() }
