// 对一批 URL 先直接抓正文，失败再走 r.jina.ai 代理，落 lit\_web\<slug>.txt 供检索。
import { writeFileSync, mkdirSync, readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const ROOT = 'C:/Ash/_research_20261013/lit';
const OUT = join(ROOT, '_web');
mkdirSync(OUT, { recursive: true });
const targets = JSON.parse(readFileSync(join(ROOT, '_web_targets.json'), 'utf8'));

for (const t of targets) {
  if (existsSync(join(OUT, `${t.slug}.txt`)) && !t.force) { console.log('skip', t.slug); continue; }
  let saved = null;
  for (const url of t.urls) {
    for (const prox of [false, true]) {
      const u = prox ? `https://r.jina.ai/${url}` : url;
      try {
        const r = await fetch(u, { headers: { 'User-Agent': 'Mozilla/5.0 (research; research@example.org)' } });
        const txt = await r.text();
        if (r.ok && txt.length > 3000) {
          writeFileSync(join(OUT, `${t.slug}.txt`), `# source: ${u}\n\n${txt}`, 'utf8');
          saved = { u, len: txt.length };
          break;
        }
      } catch (e) { /* 继续试下一个 */ }
    }
    if (saved) break;
  }
  console.log(saved ? `OK   ${t.slug} ${saved.len} chars <- ${saved.u}` : `FAIL ${t.slug}`);
  await new Promise(r => setTimeout(r, 300));
}
