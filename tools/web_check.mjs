// 웹 빌드 자동 확인(05 §11.3): ?debug=1 의 window.sqfDebug 로 상태를 읽으며 실제 키·마우스·파일 고르기로 조작한다.
// 1) 고정 공략 행동열로 지름길을 열 때까지 걷는다(전투는 「승리」 단추). 2) 지도 편집(벽·바닥 색·메모 입력 창).
// 3) IndexedDB 의 자동 저장(세대와 저장 글의 상태 해시)이 화면과 같아질 때까지 기다린다. 4) 새로 고침 → 전체 해시와 다음 행동 결과 비교.
// 5) 내보내기(내려받기) → 이동 → 가져오기(파일 고르기) → 해시 비교. 늦게 끝난 앞 가져오기(A)는 새 가져오기(B) 결과를
//    덮지 않는다. 1MB 넘는 파일은 거부.
// 실행: flock /tmp/voxel-test-heavy.lock xvfb-run -a node tools/web_check.mjs [너비x높이]
// 결과: build/check/ 에 캡처·내보낸 파일·report.json.
import { chromium } from 'playwright-core';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { idbMatches } from './web_check_lib.mjs';

const [W, H] = (process.argv[2] ?? '1280x720').split('x').map(Number);
const root = path.resolve('build/web');
const outDir = path.resolve('build/check');
fs.mkdirSync(outDir, { recursive: true });
const route = JSON.parse(fs.readFileSync('data/floors/f1_test_route.json', 'utf8'));
const KEYS = { forward: 'KeyW', back: 'KeyS', turn_left: 'KeyA', turn_right: 'KeyD',
  strafe_left: 'KeyQ', strafe_right: 'KeyE', investigate: 'Space' };
const FOLLOW_UP = ['turn_left', 'forward', 'forward', 'turn_right', 'investigate', 'back', 'strafe_left'];
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream', '.png': 'image/png' };

const server = http.createServer((req, res) => {
  const p = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname).replace(/^\/$/, '/index.html'));
  if (!p.startsWith(root) || !fs.existsSync(p)) { res.writeHead(404).end(); return; }
  res.writeHead(200, { 'Content-Type': types[path.extname(p)] ?? 'application/octet-stream' });
  fs.createReadStream(p).pipe(res);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const url = `http://127.0.0.1:${server.address().port}/?debug=1`;

const report = { size: `${W}x${H}`, steps: [], checks: [], errors: [] };
const log = (msg, extra) => { console.log(msg, extra === undefined ? '' : JSON.stringify(extra)); report.steps.push(extra === undefined ? msg : { msg, ...extra }); };
const check = (ok, name, detail) => { report.checks.push({ ok: !!ok, name, ...(detail ? { detail } : {}) }); console.log(ok ? 'OK  ' : 'FAIL', name, detail ? JSON.stringify(detail) : ''); };

const browser = await chromium.launch({
  executablePath: '/usr/bin/chromium',
  headless: false,
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--no-zygote', '--mute-audio',
    '--ignore-gpu-blocklist', '--use-gl=angle', '--use-angle=gl'],
});
let page;
const snap = async () => JSON.parse(await page.evaluate(() => window.sqfDebug?.snapshot || '{}'));
const request = async (req) => JSON.parse(await page.evaluate((j) => { window.sqfDebug.request(j); return window.sqfDebug.result; }, JSON.stringify(req)));
async function waitFor(pred, what, timeoutMs = 15000) {
  const t0 = Date.now();
  for (;;) {
    const s = await snap();
    if (s.hash && pred(s)) return s;
    if (Date.now() - t0 > timeoutMs) throw new Error(`기다림 시간 초과: ${what} (마지막 ${JSON.stringify({ at: s.at, busy: s.busy, modal: s.modal, generation: s.generation })})`);
    await page.waitForTimeout(30);
  }
}
const waitReady = () => page.waitForFunction(() => window.sqfDebug && window.sqfDebug.ready, null, { timeout: 60000 }).then(() => waitFor((s) => !s.busy, '처음 화면'));
// 창이 막 열린 프레임의 좌표는 배치 전일 수 있어 잠깐 기다린 뒤 새 상태 요약에서 위치를 읽는다.
async function clickButton(name) {
  await page.waitForTimeout(80);
  const s = await snap();
  const p = s.buttons[name];
  if (!p) throw new Error(`단추 없음: ${name} (있는 것: ${Object.keys(s.buttons).join(',')})`);
  await page.mouse.click(p[0], p[1]);
}
async function idbAuto() {
  return page.evaluate(() => new Promise((resolve) => {
    const req = indexedDB.open('/userfs');
    req.onerror = () => resolve({ error: 'open' });
    req.onsuccess = () => {
      const db = req.result;
      const tx = db.transaction('FILE_DATA', 'readonly');
      const store = tx.objectStore('FILE_DATA');
      const keysReq = store.getAllKeys();
      keysReq.onsuccess = () => {
        const keys = keysReq.result.filter((k) => String(k).endsWith('/saves/auto.json'));
        if (!keys.length) { resolve({ keys: [] }); return; }
        const g = store.get(keys[0]);
        g.onsuccess = () => {
          try {
            const doc = JSON.parse(new TextDecoder().decode(g.result.contents));
            resolve({ keys, generation: doc.generation, text: new TextDecoder().decode(g.result.contents) });
          } catch (e) { resolve({ keys, error: String(e) }); }
        };
      };
    };
  }));
}
// 화면 상태 요약 want 의 세대·해시와 IndexedDB 자동 저장의 세대·해시(저장 글을 게임이 읽어 계산)가 같을 때까지.
async function waitIdb(want) {
  const t0 = Date.now();
  for (;;) {
    const { text, ...r } = await idbAuto();
    if (typeof text === 'string') {
      const h = await request({ op: 'hash_save', text });
      if (h.error) r.error = h.error; else r.hash = h.hash;
    }
    const info = { ...r, hash: r.hash?.slice(0, 12), want: { generation: want.generation, hash: want.hash?.slice(0, 12) } };
    if (idbMatches(r, want)) return { ...info, waitedMs: Date.now() - t0 };
    if (Date.now() - t0 > 10000) return { ...info, timeout: true };
    await page.waitForTimeout(50);
  }
}
let battles = 0;
let battleShot = false;
// 행동 하나: 키를 누르고, 세대가 오르고 연출이 끝날 때까지 기다린다. 전투 창이면 「승리」.
async function act(name) {
  const before = await snap();
  await page.keyboard.press(KEYS[name]);
  let s = await waitFor((x) => x.generation > before.generation && !x.busy, `행동 ${name}`);
  const actionHash = s.hash;  // 전투 해결 전(모의 실행도 행동 직후 해시를 낸다)
  if (s.modal === 'battle') {
    battles += 1;
    if (!battleShot) { battleShot = true; await page.screenshot({ path: `${outDir}/05_battle.png` }); }
    const g = s.generation;
    await clickButton('BattleWin', s);
    s = await waitFor((x) => x.modal === '' && !x.pending && x.generation > g, '전투 해결');
  }
  return { ...s, actionHash };
}

try {
  page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1, acceptDownloads: true });
  page.on('console', (m) => { if (m.type() === 'error' || /CONTEXT_LOST/.test(m.text())) report.errors.push(m.text()); });
  page.on('pageerror', (e) => report.errors.push(String(e)));
  await page.goto(url);
  let s = await waitReady();
  check(s.user_dir === '/userfs/sqfangame', 'user:// 경로', { user_dir: s.user_dir });
  check(s.autosaves === 1 && s.modal === '', '새 게임 자동 저장', { autosaves: s.autosaves, modal: s.modal });
  await page.screenshot({ path: `${outDir}/01_start.png` });
  // 캔버스에 키 포커스를 준다(3D 시야 영역 클릭은 아무 일도 하지 않는다).
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));

  // ---- 1) 공략 행동열 ----
  const t0 = Date.now();
  let maxGuard = 0;
  for (let i = 0; i < route.actions.length; i++) {
    s = await act(route.actions[i]);
    maxGuard = Math.max(maxGuard, Math.abs(s.guard_delta));
    const cp = route.checkpoints.find((c) => c.after === i + 1);
    if (cp && (s.at[0] !== cp.at[0] || s.at[1] !== cp.at[1])) check(false, `체크포인트 ${cp.after}`, { want: cp.at, got: s.at });
    // 경계 겉모습 캡처: 숨은 통로 찾기 전후, 일방통행, 지름길 닫힘·열림.
    if (cp && [13, 14, 58, 61, 88, 89].includes(cp.after)) {
      await page.waitForTimeout(150);
      await page.screenshot({ path: `${outDir}/cp${String(cp.after).padStart(2, '0')}.png` });
    }
  }
  check(s.shortcuts_open === 1, '공략 끝: 지름길 열림', { at: s.at, shortcuts_open: s.shortcuts_open, passages_found: s.passages_found, battles, ms: Date.now() - t0 });
  log('공략 끝', { at: s.at, steps: s.steps, generation: s.generation, battles, last_guard_delta: s.guard_delta, guard_radius: s.guard_radius, plan_ms_max: s.plan_ms_max,
    plan_count: s.plan_count, plan_ms_total: s.plan_ms_total, plan_ms_total_max: s.plan_ms_total_max, plan_count_max: s.plan_count_max });
  await page.screenshot({ path: `${outDir}/02_route_end.png` });

  // ---- 2) 지도 편집 ----
  const cellPt = (s2, x, y) => [s2.map.origin[0] + s2.map.cell[0] * x, s2.map.origin[1] + s2.map.cell[1] * y];
  const [px, py] = s.at;
  await clickButton('Tool_wall', s);
  s = await waitFor((x) => x.tool === 'wall', '벽 도구');
  let g = s.generation;
  let e0 = s.edges;
  let pt = cellPt(s, px + 0.5, py + 1);  // 파티 칸 남쪽 변
  await page.mouse.click(pt[0], pt[1]);
  s = await waitFor((x) => x.generation > g, '벽 편집 저장');
  check(s.edges === e0 + 1 || s.edges === e0 - 1, '벽 한 번 클릭 = 경계 하나 바뀜', { before: e0, after: s.edges });
  await clickButton('Tool_color2', s);
  s = await waitFor((x) => x.tool === 'color', '색 도구');
  g = s.generation;
  pt = cellPt(s, px + 0.5, py + 0.5);
  await page.mouse.click(pt[0], pt[1]);
  s = await waitFor((x) => x.generation > g, '바닥 색 저장');
  await clickButton('Tool_memo', s);
  s = await waitFor((x) => x.tool === 'memo', '메모 도구');
  g = s.generation;
  const m0 = s.memos;
  const memoText = '지름길 앞 보물 상자';
  let dialogInfo = null;
  page.once('dialog', async (d) => { dialogInfo = { type: d.type(), message: d.message() }; await d.accept(memoText); });
  pt = cellPt(s, px + 0.5, py + 0.5);
  await page.mouse.click(pt[0], pt[1]);
  s = await waitFor((x) => x.generation > g, '메모 저장');
  check(dialogInfo?.type === 'prompt' && s.memos === m0 + 1, '메모: 브라우저 입력 창 → 한국어 메모 한 단계', { dialogInfo, memos: s.memos });
  const memoKey = `${px},${py}`;
  check(s.memo_texts?.[memoKey] === memoText, '메모: 저장된 글 = 입력한 한국어 글', { want: memoText, got: s.memo_texts?.[memoKey] });
  check(s.at[0] === px && s.at[1] === py, '지도 편집은 파티를 움직이지 않는다', { at: s.at });
  await page.screenshot({ path: `${outDir}/03_map_edit.png` });
  // 되돌림 한 번(자동 저장), 다시 메모.
  g = s.generation;
  await page.keyboard.press('Control+KeyZ');
  s = await waitFor((x) => x.generation > g, 'Ctrl+Z 저장');
  check(s.memos === m0 && s.memo_texts?.[memoKey] === undefined, 'Ctrl+Z 로 메모 되돌림', { memos: s.memos, got: s.memo_texts?.[memoKey] });

  // ---- 3) IndexedDB 반영 ----
  let idb = await waitIdb(s);
  check(!idb.timeout && idb.keys?.[0] === '/userfs/sqfangame/saves/auto.json', 'IndexedDB 자동 저장 = 화면 세대·상태 해시', idb);

  // ---- 4) 새로 고침 → 같은 상태, 다음 행동도 같은 결과 ----
  const sim = await request({ op: 'simulate', actions: FOLLOW_UP });
  const before = s;
  await page.reload();
  s = await waitReady();
  check(s.hash === before.hash && s.generation === before.generation, '새로 고침 뒤 전체 상태 해시·세대 같음', { before: before.hash.slice(0, 12), after: s.hash.slice(0, 12), generation: s.generation });
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));
  const real = [];
  for (const a of FOLLOW_UP) {
    s = await act(a);
    real.push(s.actionHash);
  }
  // 길이를 먼저 본다(빈 배열·짧은 배열이면 every 가 참이 되어 비교 없이 통과한다).
  const lengthsOk = Array.isArray(sim.hashes) && Array.isArray(real)
    && sim.hashes.length === FOLLOW_UP.length && real.length === FOLLOW_UP.length;
  const same = lengthsOk && sim.hashes.every((h, i) => typeof h === 'string' && h === real[i]);
  check(same, `새로 고침 뒤 다음 행동 ${FOLLOW_UP.length}개 결과 = 새로 고침 전 모의 결과`, same ? undefined : {
    simLength: Array.isArray(sim.hashes) ? sim.hashes.length : typeof sim.hashes, realLength: real.length,
    sim: Array.isArray(sim.hashes) ? sim.hashes.map((h) => String(h).slice(0, 8)) : sim, real: real.map((h) => String(h).slice(0, 8)),
  });
  await page.screenshot({ path: `${outDir}/04_after_reload.png` });

  // ---- 5) 내보내기 → 이동 → 가져오기 ----
  await clickButton('MenuButton', s);
  s = await waitFor((x) => x.modal === 'menu', '메뉴');
  await page.screenshot({ path: `${outDir}/06_menu.png` });
  const exportHash = s.hash;
  const [download] = await Promise.all([page.waitForEvent('download', { timeout: 10000 }), clickButton('Export', s)]);
  const exportPath = `${outDir}/export.json`;
  await download.saveAs(exportPath);
  const exported = JSON.parse(fs.readFileSync(exportPath, 'utf8'));
  check(exported.format === 'sqfangame-save' && download.suggestedFilename().endsWith('.json'), '내보내기: 단추 처리 안에서 내려받기', { file: download.suggestedFilename(), bytes: fs.statSync(exportPath).size });
  await clickButton('Close');
  s = await waitFor((x) => x.modal === '', '메뉴 닫힘');
  s = await act('turn_right');
  s = await act('forward');
  check(s.hash !== exportHash, '내보낸 뒤 상태가 바뀜');
  await clickButton('MenuButton', s);
  s = await waitFor((x) => x.modal === 'menu', '메뉴');
  let [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import', s)]);
  g = s.generation;
  await chooser.setFiles(exportPath);
  s = await waitFor((x) => x.modal === '' && x.hash === exportHash, '가져오기 결과', 10000);
  check(true, '가져오기: 내보낸 상태 해시로 돌아옴', { generation: s.generation, previous: g });
  idb = await waitIdb(s);
  check(!idb.timeout, '가져오기 직후 자동 저장(세대·상태 해시)이 IndexedDB 에 반영', idb);
  await page.screenshot({ path: `${outDir}/07_imported.png` });
  // 늦게 끝난 앞 가져오기: 첫 파일 읽기(A)를 붙잡아 두고 새 가져오기(B)를 끝낸 뒤 A 를 풀면 상태는 B 그대로다.
  s = await act('turn_right');
  s = await act('forward');
  await clickButton('MenuButton', s);
  s = await waitFor((x) => x.modal === 'menu', '메뉴');
  const [downloadB] = await Promise.all([page.waitForEvent('download', { timeout: 10000 }), clickButton('Export', s)]);
  const exportBPath = `${outDir}/export_b.json`;
  await downloadB.saveAs(exportBPath);
  const hashB = s.hash;
  await clickButton('Close');
  s = await waitFor((x) => x.modal === '', '메뉴 닫힘');
  s = await act('turn_left');
  check(s.hash !== hashB && s.hash !== exportHash, '늦은 읽기 준비: 지금 상태는 A·B 와 다르다');
  const dropped0 = await page.evaluate(() => {
    const h = { orig: File.prototype.text, calls: 0, release: null };
    window.sqfHoldRead = h;
    File.prototype.text = function () {
      h.calls += 1;
      if (h.calls > 1) return h.orig.call(this);
      return new Promise((res, rej) => { h.release = () => h.orig.call(this).then(res, rej); });
    };
    return window.sqfImportState?.dropped ?? 0;
  });
  await clickButton('MenuButton', s);
  s = await waitFor((x) => x.modal === 'menu', '메뉴');
  [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import', s)]);
  await chooser.setFiles(exportPath);  // A: 읽기가 붙잡힌다
  await page.waitForFunction(() => typeof window.sqfHoldRead.release === 'function', null, { timeout: 5000 });
  const heldHash = (await snap()).hash;
  [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import', s)]);
  await chooser.setFiles(exportBPath);  // B: 바로 읽힌다
  s = await waitFor((x) => x.modal === '' && x.hash === hashB, '새 가져오기(B) 결과', 10000);
  const genB = s.generation;
  await page.evaluate(() => window.sqfHoldRead.release());
  await page.waitForFunction((d) => (window.sqfImportState?.dropped ?? 0) > d, dropped0, { timeout: 5000 }).catch(() => {});
  await page.waitForTimeout(300);
  s = await snap();
  const dropped1 = await page.evaluate(() => {
    File.prototype.text = window.sqfHoldRead.orig;
    return window.sqfImportState?.dropped ?? 0;
  });
  check(heldHash !== exportHash && s.hash === hashB && s.generation === genB && s.modal === '' && dropped1 === dropped0 + 1,
    '늦게 끝난 앞 가져오기(A)는 버린다: 상태·세대는 B 그대로', { hash: s.hash.slice(0, 12), hashB: hashB.slice(0, 12), generation: s.generation, genB, modal: s.modal, dropped: dropped1 - dropped0 });
  // 1MB 넘는 파일.
  const bigPath = `${outDir}/too_large.json`;
  fs.writeFileSync(bigPath, 'x'.repeat(1100000));
  const keep = s.hash;
  await clickButton('MenuButton', s);
  s = await waitFor((x) => x.modal === 'menu', '메뉴');
  [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import', s)]);
  await chooser.setFiles(bigPath);
  s = await waitFor((x) => x.modal === 'alert', '크기 초과 알림', 10000);
  check(s.hash === keep, '1MB 넘는 파일 거부, 상태 그대로');
  await page.screenshot({ path: `${outDir}/08_too_large.png` });
  await clickButton('AlertOk', s);
  // 고르기 취소.
  await clickButton('MenuButton');
  s = await waitFor((x) => x.modal === 'menu', '메뉴');
  [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import', s)]);
  await chooser.setFiles([]);
  await page.waitForTimeout(500);
  s = await snap();
  check(s.hash === keep, '파일 고르기 취소: 상태 그대로', { modal: s.modal });
  log('끝', { maxGuardDuringRoute: maxGuard });
} catch (e) {
  report.errors.push(String(e?.stack ?? e));
  console.log('ERROR', e);
  try { await page?.screenshot({ path: `${outDir}/99_error.png` }); } catch { /* 무시 */ }
} finally {
  await browser.close();
  server.close();
}
const failed = report.checks.filter((c) => !c.ok).length + (report.errors.length ? 1 : 0);
report.result = failed ? 'FAIL' : 'OK';
fs.writeFileSync(`${outDir}/report.json`, JSON.stringify(report, null, 1));
console.log(`결과: 확인 ${report.checks.length}개 중 실패 ${report.checks.filter((c) => !c.ok).length}, 오류 ${report.errors.length}`);
process.exit(failed ? 1 : 0);
