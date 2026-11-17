// List the MMSDM monthly DATA directory and pull the table names that matter.
//
// The five minute dispatch tables live here one file per table per month. The
// exact file names are read from the index rather than constructed.

const DIR = "https://www.nemweb.com.au/Data_Archive/Wholesale_Electricity/MMSDM/2026/MMSDM_2026_09/MMSDM_Historical_Data_SQLLoader/DATA/";

const res = await fetch(DIR);
const html = await res.text();
const hrefs = [...html.matchAll(/href="([^"]+)"/gi)].map((m) => decodeURIComponent(m[1])).filter((h) => /\.zip$/i.test(h));
console.log(`status ${res.status}, ${hrefs.length} zips`);

const want = hrefs.filter((h) => /REGIONSUM|INTERCONNECTOR|UNIT_SCADA/i.test(h));
console.log(`--- ${want.length} matching REGIONSUM, INTERCONNECTOR or UNIT_SCADA ---`);
for (const h of want) console.log(`  ${h.split("/").pop()}`);

console.log("--- first 15 of all ---");
for (const h of hrefs.slice(0, 15)) console.log(`  ${h.split("/").pop()}`);
