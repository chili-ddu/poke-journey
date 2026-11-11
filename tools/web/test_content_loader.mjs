import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {gzipSync} from 'node:zlib';
import {webcrypto} from 'node:crypto';
import vm from 'node:vm';
const code = await readFile(new URL('./content_loader.js', import.meta.url), 'utf8');

async function fixture({offlineCache = false} = {}) {
    const entries = {};
    const bodies = {};
    for (const name of ['boot', 'engine', 'world', 'actors', 'pokemon-0252', 'pokemon-0253', 'pokemon-0254']) {
        const raw = new TextEncoder().encode(name);
        const bytes = gzipSync(raw);
        const sha = Buffer.from(await webcrypto.subtle.digest('SHA-256', bytes)).toString('hex');
        entries[name] = {url: `content/${name}-${sha.slice(0, 16)}.gz`, bytes: bytes.length, raw_bytes: raw.length, sha256: sha};
        bodies[new URL(entries[name].url, 'https://test/game/').href] = bytes;
    }
    const requests = [], copies = [], started = [];
    const store = new Map();
    let fail = '';
    const cache = {
        match: async url => store.get(url)?.clone(),
        put: async (url, response) => { store.set(url, response.clone()); },
        delete: async url => store.delete(url),
        keys: async () => [...store.keys()].map(url => ({url})),
    };
    const nodes = new Map();
    const document = {baseURI: 'https://test/game/', getElementById: id => nodes.get(id),
        createElement: () => ({style: {}, setAttribute() {}}), body: {appendChild: el => nodes.set(el.id, el)}};
    const sandbox = {window: {DecompressionStream, JOURNEY_CONTENT: {boot: entries.boot, engine: entries.engine,
        packs: {...entries}, species: {charmander: ['actors'], treecko: ['pokemon-0252', 'pokemon-0253', 'pokemon-0254']}}},
        caches: {open: async () => { if (offlineCache) throw Error('Unavailable'); return cache; }},
        document, console: {error() {}}, crypto: webcrypto, Blob, Response, DecompressionStream,
        Uint8Array, URL, AbortController, setTimeout, clearTimeout,
        fetch: async url => { requests.push(url); return new Response(bodies[url], {status: url.includes(fail) && fail ? 404 : 200}); }};
    vm.runInNewContext(code, sandbox);
    const loader = sandbox.window.journeyContent;
    const engine = {init: async () => { await loader.wasm(); },
        preloadFile: async (data, path) => copies.push([path, new TextDecoder().decode(data)]),
        copyToFS: (path, data) => copies.push([path, new TextDecoder().decode(data)]),
        start: async config => started.push(config.args)};
    async function prepare(species) {
        loader.begin(species);
        for (let i = 0; i < 200; i++) {
            const state = JSON.parse(loader.status());
            if (state.done) return state;
            await new Promise(resolve => setTimeout(resolve, 5));
        }
        throw Error('Preparation stalled');
    }
    await loader.start(engine, {executable: 'index'});
    return {loader, prepare, entries, bodies, store, requests, copies, started, nodes, fail: value => { fail = value; }};
}

test('title fetches only engine and boot; play mounts world before actors', async () => {
    const f = await fixture();
    assert.equal(f.requests.length, 2);
    assert.deepEqual(f.copies, [['index.pck', 'boot']]);
    assert.deepEqual(Array.from(f.started[0]), ['--main-pack', 'index.pck']);
    const state = await f.prepare('charmander');
    assert.equal(state.error, '');
    assert.deepEqual(state.paths, ['/journey-world.pck', '/journey-actors.pck']);
    assert.deepEqual(f.copies.slice(1).map(x => x[1]), ['world', 'actors']);
    await f.prepare('charmander');
    assert.equal(f.requests.length, 4, 'Mounted content must not be fetched twice');
});

test('an existing save also fetches its complete optional evolution family', async () => {
    const f = await fixture();
    const state = await f.prepare('treecko');
    assert.equal(state.error, '');
    assert.deepEqual(f.copies.slice(-3).map(x => x[1]), ['pokemon-0252', 'pokemon-0253', 'pokemon-0254']);
});

test('404 does not enter gameplay; retry keeps successful files and recovers', async () => {
    const f = await fixture();
    f.fail('actors-');
    assert.match((await f.prepare('charmander')).error, /404/);
    assert.equal(f.copies.length, 2, 'Only boot and world should exist');
    assert.equal(f.nodes.get('content-error').hidden, false);
    f.fail('');
    assert.equal((await f.prepare('charmander')).error, '');
    assert.equal(f.requests.filter(url => url.includes('world-')).length, 1);
    assert.equal(f.nodes.get('content-error').hidden, true);
});

test('corrupted cached content is discarded and fetched again', async () => {
    const f = await fixture();
    const url = new URL(f.entries.actors.url, 'https://test/game/').href;
    f.store.set(url, new Response('damaged'));
    assert.equal((await f.prepare('charmander')).error, '');
    assert.equal(f.requests.filter(request => request === url).length, 1);
});

test('cache unavailability still permits normal play', async () => {
    const f = await fixture({offlineCache: true});
    assert.equal((await f.prepare('charmander')).error, '');
});

test('a damaged network response is never copied to the engine', async () => {
    const f = await fixture();
    const url = new URL(f.entries.actors.url, 'https://test/game/').href;
    f.bodies[url] = Buffer.from('incomplete');
    assert.match((await f.prepare('charmander')).error, /damaged/);
    assert.equal(f.copies.length, 2);
});
