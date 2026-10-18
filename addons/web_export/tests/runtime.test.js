 'use strict';
const assert=require('node:assert/strict');
globalThis.crypto ||= require('node:crypto').webcrypto;
const {Download,sha256,withAssets,boot}=require('../web/runtime.js');
const base='https://example.test/games/test/';
const meta={project:'a'.repeat(32),manifest:'releases/'+ '1'.repeat(24)+'/manifest.json',base:'releases/'+ '1'.repeat(24)+'/',cache:true,cache_bytes:128};
class Storage {
 constructor(){this.maps=new Map();this.fail=false;}
 async open(name){if(!this.maps.has(name))this.maps.set(name,new Map());const m=this.maps.get(name),owner=this;return {
 async keys(){return [...m.keys()].map(url=>({url}));},
 async match(k){return m.get(typeof k==='string'?k:k.url)?.clone();},
 async put(k,v){if(owner.fail)throw new Error('QuotaExceeded');m.set(k,v.clone());},
 async delete(k){return m.delete(typeof k==='string'?k:k.url);}
 };}
}
class Locks {
 constructor(){this.held=new Map();}
 async request(name,options,callback){if(typeof options==='function'){callback=options;options={};}
 const count=this.held.get(name)||0;
 if(options.mode!=='shared'&&count>0){if(options.ifAvailable)return callback(null);throw new Error('test lock contention');}
 this.held.set(name,count+1);
 try{return await callback({name});}finally{this.held.set(name,(this.held.get(name)||1)-1);}}
}
async function fixture(changed=false){const data=new Map();const files=[];
 for(const [i,name] of ['index.wasm','index.pck'].entries()){
 const bytes=Uint8Array.from([i+1,11,i+2,22,i+3,changed&&i===1?99:33]);const parts=[];
 for(let n=0;n<3;n++){const part=bytes.slice(n*2,n*2+2);const hash=await sha256(part);const url='objects/'+hash+'.bin';parts.push({url,bytes:2,sha256:hash,encoding:'identity',wire_bytes:2});data.set(new URL(url,base).href,part);}
 files.push({name,bytes:6,sha256:await sha256(bytes),parts});}
 data.set(new URL(meta.manifest,base).href,JSON.stringify({schema:1,project:meta.project,release:'1'.repeat(24),files}));return {files,data};}
(async()=>{let passed=0;const f=await fixture();const store=new Storage();const locks=new Locks();
 async function visit(fix,options={},metadata=meta){let chunks=0,manifests=0;const dl=new Download({delay:async()=>{},cacheOptions:{store,locks,...options},fetcher:async url=>{url.endsWith('manifest.json')?manifests++:chunks++;return new Response(fix.data.get(url));}});const assets=await dl.load(metadata,{'index.wasm':6,'index.pck':6},base);for(const file of fix.files)assert.equal(await sha256(assets.get(file.name)),file.sha256);dl.close();return {dl,chunks,manifests};}
 assert.equal((await visit(f)).chunks,6);passed++;
 const second=await visit(f);assert.equal(second.chunks,0);assert.equal(second.manifests,1);assert.equal(second.dl.stats.cached,12);passed++;
 const next=await fixture(true);assert.equal((await visit(next)).chunks,1);passed++;
 const cache=await store.open([...store.maps.keys()][0]);const key=new URL('__web_export_cache__/'+next.files[1].parts[2].sha256,base).href;
 await cache.put(key,new Response(Uint8Array.from([0,0]),{headers:{'X-Web-Export-Bytes':'2'}}));assert.equal((await visit(next)).chunks,1);passed++;
 assert.equal((await visit(f,{store:null})).chunks,6);passed++;
 assert.equal((await visit(f,{store:{open:async()=>{throw new Error('SecurityError');}}})).chunks,6);passed++;
 const quota=new Storage();quota.fail=true;assert.equal((await visit(f,{store:quota})).chunks,6);passed++;
 const small=new Storage();await visit(f,{store:small}, {...meta,cache_bytes:4});let bytes=0;for(const value of small.maps.values().next().value.values())bytes+=Number(value.headers.get('x-web-export-bytes'));assert.ok(bytes<=4);passed++;
 const disabled=new Storage();assert.equal((await visit(f,{store:disabled},{...meta,cache:false})).chunks,6);assert.equal(disabled.maps.size,0);passed++;
 const bad=new Download({cacheOptions:{store:null},attempts:2,delay:async()=>{},fetcher:async()=>new Response('bad')});await assert.rejects(bad.request('https://example.test/x',f.files[0].parts[0]),/SHA-256/);passed++;
 const missing=new Download({attempts:1,fetcher:async()=>new Response('',{status:404})});await assert.rejects(missing.request(base),/404/);passed++;
 const timeout=new Download({attempts:1,timeout:5,fetcher:(_,o)=>new Promise((resolve,reject)=>o.signal.addEventListener('abort',()=>reject(new Error('timeout'))))});await assert.rejects(timeout.request(base),/timeout/);passed++;
 await assert.rejects(bad.request(base,{...f.files[0].parts[0],encoding:'gzip'}),/Content-Encoding/);passed++;
 const manifest=JSON.parse(f.data.get(new URL(meta.manifest,base).href));const validator=new Download();const expected={'index.wasm':6,'index.pck':6};
 assert.throws(()=>validator.validate({...manifest,project:'b'.repeat(32)},meta.project,expected));passed++;
 const malicious=structuredClone(manifest);malicious.files[0].parts[0].url='../save';assert.throws(()=>validator.validate(malicious,meta.project,expected));passed++;
 assert.throws(()=>validator.validate(manifest,meta.project,{'index.wasm':7,'index.pck':6}));passed++;
 let calls=0;const flaky=new Download({attempts:2,delay:async()=>{},fetcher:async()=>{calls++;if(calls===1)return {ok:true,headers:new Headers(),arrayBuffer:async()=>{throw new Error('truncated');}};return new Response(f.data.get(new URL(f.files[0].parts[0].url,base).href));}});await flaky.request(base,f.files[0].parts[0]);assert.equal(calls,2);passed++;
 const original=globalThis.fetch;try{globalThis.fetch=async()=>new Response('outside');const upstream=globalThis.fetch;await withAssets(new Map([['index.wasm',new Uint8Array([1]).buffer]]),base,async()=>{assert.equal((await (await fetch(base+'index.wasm')).arrayBuffer()).byteLength,1);assert.equal(await(await fetch(base+'x')).text(),'outside');});assert.equal(globalThis.fetch,upstream);await assert.rejects(withAssets(new Map(),base,async()=>{throw new Error('boot');}));assert.equal(globalThis.fetch,upstream);passed++;}finally{globalThis.fetch=original;}
 // Another active page prevents eviction of its release.
 const shared=new Storage(),activeLocks=new Locks();const active=new Download({cacheOptions:{store:shared,locks:activeLocks},fetcher:async u=>new Response(f.data.get(u))});await active.load(meta,expected,base);
 await visit(next,{store:shared,locks:activeLocks},{...meta,cache_bytes:12});assert.equal(shared.maps.values().next().value.size,6);active.close();passed++;
 // An unrelated application's cache is never deleted.
 const other=await store.open('other-app');await other.put(base+'save',new Response('keep'));await visit(next);assert.equal(await(await other.match(base+'save')).text(),'keep');passed++;
 // Native script errors during start must leave a retryable error screen, not false success.
 const elements=new Map(['web-export-start','web-export-status','web-export-progress','canvas'].map(id=>[id,{remove(){throw new Error('must not hide failure');}}]));
 const prior={document:globalThis.document,location:globalThis.location,Engine:globalThis.Engine,WebExport:globalThis.WebExport,addEventListener:globalThis.addEventListener,removeEventListener:globalThis.removeEventListener,fetch:globalThis.fetch};
 try {
  globalThis.document={getElementById:id=>elements.get(id)};globalThis.location={href:base};globalThis.WebExport={};globalThis.addEventListener=()=>{};globalThis.removeEventListener=()=>{};
  globalThis.fetch=async u=>new Response(f.data.get(u));
  globalThis.Engine=class {static getMissingFeatures(){return [];}constructor(config){this.config=config;}async init(){}async preloadFile(){}async start(){this.config.onPrintError('SCRIPT ERROR: Missing startup class');}};
  await boot({fileSizes:expected,onPrintError:()=>{}},{...meta,cache:false});await elements.get('web-export-start').onclick();
  assert.match(elements.get('web-export-status').textContent,/Missing startup class/);assert.equal(elements.get('web-export-start').disabled,false);assert.equal(elements.get('web-export-start').textContent,'Reload');passed++;
 } finally {Object.assign(globalThis,prior);}
 console.log('WEB_EXPORT_RUNTIME_RESULT passed='+passed+' failed=0');
})().catch(e=>{console.error(e);process.exitCode=1;});
