// web_check 부분 K1~K4(M3 A10a, 05 §24, 실제 미궁 arbor: 주소에 &set 없음, 저장 폴더 saves): 새 게임부터 보스 처치·기록·불러오기까지 한 이야기를 실제 빌드로 걷는다.
// 헤드리스 tests/test_expedition_route.gd 와 같은 이야기이고 다른 점은 이 빌드의 IndexedDB·터치 누르기·새로 고침이다. 한 부분을 5분 안에 끝내려고 넷으로 나눴다.
// 부분 사이에 브라우저를 닫아도 같은 크로미움 프로필이라 IndexedDB(자동 저장)가 남고, 다음 부분은 제목 「이어하기」로 시작한다(k1 이 프로필을 비운다).
// 각 부분은 시작할 때 앞 부분 끝의 해시·세대·소지금(build/check/k_state.json)과 같은지 먼저 본다(교훈 16: 기다린 조건을 다시 단언).
//
// 하강은 임무 구조상 셋이다(헤드리스 시험 머리글): 1) B3F 에 닿는다 2) 「봉인된 문」을 받은 뒤 (9,2) 에 다시 선다 3) permit.boss 를 지니고 봉인까지.
// 걷기는 data/floors/arbor_route.json 을 되풀이한다. 하강 1 에서 행동마다 [층, 칸, 방향]을 build/check/k_trace.json 에 적고(처음 걷기 자취),
// 하강 2·3 은 그 자취와 걸음마다 견준다. 이미 이룬 일을 되풀이하는 걸음(열린 상자의 open, 처음 걷기에서 안 움직인 forward = 열쇠 문 앞 막힘·문 열기)은 건너뛴다.
// 부딪힘 전투로 걸음이 안 되면 같은 걸음을 다시 한다. 전투는 모두 디버그 battle_finish 로 넘긴다(D15). 보스만 실제 명령 턴(battle_commands, 차지가 걸린 턴까지)을 한 뒤 finish.
//
// K1: 새 게임 → 첫 임무(관리국 UI) → B1F 계단 칸 → 마을 문 → 보고 → 공방 비콘 둘 → 하강 1 의 B3F 도착까지.
// K2: 하강 1 의 나머지(B3F (9,2)) → 비콘으로 마을 → 임무 2 받기 → 하강 2 ((9,2) 에 다시 선다).
// K3: 비콘으로 마을 → 임무 2 보고(permit.boss) → 비콘 하나 더 → 숙박 → 디버그 grant_exp 로 Lv 20(통과용, 밸런스 아님 D15) → 하강 3 (봉인 앞).
// K4: 봉인 열기 → 보스 물음 → 전투 → 이야기 → 클리어 → 방 안 비콘 거부 → 걸어 나와 비콘 → 숙소 기록 → 제목 불러오기(클리어 표) → 이어하기.
//
// 소지금(고정): 200 → 보고 +100 = 300 → 비콘 둘 −300 = 0 → 보고 +300 = 300 → 비콘 하나 −150 = 150 → 숙박 −(10 × 최고 레벨).
// 쪽마다 캡처(build/check/k??_*.png).
import fs from 'node:fs';
import path from 'node:path';
import { planOpen } from './web_check_lib.mjs';
import {
  W, H, outDir, KEYS, page, check, log, snap, request, waitFor, waitReady, clickButton, enterLabyrinth, finishBattle, waitIdb, waitTitle, idbAuto,
} from './web_check_common.mjs';

const route = JSON.parse(fs.readFileSync('data/floors/arbor_route.json', 'utf8'));
const acts = route.actions;
const growth = JSON.parse(fs.readFileSync('data/rules/growth.json', 'utf8'));
const LEVEL_STEP = 20;
const CUM = (lv) => growth.exp_next.slice(0, lv - 1).reduce((a, b) => a + b, 0);
const TRACE = path.join(outDir, 'k_trace.json');
const STATE = path.join(outDir, 'k_state.json');
const M1 = 'mission.permit_b2f';
const M2 = 'mission.boss_seal';
const BEACON = 'use.ariadne_beacon';
const MISSION_NOTE = '임무 「아보르 탐사 허가」의 목표를 이뤘다. 관리국에 보고하자';
const ASK = '네온 펜리르가 버티고 서 있다. 싸울까?\n이 싸움에서는 도망칠 수 없다';
const INVERSE = { forward: 'back', back: 'forward', strafe_left: 'strafe_right', strafe_right: 'strafe_left', turn_left: 'turn_right', turn_right: 'turn_left' };
let battlesK = 0;
// trace = 행동마다 처음 걷기의 [층, 칸, 방향], opens = open 행동 번호 → 처음 걷기에서 연 상자 {kind, pos, id}(되풀이가 같은 상자인지 본다).
let trace = [];
let opens = {};
const loadTrace = () => {
  const d = fs.existsSync(TRACE) ? JSON.parse(fs.readFileSync(TRACE, 'utf8')) : { trace: [], opens: {} };
  trace = d.trace;
  opens = d.opens;
};
const saveTrace = () => fs.writeFileSync(TRACE, JSON.stringify({ trace, opens }));
const posOf = (s) => [s.floor, s.at[0], s.at[1], s.facing];
const samePos = (a, b) => !!a && !!b && a.length === b.length && a.every((v, i) => v === b[i]);

async function shot(name) {
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/${name}_${W}x${H}.png` });
}

// ---- 부분 사이 상태 ----

async function saveState(tag, s) {
  const idb = await waitIdb(s);
  check(!idb.timeout, `${tag}: 끝 자동 저장이 IndexedDB 에 반영`, idb);
  fs.writeFileSync(STATE, JSON.stringify({ tag, hash: s.hash, generation: s.generation, money: s.money, floor: s.floor, at: s.at, location: s.location }));
}

// 부분 시작: 제목 「이어하기」(waitReady)로 열어 앞 부분 끝과 같은지 본다. 반환: 상태 요약.
async function resume(tag) {
  if (!fs.existsSync(STATE)) throw new Error(`${tag}: 앞 부분의 상태 파일이 없다(${STATE}). k1 부터 차례로 돌려야 한다`);
  const want = JSON.parse(fs.readFileSync(STATE, 'utf8'));
  const s = await waitReady();
  check(s.set === 'game' && s.hash === want.hash && s.generation === want.generation && s.money === want.money && s.location === want.location,
    `${tag}: 이어하기 = 앞 부분(${want.tag}) 끝과 같은 해시·세대·소지금·장소`, { want: { hash: want.hash.slice(0, 12), generation: want.generation, money: want.money, location: want.location },
      got: { hash: s.hash.slice(0, 12), generation: s.generation, money: s.money, location: s.location } });
  return s;
}

// 같은 부분 안의 새로 고침: 닫기 전에 IndexedDB = 화면, 연 뒤 같은 해시·세대·소지금.
async function reloadHere(tag, s) {
  const idb = await waitIdb(s);
  check(!idb.timeout, `${tag}: 새로 고침 전 IndexedDB = 화면`, idb);
  await page.reload();
  const r = await waitReady();
  check(r.hash === s.hash && r.generation === s.generation && r.money === s.money && r.location === s.location && r.modal === '',
    `${tag}: 새로 고침 → 같은 해시·세대·소지금, 물음 없음`, { before: [s.hash.slice(0, 12), s.generation, s.money], after: [r.hash.slice(0, 12), r.generation, r.money], modal: r.modal });
  if (r.location === 'labyrinth') await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));  // 캔버스에 키 포커스(마을에서는 광장 줄을 누르게 되므로 하지 않는다)
  return r;
}

// ---- 걷기 ----

// 상자 근거: 층 정의(data/floors/<층>.json)에서 칸에 정의된 상자 id, 저장 문서의 열린 상자 id 목록(state.floor_states.<층>.world.chests_opened).
const floorChests = {};
for (const f of ['b1f', 'b2f', 'b3f']) {
  floorChests[f] = {};
  for (const c of JSON.parse(fs.readFileSync(`data/floors/${f}.json`, 'utf8')).chests ?? []) floorChests[f][`${c.at[0]}:${c.at[1]}`] = c.id;
}
const openEnv = (doc) => ({
  chestAt: (floor, x, y) => floorChests[floor]?.[`${x}:${y}`] ?? '',
  opened: (floor) => doc?.state?.floor_states?.[floor]?.world?.chests_opened ?? [],
});

async function press(name) {
  const before = await snap();
  await page.keyboard.press(KEYS[name]);
  let s = await waitFor((x) => x.generation > before.generation && !x.busy, `행동 ${name}`);
  let fought = false;
  if (s.battle?.open) {
    battlesK += 1;
    fought = true;
    s = await finishBattle(s, false);
    s = await waitFor((x) => !x.battle?.open && !x.busy, '전투 뒤 탐색');
  }
  return { s, fought };
}

async function answerNo(no) {
  await clickButton(no);
  return waitFor((x) => x.modal === '' && !x.busy, no);
}

// 공략의 open·stairs: 물음이 떠 있지 않으면(전투가 난 걸음) 조사로 다시 묻고 「예」.
async function answerYes(kind, yes) {
  let s = await snap();
  if (s.modal !== kind) {
    ({ s } = await press('investigate'));
    s = await waitFor((x) => x.modal === kind, `조사로 ${kind} 물음`);
  }
  const g = s.generation;
  await clickButton(yes);
  return waitFor((x) => x.modal === '' && x.generation > g && !x.busy, `${kind} 「예」`);
}

// 공략 행동 [from, to) 를 걷는다. pass 1 = 처음 걷기(자취를 적는다, 그 부분 끝에서 saveTrace), 2·3 = 되풀이(자취와 견주고 이룬 일은 건너뛴다). rec 이 있으면 움직인 행동을 적는다.
async function walk(from, to, tag, pass, rec = null) {
  for (let i = from; i < to; i++) {
    const a = acts[i];
    const next = acts[i + 1];
    let s = await snap();
    if (a === 'open') {
      // 처음 걷기: 닫힌 상자를 적고 연다. 되풀이: 적어 둔 같은 상자가 층 정의의 같은 칸에 있고 저장 상태(IndexedDB 자동 저장)의 열린 목록에 있을 때만 건너뛴다
      // (없음·다름·닫힘은 행동 번호를 붙여 실패). 요약의 chest_here 만으로는 열린 상자와 없는 상자를 가르지 못한다(web_check_lib.mjs planOpen).
      let doc = null;
      if (opens[i]) {
        const idb = await waitIdb(s);
        check(!idb.timeout, `${tag} #${i + 1} open: 저장 상태 근거를 읽기 전 IndexedDB = 화면`, idb);
        const stored = await idbAuto();
        doc = JSON.parse(stored.text);
      }
      const plan = planOpen(opens[i], i, s, tag, openEnv(doc));
      if (plan.act === 'fail') throw new Error(plan.error);
      if (plan.act === 'open') {
        opens[i] = plan.record;
        s = await answerYes('chest', 'ChestYes');
      }
      if (pass === 1) trace[i] = posOf(s);
      continue;
    }
    if (a === 'stairs') {
      s = await answerYes('stairs', 'StairsYes');
      if (pass === 1) trace[i] = posOf(s);
      else check(samePos(posOf(s), trace[i]), `${tag} #${i + 1}: 계단 뒤 자취와 같은 자리`, { got: posOf(s), want: trace[i] });
      continue;
    }
    if (pass > 1 && a === 'forward' && i > 0 && samePos(trace[i], trace[i - 1])) continue;  // 처음 걷기에서 안 움직인 forward(문 앞 막힘·문 열기): 이미 이룸
    const before = posOf(s);
    let fought = false;
    for (let attempt = 0; attempt < 3; attempt++) {
      const r = await press(a);
      s = r.s;
      fought = fought || r.fought;
      if (pass === 1 || samePos(posOf(s), trace[i]) || !fought) break;  // 부딪힘 전투로 안 움직였으면 같은 걸음을 다시
    }
    if (pass === 1) trace[i] = posOf(s);
    else if (!samePos(posOf(s), trace[i])) throw new Error(`${tag} #${i + 1} ${a}: 자취와 다르다 ${JSON.stringify(posOf(s))} ≠ ${JSON.stringify(trace[i])}`);
    if (rec) rec.push([a, before]);
    if (s.modal === 'chest' && next !== 'open') s = await answerNo('ChestNo');
    if (s.modal === 'stairs' && next !== 'stairs') s = await answerNo('StairsNo');
    const cp = pass === 1 ? route.checkpoints.find((c) => c.after === i + 1) : null;
    if (cp) check(s.floor === cp.floor && s.at[0] === cp.at[0] && s.at[1] === cp.at[1], `${tag}: 체크포인트 「${cp.note}」`, { floor: s.floor, at: s.at });
  }
  return snap();
}

// ---- 마을 도우미 ----

const rows = (s) => s.quest_screen?.rows ?? [];
async function pickRow(s, id) {
  const k = rows(s).findIndex((r) => r.id === id);
  if (k < 0) throw new Error(`줄 없음: ${id} (${JSON.stringify(rows(s))})`);
  await clickButton(`QuestRow_${k}`);
  return waitFor((x) => x.quest_screen?.dialog?.mode === 'confirm' || x.quest_screen?.notice, `${id} 고름`);
}
async function yesQuest(s, what) {
  const g = s.generation;
  await clickButton('Yes');
  return waitFor((x) => x.generation > g && x.quest_screen?.dialog?.mode === '' && !x.busy, what);
}
async function toPlaza() {
  for (let k = 0; k < 4; k++) {
    const s = await snap();
    if (!s.quest_screen?.open && !s.shop?.open && s.town?.page === 'plaza' && s.modal === '') break;
    await page.keyboard.press('Escape');
    await page.waitForTimeout(150);
  }
  return waitFor((x) => !x.quest_screen?.open && !x.shop?.open && x.town?.page === 'plaza', '광장');
}
// 관리국 받기/보고: 줄을 눌러 「예」. 돌려주는 것은 저장 뒤 상태(보고면 결과 줄이 quest_screen.box 에 있다).
async function council(pageName, id, tag) {
  await toPlaza();
  await clickButton('Plaza_council');
  await waitFor((x) => x.quest_screen?.open && x.quest_screen.giver === 'council' && x.quest_screen.page === 'root', `${tag}: 관리국 뿌리`);
  await clickButton(pageName === 'accept' ? 'Quest_accept' : 'Quest_report');
  let s = await waitFor((x) => x.quest_screen?.page === pageName, `${tag}: ${pageName} 목록`);
  s = await pickRow(s, id);
  check(s.quest_screen.dialog.pick === 0 && s.buttons.Yes, `${tag}: 확인 창 「예」 먼저`, { dialog: s.quest_screen.dialog });
  return yesQuest(s, `${tag} 저장`);
}
async function shopBeacons(n, tag) {
  await toPlaza();
  await clickButton('Plaza_shop');
  await waitFor((x) => x.shop?.open && x.shop.page === 'root', `${tag}: 공방 뿌리`);
  await clickButton('Root_buy');
  await waitFor((x) => x.shop?.page === 'branch', `${tag}: 구매 갈래`);
  await clickButton('Branch_item');
  let s = await waitFor((x) => x.shop?.page === 'buy' && x.shop.branch === 'item' && x.shop.rows.length > 0, `${tag}: 아이템 목록`);
  const k = s.shop.rows.findIndex((r) => r.name === '아리아드네 비콘');
  if (k < 0) throw new Error(`${tag}: 진열에 비콘이 없다 ${JSON.stringify(s.shop.rows.map((r) => r.name))}`);
  await clickButton(`Row_${k}`);
  s = await waitFor((x) => x.shop?.dialog?.mode === 'qty', `${tag}: 수량 창`);
  for (let i = 1; i < n; i++) await page.keyboard.press('ArrowUp');
  s = await waitFor((x) => x.shop.dialog.qty === n, `${tag}: ${n}개`);
  const g = s.generation;
  await clickButton('Yes');
  s = await waitFor((x) => x.generation > g && x.shop?.dialog?.mode === '' && !x.busy, `${tag}: 사기 저장`);
  return s;
}
async function openItems() {
  await clickButton('CampButton');
  await waitFor((x) => x.party_menu?.open && x.party_menu.page === 'root', '캠프 뿌리');
  await clickButton('Camp_items');
  let s = await waitFor((x) => x.party_menu?.page === 'sub' && x.party_menu.tab === 'items' && x.party_menu.item_rows?.length > 0, '소지품');
  for (let k = 0; k < 12 && s.party_menu.items.item !== BEACON; k++) {
    await page.keyboard.press('ArrowDown');
    await page.waitForTimeout(100);
    s = await snap();
  }
  return s;
}
async function beaconToTown(tag) {
  let s = await openItems();
  check(s.party_menu.items.item === BEACON && s.party_menu.items.use === 'on', `${tag}: 캠프 소지품 커서 = 비콘, 「쓰기」 켜짐`, { items: s.party_menu.items });
  await page.keyboard.press('Enter');
  s = await waitFor((x) => x.party_menu.items.mode === 'pills', `${tag}: 알약 쪽`);
  await page.keyboard.press('Enter');
  s = await waitFor((x) => x.party_menu.dialog === 'beacon', `${tag}: 비콘 확인 창`);
  const g = s.generation;
  await clickButton('DialogOk');
  s = await waitFor((x) => x.generation > g && x.location === 'town' && x.town?.open && !x.party_menu?.open && !x.busy, `${tag}: 비콘 → 광장`);
  check(s.town.page === 'plaza', `${tag}: 비콘 → 마을 광장`, { page: s.town.page });
  return s;
}
async function innStay(tag) {
  await toPlaza();
  await clickButton('Plaza_inn');
  await waitFor((x) => x.town?.page === 'inn', `${tag}: 숙소`);
  await clickButton('Inn_stay');
  let s = await waitFor((x) => x.town?.dialog?.mode === 'confirm', `${tag}: 숙박 확인`);
  const day0 = s.day;
  await clickButton('Yes');
  s = await waitFor((x) => x.day === day0 + 1 && x.town?.dialog?.mode === '' && !x.busy, `${tag}: 숙박`);
  return s;
}
const lowHp = (s) => Math.min(...s.members.map((m, i) => Math.round((100 * s.hp[i]) / m.max_hp)));
const eachHp = (s) => s.members.map((m, i) => `${m.id} ${s.hp[i]}/${m.max_hp}`);

// ============================ K1 ============================

export async function partK1() {
  const t0 = Date.now();
  trace = [];
  opens = {};
  saveTrace();
  // 1) 제목 「새 게임」(빈 프로필이라 이어하기·확인 창 없음) → 광장.
  const title = await waitTitle();
  check(title.buttons.TitleNewGame && !title.buttons.TitleContinue && !title.title?.continue, 'K1 1: 빈 프로필 제목 = 새 게임만(이어하기 없음)', { title: title.title, buttons: Object.keys(title.buttons) });
  let s = await waitReady();
  check(s.set === 'game' && s.location === 'town' && s.town?.page === 'plaza' && s.day === 1 && s.money === 200 && s.flags.length === 0 && s.autosaves === 1,
    'K1 1: 새 게임 → 마을 광장·1일째·소지금 200·플래그 없음·자동 저장 하나', { location: s.location, day: s.day, money: s.money, flags: s.flags, autosaves: s.autosaves });
  await shot('k101_plaza');
  s = await reloadHere('K1 P1 새 게임 직후', s);
  // 2) 관리국에서 첫 임무.
  s = await council('accept', M1, 'K1 2');
  check(s.quests[M1]?.status === 'accepted' && s.quest_screen.notice === '「아보르 탐사 허가」 임무를 받았다', 'K1 2: 첫 임무 받음(안내·수락 중)', { quest: s.quests[M1], notice: s.quest_screen.notice });
  await toPlaza();
  s = await reloadHere('K1 P2 첫 임무 받은 뒤', await snap());
  // 3) B1F 계단 칸까지 → 되돌아 마을.
  s = await enterLabyrinth();
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));
  const rec = [];
  s = await walk(0, 28, 'K1 3 B1F 계단 칸까지', 1, rec);
  check(s.floor === 'b1f' && s.at[0] === 17 && s.at[1] === 1 && s.modal === '' && s.toast === MISSION_NOTE && s.quests[M1]?.status === 'done',
    'K1 3: B1F 계단 칸 → 임무 달성 안내(허가 안내 아님), 물음 없음, 목표 달성', { at: s.at, modal: s.modal, toast: s.toast, quest: s.quests[M1] });
  for (const [a, before] of rec.slice().reverse()) {
    const r = await press(INVERSE[a]);
    check(samePos(posOf(r.s), before) || r.fought || r.s.modal === 'stairs', `K1 3: 되돌기 ${INVERSE[a]}`, { got: posOf(r.s), want: before });
    if (r.s.modal === 'stairs') break;
  }
  s = await waitFor((x) => x.modal === 'stairs', 'K1 3: 마을 문 물음');
  await clickButton('StairsYes');
  s = await waitFor((x) => x.location === 'town' && x.town?.page === 'plaza' && !x.busy, 'K1 3: 마을');
  // 4) 보고.
  s = await council('report', M1, 'K1 4');
  const lines = s.quest_screen.box.lines;
  check(lines[0] === '100엔' && lines[1] === '받은 허가: B2F 탐사 허가' && lines[2] === '경험치 30' && s.money === 300 && JSON.stringify(s.flags) === '["permit.b2f"]'
    && s.quests[M1]?.status === 'finished', 'K1 4: 보고 → 100엔·허가·경험치 30, 소지금 300, flags [permit.b2f]', { lines, money: s.money, flags: s.flags });
  await toPlaza();
  s = await reloadHere('K1 P3 첫 임무 보고 뒤', await snap());
  // 5) 공방에서 비콘 둘.
  s = await shopBeacons(2, 'K1 5');
  const matCount = Object.values(s.materials).reduce((a, b) => a + b, 0);
  check(s.money === 0 && s.consumables[BEACON] === 2 && s.bag_used === 2 + matCount, 'K1 5: 비콘 둘 → 소지금 0·비콘 2·가방 = 비콘 2 + 소재(상자 c1 에서 얻은 것)', { money: s.money, consumables: s.consumables, bag_used: s.bag_used, materials: s.materials });
  await shot('k102_beacons');
  s = await toPlaza().then(() => snap());
  s = await reloadHere('K1 P4 비콘을 산 뒤', s);
  // 6) 하강 1: B3F 도착까지.
  s = await enterLabyrinth();
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));
  s = await walk(0, 29, 'K1 6 하강1 B2F', 1);
  check(s.floor === 'b2f' && s.at[0] === 17 && s.at[1] === 1 && s.toast === '네온 이끼숲 / B2F', 'K1 6: B2F 도착', { floor: s.floor, at: s.at, toast: s.toast });
  log('P5 B2F 도착', { low_hp_pct: lowHp(s), money: s.money, members: eachHp(s) });
  s = await reloadHere('K1 P5 B2F 도착', s);
  s = await walk(29, 96, 'K1 6 하강1 B3F', 1);
  check(s.floor === 'b3f' && s.at[0] === 17 && s.at[1] === 18 && s.toast === '네온 이끼숲 / B3F', 'K1 6: B3F 도착', { floor: s.floor, at: s.at, toast: s.toast });
  log('P6 B3F 도착', { low_hp_pct: lowHp(s), money: s.money, members: eachHp(s) });
  await shot('k103_b3f');
  s = await reloadHere('K1 P6 B3F 도착', s);
  saveTrace();
  await saveState('K1', s);
  log('부분 K1 끝', { battles: battlesK, seconds: Math.round((Date.now() - t0) / 1000) });
}

// ============================ K2 ============================

export async function partK2() {
  const t0 = Date.now();
  loadTrace();
  let s = await resume('K2 0');
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));
  check(trace.length >= 96 && s.floor === 'b3f' && s.location === 'labyrinth', 'K2 0: 하강 1 자취 96개 이상, B3F 위', { trace: trace.length, floor: s.floor });
  // 하강 1 의 나머지.
  s = await walk(96, 144, 'K2 1 하강1 봉인 앞', 1);
  saveTrace();
  check(trace.filter(Boolean).length === 144, 'K2 1: 처음 걷기 자취 144개(0~143)', { n: trace.filter(Boolean).length });
  check(s.floor === 'b3f' && s.at[0] === 9 && s.at[1] === 2 && s.facing === 3 && s.key_items.length === 2 && s.quests[M2]?.status !== 'accepted', 'K2 1: (9,2) 서쪽, 열쇠 둘, 임무 2 아직 안 받음',
    { at: s.at, facing: s.facing, key_items: s.key_items, quest: s.quests[M2] });
  log('P6b 하강1 끝', { low_hp_pct: lowHp(s), money: s.money, members: eachHp(s) });
  // 2) 비콘으로 마을 → 임무 2 받기.
  s = await beaconToTown('K2 2 하강1');
  check(s.consumables[BEACON] === 1 && s.money === 0, 'K2 2: 비콘 하나 남음·소지금 0', { consumables: s.consumables, money: s.money });
  s = await reloadHere('K2 P7 비콘으로 돌아온 뒤', s);
  s = await council('accept', M2, 'K2 3');
  check(s.quests[M2]?.status === 'accepted', 'K2 3: 임무 「봉인된 문」 받음', { quest: s.quests[M2] });
  await shot('k201_m2_accepted');
  await toPlaza();
  s = await reloadHere('K2 P8 임무 2 받은 뒤', await snap());
  // 3) 하강 2: (9,2) 에 다시 선다.
  s = await enterLabyrinth();
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));
  s = await walk(0, 144, 'K2 4 하강2', 2);
  check(s.floor === 'b3f' && s.at[0] === 9 && s.at[1] === 2 && s.quests[M2]?.status === 'done', 'K2 4: 하강 2 → (9,2), 임무 2 목표 달성(받은 뒤의 걸음)', { at: s.at, quest: s.quests[M2] });
  log('P9 하강2 끝', { low_hp_pct: lowHp(s), money: s.money, members: eachHp(s) });
  await saveState('K2', s);
  log('부분 K2 끝', { battles: battlesK, seconds: Math.round((Date.now() - t0) / 1000) });
}

// ============================ K3 ============================

export async function partK3() {
  const t0 = Date.now();
  loadTrace();
  let s = await resume('K3 0');
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));
  check(s.floor === 'b3f' && s.at[0] === 9 && s.at[1] === 2 && s.quests[M2]?.status === 'done', 'K3 0: B3F (9,2), 임무 2 목표 달성', { at: s.at, quest: s.quests[M2] });
  // 1) 비콘 → 보고.
  s = await beaconToTown('K3 1 하강2');
  check(s.consumables[BEACON] === undefined && s.money === 0, 'K3 1: 비콘 다 씀·소지금 0', { consumables: s.consumables, money: s.money });
  s = await council('report', M2, 'K3 2');
  check(s.money === 300 && s.flags.includes('permit.boss') && s.quests[M2]?.status === 'finished' && s.quest_screen.box.lines[0] === '300엔',
    'K3 2: 임무 2 보고 → 300엔·permit.boss', { money: s.money, flags: s.flags, lines: s.quest_screen.box.lines });
  await toPlaza();
  s = await reloadHere('K3 P9 임무 2 보고 뒤', await snap());
  // 2) 비콘 하나(150), 숙박(현재 레벨 값), 그다음 Lv 20.
  s = await shopBeacons(1, 'K3 3');
  check(s.money === 150 && s.consumables[BEACON] === 1, 'K3 3: 세 번째 비콘 → 소지금 150', { money: s.money, consumables: s.consumables });
  const price = 10 * Math.max(...s.members.map((m) => m.level));
  s = await innStay('K3 4');
  check(s.day === 2 && s.money === 150 - price && s.hp.every((h, i) => h === s.members[i].max_hp), `K3 4: 숙박 → 2일째·값 ${price}·HP 가득`, { day: s.day, money: s.money, hp: s.hp });
  for (let i = 0; i < s.members.length; i++) {
    const r = await request({ op: 'grant_exp', member: i, n: CUM(LEVEL_STEP) - s.members[i].exp });
    check(r.ok === true, `K3 5: 디버그 grant_exp 대원 ${i}(통과용 레벨 올리기)`, r);
  }
  s = await waitFor((x) => x.members.every((m) => m.level === LEVEL_STEP) && !x.busy, 'K3 5: 다섯 모두 Lv 20');
  check(s.hp.every((h, i) => h === s.members[i].max_hp), 'K3 5: 레벨을 올린 뒤에도 HP 가득', { hp: s.hp, max: s.members.map((m) => m.max_hp) });
  s = await reloadHere('K3 P10 레벨 올린 뒤', s);
  check(s.members.every((m) => m.level === LEVEL_STEP), 'K3 5: 다시 열어도 Lv 20', { levels: s.members.map((m) => m.level) });
  // 3) 하강 3: 봉인 앞.
  s = await enterLabyrinth();
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));
  s = await walk(0, 144, 'K3 6 하강3', 3);
  check(s.floor === 'b3f' && s.at[0] === 9 && s.at[1] === 2 && s.facing === 3 && s.flags.includes('permit.boss') && s.locks_open >= 1, 'K3 6: 봉인 앞 (9,2) 서쪽, permit.boss', { at: s.at, facing: s.facing });
  await shot('k301_seal');
  await saveState('K3', s);
  log('부분 K3 끝', { battles: battlesK, seconds: Math.round((Date.now() - t0) / 1000) });
}

// ============================ K4 ============================

export async function partK4() {
  const t0 = Date.now();
  let s = await resume('K4 0');
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));
  const locks0 = s.locks_open;
  // 1) 봉인 열기 → 보스 앞.
  await page.keyboard.press(KEYS.forward);
  s = await waitFor((x) => x.toast === '관리국의 허가 신호에 봉인이 풀렸다' && !x.busy, 'K4 1: 봉인 열림 알림');
  check(s.at[0] === 9 && s.locks_open === locks0 + 1, 'K4 1: 앞으로 → 봉인 열림 알림, 제자리, 연 문 +1', { at: s.at, locks: [locks0, s.locks_open] });
  s = await reloadHere('K4 P11 봉인이 열린 뒤', s);
  check(s.locks_open === locks0 + 1, 'K4 1: 다시 열어도 봉인 열림', { locks: s.locks_open });
  for (let k = 0; k < 4; k++) s = (await press('forward')).s;
  check(s.at[0] === 5 && s.at[1] === 2 && !s.battle?.open && s.boss_near === 'boss', 'K4 2: (5,2) 보스 앞, 전투 없음', { at: s.at, boss_near: s.boss_near });
  // 2) 물음 「아니오」 → 다시 「예」.
  await page.keyboard.press(KEYS.forward);
  s = await waitFor((x) => x.modal === 'boss' && !x.busy, 'K4 3: 보스 물음');
  check(s.modal_title === '강대한 기척' && s.modal_text === ASK && s.modal_focus === 'BossNo', 'K4 3: 물음 창(제목·글·경고), 처음 커서 「아니오」', { title: s.modal_title, text: s.modal_text, focus: s.modal_focus });
  const g3 = s.generation;
  const h3 = s.hash;
  await clickButton('BossNo');
  s = await waitFor((x) => x.modal === '' && !x.busy, 'K4 3: 물음 닫힘');
  await page.waitForTimeout(300);
  s = await snap();
  check(s.generation === g3 && s.hash === h3 && !s.battle?.open, 'K4 3: 「아니오」 → 닫기만(저장·상태 그대로)', { generation: [g3, s.generation] });
  await page.keyboard.press(KEYS.forward);
  await waitFor((x) => x.modal === 'boss' && !x.busy, 'K4 3: 보스 물음 다시');
  await clickButton('BossYes');
  s = await waitFor((x) => x.battle?.open && x.battle.phase === 'command' && !x.busy, 'K4 3: 보스 전투');
  check(s.battle.foe === 'boss' && s.battle.music_cue === 'boss' && s.battle.enemy_hp[0] === 1800, 'K4 3: 「예」 → 보스 전투(펜리르 1800, music_cue boss)', { battle: { foe: s.battle.foe, music: s.battle.music_cue, hp: s.battle.enemy_hp } });
  await shot('k401_boss_battle');
  // 3) 실제 명령 턴(모두 적 0 공격)을 보스가 차지를 건 첫 턴까지 → 새로 고침 → 같은 전투(해시·턴·차지) → finish.
  // 스냅숏에는 그려진 딱지(강화·약화 칩)가 없다 — 이 부분은 차지(battle.charging)와 해시·턴으로만 본다. 그려진 딱지는 헤드리스 test_expedition_route 의 P12 가 본다.
  const isCharging = (x) => (x.battle?.charging ?? []).some((c) => typeof c === 'string' && c.length > 0);
  let turnsK4 = 0;
  while (!isCharging(s) && turnsK4 < 12 && s.battle?.open && s.battle.phase === 'command') {
    const cmds = s.battle.can_command.map((ok) => (ok ? { kind: 'attack', target: 0 } : null));
    const g = s.generation;
    let rr = null;
    for (let k = 0; k < 3 && !rr?.ok; k++) {
      if (k) await page.waitForTimeout(100);
      rr = await request({ op: 'battle_commands', commands: cmds });
    }
    check(rr?.ok, `K4 4: battle_commands 턴 ${turnsK4 + 1}(모두 적 0 공격)`, rr);
    s = await waitFor((x) => x.generation > g && x.battle?.phase !== 'anim' && !x.busy, `K4 4: 턴 ${turnsK4 + 1} 끝`, 30000);
    turnsK4 += 1;
  }
  check(s.battle?.open && s.battle.phase === 'command' && isCharging(s) && s.battle.turn === turnsK4 && s.battle.enemy_hp[0] < 1800,
    `K4 4: 보스가 차지를 건 턴(턴 ${turnsK4})에 전투가 이어지고 펜리르 HP 가 줄었다`, { turn: s.battle?.turn, hp: s.battle?.enemy_hp, charging: s.battle?.charging, phase: s.battle?.phase });
  const idb = await waitIdb(s);
  check(!idb.timeout, 'K4 4: 턴 자동 저장이 IndexedDB 에 반영', idb);
  await page.reload();
  const r = await waitReady();
  check(r.hash === s.hash && r.battle?.open && r.battle.phase === 'command' && r.battle.turn === s.battle.turn && r.battle.foe === 'boss' && r.battle.music_cue === 'boss'
    && JSON.stringify(r.battle.charging) === JSON.stringify(s.battle.charging) && isCharging(r),
  'K4 P12 보스 전투 새로 고침 → 같은 해시·같은 턴·같은 차지(비어 있지 않음)·보스 전투', { before: s.hash.slice(0, 12), after: r.hash.slice(0, 12), turn: [s.battle.turn, r.battle?.turn], charging: [s.battle.charging, r.battle?.charging] });
  await page.mouse.click(Math.round(W * 0.3), 30);
  s = await finishBattle(r, false);
  // 4) 이야기 → 클리어.
  s = await waitFor((x) => x.modal === 'clear' && !x.busy, 'K4 5: 이야기 상자');
  check(s.story.page === 0 && s.story.pages === 3 && s.story.speaker === '관리국 통신', 'K4 5: 결과 「확인」 → 이야기 상자(관리국 통신, 쪽 셋)', { story: s.story });
  await shot('k402_story');
  const hClear = s.hash;
  await clickButton('StoryTap');
  await waitFor((x) => x.story?.page === 1, 'K4 5: 둘째 쪽');
  await clickButton('VPad_ok');
  s = await waitFor((x) => x.story?.page === 2 && x.story.last === true, 'K4 5: 셋째(마지막) 쪽');
  await clickButton('StoryNext');
  s = await waitFor((x) => x.modal === '' && !x.busy, 'K4 5: 이야기 닫힘');
  check(s.hash === hClear && JSON.stringify(s.cleared) === '["b3f"]', 'K4 5: 이야기는 보이기만(해시 그대로), cleared [b3f]', { cleared: s.cleared });
  s = await reloadHere('K4 P13 클리어 뒤', s);
  check(JSON.stringify(s.cleared) === '["b3f"]' && s.modal === '' && s.foes.find((f) => f.id === 'boss')?.state === 'defeated', 'K4 5: 다시 열어도 클리어·보스 defeated, 이야기 다시 안 뜸', { cleared: s.cleared, modal: s.modal });
  // 5) 방 안에서는 비콘 거부, 걸어 나가 비콘.
  s = await openItems();
  check(s.party_menu.items.item === BEACON && s.party_menu.items.use === 'dim', 'K4 6: 보스 방에서 비콘 「쓰기」 흐림', { items: s.party_menu.items });
  await page.keyboard.press('Enter');
  await waitFor((x) => x.party_menu.items.mode === 'pills', 'K4 6: 알약 쪽');
  await page.keyboard.press('Enter');
  s = await waitFor((x) => x.party_menu.notice === '이곳에서는 비콘 신호가 닿지 않는다', 'K4 6: 비콘 이유');
  check(s.location === 'labyrinth' && s.party_menu.dialog === '' && s.consumables[BEACON] === 1, 'K4 6: 「쓰기」 → 이유 「이곳에서는 비콘 신호가 닿지 않는다」, 비콘 그대로', { notice: s.party_menu.notice });
  for (let k = 0; k < 4 && (await snap()).party_menu?.open; k++) {
    await page.keyboard.press('Escape');
    await page.waitForTimeout(150);
  }
  await waitFor((x) => !x.party_menu?.open && x.modal === '', 'K4 6: 캠프 닫힘');
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));
  await press('turn_left');
  await press('turn_left');
  for (let k = 0; k < 5; k++) s = (await press('forward')).s;
  check(s.floor === 'b3f' && s.at[0] === 10 && s.at[1] === 2, 'K4 6: 열린 봉인을 지나 방 밖 (10,2)', { at: s.at });
  s = await beaconToTown('K4 6 방 밖');
  check(s.consumables[BEACON] === undefined, 'K4 6: 비콘 사용 → 마을', { consumables: s.consumables });
  // 6) 숙소 기록 → 제목 불러오기 → 클리어 표.
  await toPlaza();
  await clickButton('Plaza_inn');
  await waitFor((x) => x.town?.page === 'inn', 'K4 7: 숙소');
  await clickButton('Inn_save');
  await waitFor((x) => x.town?.page === 'inn_save', 'K4 7: 숙소 기록');
  await clickButton('Save_slot1');
  s = await waitFor((x) => x.town?.records?.cards?.[0]?.[1] !== '', 'K4 7: 슬롯 1 기록');
  const slotHash = s.hash;
  check(s.town.records.cards[0][1].startsWith('뿌리마을 광장 · 걸음'), 'K4 7: 슬롯 1 = 마을 광장 기록', { cards: s.town.records.cards });
  // 슬롯 쓰기는 IndexedDB 에 비동기로 들어간다: 닫기 전에 저장 대기(save_pending)가 비었는지 본다(자동 저장은 waitIdb 가 본다).
  s = await waitFor((x) => x.save_pending === false, 'K4 7: 슬롯 저장이 IndexedDB 에 반영', 30000);
  check(s.save_pending === false, 'K4 7: 저장 대기 없음(슬롯 1 이 IndexedDB 에 들어감)', { pending: s.save_pending, gens: s.save_pending_gens });
  await page.reload();
  await page.waitForFunction(() => window.sqfDebug && window.sqfDebug.ready, null, { timeout: 60000 });
  let t = await waitTitle();
  await clickButton('TitleLoad');
  await page.waitForTimeout(150);
  // 제목에는 상태가 없어 해시가 빈 글이라 waitFor 를 쓰지 못한다: 불러오기 판의 클리어 줄이 나올 때까지 직접 본다.
  for (let k = 0; k < 50; k++) {
    t = await snap();
    if (t.title?.page === 'load' && t.title.records?.clear !== undefined) break;
    await page.waitForTimeout(100);
  }
  check(t.title.page === 'load' && JSON.stringify(t.title.records?.clear) === '[true,false,false]', 'K4 7: 제목 불러오기 판 = 슬롯 1 「제1계층 돌파」', { page: t.title.page, clear: t.title.records?.clear });
  await shot('k403_title_load_clear');
  await clickButton('Load_slot1');
  s = await waitFor((x) => x.town?.open && !x.busy && !x.title?.open, 'K4 7: 슬롯 1 불러오기');
  check(s.hash === slotHash && JSON.stringify(s.cleared) === '["b3f"]' && s.location === 'town', 'K4 P14 슬롯 1 불러오기 → 같은 해시·클리어·마을', { slot: slotHash.slice(0, 12), now: s.hash.slice(0, 12) });
  s = await reloadHere('K4 P14 불러온 뒤 이어하기', s);
  log('부분 K4 끝', { battles: battlesK, seconds: Math.round((Date.now() - t0) / 1000) });
}
