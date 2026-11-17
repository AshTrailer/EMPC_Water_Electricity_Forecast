const out = {}
out.windowAm5 = typeof window.am5
out.am5Keys = Object.keys(window).filter((k) => /am5|amcharts/i.test(k))
const canvas = document.querySelector('canvas.am5-layer-0')
const chain = []
let n = canvas
for (let i = 0; i < 6 && n !== null; i += 1) {
   chain.push({ tag: n.tagName, cls: String(n.className).slice(0, 60), own: Object.getOwnPropertyNames(n).filter((k) => k.startsWith('__') || k.startsWith('_am') || k.startsWith('am')).slice(0, 20) })
   n = n.parentElement
}
out.chain = chain
const rootDiv = canvas.parentElement?.parentElement ?? canvas.parentElement
out.rootTag = rootDiv?.tagName
out.rootOwn = rootDiv === null || rootDiv === undefined ? [] : Object.getOwnPropertyNames(rootDiv).slice(0, 40)
return out
