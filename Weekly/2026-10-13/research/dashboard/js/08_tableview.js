const target = [...document.querySelectorAll('button')].find((b) => b.getAttribute('aria-label') === 'Table view')
if (target === undefined) return { error: 'no Table view' }
target.click()
return { clicked: true, t: new Date().toString() }
