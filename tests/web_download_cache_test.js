 'use strict';
const assert = require('node:assert/strict');
globalThis.crypto ||= require('node:crypto').webcrypto;
const {Download, sha256} = require('../features/web/download_loader.js');
const base = 'https://example.test/gersang/downloads/one/manifest.json';
class Storage {
  constructor() { this.caches = new Map(); this.failWrites = false; }
  async open(name) {
    if (!this.caches.has(name)) this.caches.set(name, new Map());
    const entries = this.caches.get(name); const storage = this;
    return {
      async match(key) { return entries.get(key)?.clone(); },
      async put(key, value) { if (storage.failWrites) throw new Error('QuotaExceededError'); entries.set(key, value.clone()); },
      async delete(key) { return entries.delete(typeof key === 'string' ? key : key.url); },
      async keys() { return Array.from(entries.keys(), url => ({url})); }
    };
  }
}
async function fixture(changed = false, manifestURL = base) {
  const files = []; const data = new Map();
  for (const [index, name] of ['index.wasm','index.pck'].entries()) {
    const bytes = Uint8Array.from([index+1,11, index+2,22, index+3,changed && index===1 ? 99 : 33]);
    const parts = [];
    for (let n=0;n<3;n++) {
      const part = bytes.slice(n*2,n*2+2); const partName = name+'.'+n+'.bin';
      parts.push({name:partName,bytes:2,sha256:await sha256(part)});
      data.set(new URL(partName,manifestURL).href,part);
    }
    files.push({name,bytes:6,sha256:await sha256(bytes),parts});
  }
  data.set(manifestURL,JSON.stringify({version:1,files}));
  return {files,data,manifestURL};
}
(async () => {
  let passed=0;
  const f=await fixture(); const storage=new Storage();
  async function visit(fixture, cacheStorage=storage) {
    const counts={manifest:0,chunks:0};
    const loader=new Download({cacheStorage,fetcher:async url => {
      if (url===fixture.manifestURL) counts.manifest++; else counts.chunks++;
      assert.ok(fixture.data.has(url)); return new Response(fixture.data.get(url));
    }});
    const assets=await loader.load(fixture.manifestURL,{'index.wasm':6,'index.pck':6});
    for(const file of fixture.files) assert.equal(await sha256(assets.get(file.name)),file.sha256);
    loader.release(); return {counts,loader};
  }
  assert.equal((await visit(f)).counts.chunks,6); passed++;
  const again=await visit(f);
  assert.deepEqual(again.counts,{manifest:1,chunks:0}); assert.equal(again.loader.cachedBytes,12); passed++;
  const next=await fixture(true,base.replace('/one/','/two/'));
  assert.equal((await visit(next)).counts.chunks,1); passed++;
  assert.equal((await visit(next)).counts.chunks,0); passed++;
  const entries=storage.caches.values().next().value;
  assert.equal(entries.size,6); passed++; // Superseded chunk pruned only after complete success.
  const badKey=Array.from(entries.keys()).find(key => key.endsWith(next.files[1].parts[2].sha256));
  entries.set(badKey,new Response(Uint8Array.from([0,0])));
  assert.equal((await visit(next)).counts.chunks,1); passed++;
  entries.set(badKey,new Response(Uint8Array.from([0])));
  assert.equal((await visit(next)).counts.chunks,1); passed++;
  assert.equal((await visit(next,null)).counts.chunks,6); passed++;
  assert.equal((await visit(next,{open:async()=>{throw new Error('SecurityError');}})).counts.chunks,6); passed++;
  const quota=new Storage(); quota.failWrites=true;
  assert.equal((await visit(next,quota)).counts.chunks,6); passed++;
  const unrelated=await storage.open('other-app'); await unrelated.put('https://example.test/save',new Response('keep'));
  await visit(next); assert.equal(await (await unrelated.match('https://example.test/save')).text(),'keep'); passed++;
  // A failed release keeps previous complete cached assets and never stores corrupt network bytes.
  const failed=new Download({cacheStorage:storage,attempts:1,fetcher:async url => new Response(url===base ? f.data.get(base) : Uint8Array.from([0]))});
  await assert.rejects(failed.load(base,{'index.wasm':6,'index.pck':6}),/下載中斷/);
  assert.equal((await visit(next)).counts.chunks,0); passed++;
  console.log('WEB_CACHE_RESULT passed='+passed+' failed=0');
})().catch(error=>{console.error(error);process.exitCode=1;});
