/* Isolated headless Edge/Chrome acceptance, never uses a user's browser profile. */
'use strict';
const fs=require('node:fs');const path=require('node:path');const {spawn}=require('node:child_process');
const assert=require('node:assert/strict');
const browser=process.argv[2],url=process.argv[3],dir=path.resolve(process.argv[4]);
if(!browser||!url||!dir)throw new Error('browser.test.js <browser.exe> <localhost URL> <evidence folder>');
if(!/^http:\/\/127\.0\.0\.1:\d+\/$/.test(url))throw new Error('Only a local isolated fixture is supported');
fs.mkdirSync(dir,{recursive:true});
const profile=path.join(dir,'browser-profile');fs.mkdirSync(profile,{recursive:true});
const child=spawn(browser,[...(process.env.WEB_EXPORT_HEADFUL?['--window-position=-3000,-3000']:['--headless=new']),'--disable-extensions','--no-first-run','--no-default-browser-check','--remote-debugging-port=0','--remote-debugging-address=127.0.0.1','--user-data-dir='+profile,'--enable-unsafe-swiftshader','--use-angle=swiftshader','about:blank'],{windowsHide:true,stdio:'ignore'});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));let socket;let seq=0;const pending=new Map();const logs=[];const errors=[];const requests=[];const networkFailures=[];const worklets=new Set();let phase="boot";
async function until(test,label,timeout=120000){const start=Date.now();while(Date.now()-start<timeout){const result=await test();if(result)return result;await sleep(200);}throw new Error('Timed out: '+label);}
function send(method,params={}){return new Promise((resolve,reject)=>{const id=++seq;const timer=setTimeout(()=>{pending.delete(id);reject(new Error('CDP timeout: '+method));},30000);pending.set(id,{resolve:value=>{clearTimeout(timer);resolve(value);},reject});socket.send(JSON.stringify({id,method,params}));});}
async function evaluate(expression,userGesture=false){const result=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true,userGesture});if(result.exceptionDetails)throw new Error(JSON.stringify(result.exceptionDetails));return result.result.value;}
(async()=>{
 const portFile=path.join(profile,'DevToolsActivePort');await until(()=>fs.existsSync(portFile),'browser start');const port=fs.readFileSync(portFile,'utf8').split('\n')[0];
 const pages=await(await fetch('http://127.0.0.1:'+port+'/json/list')).json();const page=pages.find(p=>p.type==='page');
 socket=new WebSocket(page.webSocketDebuggerUrl);await new Promise((resolve,reject)=>{socket.onopen=resolve;socket.onerror=reject;});
 socket.onmessage=event=>{const message=JSON.parse(event.data);if(message.id&&pending.has(message.id)){const p=pending.get(message.id);pending.delete(message.id);message.error?p.reject(new Error(message.error.message)):p.resolve(message.result);}else if(message.method==='Runtime.exceptionThrown')errors.push({phase,...message.params});else if(message.method==='Runtime.consoleAPICalled' && (logs.push(message.params.args.map(a=>a.value||'').join(' ')), /SCRIPT ERROR|ERROR:/.test(message.params.args.map(a=>a.value||'').join(' '))))errors.push({phase,...message.params});else if(message.method==='Network.requestWillBeSent'){requests.push(message.params.request.url);if(message.params.request.url.includes('.worklet.js'))worklets.add(message.params.requestId);}else if(message.method==='Network.loadingFinished')worklets.delete(message.params.requestId);else if(message.method==='Network.loadingFailed'){worklets.delete(message.params.requestId);networkFailures.push({phase,...message.params});}};
 await send('Runtime.enable');await send('Page.enable');await send('Network.enable');
 await send('Emulation.setDeviceMetricsOverride',{width:800,height:500,deviceScaleFactor:1,mobile:false});
 await send('Page.navigate',{url});await until(()=>evaluate("typeof document.getElementById('web-export-start')?.onclick === 'function'"),'shell');
 if(process.env.WEB_EXPORT_AUDIO_DIAG){const audio=await evaluate("(async()=>{const base=document.querySelector('script[src$=\"index.js\"]').src;const context=new AudioContext();try{await context.audioWorklet.addModule(base.replace('index.js','index.audio.position.worklet.js'));return {ok:true,state:context.state};}catch(error){return {ok:false,error:String(error),state:context.state};}finally{await context.close();}})()");fs.writeFileSync(path.join(dir,'audio-diagnostic.json'),JSON.stringify(audio));console.log('AUDIO_DIAGNOSTIC',audio);}
 await evaluate("for(const key of ['init','preloadFile','start']){const original=Engine.prototype[key];if(original)Engine.prototype[key]=function(...args){console.log('ENGINE_PHASE',key,'begin');return Promise.resolve(original.apply(this,args)).then(value=>{console.log('ENGINE_PHASE',key,'end');return value;});}}");
 await evaluate("document.getElementById('web-export-start').click()",true);
 await until(async()=>{const error=await evaluate("document.getElementById('web-export-start')?.disabled===false ? document.getElementById('web-export-status')?.textContent : ''");if(error)throw new Error(error);return evaluate("!document.getElementById('web-export-loading') && !!window.WebExport.lastStats");},'engine boot');
 const first=await evaluate('WebExport.lastStats');if(process.argv[5]!=="warm")assert.ok(first.network>0);
 await sleep(1500);
 await send('Input.dispatchMouseEvent',{type:'mousePressed',x:400,y:250,button:'left',clickCount:1});await send('Input.dispatchMouseEvent',{type:'mouseReleased',x:400,y:250,button:'left',clickCount:1});
 await sleep(2500);await until(()=>worklets.size===0,"audio worklets");await sleep(1000);
 const image=await send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(dir,'first-play.png'),Buffer.from(image.data,'base64'));
 const index=requests.length;
 phase='reload';await send('Page.reload',{ignoreCache:false});await until(()=>evaluate("typeof document.getElementById('web-export-start')?.onclick === 'function'"),'reload shell');await evaluate("document.getElementById('web-export-start').click()",true);
 await until(()=>evaluate("!document.getElementById('web-export-loading') && !!window.WebExport.lastStats"),'warm engine boot');
 const warm=await evaluate('WebExport.lastStats');assert.equal(warm.network,0);assert.equal(warm.cached,warm.total);
 const downloads=requests.slice(index).filter(u=>u.includes('/objects/'));assert.equal(downloads.length,0);
 await sleep(2500);await until(()=>worklets.size===0,'warm audio worklets');const warmImage=await send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(dir,'warm-play.png'),Buffer.from(warmImage.data,'base64'));
 assert.equal(errors.length,0,JSON.stringify(errors.map(e=>({phase:e.phase,message:e.args?.map(a=>a.value).join(' ')||e.exceptionDetails?.exception?.description}))));
 const report={browser,first,warm,warm_chunk_requests:downloads.length,exceptions:errors};fs.writeFileSync(path.join(dir,'result.json'),JSON.stringify(report,null,2));console.log('BROWSER_ACCEPTANCE_PASS '+JSON.stringify(report));
})().catch(error=>{fs.writeFileSync(path.join(dir,'failure.json'),JSON.stringify({error:String(error),errors,networkFailures,logs},null,2));console.error(error);process.exitCode=1;}).finally(()=>{socket?.close();child.kill();});
