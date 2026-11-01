import { cp, mkdir, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { dirname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const source = resolve(root, 'build/web');
const output = resolve(root, '.vercel/output');
// Restrict cleanup to this repository's generated output directory.
if (output !== resolve(root, `.vercel${sep}output`) ||
    dirname(output) !== resolve(root, '.vercel')) {
  throw new Error('Unsafe Vercel output path');
}
for (const file of ['index.html', 'flutter_bootstrap.js', 'main.dart.js']) {
  if (!(await stat(resolve(source, file))).isFile()) {
    throw new Error(`Missing Flutter build artifact: ${file}`);
  }
}
const index = await readFile(resolve(source, 'index.html'), 'utf8');
if (!index.includes('<base href="/">')) {
  throw new Error('This deployment requires flutter build web with base href /');
}
await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
await cp(source, resolve(output, 'static'), { recursive: true });
await writeFile(resolve(output, 'config.json'), JSON.stringify({
  version: 3,
  routes: [
    {
      src: '/(.*)',
      headers: {
        'Cache-Control': 'public, max-age=0, must-revalidate',
        'X-Content-Type-Options': 'nosniff',
      },
      continue: true,
    },
    { handle: 'filesystem' },
    // Missing assets must not return HTML, especially JS/Wasm/font requests.
    { src: '/(?:assets|canvaskit|icons)/.*', status: 404 },
    { src: '/.*\\.[^/]+$', status: 404 },
    { src: '/.*', dest: '/index.html' },
  ],
}, null, 2) + '\n');
console.log('Prepared .vercel/output from build/web (no Vercel rebuild).');
