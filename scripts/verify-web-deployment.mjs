import assert from 'node:assert/strict';

const origin = new URL(process.argv[2]);
assert.equal(origin.protocol, 'https:');
for (const path of [
  '/', '/login', '/flutter_bootstrap.js', '/main.dart.js',
  '/manifest.json', '/assets/FontManifest.json',
  '/canvaskit/canvaskit.wasm', '/icons/Icon-192.png',
]) {
  const response = await fetch(new URL(path, origin), {
    signal: AbortSignal.timeout(30000),
  });
  assert.equal(response.status, 200, `${path}: HTTP ${response.status}`);
  const type = response.headers.get('content-type') ?? '';
  if (path === '/' || path === '/login') {
    assert.match(type, /text\/html/);
    assert.match(await response.text(), /flutter_bootstrap\.js/);
  } else {
    assert.doesNotMatch(type, /text\/html/, `${path} received the SPA fallback`);
    if (path.endsWith('.wasm')) assert.match(type, /application\/wasm/);
    await response.arrayBuffer();
  }
  console.log(`Verified ${path}`);
}
const missing = await fetch(new URL('/assets/missing-deployment-check.js', origin));
assert.equal(missing.status, 404, 'Missing static assets must return 404');
console.log('Production static files and direct-route fallback passed.');
