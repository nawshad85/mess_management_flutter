import { readFile } from 'node:fs/promises';

const text = (await readFile(process.argv[2], 'utf8')).trim();
// Vercel can emit either a URL or structured output depending on CLI context.
let value = text;
if (text.startsWith('{')) {
  const result = JSON.parse(text);
  if (result.status !== 'ok' || result.deployment?.readyState !== 'READY') {
    throw new Error('Vercel did not report a ready deployment');
  }
  value = result.deployment.productionUrl ?? result.deployment.url;
}
const url = new URL(value);
if (url.protocol !== 'https:' || !url.hostname.endsWith('.vercel.app')) {
  throw new Error('Unexpected deployment URL');
}
console.log(url.href);
