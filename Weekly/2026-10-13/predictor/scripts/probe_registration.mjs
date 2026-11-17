// Check whether the AEMO registration list is reachable and what it holds.
//
// The list is the small authoritative DUID to region mapping. It sits on the
// corporate site rather than NEMWEB, so reachability is the first question and
// the sheet layout is the second.

const urls = [
  "https://www.aemo.com.au/-/media/files/electricity/nem/participant_information/nem-registration-and-exemption-list.xlsx",
  "https://www.aemo.com.au/energy-systems/electricity/national-electricity-market-nem/participant-information/participant-registration",
];

for (const u of urls) {
  try {
    const r = await fetch(u);
    const buf = Buffer.from(await r.arrayBuffer());
    console.log(`\n${u}`);
    console.log(`  HTTP ${r.status}  ${r.headers.get("content-type")}  ${buf.length} bytes`);
    console.log(`  head ${buf.subarray(0, 8).toString("hex")}`);
    writeHead(buf);
  } catch (e) {
    console.log(`\n${u} FAILED ${e.message}`);
  }
}

function writeHead(buf) {
  // PK zip signature means xlsx, which is the case we want.
  if (buf.length > 4 && buf.readUInt32LE(0) === 0x04034b50) console.log("  looks like xlsx");
}
