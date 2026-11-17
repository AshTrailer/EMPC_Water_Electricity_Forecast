/**
 * Build the standalone model-number and symbol document.
 *
 * Takes section 2 and section 3 of the large reference report verbatim, so the
 * formulas and symbol definitions in it are the ones already checked against
 * the source code, and prepends a table that ties each model number to its
 * registry key and its display label.
 *
 *   node build_model_reference.mjs [--apply]
 */
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const root = "C:/Ash/Projects/EMPC_Water_Electricity_Forecast";
const week = join(root, "Weekly/2026-10-13");
const src = join(week, "HANDOVER_预测器整理与全跨度比较_20261013.md");
const registry = join(root, "Predicitor/Shared/model_registry.m");
const outPath = join(week, "预测器数学模型与符号_20261013.md");
const apply = process.argv.includes("--apply");

const fail = (m) => { process.stderr.write(m + "\n"); process.exit(1); };
if (!existsSync(src)) fail("missing " + src);
if (!existsSync(registry)) fail("missing " + registry);

/** Pull one registry row per model: key, display label, folder, model number. */
function readRegistry(text) {
   const re = /add\(reg,\s*"([^"]+)",\s*"([^"]+)",\s*"([^"]*)",\s*"([^"]+)"\)/g;
   const rows = [];
   for (const m of text.matchAll(re)) {
      rows.push({ key: m[1], label: m[2], folder: m[3], spec: m[4] });
   }
   if (rows.length === 0) fail("the registry has no add(...) rows");
   return rows;
}

/** Slice a top level section out of the report, headings included. */
function section(text, startHeading, stopHeading) {
   const a = text.indexOf(startHeading);
   if (a < 0) fail("section not found: " + startHeading);
   const b = text.indexOf(stopHeading, a);
   if (b < 0) fail("section end not found: " + stopHeading);
   return text.slice(a, b).replace(/\s+$/, "");
}

const reportText = readFileSync(src, "utf8").replace(/\r\n/g, "\n");
const rows = readRegistry(readFileSync(registry, "utf8"));

const sym = section(reportText, "## 2. 统一符号系统", "## 3. 每个预测器的数学模型");
let models = section(reportText, "## 3. 每个预测器的数学模型", "## 4. 跨度分层与各自的评价口径");

// Section 3 still ranks the AR order by a whole-atlas number. That row is a run
// fingerprint, not a ranking basis, so it is marked where it appears.
const at = models.indexOf("| **整图** |");
if (at >= 0) {
   const lineEnd = models.indexOf("\n", at);
   const carved = models.slice(0, at) + models.slice(lineEnd + 1);
   const note = "整图上从 p = 1 到 p = 48 的整图值见 `ar_sweep.mat`,**那一列只作运行指纹,不作判据**。\n";
   const anchor = "**整图上从 p = 1 的 46.83 单调变差到 p = 48 的 67.24,一路没有第二个极小值。**";
   const withNote = carved.replace(anchor, note + anchor);
   if (withNote === carved) fail("the AR order paragraph was not found");
   models = withNote;
}

const table = [
   "| 短号 | key | 显示名 | 代码目录 | 详细节 |",
   "|---|---|---|---|---|",
   ...rows.map((r) => `| ${r.spec} | \`${r.key}\` | ${r.label} | ${r.folder || "内联" } | ${r.spec} |`),
].join("\n");

const head = `# 预测器数学模型与符号 2026-10-13

这份是 \`HANDOVER_预测器整理与全跨度比较_20261013.md\` 第 2 节与第 3 节的独立抽出件,内容逐字相同。
单独抽出来是因为看 \`HANDOVER_预测器图证_20261013.md\` 与幻灯片时需要一处随手可查:**M8 是哪个模型,以及 T 到底是什么**。

## 0 短号、key 与显示名

三个名字说的是同一个模型,来源是 \`Predicitor/Shared/model_registry.m\`,那是图集列序的唯一权威。
图集第 m 列就是这张表的第 m 行。

${table}

写作时一律三者并列一次,之后只用短号。幻灯片上用短号加显示名。

## 1 统一符号系统

${sym}

## 2 每个预测器的数学模型

${models}
`;

if (!apply) {
   process.stdout.write(`will write ${outPath}\n${outPath} would hold ${head.split("\n").length} lines\n`);
   process.exit(0);
}
writeFileSync(outPath, head, "utf8");
process.stdout.write(`wrote ${outPath}, ${head.split("\n").length} lines, ${rows.length} models\n`);
