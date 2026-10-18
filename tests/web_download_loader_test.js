'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
globalThis.crypto ||= require('node:crypto').webcrypto;
const {Download, withAssets, sha256} = require('../features/web/download_loader.js');
const url = 'https://example.test/gersang/downloads/test/manifest.json';
const ab = bytes => Uint8Array.from(bytes).buffer;
async function fixture() {
  const data = new Map(); const files = [];
  for (const name of ['index.wasm', 'index.pck']) {
    const bytes = ab([1, 2, name.length, 4, name === 'index.wasm' ? 5 : 7, 6]);
    const parts = [];
    for (let i = 0; i < 3; i++) {
      const part = bytes.slice(i * 2, i * 2 + 2);
      const partName = name + '.' + i + '.bin';
      data.set(new URL(partName, url).href, part);
      parts.push({name: partName, bytes: 2, sha256: await sha256(part)});
    }
    files.push({name, bytes: bytes.byteLength, sha256: await sha256(bytes), parts});
  }
  const manifest = {version: 1, files};
  data.set(url, new TextEncoder().encode(JSON.stringify(manifest)).buffer);
  return {data, manifest, expected: {'index.wasm': 6, 'index.pck': 6}};
}
async function run() {
  let passed = 0;
  const f = await fixture(); const counts = new Map();
  const corrupted = new URL('index.pck.1.bin', url).href;
  const interrupted = new URL('index.wasm.1.bin', url).href;
  const progress = [];
  const loader = new Download({attempts: 3, delay: async () => {}, onProgress: (n, total) => progress.push([n, total]),
    fetcher: async path => {
      const count = (counts.get(path) || 0) + 1; counts.set(path, count);
      if (path === interrupted && count === 1) return {ok: true, arrayBuffer: async () => {throw new TypeError('network error');}};
      if (path === corrupted && count === 1) return new Response(ab([99, 99]));
      return new Response(f.data.get(path));
    }});
  const assets = await loader.load(url, f.expected);
  assert.equal(counts.get(interrupted), 2); passed++;
  assert.equal(counts.get(corrupted), 2); passed++;
  for (const file of f.manifest.files) assert.equal(await sha256(assets.get(file.name)), file.sha256);
  passed++;
  assert.deepEqual(progress.at(-1), [12, 12]); passed++;
  // Exhaust retries, then explicitly retry without discarding verified segments.
  const retryCounts = new Map(); let online = false;
  const retryLoader = new Download({attempts: 2, delay: async () => {}, fetcher: async path => {
    retryCounts.set(path, (retryCounts.get(path) || 0) + 1);
    if (path === corrupted && !online) throw new Error('connection closed');
    return new Response(f.data.get(path));
  }});
  await assert.rejects(retryLoader.load(url, f.expected), /下載中斷/); passed++;
  const completedWasmRequests = retryCounts.get(interrupted);
  online = true; await retryLoader.load(url, f.expected);
  assert.equal(retryCounts.get(interrupted), completedWasmRequests); passed++;
  assert.equal(await sha256(retryLoader.files.get(f.manifest.files[1].sha256)), f.manifest.files[1].sha256); passed++;
  // A silent short response is a failure even when HTTP returns 200.
  const short = new Download({attempts: 1, fetcher: async () => new Response(ab([1]))});
  await assert.rejects(short.request('https://example.test/part.bin', {bytes: 2, sha256: '0'.repeat(64)}), /不完整/); passed++;
  const timed = new Download({attempts: 1, timeout: 10, fetcher: (path, {signal}) => new Promise((resolve, reject) => signal.addEventListener('abort', () => reject(new Error('timeout'))))});
  await assert.rejects(timed.request('https://example.test/part.bin'), /timeout/); passed++;
  await assert.rejects(loader.load(url, {'index.wasm': 7, 'index.pck': 6}), /版本不符/); passed++;
  const original = globalThis.fetch; let outside = 0;
  globalThis.fetch = async () => {outside++; return new Response('outside');};
  const networkFetch = globalThis.fetch;
  try {
    await withAssets(assets, 'https://example.test/gersang/', async () => {
      const wasm = await fetch('https://example.test/gersang/index.wasm');
      assert.equal(wasm.headers.get('content-type'), 'application/wasm');
      assert.equal(await sha256(await wasm.arrayBuffer()), f.manifest.files[0].sha256); passed++;
      assert.equal(await (await fetch('https://example.test/gersang/voice.ogg')).text(), 'outside');
      assert.equal(outside, 1); passed++;
    });
    assert.equal(globalThis.fetch, networkFetch); passed++;
    await assert.rejects(withAssets(assets, 'https://example.test/gersang/', async () => {throw new Error('boot failed');}), /boot failed/);
    assert.equal(globalThis.fetch, networkFetch); passed++;
  } finally { globalThis.fetch = original; }
  loader.release(); assert.equal(loader.parts.size + loader.files.size, 0); passed++;
  const shell = fs.readFileSync(require('node:path').join(__dirname, '../features/web/demo_shell.html'), 'utf8');
  assert.ok(shell.includes('Math.min(99,Math.floor(') && shell.includes('重試下載') && shell.includes("window.addEventListener('unhandledrejection'")); passed++;
  // Exercise the actual shell's failure/retry state and Engine API ordering.
  const vm = require('node:vm');
  const script = shell.split('<script>').at(-1).split('</script>')[0].replace('$GODOT_CONFIG', JSON.stringify({executable:'index', fileSizes:f.expected, args:[]}));
  function shellContext(mode) {
    const elements = Object.fromEntries(['start','status','progress','canvas','loading'].map(id => [id, {
      hidden:false, disabled:false, textContent:'', style:{}, setAttribute(){}, addEventListener(){}, appendChild(){}, removeAttribute(){}, focus(){}, remove(){this.removed=true;}
    }]));
    const events = {}; const calls = []; let loads = 0; let constructions = 0; let reloads = 0;
    const context = {URL, Map, Object, Promise, setTimeout, clearTimeout, console:{info(){},error(){}},
      location:{href:'https://example.test/gersang/',reload(){reloads++;}},
      document:{getElementById:id=>elements[id],createElement:()=>({style:{},setAttribute(){},addEventListener(){},appendChild(){}}),body:{appendChild(){}},addEventListener(){}},
      addEventListener(type,fn){events[type]=fn;}, removeEventListener(type){delete events[type];}
    };
    context.window=context;
    context.GersangDownload={Download:class {
      constructor(options){this.options=options; constructions++;}
      async load(){loads++; if(mode==='download' && loads===1)throw new Error('connection closed'); return assets;}
      release(){calls.push('release');}
    },withAssets:async (buffers,base,initialize)=>initialize()};
    context.Engine=class {
      static getMissingFeatures(){return [];}
      async init(){calls.push('init'); if(mode==='boot')return new Promise(()=>queueMicrotask(()=>events.unhandledrejection({type:'unhandledrejection',reason:new Error('WASM failed'),preventDefault(){}})));}
      async preloadFile(buffer,name){assert.equal(buffer,assets.get('index.pck'));assert.equal(name,'index.pck');calls.push('preload');}
      async start(config){assert.deepEqual(Array.from(config.args),['--main-pack','index.pck']);calls.push('start');}
    };
    vm.runInNewContext(script,context);
    return {elements,calls,context,get constructions(){return constructions;},get reloads(){return reloads;}};
  }
  const ui=shellContext('download');
  await ui.elements.start.onclick();
  assert.ok(ui.elements.status.textContent.includes('connection closed') && !ui.elements.start.disabled && !ui.elements.start.hidden && !ui.elements.loading.removed); passed++;
  await ui.elements.start.onclick();
  assert.equal(ui.constructions,1); assert.deepEqual(ui.calls,['init','preload','start','release']); assert.ok(ui.elements.loading.removed); passed++;
  const brokenBoot=shellContext('boot');
  await brokenBoot.elements.start.onclick();
  assert.equal(brokenBoot.elements.start.textContent,'重新啟動'); assert.ok(brokenBoot.elements.status.textContent.includes('WASM failed')); passed++;
  await brokenBoot.elements.start.onclick(); assert.equal(brokenBoot.reloads,1); passed++;
  console.log(`WEB_DOWNLOAD_RESULT passed=${passed} failed=0`);
}
run().catch(error => {console.error(error); process.exitCode = 1;});
