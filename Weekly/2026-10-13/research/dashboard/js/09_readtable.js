const out = {}
const table = document.querySelector('.p-datatable')
out.hasTable = table !== null
if (table !== null) {
   out.headers = [...table.querySelectorAll('thead th')].map((th) => th.innerText.trim())
   const rows = [...table.querySelectorAll('tbody tr')]
   out.renderedRows = rows.length
   const cells = (tr) => [...tr.querySelectorAll('td')].map((td) => td.innerText.trim())
   out.firstRows = rows.slice(0, 3).map(cells)
   out.lastRows = rows.slice(-3).map(cells)
   const pag = document.querySelector('.p-paginator')
   out.paginator = pag === null ? null : pag.innerText.replace(/\s+/g, ' ').trim()
}
out.viewToggles = [...document.querySelectorAll('button')].map((b) => b.getAttribute('aria-label'))
out.bodyHead = document.body.innerText.slice(0, 600)
return out
