/* Real HTTP failures and recovery under a nested deployment path. Node is test-only. */
'use strict';
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),zlib=require('node:zlib'),assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const browser=process.argv[2],output=path.resolve(process.argv[3]),evidence=path.resolve(process.argv[4]);
fs.mkdirSync(evidence,{recursive:true});const profile=path.join(evidence,'profile');fs.mkdirSync(profile,{recursive:true});
let mode='normal',wireRequests=0;let entryOverride=process.argv[5]?path.resolve(process.argv[5]):null;const prefix='/nested/game/';
const server=http.createServer((req,res)=>{
 let relative=decodeURIComponent(new URL(req.url,'http://localhost').pathname).slice(prefix.length)||'index.html';
 if(!req.url.startsWith(prefix)||relative.includes('..')){res.writeHead(404);res.end();return;}
 const file=path.join(output,relative);if(!fs.existsSync(file)){res.writeHead(404);res.end();return;}
 let bytes=fs.readFileSync(relative==='index.html'&&entryOverride?entryOverride:file);const object=relative.startsWith('objects/');if(object)wireRequests++;
 if(object&&mode==='404'){res.writeHead(404);res.end();return;}
 if(object&&mode==='corrupt'){bytes=relative.endsWith('.gz')?zlib.gunzipSync(bytes):bytes;bytes=Buffer.from(bytes);bytes[0]^=255;if(relative.endsWith('.gz'))bytes=zlib.gzipSync(bytes);}
 const headers={'Content-Type':relative.endsWith('.js')?'text/javascript':relative.endsWith('.html')?'text/html':relative.endsWith('.json')?'application/json':'application/octet-stream','Cache-Control':'no-store'};
 if(relative.endsWith('.gz')&&mode!=='gzip-header')headers['Content-Encoding']='gzip';
 headers['Content-Length']=bytes.length;
 res.writeHead(200,headers);
 if(object&&mode==='truncated'){res.end(bytes.subarray(0,Math.floor(bytes.length/2)));return;}
 res.end(bytes);
});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));let child,socket,seq=0;const pending=new Map(),results=[];
async function until(fn,label,timeout=120000){const start=Date.now();while(Date.now()-start<timeout){const value=await fn();if(value)return value;await sleep(100);}throw new Error('Timeout '+label);}
function send(method,params={}){return new Promise((resolve,reject)=>{const id=++seq;const timer=setTimeout(()=>reject(new Error('CDP timeout '+method)),30000);pending.set(id,{resolve:v=>{clearTimeout(timer);resolve(v);},reject});socket.send(JSON.stringify({id,method,params}));});}
async function evaluate(expression){const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const url='http://127.0.0.1:'+server.address().port+prefix;
 child=spawn(browser,['--headless=new','--remote-debugging-port=0','--remote-debugging-address=127.0.0.1','--user-data-dir='+profile,'--disable-extensions','--no-first-run','--no-default-browser-check','--enable-unsafe-swiftshader','--use-angle=swiftshader','about:blank'],{windowsHide:true,stdio:'ignore'});
 const portFile=path.join(profile,'DevToolsActivePort');await until(()=>fs.existsSync(portFile),'browser');const port=fs.readFileSync(portFile,'utf8').split('\n')[0];
 const pages=await(await fetch('http://127.0.0.1:'+port+'/json/list')).json();socket=new WebSocket(pages.find(p=>p.type==='page').webSocketDebuggerUrl);await new Promise((r,j)=>{socket.onopen=r;socket.onerror=j;});
 socket.onmessage=e=>{const m=JSON.parse(e.data);if(m.id&&pending.has(m.id)){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(new Error(m.error.message)):p.resolve(m.result);}};
 await send('Runtime.enable');await send('Page.enable');
 async function navigate(){await send('Page.navigate',{url});await until(()=>evaluate("typeof document.getElementById('web-export-start')?.onclick==='function'"),'shell');}
 async function clearCache(){await evaluate("caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('web-export')).map(k=>caches.delete(k))))");}
 async function start(){await evaluate("document.getElementById('web-export-start').click()");}
 async function playing(){await until(async()=>{const error=await evaluate("document.getElementById('web-export-start')?.disabled===false ? document.getElementById('web-export-status').textContent : ''");if(error)throw new Error(error);return evaluate("!document.getElementById('web-export-loading')");},'engine');}
 for(const fault of ['404','corrupt','gzip-header']){
  mode=fault;await navigate();await clearCache();await start();
  const message=await until(()=>evaluate("document.getElementById('web-export-start')?.disabled===false ? document.getElementById('web-export-status').textContent : ''"),'visible '+fault);
  assert.match(message,fault==='404'?/404/:fault==='corrupt'?/SHA-256/:/Content-Encoding/);
  mode='normal';await start();await playing();results.push({test:fault,message,retry:'passed'});
 }
 // The browser really rejects a truncated HTTP body, followed by a clean retry.
 mode='truncated';await navigate();await clearCache();await start();
 const truncation=await until(()=>evaluate("document.getElementById('web-export-start')?.disabled===false ? document.getElementById('web-export-status').textContent : ''"),'truncated body',180000);
 mode='normal';await start();await playing();results.push({test:'truncated',message:truncation,retry:'passed'});
 // Force CacheStorage unavailability in an actual browser; gameplay must still boot.
 await navigate();await clearCache();await evaluate("CacheStorage.prototype.open=async()=>{throw new DOMException('test quota','QuotaExceededError')}");await start();await playing();results.push({test:'storage-unavailable',result:'passed'});
 // Fresh page restores the browser API; warm launch must issue zero object requests.
 await navigate();await start();await playing();const first=await evaluate('WebExport.lastStats');
 await navigate();const before=wireRequests;await start();await playing();const warm=await evaluate('WebExport.lastStats');assert.equal(warm.network,0);assert.equal(wireRequests,before);
 results.push({test:'nested-path-and-warm-cache',first,warm,object_requests:wireRequests-before});
 if(entryOverride){
  entryOverride=null;await navigate();await start();await playing();const updated=await evaluate('WebExport.lastStats');assert.ok(updated.cached>0);assert.ok(updated.network>0&&updated.network<updated.total);results.push({test:'cross-version-content-reuse',updated});
 }
 await evaluate("(()=>{const frame=document.createElement('iframe');frame.id='parallel-game';frame.src=location.href;frame.style='position:fixed;bottom:0;right:0;width:320px;height:200px';document.body.appendChild(frame);})()");
 await until(()=>evaluate("typeof document.getElementById('parallel-game')?.contentDocument?.getElementById('web-export-start')?.onclick==='function'"),'second active page');
 await evaluate("document.getElementById('parallel-game').contentDocument.getElementById('web-export-start').click()");
 await until(()=>evaluate("!document.getElementById('parallel-game').contentDocument.getElementById('web-export-loading')"),'concurrent startup');
 const concurrent=await evaluate("document.getElementById('parallel-game').contentWindow.WebExport.lastStats");assert.equal(concurrent.network,0);results.push({test:'concurrent-active-pages',concurrent});
 fs.writeFileSync(path.join(evidence,'result.json'),JSON.stringify(results,null,2));console.log('BROWSER_HTTP_RECOVERY_PASS '+results.length);
})().catch(e=>{console.error(e);fs.writeFileSync(path.join(evidence,'failure.log'),String(e));process.exitCode=1;}).finally(()=>{socket?.close();child?.kill();server.closeAllConnections();server.close();});
