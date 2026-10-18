// 웹 빌드 자동 확인(05 §11.3): ?debug=1 의 window.sqfDebug 로 상태를 읽으며 실제 키·마우스·파일 고르기로 조작한다.
// 전투 승패(밸런스)에 기대지 않는다(D15): 실제 누르기 한 턴은 어떻게 끝나도 그 끝에 맞는 화면·저장을 보고 공략을 잇는다.
// 그 밖의 전투는 디버그 요청 battle_finish 로 넘긴다(전투 층이 규칙의 finish 「승리」 → 저장 → 연출 → 결과 창).
// 1) 고정 공략 행동열로 지름길을 열 때까지 걷는다. 첫 전투(06 §10.4): 전투 시작 저장(IndexedDB)을 따로 둔다 → 새로 고침 → 같은
//    해시·명령 입력 처음 → 전투 층 캡처 → 한 턴을 실제 누르기로(공격 → 적 칸 → … → 실행 → 누르기로 연출 건너뛰기) → 저장·해시
//    (이어지면 턴 +1·로그) 확인 → 그 턴의 끝에 따라: 이어짐 → battle_finish → 결과 창 「확인」 / 승리·도주 → 결과 창 「확인」 /
//    전멸 → M1 전멸 창 확인 → 「새 게임」 → 메뉴 「가져오기」로 전투 시작 저장 → 같은 전투(턴 0) → battle_finish → 결과 창.
//    그 뒤 전투도 battle_finish, 남은 공략의 행동마다 해시 = 첫 전투 뒤 simulate(전투는 같은 finish 로 넘긴다).
//    2) 지도 편집(벽·바닥 색·메모 입력 창).
// 3) IndexedDB 의 자동 저장(세대와 저장 글의 상태 해시)이 화면과 같아질 때까지 기다린다. 4) 새로 고침 → 전체 해시와 다음 행동 결과 비교.
// 5) 내보내기(내려받기) → 이동 → 가져오기(파일 고르기) → 해시 비교. 늦게 끝난 앞 가져오기(A)는 새 가져오기(B) 결과를
//    덮지 않는다. 1MB 넘는 파일은 거부.
// 6) 가져오기로 준비한 저장(전투 중, 넷 쓰러짐, 하나 HP 1 독) → 방어 → 실행 → 전멸 창(규칙 기능 확인).
// 7) 성장(07 §10.5): 전멸 창 「새 게임」 → 「파티」 단추로 메뉴 → grant_exp → 스킬 배분 취소(버리기)·확정(실제 누르기, IndexedDB 확인)
//    → supply → 장비 탭에서 이온 세이버 장착 → 새로 고침(같은 해시·메뉴 닫힘) → 고정 저장 tools/web_check_victory_save.json 가져오기
//    (편성 rats, 쥐 0·1 HP 0·처치 기록, 쥐 2 살아 있음·처치 기록 없음, 대원 가득, 듀얼리스트 A exp 26) → 전투 중 「파티」 없음·P 무시
//    → battle_finish → 결과 창 「경험치 +4」「레벨 업」「듀얼리스트 A  Lv 1 → 2  SP +1」 → 상태 탭 Lv 2·SP 1. 승패에 기대지 않는다(D15).
// 새 게임 시드는 SEED(디버그 주소 &seed=)로 고정한다: 실행마다 같은 인카운트·같은 첫 턴이 되게 하는 재현용이고, 값에 다른 뜻은 없다
// (그 시드의 첫 턴이 이어지든 이기든 전멸하든 위 길로 통과해야 한다).
// 실행: flock /tmp/voxel-test-heavy.lock xvfb-run -a node tools/web_check.mjs [너비x높이]
// 결과: build/check/ 에 캡처·내보낸 파일·report.json.
import { chromium } from 'playwright-core';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { idbMatches } from './web_check_lib.mjs';

const [W, H] = (process.argv[2] ?? '1280x720').split('x').map(Number);
// 새 게임 시드(디버그 주소 &seed=, 재현용).
const SEED = 41;
// IndexedDB 반영 기다림 한도(밀리초). 이 기기가 느린 상태(백그라운드 CPU 제한)면 늘려 「느림」과 「반영 안 됨」을 가른다.
const IDB_WAIT_MS = Number(process.env.WEB_CHECK_IDB_MS ?? 30000);
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
const url = `http://127.0.0.1:${server.address().port}/?debug=1&seed=${SEED}`;

const report = { size: `${W}x${H}`, seed: SEED, idbWaitMs: IDB_WAIT_MS, steps: [], checks: [], errors: [] };
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
    if (Date.now() - t0 > IDB_WAIT_MS) return { ...info, timeout: true };
    await page.waitForTimeout(50);
  }
}
const HIGH_SLASH = 'skill.blade_duelist.high_slash';
const LEG_CUTTER = 'skill.blade_duelist.leg_cutter';
const ION_SABER = 'equip.ion_saber';
const VICTORY_SAVE = path.resolve('tools/web_check_victory_save.json');
let battles = 0;
let battleTurns = 0;
let reloadChecked = false;
const tryWait = (pred, what, ms) => waitFor(pred, what, ms).catch(() => null);
// 행동 하나: 키를 누르고, 세대가 오르고 연출이 끝날 때까지 기다린다. 전투가 열리면 기능을 보고 battle_finish 로 넘긴다.
async function act(name) {
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
async function firstBattle(s) {
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
    await clickButton('MenuButton');
    s = await waitFor((x) => x.modal === 'menu', '메뉴');
    const [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import')]);
    await chooser.setFiles(prePath);
    s = await waitFor((x) => x.battle?.open && x.battle.phase === 'command' && x.hash === startHash, '전투 시작 저장 가져오기', 10000);
    check(s.battle.turn === 0 && !s.wiped, '전멸 뒤 전투 시작 저장을 가져와 같은 전투(턴 0)로 돌아옴', { turn: s.battle.turn, generation: s.generation });
    await page.mouse.click(Math.round(W * 0.3), 30);  // 캔버스에 키 포커스
  } else if (!(s.battle?.open && s.battle.phase === 'command')) {
    check(s.battle?.open && s.battle.phase === 'result' && ['victory', 'escaped'].includes(s.battle.outcome),
      '첫 턴에 전투가 끝남 → 결과 창(승리·도주)', { phase: s.battle?.phase, outcome: s.battle?.outcome });
  }
  return s;
}
// 06 §10.4 1·2: 전투 층 캡처, 한 턴을 실제 누르기로.
async function firstBattleTurn(s) {
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/05_battle.png` });
  check(s.battle.phase === 'command' && s.battle.member >= 0 && s.modal === '', '인카운트 → 전투 층(명령 입력)', { phase: s.battle.phase, member: s.battle.member, modal: s.modal });
  check(!s.buttons.MenuButton && !s.buttons.Pad_forward && !s.buttons.Tool_wall && s.buttons.Cmd_attack && s.buttons.LogButton,
    '전투 중 지도·이동 단추·메뉴 없음, 명령 단추 있음', { buttons: Object.keys(s.buttons) });
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
async function reloadInBattle(s) {
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
async function finishBattle(s, shotResult) {
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

// 성장(07 §10.5). s 는 전멸 창이 떠 있는 상태.
async function growthChecks(s) {
  const tag = `${W}x${H}`;
  await clickButton('WipeNewGame');
  s = await waitFor((x) => x.modal === '' && !x.wiped && !x.battle?.open && !x.busy, '새 게임');
  // 1. 「파티」 단추를 실제로 눌러 연다.
  await clickButton('PartyButton');
  s = await waitFor((x) => x.party_menu?.open, '파티 메뉴');
  check(s.party_menu.tab === 'status' && s.party_menu.member === 0 && !s.buttons.Pad_forward && !s.buttons.PartyButton && s.buttons.Tab_skills,
    '성장 1: 「파티」 단추 → 상태 탭·칸 0, 덮인 탐색 단추는 요약에 없다', { tab: s.party_menu.tab, member: s.party_menu.member });
  await page.screenshot({ path: `${outDir}/10_party_status_${tag}.png` });
  // 2. grant_exp(듀얼리스트 A, cum(3) = 115).
  let g = s.generation;
  let r = await request({ op: 'grant_exp', member: 1, n: 115 });
  s = await waitFor((x) => x.generation > g, 'grant_exp 저장');
  check(r.ok && s.members[1].level === 3 && s.members[1].sp_left === 2, '성장 2: grant_exp → Lv3·남은 SP 2', { r: r.ok ?? r, level: s.members[1].level, sp_left: s.members[1].sp_left });
  const base = { hash: s.hash, generation: s.generation };
  // 3. 취소 먼저: 초안 → 「닫기」 → 버리기 확인 창 → 「버리기」.
  await clickButton('Tab_skills');
  s = await waitFor((x) => x.party_menu?.tab === 'skills', '스킬 탭');
  await clickButton('Member_1');
  s = await waitFor((x) => x.party_menu?.member === 1, '듀얼리스트 A');
  check(s.party_menu.cursor.skill === HIGH_SLASH, '성장 3: 스킬 커서는 트리 첫 항목', { cursor: s.party_menu.cursor });
  await clickButton('SkillPlus');
  s = await waitFor((x) => x.party_menu?.draft?.[HIGH_SLASH] === 1, '초안 +1');
  check(s.party_menu.sp_line === '남은 SP 2(배분 중 -1)' && s.hash === base.hash, '성장 3: 「+」 → 초안만(남은 SP 줄)', { sp_line: s.party_menu.sp_line });
  await clickButton('Close');
  s = await waitFor((x) => x.party_menu?.dialog === 'discard', '버리기 확인 창');
  check(s.party_menu.dialog_pick === 0 && s.buttons.DialogOk && !s.buttons.Tab_status, '성장 3: 버리기 확인 창(처음 고른 쪽 「돌아가기」)');
  await clickButton('DialogOk');
  s = await waitFor((x) => !x.party_menu?.open, '버린 뒤 닫힘');
  check(s.hash === base.hash && s.generation === base.generation && s.members[1].sp_left === 2, '성장 3: 「버리기」 → 상태·세대 그대로', { generation: s.generation });
  // 4. 확정: 하이 슬래시 「+」 → 레그 커터 「+」(선행을 같은 초안이 채움) → 「확정」 → 확정 확인 창 → 「확정」.
  await clickButton('PartyButton');
  s = await waitFor((x) => x.party_menu?.open, '파티 메뉴 다시');
  await clickButton('Tab_skills');
  s = await waitFor((x) => x.party_menu?.tab === 'skills', '스킬 탭');
  await clickButton('Member_1');
  s = await waitFor((x) => x.party_menu?.member === 1, '듀얼리스트 A');
  await clickButton('SkillPlus');
  s = await waitFor((x) => x.party_menu?.draft?.[HIGH_SLASH] === 1, '하이 슬래시 초안');
  const leg = s.party_menu.nodes[LEG_CUTTER];
  await page.mouse.click(leg[0], leg[1]);
  s = await waitFor((x) => x.party_menu?.cursor?.skill === LEG_CUTTER, '레그 커터 노드');
  await clickButton('SkillPlus');
  s = await waitFor((x) => x.party_menu?.draft?.[LEG_CUTTER] === 1, '레그 커터 초안');
  await page.screenshot({ path: `${outDir}/11_party_skills_${tag}.png` });
  g = s.generation;
  await clickButton('SkillCommit');
  s = await waitFor((x) => x.party_menu?.dialog === 'commit', '확정 확인 창');
  check(s.party_menu.dialog_pick === 0 && s.generation === g, '성장 4: 확정 확인 창(「돌아가기」), 아직 저장 없음');
  await clickButton('DialogOk');
  s = await waitFor((x) => x.generation > g && x.party_menu?.dialog === '', '배분 확정 저장');
  const sk = s.members[1].skills;
  check(sk[HIGH_SLASH] === 2 && sk[LEG_CUTTER] === 1 && s.members[1].sp_left === 0 && Object.keys(s.party_menu.draft).length === 0,
    '성장 4: 「확정」 → 스킬 바뀜·남은 SP 0', { skills: sk, sp_left: s.members[1].sp_left });
  let idb = await waitIdb(s);
  check(!idb.timeout, '성장 4: 배분 확정 자동 저장이 IndexedDB 에 반영', idb);
  // 5. supply → 장비 탭 → 칸 0 → 이온 세이버 줄.
  g = s.generation;
  r = await request({ op: 'supply', item: ION_SABER, n: 1 });
  s = await waitFor((x) => x.generation > g, 'supply 저장');
  check(r.ok && s.gear_bag[ION_SABER] === 1, '성장 5: supply → 가방', { gear_bag: s.gear_bag });
  const atk0 = s.members[1].gear.atk;
  await clickButton('Tab_equip');
  s = await waitFor((x) => x.party_menu?.tab === 'equip', '장비 탭');
  await clickButton('Slot_0');
  s = await waitFor((x) => x.party_menu?.cursor?.list_open, '칸 0 목록');
  const row = s.party_menu.equip_rows.find((x) => x.item === ION_SABER);
  check(row && row.block === '', '성장 5: 목록에 낄 수 있는 이온 세이버 줄', { rows: s.party_menu.equip_rows });
  await page.screenshot({ path: `${outDir}/12_party_equip_${tag}.png` });
  g = s.generation;
  await clickButton(row.button);
  s = await waitFor((x) => x.generation > g && !x.party_menu?.cursor?.list_open, '장착 저장');
  check(s.members[1].equip[0] === ION_SABER && s.members[1].gear.atk === atk0 + 8 && s.members[1].attack_element === 'volt'
    && s.gear_bag[ION_SABER] === undefined && s.gear_bag['equip.twin_edge'] === 1,
  '성장 5: 장착 → 공격 +8·일반 공격 전격·가방(트윈 엣지 +1)', { equip: s.members[1].equip, atk: s.members[1].gear.atk, element: s.members[1].attack_element, gear_bag: s.gear_bag });
  idb = await waitIdb(s);
  check(!idb.timeout, '성장 5: 장착 자동 저장이 IndexedDB 에 반영', idb);
  // 6. 새로 고침 → 같은 해시, 메뉴 닫힘, 레벨·스킬·장비 그대로.
  const before = s;
  await page.reload();
  s = await waitReady();
  check(s.hash === before.hash && !s.party_menu?.open && s.members[1].level === 3 && s.members[1].skills[LEG_CUTTER] === 1
    && s.members[1].equip[0] === ION_SABER, '성장 6: 새로 고침 → 같은 해시·메뉴 닫힘·성장 그대로', { before: before.hash.slice(0, 12), after: s.hash.slice(0, 12) });
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));
  // 7. 승리 경로: 고정 저장 가져오기 → 전투 중 「파티」 없음·P 무시 → battle_finish → 결과 창 줄 → 상태 탭.
  await clickButton('MenuButton');
  s = await waitFor((x) => x.modal === 'menu', '메뉴');
  const [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import', s)]);
  await chooser.setFiles(VICTORY_SAVE);
  s = await waitFor((x) => x.battle?.open && x.battle.phase === 'command', '승리 경로 저장 가져오기', 10000);
  check(!s.buttons.PartyButton && s.members[1].exp === 26, '성장 7: 전투 중 「파티」 단추 없음·듀얼리스트 A exp 26', { exp: s.members[1].exp });
  await page.keyboard.press('KeyP');
  await page.waitForTimeout(300);
  s = await snap();
  check(!s.party_menu?.open && s.battle?.open, '성장 7: 전투 중 P 는 메뉴를 열지 않는다');
  g = s.generation;
  r = null;
  for (let k = 0; k < 3 && !r?.ok; k++) {
    if (k) await page.waitForTimeout(100);
    r = await request({ op: 'battle_finish' });
  }
  check(r?.ok, '성장 7: battle_finish', r);
  s = await waitFor((x) => x.generation > g, 'battle_finish 저장');
  if (s.battle?.phase === 'anim') await page.keyboard.press('Enter');
  s = await waitFor((x) => x.battle?.phase === 'result', '결과 창');
  const lines = s.battle.result_lines ?? [];
  check(lines.includes('경험치 +4') && lines.indexOf('레벨 업') === lines.indexOf('듀얼리스트 A  Lv 1 → 2  SP +1') - 1,
    '성장 7: 결과 창 「경험치 +4」·「레벨 업」·「듀얼리스트 A  Lv 1 → 2  SP +1」', { lines });
  await page.screenshot({ path: `${outDir}/13_victory_result_${tag}.png` });
  await clickButton('ResultOk');
  s = await waitFor((x) => !x.battle?.open, '결과 창 닫힘');
  await clickButton('PartyButton');
  s = await waitFor((x) => x.party_menu?.open, '파티 메뉴(승리 뒤)');
  check(s.party_menu.tab === 'status' && s.members[1].level === 2 && s.members[1].sp_left === 1, '성장 7: 상태 탭 Lv 2·SP 1',
    { level: s.members[1].level, sp_left: s.members[1].sp_left });
  await page.screenshot({ path: `${outDir}/14_after_victory_${tag}.png` });
  idb = await waitIdb(s);
  check(!idb.timeout, '성장 7: 승리 자동 저장이 IndexedDB 에 반영', idb);
  return s;
}

try {
  page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1, acceptDownloads: true });
  page.on('console', (m) => { if (m.type() === 'error' || /CONTEXT_LOST/.test(m.text())) report.errors.push(m.text()); });
  page.on('pageerror', (e) => report.errors.push(String(e)));
  await page.goto(url);
  let s = await waitReady();
  check(s.user_dir === '/userfs/sqfangame', 'user:// 경로', { user_dir: s.user_dir });
  check(s.seed === SEED, `새 게임 시드 = 주소의 seed ${SEED}`, { seed: s.seed });
  check(s.autosaves === 1 && s.modal === '', '새 게임 자동 저장', { autosaves: s.autosaves, modal: s.modal });
  await page.screenshot({ path: `${outDir}/01_start.png` });
  // 캔버스에 키 포커스를 준다(3D 시야 영역 클릭은 아무 일도 하지 않는다).
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));

  // ---- 1) 공략 행동열 ----
  const t0 = Date.now();
  let maxGuard = 0;
  let simRest = null;  // 첫 전투가 끝난 뒤 남은 공략의 simulate 결과
  const realRest = [];
  for (let i = 0; i < route.actions.length; i++) {
    s = await act(route.actions[i]);
    if (simRest) realRest.push(s.actionHash);
    if (!simRest && battles >= 1 && !s.battle?.open) {
      const rest = route.actions.slice(i + 1);
      simRest = { actions: rest.length, ...(await request({ op: 'simulate', actions: rest })) };
    }
    maxGuard = Math.max(maxGuard, Math.abs(s.guard_delta));
    const cp = route.checkpoints.find((c) => c.after === i + 1);
    if (cp && (s.at[0] !== cp.at[0] || s.at[1] !== cp.at[1])) check(false, `체크포인트 ${cp.after}`, { want: cp.at, got: s.at });
    // 경계 겉모습 캡처: 숨은 통로 찾기 전후, 일방통행, 지름길 닫힘·열림.
    if (cp && [13, 14, 58, 61, 88, 89].includes(cp.after)) {
      await page.waitForTimeout(150);
      await page.screenshot({ path: `${outDir}/cp${String(cp.after).padStart(2, '0')}.png` });
    }
  }
  check(s.shortcuts_open === 1, '공략 끝: 지름길 열림', { at: s.at, shortcuts_open: s.shortcuts_open, passages_found: s.passages_found, battles, battleTurns, ms: Date.now() - t0 });
  const restOk = simRest && Array.isArray(simRest.hashes) && simRest.hashes.length === simRest.actions && realRest.length === simRest.actions
    && simRest.hashes.every((h, k) => typeof h === 'string' && h === realRest[k]);
  check(battles >= 1 && reloadChecked, '공략 중 전투가 있었고 전투 중 새로 고침을 확인했다', { battles, reloadChecked });
  check(restOk, `첫 전투 뒤 남은 공략 ${simRest?.actions} 행동: battle_finish 로 넘긴 해시 = simulate`, restOk ? { battles } : {
    battles, error: simRest?.error, sim: simRest?.hashes?.map((h) => String(h).slice(0, 8)), real: realRest.map((h) => String(h).slice(0, 8)) });
  log('공략 끝', { at: s.at, steps: s.steps, generation: s.generation, battles, battleTurns, hp: s.hp, materials: s.materials, last_guard_delta: s.guard_delta, guard_radius: s.guard_radius, plan_ms_max: s.plan_ms_max,
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

  // ---- 6) 준비한 저장으로 전멸 (06 §10.4 5) ----
  const wipeDoc = JSON.parse(fs.readFileSync(exportPath, 'utf8'));
  const enemyDefs = JSON.parse(fs.readFileSync('data/enemies/stratum1.json', 'utf8')).enemies;
  const ratHp = enemyDefs.find((e) => e.id === 'enemy.neon_rat').max_hp;
  const st = wipeDoc.state;
  st.encounter.danger = st.encounter.threshold;
  st.encounter.pending = true;
  st.party.members.forEach((m, i) => { m.hp = i < 4 ? 0 : 1; });
  const unit = (extra) => ({ ailment: null, binds: {}, buffs: [], debuffs: [], resist: {}, ...extra });
  st.battle = { formation: 'formation.f1.rats', turn: 0, seq: 1,
    party: [0, 1, 2, 3, 4].map((i) => unit(i === 4 ? { ailment: { id: 'poison', turns: 3, damage: 5 } } : {})),
    enemies: [0, 1, 2].map(() => unit({ hp: ratHp, charging: null, kill: null })) };
  const wipePath = `${outDir}/wipe_setup.json`;
  fs.writeFileSync(wipePath, JSON.stringify(wipeDoc));
  await clickButton('MenuButton');
  s = await waitFor((x) => x.modal === 'menu', '메뉴');
  [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import', s)]);
  await chooser.setFiles(wipePath);
  s = await waitFor((x) => x.battle?.open && x.battle.phase === 'command', '준비한 전투 가져오기', 10000);
  check(s.battle.member === 4, '가져온 전투: 남은 대원 차례', { member: s.battle.member });
  const gw = s.generation;
  await clickButton('Cmd_guard');
  s = await waitFor((x) => x.battle?.sub === 'confirm', '방어');
  await clickButton('Execute');
  s = await waitFor((x) => x.generation > gw, '제출');
  if (s.battle?.phase === 'anim') await page.keyboard.press('Enter');
  s = await waitFor((x) => x.modal === 'wipe', '전멸 창', 10000);
  check(s.wiped && !s.battle?.open && s.buttons.WipeNewGame, '방어 제출 → 그 턴 전멸 → M1 전멸 창', { wiped: s.wiped });
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/09_wipe.png` });

  // ---- 7) 성장 (07 §10.5) ----
  s = await growthChecks(s);
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
