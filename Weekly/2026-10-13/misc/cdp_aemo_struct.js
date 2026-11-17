// Inspect the AEMO dashboard page structure: iframes, canvases, svg charts, scripts.
const frames = [...document.querySelectorAll('iframe')].map(f => ({ src: f.src, id: f.id, cls: f.className, w: f.clientWidth, h: f.clientHeight }));
const canvases = [...document.querySelectorAll('canvas')].map(c => ({ id: c.id, cls: c.className, w: c.width, h: c.height }));
const svgs = document.querySelectorAll('svg').length;
const scripts = [...document.querySelectorAll('script[src]')].map(s => s.src);
const bodyText = (document.body.innerText || '').slice(0, 1200);
return JSON.stringify({ frames, canvases, svgs, scripts: scripts.slice(-25), bodyText }, null, 1);
