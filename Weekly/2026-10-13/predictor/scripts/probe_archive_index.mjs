// List the two archive indexes E09 needs: the weekly predispatch packs and the
// monthly SQLLoader data directory.
//
// Prints every link whose name looks like a week pack or a table, so the exact
// file names are read rather than guessed.

const URLS = [
  ["predispatch-archive", "https://www.nemweb.com.au/Reports/ARCHIVE/Predispatch_Reports/"],
  ["mmsdm-sqlloader", "https://www.nemweb.com.au/Data_Archive/Wholesale_Electricity/MMSDM/2026/MMSDM_2026_09/MMSDM_Historical_Data_SQLLoader/"],
];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

for (const [label, url] of URLS) {
  try {
    const res = await fetch(url);
    const html = await res.text();
    const hrefs = [...html.matchAll(/href="([^"]+)"/gi)].map((m) => m[1]);
    console.log(`\n=== ${label} ${res.status} links ${hrefs.length} ===`);
    const want = hrefs.filter((h) => /PREDISPATCH|SQLLoader|DATA/i.test(h));
    for (const h of (want.length ? want : hrefs).slice(0, 60)) console.log(`  ${h}`);
    if (/PREDISPATCH/.test(want.join(" "))) {
      const names = want.map((h) => (h.split("/").pop() || "")).filter((n) => n);
      names.sort();
      console.log(`  --- ${names.length} pack names, last 12 ---`);
      for (const n of names.slice(-12)) console.log(`  ${n}`);
    }
  } catch (e) {
    console.log(`\n=== ${label} ERR ${e.message}`);
  }
  await sleep(900);
}
