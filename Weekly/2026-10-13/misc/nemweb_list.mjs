// List a NEMWEB report directory (ARCHIVE or CURRENT) with names, dates and sizes.
const url = process.argv[2];
const filter = process.argv[3] || '';
const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
if (!res.ok) { console.log('HTTP', res.status, res.statusText); process.exit(1); }
const html = await res.text();
const re = /<a href="([^"]+)">([^<]*)<\/a>([^<]*)/gi;
const rows = [];
let m;
while ((m = re.exec(html)) !== null) {
  const href = m[1];
  const text = (m[2] || '').trim();
  const tail = (m[3] || '').trim();
  if (!href || href.startsWith('?') || href === '../' || href.startsWith('/')) continue;
  rows.push({ href, text, tail });
}
console.log(`url ${url}`);
console.log(`anchors ${rows.length}`);
const shown = rows.filter(r => !filter || r.href.includes(filter) || r.text.includes(filter));
console.log(`matching "${filter}" ${shown.length}`);
for (const r of shown.slice(0, 400)) console.log(`  ${r.text.padEnd(60)} ${r.tail}`);
if (rows.length && rows.length <= 40) {
  console.log('--- all anchors ---');
  for (const r of rows) console.log(`  ${r.href}  |  ${r.text}  |  ${r.tail}`);
}
