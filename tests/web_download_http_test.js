'use strict';
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
globalThis.crypto ||= require('node:crypto').webcrypto;
const {Download, sha256, withAssets} = require('../features/web/download_loader.js');
(async () => {
  const output = path.resolve(process.argv[2]);
  const html = fs.readFileSync(path.join(output, 'index.html'), 'utf8');
  const relative = html.match(/downloads\/[a-f0-9]{16}\/manifest\.json/)[0];
  const manifest = JSON.parse(fs.readFileSync(path.join(output, relative), 'utf8'));
  let retries = 0; let maximum = 0;
  const downloader = new Download({onRetry: () => retries++, onProgress: (current, total) => {
    assert.ok(current <= total); maximum = Math.max(maximum, Math.min(99, Math.floor(current / total * 100)));
  }});
  const assets = await downloader.load('http://127.0.0.1:18764/gersang/' + relative,
    Object.fromEntries(manifest.files.map(file => [file.name, file.bytes])));
  for (const file of manifest.files) {
    assert.equal(await sha256(assets.get(file.name)), file.sha256);
    assert.equal(await sha256(fs.readFileSync(path.join(output, file.name))), file.sha256);
  }
  const engine = await WebAssembly.compile(assets.get('index.wasm'));
  assert.ok(WebAssembly.Module.exports(engine).length > 0);
  const original = globalThis.fetch;
  await withAssets(assets, 'http://127.0.0.1:18764/gersang/', async () => {
    assert.equal(await sha256(await (await fetch('http://127.0.0.1:18764/gersang/index.wasm')).arrayBuffer()), manifest.files[0].sha256);
  });
  assert.equal(globalThis.fetch, original);
  const diagnosis = await (await fetch('http://127.0.0.1:18764/diagnosis.json')).json();
  assert.equal(Object.values(diagnosis.faults).length, 2);
  for (const faultyPath of Object.keys(diagnosis.faults)) assert.equal(diagnosis.requests[faultyPath], 2);
  assert.equal(maximum, 99);
  assert.equal(retries, 2);
  const result = {passed: true, retries, maximumDownloadPercent: maximum, faults: diagnosis.faults,
    exactPackAndWasm: true, wasmCompiled: true, note: 'HTTP and WASM validation; browser gameplay acceptance unavailable after Computer Use stopped.'};
  fs.writeFileSync(path.join(output, '..', 'http-fault-results.json'), JSON.stringify(result, null, 2));
  console.log('WEB_HTTP_FAULT_RESULT ' + JSON.stringify(result));
})().catch(error => {console.error(error); process.exitCode = 1;});
