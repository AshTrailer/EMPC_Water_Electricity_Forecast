// Locate a contemporaneous DUID to region snapshot and the 60 offer files.
//
// Both listings are needed before anything is downloaded at scale: the archive
// MTPASA folder gives a region map dated inside the window, and the offer
// folder has to be matched against the 60 trading days the atlas covers.

const archive = "https://nemweb.com.au/Reports/ARCHIVE/MTPASA_DUIDAvailability/";
const current = "https://nemweb.com.au/Reports/CURRENT/Next_Day_Offer_Energy_SPARSE/";
const offerArchive = "https://nemweb.com.au/Reports/ARCHIVE/Next_Day_Offer_Energy_SPARSE/";

const want = process.argv.slice(2);

for (const url of [archive, current, offerArchive]) {
  const html = await (await fetch(url)).text();
  const zips = [...new Set((html.match(/[\w()\-]+\.zip/gi) || []))].sort();
  console.log(`\n=== ${url}  ${zips.length} zips`);
  if (zips.length === 0) continue;
  console.log(`  first ${zips[0]}`);
  console.log(`  last  ${zips[zips.length - 1]}`);
  // Report coverage of the requested days, if any were named.
  for (const day of want) {
    const hit = zips.filter((z) => z.includes(day));
    console.log(`  ${day}: ${hit.length} file(s)${hit.length ? "  " + hit[0] : ""}`);
  }
  if (url === archive) {
    const oct = zips.filter((z) => /202610/.test(z));
    console.log(`  202610 files: ${oct.length}`);
    for (const z of oct.slice(0, 6)) console.log(`    ${z}`);
  }
}
