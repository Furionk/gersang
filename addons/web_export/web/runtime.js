/* Web Export Studio v1. No application saves or unrelated caches are touched. */
(function (root) {
'use strict';
const hashPattern = /^[a-f0-9]{64}$/;
async function sha256(bytes) {
  return Array.from(new Uint8Array(await root.crypto.subtle.digest('SHA-256', bytes)), n=>n.toString(16).padStart(2,'0')).join('');
}
function storage() { try { return root.caches; } catch (_) { return null; } }
class ChunkCache {
  constructor({project, base, enabled=true, budget=536870912, store=storage(), locks=root.navigator?.locks}) {
    this.base=base; this.name='web-export-v1:'+project+':'+base;
    this.enabled=enabled; this.budget=budget; this.store=store; this.locks=locks;
    this.bytes=0; this.releaseLease=null; this.cache=null;
  }
  key(hash) { return new URL('__web_export_cache__/'+hash,this.base).href; }
  async begin(parts) {
    if (!this.enabled || !this.store) return;
    try {
      this.cache=await this.store.open(this.name);
      const wanted=new Set(parts.map(p=>this.key(p.sha256)));
      const entries=[]; let used=0; let present=0;
      for (const req of await this.cache.keys()) {
        const response=await this.cache.match(req); if(!response) continue;
        const bytes=Number(response.headers.get('x-web-export-bytes'))||0;
        entries.push({req,bytes,time:Number(response.headers.get('x-web-export-access'))||0});
        used+=bytes; if(wanted.has(req.url)) present+=bytes;
      }
      const unique=new Map(parts.map(p=>[p.sha256,p.bytes]));
      const needed=Array.from(unique.values()).reduce((a,b)=>a+b,0);
      // Without Web Locks, skip automatic eviction rather than race another page.
      if(this.locks) await this.locks.request(this.name+':active',{mode:'exclusive',ifAvailable:true},async lock=>{
        if(!lock) return;
        for(const entry of entries.sort((a,b)=>a.time-b.time)) {
          if(used+Math.max(0,needed-present)<=this.budget) break;
          if(!wanted.has(entry.req.url)) { await this.cache.delete(entry.req); used-=entry.bytes; }
        }
      });
      this.bytes=used;
      if(this.locks) await new Promise((resolve,reject)=>{
        this.locks.request(this.name+':active',{mode:'shared'},async()=>{
          const held=new Promise(done=>{this.releaseLease=done;}); resolve(); await held;
        }).catch(reject);
      });
    } catch (_) { this.cache=null; this.close(); }
  }
  async read(part) {
    if(!this.cache) return null;
    try {
      const response=await this.cache.match(this.key(part.sha256));
      if(!response) return null;
      const data=await response.arrayBuffer();
      if(data.byteLength===part.bytes && await sha256(data)===part.sha256) {
        try {const headers=new Headers(response.headers);headers.set('X-Web-Export-Access',String(Date.now()));await this.cache.put(this.key(part.sha256),new Response(data,{headers}));} catch (_) {}
        return data;
      }
      await this.cache.delete(this.key(part.sha256)); this.bytes=Math.max(0,this.bytes-part.bytes);
    } catch (_) {}
    return null;
  }
  async put(part,data) {
    if(!this.cache) return;
    const save=async()=>{
      if(await this.cache.match(this.key(part.sha256))) return;
      // Recount under the write lock because another tab may have added entries.
      let used=0;
      for(const req of await this.cache.keys()) {
        const value=await this.cache.match(req); used+=Number(value?.headers.get('x-web-export-bytes'))||0;
      }
      this.bytes=used;
      if(used+part.bytes>this.budget) return;
      await this.cache.put(this.key(part.sha256),new Response(data,{headers:{'Content-Type':'application/octet-stream','X-Web-Export-Bytes':String(part.bytes),'X-Web-Export-Access':String(Date.now())}}));
      this.bytes+=part.bytes;
    };
    try { if(this.locks) await this.locks.request(this.name+':write',save); else await save(); } catch (_) {}
  }
  close() { if(this.releaseLease) {this.releaseLease();this.releaseLease=null;} }
}
class Download {
  constructor({fetcher=root.fetch.bind(root), attempts=4, timeout=30000, parallel=3, delay=ms=>new Promise(r=>setTimeout(r,ms)), progress=()=>{}, cacheOptions={}}={}) {
    Object.assign(this,{fetcher,attempts,timeout,parallel,delay,progress,cacheOptions});
    this.pending=new Map(); this.cache=null; this.stats={network:0,cached:0,completed:0,total:0};
  }
  async request(url,part=null) {
    let last;
    for(let attempt=0;attempt<this.attempts;attempt++) {
      const controller=new AbortController(); const timer=setTimeout(()=>controller.abort(),this.timeout);
      try {
        const response=await this.fetcher(url,{signal:controller.signal,cache:part && attempt===0?'force-cache':'no-store'});
        if(!response.ok) throw new Error('HTTP '+response.status);
        if(part?.encoding==='gzip' && response.headers.get('content-encoding')?.toLowerCase()!=='gzip') throw new Error('Host must send Content-Encoding: gzip for '+part.url);
        const bytes=await response.arrayBuffer();
        if(part && (bytes.byteLength!==part.bytes || await sha256(bytes)!==part.sha256)) throw new Error('Size/SHA-256 mismatch: '+part.url);
        return bytes;
      } catch(error) { last=error; if(attempt+1<this.attempts) {this.progress('retry',this.stats,error.message);await this.delay(500*2**attempt);} }
      finally {clearTimeout(timer);}
    }
    throw new Error('Download failed. Retry is safe. '+last.message);
  }
  validate(manifest,project,expected) {
    if(manifest.schema!==1 || manifest.project!==project || !/^[a-f0-9]{24}$/.test(manifest.release) || !Array.isArray(manifest.files)) throw new Error('Invalid release manifest.');
    const names=new Set();
    for(const file of manifest.files) {
      if(names.has(file.name) || !Object.hasOwn(expected,file.name) || file.bytes!==expected[file.name] || !hashPattern.test(file.sha256) || !Array.isArray(file.parts) || !file.parts.length) throw new Error('Manifest/engine version mismatch.');
      names.add(file.name); let size=0;
      for(const part of file.parts) {
        if(!Number.isSafeInteger(part.bytes) || part.bytes<1 || part.bytes>4194304 || !hashPattern.test(part.sha256) || !['identity','gzip'].includes(part.encoding) || part.url!=='objects/'+part.sha256+(part.encoding==='gzip'?'.bin.gz':'.bin')) throw new Error('Invalid content-addressed chunk.');
        size+=part.bytes;
      }
      if(size!==file.bytes) throw new Error('Incomplete manifest.');
    }
    if(names.size!==Object.keys(expected).length) throw new Error('Missing engine files.');
  }
  async load(meta,expected,base) {
    this.close(); this.pending.clear();
    const manifest=JSON.parse(new TextDecoder().decode(await this.request(new URL(meta.manifest,base).href)));
    this.validate(manifest,meta.project,expected);
    this.stats={network:0,cached:0,completed:0,total:manifest.files.reduce((n,f)=>n+f.bytes,0)};
    this.cache=new ChunkCache({project:meta.project,base,enabled:meta.cache,budget:meta.cache_bytes,...this.cacheOptions});
    await this.cache.begin(manifest.files.flatMap(f=>f.parts));
    const assets=new Map();
    try {
      for(const file of manifest.files) {
        const assembled=new Uint8Array(file.bytes); const offsets=[]; let position=0; let next=0;
        for(const part of file.parts) {offsets.push(position);position+=part.bytes;}
        const worker=async()=>{
          while(next<file.parts.length) {
            const index=next++; const part=file.parts[index];
            let promise=this.pending.get(part.sha256);
            if(!promise) {
              promise=(async()=>{
                let bytes=await this.cache.read(part);
                if(bytes) {this.stats.cached+=part.bytes;this.progress('cache',this.stats);}
                else {bytes=await this.request(new URL(part.url,base).href,part);this.stats.network+=part.bytes;await this.cache.put(part,bytes);}
                return bytes;
              })();
              this.pending.set(part.sha256,promise);
            }
            try {assembled.set(new Uint8Array(await promise),offsets[index]);}
            finally {if(this.pending.get(part.sha256)===promise)this.pending.delete(part.sha256);}
            this.stats.completed+=part.bytes; this.progress('download',this.stats);
          }
        };
        const results=await Promise.allSettled(Array.from({length:Math.min(6,Math.max(1,this.parallel))},worker));
        const failure=results.find(r=>r.status==='rejected'); if(failure) throw failure.reason;
        this.progress('verify',this.stats);
        if(await sha256(assembled)!==file.sha256) throw new Error('Complete asset hash mismatch.');
        assets.set(file.name,assembled.buffer);
      }
      return assets;
    } catch(error) {this.close();throw error;}
  }
  close(){this.cache?.close();}
}
async function withAssets(assets,base,initialize) {
  const original=root.fetch;
  const urls=new Map(Array.from(assets,([name,bytes])=>[new URL(name,base).href,bytes]));
  const wrapped=(input,options)=>{
    const url=new URL(typeof input==='string'||input instanceof URL?input:input.url,base).href;
    if(urls.has(url))return Promise.resolve(new Response(urls.get(url),{headers:{'Content-Type':url.endsWith('.wasm')?'application/wasm':'application/octet-stream'}}));
    return original.call(root,input,options);
  };
  root.fetch=wrapped;
  try{return await initialize();}finally{if(root.fetch===wrapped)root.fetch=original;}
}
async function boot(config,meta) {
  const $=id=>root.document.getElementById(id);
  const base=new URL('./',root.location.href).href;
  const button=$('web-export-start'),status=$('web-export-status'),bar=$('web-export-progress');
  let failedBoot=false,loader;
  root.addEventListener('pagehide',()=>loader?.close());
  button.onclick=async()=>{
    if(failedBoot){root.location.reload();return;}
    button.disabled=true;bar.hidden=false;
    let timer,onError,starting=true;
    try {
      if(!root.crypto?.subtle)throw new Error('HTTPS or localhost is required.');
      const missing=root.Engine.getMissingFeatures({threads:false}); if(missing.length)throw new Error('Missing browser features: '+missing.join(', '));
      loader=new Download({parallel:meta.parallel,progress:(phase,stats,message)=>{
        bar.max=stats.total||1;bar.value=stats.completed;
        status.textContent=phase==='retry'?message:({cache:'Reading verified cache',verify:'Verifying',download:'Loading'}[phase]||phase)+' '+Math.min(99,Math.floor(stats.completed/(stats.total||1)*100))+'%';
      }});
      const expected=Object.fromEntries(Object.entries(config.fileSizes).filter(([name])=>/\.(pck|wasm)$/.test(name)));
      const assets=await loader.load(meta,expected,base);
      root.WebExport.lastStats={...loader.stats};
      status.textContent='Starting engine…';failedBoot=true;
      let rejectBoot,startupError;
      const failure=new Promise((_,reject)=>{rejectBoot=reject;});
      onError=event=>rejectBoot(new Error(event.message||event.reason?.message||'Engine startup failed'));
      root.addEventListener('error',onError);root.addEventListener('unhandledrejection',onError);
      timer=setTimeout(()=>rejectBoot(new Error('Engine startup timed out. Reload to retry.')),90000);
      const engineBase=new URL(meta.base,base).href;
      config.executable=new URL('index',engineBase).href;
      config.canvas=$('canvas');
      const previousPrintError=config.onPrintError;
      config.onPrintError=(...args)=>{
        if(previousPrintError)previousPrintError(...args);else root.console.error(...args);
        if(starting && /SCRIPT ERROR|ERROR:/.test(args.join(' '))){startupError=new Error(args.join(' '));rejectBoot(startupError);}
      };
      const engine=new root.Engine(config);
      await Promise.race([withAssets(assets,engineBase,()=>engine.init(config.executable)),failure]);
      const pack='index.pck'; await Promise.race([engine.preloadFile(assets.get(pack),pack),failure]);
      assets.clear();
      await Promise.race([engine.start({args:['--main-pack',pack,...(config.args||[])]}),failure]);
      if(startupError)throw startupError;
      $('web-export-loading').remove();
      const badge=$('web-export-info'); if(!meta.diagnostics)badge.remove(); else badge.textContent='Downloaded (decoded) '+(loader.stats.network/1048576).toFixed(1)+' MiB · Cache '+(loader.stats.cached/1048576).toFixed(1)+' MiB';
    } catch(error) {
      loader?.close();status.textContent=error.message;button.disabled=false;button.textContent=failedBoot?'Reload':'Retry';
    } finally {starting=false;clearTimeout(timer);if(onError){root.removeEventListener('error',onError);root.removeEventListener('unhandledrejection',onError);}}
  };
}
const api={Download,ChunkCache,sha256,withAssets,boot};
if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.WebExport=api;
})(typeof window==='undefined'?globalThis:window);
