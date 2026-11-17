// 临时件：从 PyPI 取 matplotlib wheel 到工作区。任务结束删除。
import { writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const destDir = process.argv[2];
const packages = process.argv.slice(3);
mkdirSync(destDir, { recursive: true });

const tags = [
  "cp312-cp312-win_amd64",
  "py3-none-any",
  "cp312-abi3-win_amd64",
];

for (const pkg of packages) {
  const name = pkg.split("==")[0];
  const want = pkg.split("==")[1];
  const res = await fetch(`https://pypi.org/pypi/${name}/json`);
  if (!res.ok) { console.log(`FAIL meta ${name} ${res.status}`); continue; }
  const meta = await res.json();
  const version = want || meta.info.version;
  const files = meta.releases[version] || [];
  let pick = null;
  for (const tag of tags) {
    pick = files.find((f) => f.filename.endsWith(`${tag}.whl`));
    if (pick) break;
  }
  if (!pick) { console.log(`FAIL no wheel ${name} ${version}`); continue; }
  const buf = Buffer.from(await (await fetch(pick.url)).arrayBuffer());
  const out = join(destDir, pick.filename);
  writeFileSync(out, buf);
  console.log(`OK ${pick.filename} ${buf.length}`);
}
