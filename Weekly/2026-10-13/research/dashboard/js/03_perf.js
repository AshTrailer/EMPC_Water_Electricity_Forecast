const rows = performance.getEntriesByType('resource').map((r) => ({ name: r.name, type: r.initiatorType, size: r.transferSize, dur: Math.round(r.duration) }))
const interesting = rows.filter((r) => !/\.(css|js|png|jpg|jpeg|svg|woff2?|ico|gif|webp)(\?|$)/i.test(r.name))
return { total: rows.length, interesting }
