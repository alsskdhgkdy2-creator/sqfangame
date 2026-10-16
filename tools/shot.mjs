// 웹 빌드(build/web)를 내장 정적 서버로 띄우고 Chromium으로 캡처한다.
// 실행: flock /tmp/voxel-test-heavy.lock xvfb-run -a node tools/shot.mjs [출력.png] [너비x높이] [대기초]
// WebGL 조건은 ~/.config/device-rules/headless-webgl.md 를 따른다(Xvfb + ANGLE/GL).
import { chromium } from 'playwright-core';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const out = process.argv[2] ?? 'build/shot.png';
const [w, h] = (process.argv[3] ?? '1280x720').split('x').map(Number);
const waitSec = Number(process.argv[4] ?? 15);
const root = path.resolve('build/web');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream', '.png': 'image/png' };

const server = http.createServer((req, res) => {
  const p = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname).replace(/^\/$/, '/index.html'));
  if (!p.startsWith(root) || !fs.existsSync(p)) { res.writeHead(404).end(); return; }
  res.writeHead(200, { 'Content-Type': types[path.extname(p)] ?? 'application/octet-stream' });
  fs.createReadStream(p).pipe(res);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const url = `http://127.0.0.1:${server.address().port}/`;

const browser = await chromium.launch({
  executablePath: '/usr/bin/chromium',
  headless: false,
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--no-zygote', '--mute-audio',
    '--ignore-gpu-blocklist', '--use-gl=angle', '--use-angle=gl'],
});
const errors = [];
try {
  const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
  page.on('console', (m) => { if (m.type() === 'error' || /CONTEXT_LOST/.test(m.text())) errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push(String(e)));
  await page.goto(url);
  await page.waitForTimeout(waitSec * 1000);
  const info = await page.evaluate(() => {
    const c = document.querySelector('canvas');
    const gl = c?.getContext('webgl2');
    const dbg = gl?.getExtension('WEBGL_debug_renderer_info');
    return { lost: gl ? gl.isContextLost() : null,
      renderer: dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : null };
  });
  await page.screenshot({ path: out });
  console.log(JSON.stringify({ url, out, ...info, errors }, null, 1));
} finally {
  await browser.close();
  server.close();
}
