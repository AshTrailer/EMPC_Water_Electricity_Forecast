// List the network resources the AEMO data dashboard actually fetched.
const rows = performance.getEntriesByType('resource').map(r => r.name);
const interesting = rows.filter(n => /json|csv|api|data|report|nem/i.test(n));
return JSON.stringify({
  href: location.href,
  title: document.title,
  total: rows.length,
  interesting: [...new Set(interesting)].slice(-80)
}, null, 1);
