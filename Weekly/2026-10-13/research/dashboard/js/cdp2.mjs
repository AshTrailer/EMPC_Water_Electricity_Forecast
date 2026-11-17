#!/usr/bin/env node
/**
 * cdp2.mjs —— 帧感知的 CDP 求值器。cdp-eval.mjs 只能在顶层上下文求值，
 * 这个可以点名某个 iframe（含同进程跨域 iframe）的默认执行上下文。
 *
 *   node cdp2.mjs --port 9222 --frames
 *   node cdp2.mjs --port 9222 --target <正则> --frame <正则> --file <脚本.js>
 *   node cdp2.mjs --port 9222 --target <正则> --frame <正则> --expr "<js>"
 */

const args = process.argv.slice(2)
const value = (name, fallback) => {
   const i = args.indexOf(name)
   return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback
}

const port = Number(value('--port', '9222'))
const target_re = value('--target', '')
const frame_re = value('--frame', '')
const list_frames = args.includes('--frames')
const expr = value('--expr', undefined)
const file = value('--file', undefined)

const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()
const pages = list.filter((row) => row.type === 'page')
if (pages.length === 0) {
   console.error('没有 page target')
   process.exit(2)
}
let page = pages.find((row) => new RegExp(target_re || '.', 'i').test(`${row.title} ${row.url}`))
if (page === undefined) {
   console.error(`没有匹配 --target ${target_re} 的页面。现有：`)
   for (const row of pages) console.error(`  ${row.title}  ${row.url}`)
   process.exit(2)
}
console.log(`# target: ${page.title}  ${page.url}`)

const socket = new WebSocket(page.webSocketDebuggerUrl)
let next_id = 1
const pending = new Map()
const contexts = []
socket.addEventListener('message', (event) => {
   let message
   try {
      message = JSON.parse(event.data)
   } catch {
      return
   }
   if (message.method === 'Runtime.executionContextCreated') contexts.push(message.params.context)
   if (message.id === undefined) return
   const entry = pending.get(message.id)
   if (entry === undefined) return
   pending.delete(message.id)
   if (message.error !== undefined) entry.reject(new Error(JSON.stringify(message.error)))
   else entry.resolve(message.result)
})
function send(method, params = {}) {
   const id = next_id
   next_id += 1
   return new Promise((resolve, reject) => {
      pending.set(id, { resolve, reject })
      socket.send(JSON.stringify({ id, method, params }))
   })
}
await new Promise((resolve, reject) => {
   socket.addEventListener('open', resolve, { once: true })
   socket.addEventListener('error', () => reject(new Error('WebSocket 连接失败')), { once: true })
})

await send('Runtime.enable')
await send('Page.enable')
await new Promise((r) => setTimeout(r, 400))

const tree = await send('Page.getFrameTree')
const flat = []
function walk(node, depth) {
   flat.push({ frame: node.frame, depth, childCount: (node.childFrames ?? []).length })
   for (const child of node.childFrames ?? []) walk(child, depth + 1)
}
walk(tree.frameTree, 0)

if (list_frames) {
   for (const row of flat) {
      const ctx = contexts.find((c) => c.auxData?.frameId === row.frame.id && c.auxData?.isDefault)
      console.log(`${'  '.repeat(row.depth)}${row.frame.url || '(空)'}\n${'  '.repeat(row.depth)}  frameId=${row.frame.id} ctxId=${ctx?.id ?? '无'} name=${row.frame.name || '-'}`)
   }
   socket.close()
   process.exit(0)
}

const wanted = flat.find((row) => new RegExp(frame_re || '.', 'i').test(row.frame.url))
if (wanted === undefined) {
   console.error(`没有匹配 --frame ${frame_re} 的帧`)
   socket.close()
   process.exit(2)
}
console.log(`# frame: ${wanted.frame.url}`)
let ctx = contexts.find((c) => c.auxData?.frameId === wanted.frame.id && c.auxData?.isDefault)
if (ctx === undefined) {
   // 跨域 iframe 有时要先在帧上建一个隔离世界才会出上下文；再等一轮。
   await new Promise((r) => setTimeout(r, 800))
   ctx = contexts.find((c) => c.auxData?.frameId === wanted.frame.id && c.auxData?.isDefault)
}
if (ctx === undefined) {
   console.error('# 该帧没有默认执行上下文，退回隔离世界')
   const world = await send('Page.createIsolatedWorld', { frameId: wanted.frame.id, grantUniveralAccess: true })
   ctx = { id: world.executionContextId, isolated: true }
}
console.log(`# contextId: ${ctx.id}${ctx.isolated ? '（隔离世界）' : ''}`)

const code = file !== undefined ? (await import('node:fs')).readFileSync(file, 'utf8') : expr
if (code === undefined) {
   console.error('要给 --expr 或 --file')
   socket.close()
   process.exit(2)
}
const single = !code.includes('\n') && !/\breturn\b/.test(code)
const wrapped = `(async () => { ${single ? `return (${code})` : code}\n })()`
const result = await send('Runtime.evaluate', {
   expression: wrapped,
   contextId: ctx.id,
   returnByValue: true,
   awaitPromise: true,
   userGesture: true,
})
if (result.exceptionDetails !== undefined) {
   console.error('页面里抛错：')
   console.error(JSON.stringify(result.exceptionDetails, null, 1).slice(0, 2000))
   socket.close()
   process.exit(1)
}
const out = result.result?.value
console.log(typeof out === 'string' ? out : JSON.stringify(out, null, 1))
socket.close()
