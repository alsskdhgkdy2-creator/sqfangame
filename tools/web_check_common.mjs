// web_check 두 부분이 같이 쓰는 준비·도움 함수(서버·브라우저·상태 요약·기다림·누르기·IndexedDB·전투 넘기기).
// 부분(web_check_part_a·b)은 runPart 안에서 돈다: 부분마다 새 브라우저(빈 IndexedDB)와 새 페이지.
import { chromium } from 'playwright-core';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { idbMatches } from './web_check_lib.mjs';

export const [W, H] = (process.argv[2] ?? '1280x720').split('x').map(Number);
// 새 게임 시드(디버그 주소 &seed=, 재현용).
export const SEED = 41;
// IndexedDB 반영 기다림 한도(밀리초). 이 기기가 느린 상태(백그라운드 CPU 제한)면 늘려 「느림」과 「반영 안 됨」을 가른다.
export const IDB_WAIT_MS = Number(process.env.WEB_CHECK_IDB_MS ?? 30000);
const root = path.resolve('build/web');
export const outDir = path.resolve('build/check');
fs.mkdirSync(outDir, { recursive: true });
export const route = JSON.parse(fs.readFileSync('data/floors/f1_test_route.json', 'utf8'));
export const KEYS = { forward: 'KeyW', back: 'KeyS', turn_left: 'KeyA', turn_right: 'KeyD',
  strafe_left: 'KeyQ', strafe_right: 'KeyE', investigate: 'Space' };
export const FOLLOW_UP = ['turn_left', 'forward', 'forward', 'turn_right', 'investigate', 'back', 'strafe_left'];
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream', '.png': 'image/png' };

let server = null;
export let url = '';
async function startServer() {
  server = http.createServer((req, res) => {
    const p = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname).replace(/^\/$/, '/index.html'));
    if (!p.startsWith(root) || !fs.existsSync(p)) { res.writeHead(404).end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(p)] ?? 'application/octet-stream' });
    fs.createReadStream(p).pipe(res);
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  url = `http://127.0.0.1:${server.address().port}/?debug=1&seed=${SEED}`;
}

export const report = { size: `${W}x${H}`, seed: SEED, idbWaitMs: IDB_WAIT_MS, parts: {}, steps: [], checks: [], errors: [] };
// 지금 돌리는 부분(a·b). 확인·기록에 붙는다.
let part = '';
export const log = (msg, extra) => { console.log(msg, extra === undefined ? '' : JSON.stringify(extra)); report.steps.push({ part, msg, ...(extra ?? {}) }); };
export const check = (ok, name, detail) => { report.checks.push({ ok: !!ok, name, part, ...(detail ? { detail } : {}) }); console.log(ok ? 'OK  ' : 'FAIL', name, detail ? JSON.stringify(detail) : ''); };

const launchBrowser = () => chromium.launch({
  executablePath: '/usr/bin/chromium',
  headless: false,
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--no-zygote', '--mute-audio',
    '--ignore-gpu-blocklist', '--use-gl=angle', '--use-angle=gl'],
});
// 지금 부분의 페이지(부분마다 새 브라우저: IndexedDB 도 비어 있다). 다른 모듈은 이 이름을 읽기만 한다(살아 있는 묶음).
export let page;
export const snap = async () => JSON.parse(await page.evaluate(() => window.sqfDebug?.snapshot || '{}'));
export const request = async (req) => JSON.parse(await page.evaluate((j) => { window.sqfDebug.request(j); return window.sqfDebug.result; }, JSON.stringify(req)));
export async function waitFor(pred, what, timeoutMs = 15000) {
  const t0 = Date.now();
  for (;;) {
    const s = await snap();
    if (s.hash && pred(s)) return s;
    if (Date.now() - t0 > timeoutMs) throw new Error(`기다림 시간 초과: ${what} (마지막 ${JSON.stringify({ at: s.at, busy: s.busy, modal: s.modal, generation: s.generation })})`);
    await page.waitForTimeout(30);
  }
}
export const waitReady = () => page.waitForFunction(() => window.sqfDebug && window.sqfDebug.ready, null, { timeout: 60000 }).then(() => waitFor((s) => !s.busy, '처음 화면'));
// 창이 막 열린 프레임의 좌표는 배치 전일 수 있어 잠깐 기다린 뒤 새 상태 요약에서 위치를 읽는다.
export async function clickButton(name) {
  await page.waitForTimeout(80);
  const s = await snap();
  const p = s.buttons[name];
  if (!p) throw new Error(`단추 없음: ${name} (있는 것: ${Object.keys(s.buttons).join(',')})`);
  await page.mouse.click(p[0], p[1]);
}
// 캠프(M2.7 R2-d): 안내 줄 「캠프」 단추 → 캠프 뿌리 → 「기록」 줄 → 기록 화면(앞 「메뉴」 창이 하던 저장·불러오기·내보내기·
// 가져오기·자동 지도·새 게임). 단추 이름(Export·Import·Save_·Load_·Automap_·NewGame)은 앞 메뉴 창과 같다.
export async function openRecords() {
  await clickButton('CampButton');
  await waitFor((x) => x.party_menu?.open && x.party_menu.page === 'root', '캠프 뿌리');
  await clickButton('Camp_records');
  return waitFor((x) => x.party_menu?.page === 'sub' && x.party_menu.tab === 'records' && x.modal === '', '기록 화면');
}
// 기록 화면 「뒤로」 → 캠프 뿌리 「닫기」 줄 → 탐색(앞 메뉴 창 「닫기」 자리).
export async function closeCamp() {
  await clickButton('RecordsBack');
  await waitFor((x) => x.party_menu?.page === 'root', '캠프 뿌리');
  await clickButton('Camp_close');
  return waitFor((x) => !x.party_menu?.open && x.modal === '', '캠프 닫힘');
}
export async function idbAuto() {
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
export async function waitIdb(want) {
  const t0 = Date.now();
  for (;;) {
    const { text, ...r } = await idbAuto();
    if (typeof text === 'string') {
      const h = await request({ op: 'hash_save', text });
      if (h.error) r.error = h.error; else r.hash = h.hash;
    }
    const info = { ...r, hash: r.hash?.slice(0, 12), want: { generation: want.generation, hash: want.hash?.slice(0, 12) } };
    if (idbMatches(r, want)) return { ...info, waitedMs: Date.now() - t0 };
    if (Date.now() - t0 > IDB_WAIT_MS) return { ...info, timeout: true };
    await page.waitForTimeout(50);
  }
}
export const HIGH_SLASH = 'skill.blade_duelist.high_slash';
export const LEG_CUTTER = 'skill.blade_duelist.leg_cutter';
export const ION_SABER = 'equip.ion_saber';
export const VICTORY_SAVE = path.resolve('tools/web_check_victory_save.json');
export let battles = 0;
export let battleTurns = 0;
export let reloadChecked = false;
export const tryWait = (pred, what, ms) => waitFor(pred, what, ms).catch(() => null);
// 행동 하나: 키를 누르고, 세대가 오르고 연출이 끝날 때까지 기다린다. 전투가 열리면 기능을 보고 battle_finish 로 넘긴다.
export async function act(name) {
  const before = await snap();
  await page.keyboard.press(KEYS[name]);
  let s = await waitFor((x) => x.generation > before.generation && !x.busy, `행동 ${name}`);
  const actionHash = s.hash;  // 전투 전(모의 실행도 행동 직후 해시를 낸다)
  if (s.battle?.open) {
    battles += 1;
    if (battles === 1) s = await firstBattle(s);
    s = await finishBattle(s, battles === 1);
    check(!s.battle?.open && !s.pending && s.modal === '' && !s.wiped, `전투 ${battles}: 끝나고 탐색으로`, { modal: s.modal, wiped: s.wiped, outcome: s.battle?.outcome });
  }
  return { ...s, actionHash };
}
// 첫 전투: 전투 시작 저장을 따로 두고(전멸했을 때 돌아올 곳) 새로 고침 확인 → 실제 누르기 한 턴 → 그 턴의 끝에 맞는 길.
// 돌려주는 상태는 이어지는 전투(명령 입력)이거나 결과 창이다(finishBattle 이 마무리한다).
export async function firstBattle(s) {
  s = await reloadInBattle(s);
  const pre = await idbAuto();
  const prePath = `${outDir}/battle_start.json`;
  const preOk = typeof pre.text === 'string' && (await request({ op: 'hash_save', text: pre.text })).hash === s.hash;
  check(preOk, '전투 시작 저장(IndexedDB) = 화면 상태: 전멸했을 때 돌아올 곳', { generation: pre.generation, hash: s.hash.slice(0, 12) });
  if (preOk) fs.writeFileSync(prePath, pre.text);
  const startHash = s.hash;
  s = await firstBattleTurn(s);
  if (s.wiped || s.modal === 'wipe') {
    // 정상적인 전멸(능력치·난수에 따라 일어날 수 있다): 전멸 창과 저장을 보고, 전투 시작 저장으로 돌아가 공략을 잇는다.
    check(s.wiped && s.modal === 'wipe' && !s.battle?.open && !s.pending && s.buttons.WipeNewGame,
      '첫 턴에 전멸 → 결과 창 없이 M1 전멸 창(전멸 상태가 자동 저장됨)', { wiped: s.wiped, modal: s.modal, hp: s.hp });
    await page.waitForTimeout(150);
    await page.screenshot({ path: `${outDir}/05e_battle_wiped.png` });
    if (!preOk) throw new Error('전멸했지만 돌아올 전투 시작 저장이 없다');
    await clickButton('WipeNewGame');
    s = await waitFor((x) => !x.wiped && x.modal === '', '전멸 창 → 새 게임');
    s = await openRecords();
    const [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import')]);
    await chooser.setFiles(prePath);
    s = await waitFor((x) => x.battle?.open && x.battle.phase === 'command' && x.hash === startHash && !x.party_menu?.open, '전투 시작 저장 가져오기', 10000);
    check(s.battle.turn === 0 && !s.wiped, '전멸 뒤 전투 시작 저장을 가져와 같은 전투(턴 0)로 돌아옴', { turn: s.battle.turn, generation: s.generation });
    await page.mouse.click(Math.round(W * 0.3), 30);  // 캔버스에 키 포커스
  } else if (!(s.battle?.open && s.battle.phase === 'command')) {
    check(s.battle?.open && s.battle.phase === 'result' && ['victory', 'escaped'].includes(s.battle.outcome),
      '첫 턴에 전투가 끝남 → 결과 창(승리·도주)', { phase: s.battle?.phase, outcome: s.battle?.outcome });
  }
  return s;
}
// 06 §10.4 1·2: 전투 층 캡처, 한 턴을 실제 누르기로.
export async function firstBattleTurn(s) {
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/05_battle.png` });
  check(s.battle.phase === 'command' && s.battle.member >= 0 && s.modal === '', '인카운트 → 전투 층(명령 입력)', { phase: s.battle.phase, member: s.battle.member, modal: s.modal });
  check(!s.buttons.CampButton && !s.buttons.Pad_forward && !s.buttons.Tool_wall && s.buttons.Cmd_attack && s.buttons.LogButton,
    '전투 중 지도·이동 단추·캠프 없음, 명령 단추 있음', { buttons: Object.keys(s.buttons) });
  const g0 = s.generation;
  const hash0 = s.hash;
  const turn0 = s.battle.turn;
  const log0 = s.battle.log_lines;
  for (let k = 0; k < 5 && s.battle.sub !== 'confirm'; k++) {
    const m = s.battle.member;
    await clickButton('Cmd_attack');
    const t = await tryWait((x) => x.battle?.sub === 'target', '공격 → 대상', 3000);
    if (t && t.battle.targets.length) {
      if (k === 0) await page.screenshot({ path: `${outDir}/05a_battle_target.png` });
      await clickButton(`Enemy_${t.battle.targets[0]}`);
    } else {
      await clickButton('Cmd_guard');
    }
    s = await waitFor((x) => x.battle?.member !== m, `대원 ${m} 명령`);
  }
  check(s.battle.sub === 'confirm' && s.buttons.Execute && s.generation === g0, '모든 명령이 차면 「실행」(제출 전 저장 없음)', { sub: s.battle.sub });
  await clickButton('Execute');
  s = await waitFor((x) => x.generation > g0, '제출 → 자동 저장');
  if (s.battle?.phase === 'anim') {
    await page.waitForTimeout(400);
    await page.screenshot({ path: `${outDir}/05b_battle_anim.png` });
    await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.35));  // 누르기 = 건너뛰기
  }
  s = await waitFor((x) => x.battle?.phase !== 'anim', '연출 건너뛰기');
  battleTurns += 1;
  // 승패·명중과 무관한 것만 본다: 제출이 저장되고 상태가 바뀌었고, 전투가 이어지면 턴이 하나 넘어가고 로그가 늘었다.
  // 이 턴에 전투가 끝났으면(승리·도주 → 결과 창, 전멸 → 층 닫힘) 끝난 쪽 길로 넘어간다(finishBattle·act).
  const goesOn = s.battle?.open && s.battle.phase === 'command';
  check(s.hash !== hash0 && s.generation > g0 && (!goesOn || (s.battle.turn === turn0 + 1 && s.battle.log_lines > log0)),
    '한 턴 실제 누르기: 저장·해시 바뀜, 이어지면 턴 +1·로그 늘어남',
    { turn0, turn: s.battle?.turn, log0, log: s.battle?.log_lines, phase: s.battle?.phase, outcome: s.battle?.outcome, wiped: s.wiped });
  const idb = await waitIdb(s);
  check(!idb.timeout, '전투 턴 자동 저장이 IndexedDB 에 반영(세대·상태 해시)', idb);
  return s;
}
// 06 §10.4 3: 전투 중 새로 고침 → 같은 해시, 전투 층이 명령 입력 처음. 첫 전투가 열린 직후(늘 이어지는 전투)에 한다.
export async function reloadInBattle(s) {
  reloadChecked = true;
  const idb = await waitIdb(s);
  check(!idb.timeout, '새로 고침 전 IndexedDB = 화면', idb);
  const before = s;
  await page.reload();
  s = await waitReady();
  check(s.hash === before.hash && s.generation === before.generation && s.battle?.open && s.battle.phase === 'command'
    && s.battle.sub === 'menu' && s.battle.turn === before.battle.turn, '전투 중 새로 고침: 같은 해시·같은 턴·명령 입력 처음',
  { before: before.hash.slice(0, 12), after: s.hash.slice(0, 12), battle: s.battle && { phase: s.battle.phase, sub: s.battle.sub, member: s.battle.member, turn: s.battle.turn } });
  await page.screenshot({ path: `${outDir}/05c_battle_reloaded.png` });
  await page.mouse.click(Math.round(W * 0.3), 30);  // 캔버스에 키 포커스(알림 줄은 누르기를 받지 않는다)
  return s;
}
// 디버그 요청 battle_finish 로 넘긴다: 전투 층이 규칙의 finish(승리) → 저장 → 연출(Enter 로 건너뛰기) → 결과 창 → 「확인」.
// 이미 결과 창이면(첫 턴에 승리·도주로 끝남) 「확인」만 누른다.
export async function finishBattle(s, shotResult) {
  if (s.battle?.open && s.battle.phase === 'command') {
    const g = s.generation;
    let r = null;
    for (let k = 0; k < 3 && !r?.ok; k++) {
      if (k) await page.waitForTimeout(100);  // 전투 층은 한 프레임에 입력 하나: 같은 프레임에 받은 입력이 있었으면 다음 프레임에
      r = await request({ op: 'battle_finish' });
    }
    if (!r.ok) throw new Error(`battle_finish 거부: ${JSON.stringify(r)}`);
    s = await waitFor((x) => x.generation > g, 'battle_finish 저장');
    if (s.battle?.phase === 'anim') await page.keyboard.press('Enter');
    s = await waitFor((x) => x.battle?.phase !== 'anim', '연출 끝');
    check(s.battle?.phase === 'result' && s.battle.outcome === 'victory', `전투 ${battles}: battle_finish → 결과 창(승리)`,
      { phase: s.battle?.phase, outcome: s.battle?.outcome });
  }
  if (s.battle?.open && s.battle.phase === 'result') {
    if (shotResult) await page.screenshot({ path: `${outDir}/05d_battle_result.png` });
    check(s.buttons.ResultOk, `전투 ${battles}: 결과 창 「확인」`, { outcome: s.battle.outcome });
    await clickButton('ResultOk');
    s = await waitFor((x) => !x.battle?.open, '결과 창 닫힘');
  }
  return s;
}

// 부분 하나를 새 브라우저에서 돌린다. 오류는 그 부분 이름을 붙여 남기고 다음 부분은 그대로 돈다.
export async function runPart(name, body) {
  part = name;
  const t0 = Date.now();
  const n0 = report.checks.length;
  const e0 = report.errors.length;
  if (!server) await startServer();
  const browser = await launchBrowser();
  try {
    page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1, acceptDownloads: true });
    page.on('console', (m) => { if (m.type() === 'error' || /CONTEXT_LOST/.test(m.text())) report.errors.push(`[${name}] ${m.text()}`); });
    page.on('pageerror', (e) => report.errors.push(`[${name}] ${String(e)}`));
    await page.goto(url);
    await body();
  } catch (e) {
    report.errors.push(`[${name}] ${String(e?.stack ?? e)}`);
    console.log('ERROR', e);
    try { await page?.screenshot({ path: `${outDir}/99_error_${name}.png` }); } catch { /* 무시 */ }
  } finally {
    await browser.close();
  }
  const checks = report.checks.slice(n0);
  const r = { ms: Date.now() - t0, checks: checks.length, failed: checks.filter((c) => !c.ok).length, errors: report.errors.length - e0 };
  report.parts[name] = r;
  fs.writeFileSync(`${outDir}/report_${name}.json`, JSON.stringify({ size: report.size, seed: SEED, idbWaitMs: IDB_WAIT_MS, part: name, ...r,
    steps: report.steps.filter((x) => x.part === name), checks, errors: report.errors.slice(e0) }, null, 1));
  console.log(`부분 ${name}: 확인 ${r.checks}개 중 실패 ${r.failed}, 오류 ${r.errors}, ${(r.ms / 1000).toFixed(1)}초`);
  return r;
}

// 돌린 부분 전체를 report.json 에 쓰고 종료 코드(실패·오류가 있으면 1)를 돌려준다.
export function finish() {
  server?.close();
  // 확인이 하나도 없이 끝난 실행·부분은 실패다(부분 이름이 잘못되었거나 본문이 아무것도 보지 않았다).
  const empty = Object.entries(report.parts).filter(([, r]) => r.checks === 0).map(([n]) => n);
  if (report.checks.length === 0 || empty.length) report.errors.push(`확인 0개로 끝났다: ${empty.length ? empty.join(', ') : '전체'}`);
  const failed = report.checks.filter((c) => !c.ok).length + (report.errors.length ? 1 : 0);
  report.result = failed ? 'FAIL' : 'OK';
  fs.writeFileSync(`${outDir}/report.json`, JSON.stringify(report, null, 1));
  console.log(`결과: 확인 ${report.checks.length}개 중 실패 ${report.checks.filter((c) => !c.ok).length}, 오류 ${report.errors.length}`);
  return failed ? 1 : 0;
}
