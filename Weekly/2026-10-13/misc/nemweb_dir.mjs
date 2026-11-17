// Print the raw <pre> listing of a NEMWEB directory, including file sizes.
const url = process.argv[2];
const tail = Number(process.argv[3] || 6);
const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
const t = await res.text();
const i = t.indexOf('<pre>'), j = t.indexOf('</pre>');
const body = t.slice(i + 5, j);
const lines = body.split(/<br>/).map(s => s.replace(/<[^>]+>/g, '').trim()).filter(Boolean);
console.log(`url ${url}`);
console.log(`entries ${lines.length}`);
console.log('--- first 3 ---');
for (const l of lines.slice(0, 3)) console.log('  ' + l);

// pick the largest files to see the packaging granularity
const parsed = lines.map(l => {
  const m = l.match(/^(.*?)\s{2,}([\d,]+)\s+(\S+)$/);
  return m ? { date: m[1], size: Number(m[2].replace(/,/g, '')), name: m[3] } : null;
}).filter(Boolean);
parsed.sort((a, b) => b.size - a.size);
console.log(`--- largest 5 of ${parsed.length} sized entries ---`);
for (const p of parsed.slice(0, 5)) console.log(`  ${(p.size / 1048576).toFixed(1)} MB  ${p.name}  (${p.date})`);
console.log('--- last 6 raw lines ---');
for (const l of lines.slice(-6)) console.log('  ' + l);
