// Summarise several NEMWEB report directories: count, newest entries, naming pattern.
const dirs = process.argv.slice(2);
for (const d of dirs) {
  const url = `https://www.nemweb.com.au/Reports/CURRENT/${d}/`;
  try {
    const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
    if (!res.ok) { console.log(`\n### ${d}  -> HTTP ${res.status}`); continue; }
    const t = await res.text();
    const rows = [];
    const re = /<A HREF="([^"]+)">([^<]*)<\/A>/gi;
    let m;
    while ((m = re.exec(t)) !== null) rows.push(m[1]);
    const files = rows.filter(r => !r.endsWith('/'));
    console.log(`\n### ${d}   entries ${rows.length}  files ${files.length}`);
    console.log(`    newest: ${files.slice(-3).join('  ')}`);
    console.log(`    oldest: ${files.slice(0, 2).join('  ')}`);
    if (rows.length <= 12) for (const r of rows) console.log(`      ${r}`);
  } catch (e) {
    console.log(`\n### ${d}  -> ERROR ${e.message}`);
  }
}
