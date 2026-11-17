const t0 = Date.now();
try {
  const r = await fetch('https://r.jina.ai/https://arxiv.org/pdf/2104.00655', { headers: { 'User-Agent': 'Mozilla/5.0' } });
  console.log('status', r.status, 'ctype', r.headers.get('content-type'), 'ms', Date.now() - t0);
  const txt = await r.text();
  console.log('len', txt.length);
  console.log(txt.slice(0, 600));
} catch (e) { console.log('ERR', String(e && e.message), 'ms', Date.now() - t0); }