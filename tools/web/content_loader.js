/* Content-addressed downloads. No service worker and no changes to save storage. */
(() => {
    'use strict';
    const manifest = window.JOURNEY_CONTENT;
    const CACHE = 'poke-journey-content-v1';
    const ready = new Set();
    let runtime;
    let wasmResponse;
    let state = {done: false, error: '', message: '', paths: []};
    const progress = (value, total, text) => {
        const bar = document.getElementById('status-progress');
        if (bar) { bar.max = total || 1; bar.value = value; }
        state.message = text;
    };
    const digest = async bytes => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)),
        b => b.toString(16).padStart(2, '0')).join('');

    async function compressed(entry, label) {
        const url = new URL(entry.url, document.baseURI).href;
        let cache;
        try { cache = await caches.open(CACHE); } catch (_) { /* Private mode/quota: use HTTP. */ }
        let hit;
        try { hit = cache && await cache.match(url); } catch (_) { cache = null; }
        if (hit) {
            const bytes = await hit.arrayBuffer();
            if (bytes.byteLength === entry.bytes && await digest(bytes) === entry.sha256) return bytes;
            await cache.delete(url);
        }
        const controller = new AbortController();
        let timer;
        const heartbeat = () => {
            clearTimeout(timer);
            timer = setTimeout(() => controller.abort(), 120000);
        };
        heartbeat();
        let bytes;
        try {
            const response = await fetch(url, {signal: controller.signal});
            if (!response.ok) throw new Error(`Download failed (${response.status}): ${entry.url}`);
            const reader = response.body.getReader();
            const chunks = [];
            let received = 0;
            while (true) {
                const {done, value} = await reader.read();
                if (done) break;
                heartbeat();
                chunks.push(value);
                received += value.byteLength;
                progress(received, entry.bytes, `${label} ${Math.min(100, Math.floor(received * 100 / entry.bytes))}%`);
            }
            bytes = new Uint8Array(received);
            let offset = 0;
            for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
        } finally { clearTimeout(timer); }
        if (bytes.byteLength !== entry.bytes || await digest(bytes) !== entry.sha256) {
            throw new Error(`Incomplete or damaged content: ${entry.url}`);
        }
        if (cache) {
            try { await cache.put(url, new Response(bytes)); } catch (_) { /* Storage is optional. */ }
        }
        return bytes;
    }

    async function unpack(entry, label) {
        const bytes = await compressed(entry, label);
        state.message = `${label} 준비 중…`;
        const data = await new Response(new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'))).arrayBuffer();
        if (data.byteLength !== entry.raw_bytes) throw new Error(`Invalid unpacked content: ${entry.url}`);
        return data;
    }

    function failure(error) {
        console.error(error);
        state.error = String(error.message || error);
        state.done = true;
        let notice = document.getElementById('content-error');
        if (!notice) {
            notice = document.createElement('div');
            notice.id = 'content-error';
            notice.setAttribute('role', 'alert');
            Object.assign(notice.style, {position: 'fixed', top: '0', left: '0', right: '0', padding: '8px',
                background: '#5b3943', color: 'white', font: '12px/1.5 sans-serif', zIndex: '200'});
            document.body.appendChild(notice);
        }
        notice.textContent = '자료를 받지 못했습니다. 연결을 확인한 뒤 다시 시작해 주세요.';
        notice.hidden = false;
    }

    window.journeyContent = {
        // Used by the pinned Godot Web wrapper instead of its uncompressed WASM fetch.
        wasm: () => {
            wasmResponse ||= unpack(manifest.engine, '게임 엔진').then(data =>
                new Response(data, {headers: {'Content-Type': 'application/wasm'}}));
            return wasmResponse;
        },
        async start(engine, config) {
            if (!window.DecompressionStream) throw new Error('최신 버전의 브라우저에서 실행해 주세요.');
            runtime = engine;
            // Resolve download failures here; the engine init promise assumes a valid response.
            await window.journeyContent.wasm();
            await engine.init(config.executable);
            wasmResponse = null;
            await engine.preloadFile(await unpack(manifest.boot, '시작 화면'), 'index.pck');
            await engine.start({args: ['--main-pack', 'index.pck']});
        },
        begin(species) {
            const notice = document.getElementById('content-error');
            if (notice) notice.hidden = true;
            state = {done: false, error: '', message: '게임 자료 준비 중…', paths: []};
            (async () => {
                const family = manifest.species[species];
                if (!family) throw new Error(`Unknown saved species: ${species}`);
                const groups = [...new Set(['world', 'actors', ...family])];
                for (const name of groups) {
                    const path = `/journey-${name}.pck`;
                    if (!ready.has(name)) {
                        runtime.copyToFS(path, await unpack(manifest.packs[name], name === 'world' ? '맵과 음악' : '포켓몬'));
                        ready.add(name);
                    }
                    state.paths.push(path);
                }
                state.message = '';
                state.done = true;
                // Remove only obsolete files in our own content cache after a successful load.
                try {
                    const cache = await caches.open(CACHE);
                    const current = new Set([manifest.engine, manifest.boot, ...Object.values(manifest.packs)]
                        .map(entry => new URL(entry.url, document.baseURI).href));
                    const base = new URL('content/', document.baseURI).href;
                    for (const request of await cache.keys()) {
                        if (request.url.startsWith(base) && !current.has(request.url)) await cache.delete(request);
                    }
                } catch (_) { /* Cache availability must never prevent play. */ }
            })().catch(failure);
        },
        status: () => JSON.stringify(state),
    };
})();
