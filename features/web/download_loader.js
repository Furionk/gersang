/* Small, verified static downloads keep a dropped large response out of Godot's preloader. */
(function (root) {
  'use strict';
  const hex = bytes => Array.from(bytes, n => n.toString(16).padStart(2, '0')).join('');
  async function sha256(bytes) {
    return hex(new Uint8Array(await root.crypto.subtle.digest('SHA-256', bytes)));
  }
  // Only verified content is persisted. This cache never touches Godot saves.
  class HashCache {
    constructor(storage, manifestURL) {
      this.storage = storage;
      const base = new URL(manifestURL);
      base.pathname = base.pathname.split('/downloads/')[0] + '/';
      base.search = ''; base.hash = '';
      this.base = base.href;
      this.opened = null;
    }
    key(hash) { return new URL('__verified_chunks__/' + hash, this.base).href; }
    async open() {
      if (!this.storage) return null;
      if (!this.opened) this.opened = this.storage.open('gersang-chunks-v1:' + this.base).catch(() => null);
      return this.opened;
    }
    async read(part) {
      try {
        const cache = await this.open();
        if (!cache) return null;
        const response = await cache.match(this.key(part.sha256));
        if (!response) return null;
        const bytes = await response.arrayBuffer();
        if (bytes.byteLength === part.bytes && await sha256(bytes) === part.sha256) return bytes;
        await cache.delete(this.key(part.sha256));
      } catch (_) { /* Storage restrictions must not prevent play. */ }
      return null;
    }
    async write(part, bytes) {
      try {
        const cache = await this.open();
        if (cache) await cache.put(this.key(part.sha256), new Response(bytes, {headers: {'Content-Type': 'application/octet-stream'}}));
      } catch (_) { /* Includes quota exhaustion: downloaded bytes still work. */ }
    }
    async retain(hashes) {
      try {
        const cache = await this.open();
        if (!cache) return;
        const keep = new Set(Array.from(hashes, hash => this.key(hash)));
        for (const request of await cache.keys()) if (!keep.has(request.url)) await cache.delete(request);
      } catch (_) { /* Cleanup is optional; no other site cache is touched. */ }
    }
  }
  class Download {
    constructor({fetcher = root.fetch.bind(root), attempts = 4, timeout = 30000,
                 delay = ms => new Promise(resolve => setTimeout(resolve, ms)), onProgress = () => {}, onRetry = () => {}, cacheStorage = root.caches} = {}) {
      Object.assign(this, {fetcher, attempts, timeout, delay, onProgress, onRetry});
      this.cacheStorage = cacheStorage;
      this.cachedBytes = 0;
      this.networkBytes = 0;
      this.parts = new Map();
      this.files = new Map();
      this.completed = 0;
      this.total = 0;
    }
    async request(url, descriptor) {
      let last;
      for (let attempt = 1; attempt <= this.attempts; attempt++) {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), this.timeout);
        try {
          const response = await this.fetcher(url, {signal: controller.signal, cache: 'no-cache'});
          if (!response.ok) throw new Error('HTTP ' + response.status);
          const bytes = await response.arrayBuffer();
          if (descriptor && (bytes.byteLength !== descriptor.bytes || await sha256(bytes) !== descriptor.sha256)) {
            throw new Error('下載資料不完整或版本不一致');
          }
          return bytes;
        } catch (error) {
          last = error;
          if (attempt < this.attempts) {
            this.onRetry(attempt, this.attempts, error);
            await this.delay(500 * 2 ** (attempt - 1));
          }
        } finally { clearTimeout(timer); }
      }
      throw new Error('下載中斷，請按重試繼續：' + last.message);
    }
    async load(manifestURL, expectedSizes) {
      const manifest = JSON.parse(new TextDecoder().decode(await this.request(manifestURL)));
      if (manifest.version !== 1 || !Array.isArray(manifest.files)) throw new Error('下載清單無效');
      const names = new Set();
      for (const file of manifest.files) {
        if (names.has(file.name) || !Object.hasOwn(expectedSizes, file.name) || file.bytes !== expectedSizes[file.name] ||
            !Array.isArray(file.parts) || !file.parts.length || !/^[a-f0-9]{64}$/.test(file.sha256) ||
            file.parts.reduce((sum, part) => sum + part.bytes, 0) !== file.bytes) throw new Error('下載清單與遊戲版本不符');
        names.add(file.name);
        for (const part of file.parts) {
          if (!Number.isSafeInteger(part.bytes) || part.bytes <= 0 || part.bytes > 4 * 1024 * 1024 ||
              !/^[a-f0-9]{64}$/.test(part.sha256) || !/^[a-zA-Z0-9_.-]+\.bin$/.test(part.name)) throw new Error('下載分段清單無效');
        }
      }
      if (names.size !== Object.keys(expectedSizes).length) throw new Error('下載清單缺少遊戲資料');
      const disk = new HashCache(this.cacheStorage, manifestURL);
      this.cachedBytes = 0; this.networkBytes = 0;
      this.total = manifest.files.reduce((sum, file) => sum + file.bytes, 0);
      this.completed = 0;
      this.onProgress(0, this.total);
      for (const file of manifest.files) {
        if (this.files.has(file.sha256)) {
          this.completed += file.bytes; this.onProgress(this.completed, this.total); continue;
        }
        const assembled = new Uint8Array(file.bytes);
        let next = 0;
        const offsets = []; let offset = 0;
        for (const part of file.parts) { offsets.push(offset); offset += part.bytes; }
        const worker = async () => {
          while (next < file.parts.length) {
            const index = next++; const part = file.parts[index];
            let bytes = this.parts.get(part.sha256);
            if (!bytes) {
              bytes = await disk.read(part);
              if (bytes) this.cachedBytes += part.bytes;
              else {
                bytes = await this.request(new URL(part.name, manifestURL).href, part);
                this.networkBytes += part.bytes;
                await disk.write(part, bytes);
              }
              this.parts.set(part.sha256, bytes);
            }
            assembled.set(new Uint8Array(bytes), offsets[index]);
            this.completed += part.bytes; this.onProgress(this.completed, this.total);
          }
        };
        // Settle every worker before allowing another attempt, so old downloads
        // cannot corrupt the next attempt's progress or publish a partial file.
        const workers = await Promise.allSettled([worker(), worker(), worker()]);
        const failure = workers.find(result => result.status === 'rejected');
        if (failure) throw failure.reason;
        if (await sha256(assembled) !== file.sha256) {
          for (const part of file.parts) this.parts.delete(part.sha256);
          throw new Error('遊戲資料完整性驗證失敗，請重試');
        }
        this.files.set(file.sha256, assembled.buffer);
        for (const part of file.parts) this.parts.delete(part.sha256);
      }
      await disk.retain(manifest.files.flatMap(file => file.parts.map(part => part.sha256)));
      return new Map(manifest.files.map(file => [file.name, this.files.get(file.sha256)]));
    }
    release() { this.parts.clear(); this.files.clear(); }
  }
  async function withAssets(assets, baseURL, initialize) {
    const original = root.fetch;
    const urls = new Map(Array.from(assets, ([name, bytes]) => [new URL(name, baseURL).href, bytes]));
    const wrapped = (input, options) => {
      const url = new URL(typeof input === 'string' || input instanceof URL ? input : input.url, baseURL).href;
      if (urls.has(url)) return Promise.resolve(new Response(urls.get(url), {headers: {'Content-Type': url.endsWith('.wasm') ? 'application/wasm' : 'application/octet-stream'}}));
      return original.call(root, input, options);
    };
    root.fetch = wrapped;
    try { return await initialize(); }
    finally { if (root.fetch === wrapped) root.fetch = original; }
  }
  const api = {Download, withAssets, sha256};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.GersangDownload = api;
})(typeof window === 'undefined' ? globalThis : window);
