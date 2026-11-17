const out = {}
const ec = [...document.querySelectorAll('*')].filter((e) => e.hasAttribute('_echarts_instance_')).map((e) => ({ id: e.getAttribute('_echarts_instance_'), cls: String(e.className).slice(0, 40), w: e.clientWidth, h: e.clientHeight, tag: e.tagName }))
out.echartsNodes = ec
out.hasEchartsGlobal = typeof window.echarts
const canvases = [...document.querySelectorAll('canvas')].map((c) => ({ w: c.width, h: c.height, cls: String(c.className).slice(0, 40), parentCls: String(c.parentElement?.className).slice(0, 60) }))
out.canvases = canvases
const nodes = [...document.querySelectorAll('*')].filter((e) => e.__vueParentComponent !== undefined)
out.vueNodes = nodes.length
const interesting = nodes.filter((e) => /chart|price|demand|graph|visual/i.test(String(e.className))).slice(0, 12).map((e) => {
   const c = e.__vueParentComponent
   const keys = []
   let n = c
   for (let i = 0; i < 6 && n !== null && n !== undefined; i += 1) {
      keys.push({ name: n.type?.__name ?? n.type?.name ?? String(n.type), setup: Object.keys(n.setupState ?? {}).slice(0, 30), props: Object.keys(n.props ?? {}).slice(0, 20), data: Object.keys(n.data ?? {}).slice(0, 20), ctx: Object.keys(n.ctx ?? {}).slice(0, 40) })
      n = n.parent
   }
   return { cls: String(e.className).slice(0, 50), chain: keys }
})
out.components = interesting
return out
