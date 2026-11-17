// Find the backend endpoints of the public AEMO dashboard app.
const PAGE = 'https://dashboards.public.aemo.com.au/price-and-demand?Elec_enabled=Yes&Gas_enabled=No&Elec_location=NSW,QLD,SA&Gas_location=TAS,VIC,WA';
const res = await fetch(PAGE, { headers: { 'User-Agent': 'Mozilla/5.0' } });
console.log('page status', res.status, res.headers.get('content-type'));
const html = await res.text();
console.log('html bytes', html.length);
const scripts = [...html.matchAll(/<script[^>]+src=["']([^"']+)["']/gi)].map(m => m[1]);
const links = [...html.matchAll(/<link[^>]+href=["']([^"']+)["']/gi)].map(m => m[1]);
console.log('scripts:', scripts.join('\n  '));
console.log('links:', links.slice(0, 10).join('\n  '));
console.log('--- inline hints ---');
for (const m of html.matchAll(/(api|json|service|endpoint|amazonaws|azure|powerbi|tableau)[^"'\s<>]{0,120}/gi)) {
  console.log('  ' + m[0]);
}
