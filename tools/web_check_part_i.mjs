// web_check 부분 I(M3 A8b 설계 §8, 실제 미궁 arbor: 주소에 &set 없음, 저장 폴더 saves): 정보상 바·관리국 의뢰.
// 1) 새 게임 → 광장: 「정보상 바」·「관리국」 줄이 흐리지 않다.
// 2) 관리국 → 「임무를 받는다」 → 첫 임무 NEW → 「예」 → 받음, IndexedDB = 화면.
// 3) 아보르 입구 → B1F 를 고정 공략(data/floors/arbor_route.json)으로 내려가는 계단 칸(17,1)까지 실제 키로 걷는다(전투는 battle_finish,
//    걸어 들어온 상자 물음은 「아니오」) → 안내 = 임무 달성 안내(허가 안내가 아니다), 물음 없음, IndexedDB = 화면.
// 4) 조사 → 허가 안내, 계단 물음 없음.
// 5) 온 길을 거꾸로 걸어 마을 문 → 「예」 → 마을.
// 6) 관리국 → 「임무를 보고한다」 → 「예」 → 결과 줄(돈·허가·경험치·레벨 업), flags 에 permit.b2f, IndexedDB = 화면.
// 7) 정보상 바 → 이끼 수프 받기 → 디버그 supply item.neon_moss 3(소재는 디버그 요청에서만, 조정자 답) → 보고 → 메디카 +2·돈 +60, IndexedDB = 화면.
// 8) 새로 고침 → 이어하기: 같은 해시, 받는 목록의 이끼 수프 「1일 뒤」(흐림).
// 9) 숙소 숙박 → 2일째 → 이끼 수프 다시 받을 수 있다(NEW 아님) → 다시 받기.
// 쪽마다 캡처(build/check/i??_*.png).
import fs from 'node:fs';
import {
  W, H, outDir, KEYS, page, check, log, snap, request, waitFor, waitReady, clickButton, enterLabyrinth, finishBattle, waitIdb,
} from './web_check_common.mjs';

const route = JSON.parse(fs.readFileSync('data/floors/arbor_route.json', 'utf8'));
// B1F 내려가는 계단(체크포인트)에 서는 행동 수.
const AT_STAIRS = route.checkpoints.find((c) => c.floor === 'b1f' && c.at[0] === 17 && c.at[1] === 1).after;
const INVERSE = { forward: 'back', back: 'forward', strafe_left: 'strafe_right', strafe_right: 'strafe_left', turn_left: 'turn_right', turn_right: 'turn_left' };
const M1 = 'mission.permit_b2f';
const SOUP = 'quest.moss_soup';
const MISSION_NOTE = '임무 「아보르 탐사 허가」의 목표를 이뤘다. 관리국에 보고하자';
let battlesI = 0;

async function shot(name) {
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/${name}_${W}x${H}.png` });
}

const rows = (s) => s.quest_screen?.rows ?? [];
// 줄을 [id, 표, 흐림] 으로(스냅숏 사전은 키 차례가 정렬되어 있어 그대로 견주지 않는다).
const rowList = (s) => JSON.stringify(rows(s).map((r) => [r.id, r.mark, r.dim]));

// 행동 하나(키): 세대가 오르고 연출이 끝날 때까지. 전투가 열리면 battle_finish → 결과 창 「확인」. 걸어 들어온 상자·채집 물음은 「아니오」.
async function step(name) {
  const before = await snap();
  await page.keyboard.press(KEYS[name]);
  let s = await waitFor((x) => x.generation > before.generation && !x.busy, `행동 ${name}`);
  if (s.battle?.open) {
    battlesI += 1;
    s = await finishBattle(s, false);
    s = await waitFor((x) => !x.battle?.open && !x.busy, '전투 뒤 탐색');
  }
  if (s.modal === 'chest' || s.modal === 'gather') {
    await clickButton(s.modal === 'chest' ? 'ChestNo' : 'GatherNo');
    s = await waitFor((x) => x.modal === '' && !x.busy, '물음 닫기');
  }
  return s;
}

// 의뢰 화면 줄 id 를 누른다(줄 이름 QuestRow_k).
async function pickRow(s, id) {
  const k = rows(s).findIndex((r) => r.id === id);
  if (k < 0) throw new Error(`줄 없음: ${id} (${JSON.stringify(rows(s))})`);
  await clickButton(`QuestRow_${k}`);
  return waitFor((x) => x.quest_screen?.dialog?.mode === 'confirm' || x.quest_screen?.notice, `${id} 고름`);
}

// 확인 창 「예」 → 자동 저장.
async function yes(s, what) {
  const g = s.generation;
  await clickButton('Yes');
  return waitFor((x) => x.generation > g && x.quest_screen?.dialog?.mode === '' && !x.busy, what);
}

async function openFacility(giver, page1) {
  await clickButton(giver === 'pub' ? 'Plaza_pub' : 'Plaza_council');
  await waitFor((x) => x.quest_screen?.open && x.quest_screen.giver === giver && x.quest_screen.page === 'root', `${giver} 뿌리`);
  await clickButton(page1 === 'accept' ? 'Quest_accept' : 'Quest_report');
  return waitFor((x) => x.quest_screen?.page === page1, `${giver} ${page1}`);
}

async function toPlaza() {
  for (let k = 0; k < 3; k++) {
    const s = await snap();
    if (!s.quest_screen?.open) break;
    await page.keyboard.press('Escape');
    await page.waitForTimeout(120);
  }
  return waitFor((x) => !x.quest_screen?.open && x.town?.page === 'plaza', '광장');
}

export async function partI() {
  const t0 = Date.now();
  let s = await waitReady();
  check(s.set === 'game' && s.location === 'town' && s.town?.page === 'plaza', '의뢰 0: 실제 미궁·마을 광장', { set: s.set, location: s.location });
  check(s.town.dim[2] === false && s.town.dim[4] === false && s.buttons.Plaza_pub && s.buttons.Plaza_council,
    '의뢰 1: 광장 「정보상 바」·「관리국」 줄이 흐리지 않다', { dim: s.town.dim });
  await shot('i00_plaza');
  // 2) 관리국 → 첫 임무 받기.
  s = await openFacility('council', 'accept');
  check(rowList(s) === JSON.stringify([[M1, 'NEW', false]]) && s.quest_screen.box.title === '관리국 탐사과',
    '의뢰 2: 관리국 받는 목록 = 첫 임무 NEW, 말 상자 의뢰인', { rows: rows(s), box: s.quest_screen.box });
  await shot('i01_council_list');
  s = await pickRow(s, M1);
  check(s.quest_screen.dialog.text === '이 임무를 받을까?' && s.quest_screen.dialog.pick === 0 && s.buttons.Yes, '의뢰 2: 받기 확인(「예」 먼저)',
    { dialog: s.quest_screen.dialog });
  s = await yes(s, '첫 임무 받기 저장');
  check(s.quests[M1]?.status === 'accepted' && s.quest_screen.notice === '「아보르 탐사 허가」 임무를 받았다' && rows(s)[0].mark === '수락 중',
    '의뢰 2: 받았다(안내·수락 중)', { quest: s.quests[M1], notice: s.quest_screen.notice });
  let idb = await waitIdb(s);
  check(!idb.timeout, '의뢰 2: 받기 자동 저장이 IndexedDB 에 반영', idb);
  // 3) 계단 칸까지 실제로 걷는다.
  await toPlaza();
  s = await enterLabyrinth();
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));  // 캔버스에 키 포커스
  const walked = [];
  for (let i = 0; i < AT_STAIRS; i++) {
    const a = route.actions[i];
    if (!INVERSE[a]) continue;  // 공략의 open(상자 답)은 걸을 때 「아니오」로 닫았다
    s = await step(a);
    walked.push(a);
  }
  check(s.floor === 'b1f' && s.at[0] === 17 && s.at[1] === 1 && s.modal === '' && s.toast === MISSION_NOTE && s.quests[M1]?.status === 'done',
    '의뢰 3: B1F 계단 칸 → 임무 달성 안내(허가 안내가 아니다), 물음 없음, 목표 달성', { at: s.at, modal: s.modal, toast: s.toast, quest: s.quests[M1] });
  await shot('i02_mission_notice');
  idb = await waitIdb(s);
  check(!idb.timeout, '의뢰 3: 도착 자동 저장이 IndexedDB 에 반영(진행 1)', idb);
  // 4) 조사 → 허가 안내.
  await page.keyboard.press(KEYS.investigate);
  s = await waitFor((x) => x.toast === '관리국의 탐사 허가가 아직 없다' && !x.busy, '조사 → 허가 안내');
  check(s.modal === '' && s.at[0] === 17, '의뢰 4: 조사 → 「관리국의 탐사 허가가 아직 없다」, 계단 물음 없음', { modal: s.modal, toast: s.toast });
  // 5) 거꾸로 걸어 마을 문.
  for (const a of walked.slice().reverse()) {
    s = await step(INVERSE[a]);
    if (s.modal === 'stairs') break;
  }
  s = await waitFor((x) => x.modal === 'stairs', '마을 문 물음');
  await clickButton('StairsYes');
  s = await waitFor((x) => x.location === 'town' && x.town?.page === 'plaza' && !x.busy, '마을');
  check(s.location === 'town', '의뢰 5: 온 길을 거꾸로 걸어 마을 문 「예」 → 마을', { location: s.location, battles: battlesI });
  // 6) 보고.
  const money0 = s.money;
  s = await openFacility('council', 'report');
  check(rowList(s) === JSON.stringify([[M1, '달성', false]]), '의뢰 6: 보고 목록 = 첫 임무 달성', { rows: rows(s) });
  s = await pickRow(s, M1);
  check(s.quest_screen.dialog.text === '이 임무를 보고할까?' && s.quest_screen.dialog.pick === 0, '의뢰 6: 보고 확인(「예」 먼저)', { dialog: s.quest_screen.dialog });
  s = await yes(s, '보고 저장');
  const lines = s.quest_screen.box.lines;
  check(s.quest_screen.result && s.quest_screen.box.title === '보수를 받았다' && lines[0] === '100엔' && lines[1] === '받은 허가: B2F 탐사 허가'
    && lines[2] === '경험치 30' && /^레벨 업: /.test(lines[3]) && s.quest_screen.notice === '보고했다',
  '의뢰 6: 결과 줄(100엔 · 받은 허가 · 경험치 30 · 레벨 업)과 띠 「보고했다」', { box: s.quest_screen.box, notice: s.quest_screen.notice });
  check(JSON.stringify(s.flags) === JSON.stringify(['permit.b2f']) && s.money === money0 + 100 && s.quests[M1]?.status === 'finished',
    '의뢰 6: flags = [permit.b2f], 돈 +100, 첫 임무 완료', { flags: s.flags, money: [money0, s.money], quest: s.quests[M1] });
  await shot('i03_report_result');
  idb = await waitIdb(s);
  check(!idb.timeout, '의뢰 6: 보고 자동 저장이 IndexedDB 에 반영', idb);
  // 7) 정보상 바: 이끼 수프.
  await toPlaza();
  s = await openFacility('pub', 'accept');
  check(rows(s)[0]?.id === SOUP && rows(s)[0].mark === 'NEW', '의뢰 7: 정보상 바 받는 목록 첫 줄 = 이끼 수프 NEW', { rows: rows(s) });
  await shot('i04_pub_list');
  s = await pickRow(s, SOUP);
  s = await yes(s, '이끼 수프 받기 저장');
  const sup = await request({ op: 'supply', item: 'item.neon_moss', n: 3 });
  check(sup.ok === true && sup.events?.[0]?.amount === 3, '의뢰 7: 디버그 supply item.neon_moss 3(소재, 디버그 요청에서만)', sup);
  await page.keyboard.press('Escape');
  await waitFor((x) => x.quest_screen?.page === 'root', '정보상 바 뿌리');
  await clickButton('Quest_report');
  s = await waitFor((x) => x.quest_screen?.page === 'report' && x.quest_screen.rows?.[0]?.mark === '달성', '이끼 수프 달성');
  const medica0 = s.consumables?.['use.medica'] ?? 0;
  const money1 = s.money;
  s = await pickRow(s, SOUP);
  check(s.quest_screen.dialog.text === '이 의뢰를 보고할까?\n네온 이끼 3개를 건넨다', '의뢰 7: 보고 확인에 건넬 물건', { dialog: s.quest_screen.dialog });
  s = await yes(s, '이끼 수프 보고 저장');
  check((s.consumables?.['use.medica'] ?? 0) === medica0 + 2 && s.money === money1 + 60 && !(s.materials?.['item.neon_moss']),
    '의뢰 7: 보고 → 메디카 +2·돈 +60·이끼 건넴', { medica: [medica0, s.consumables?.['use.medica']], money: [money1, s.money], materials: s.materials });
  idb = await waitIdb(s);
  check(!idb.timeout, '의뢰 7: 보고 자동 저장이 IndexedDB 에 반영', idb);
  // 8) 새로 고침 → 이어하기.
  const hash = s.hash;
  await page.reload();
  s = await waitReady();
  check(s.hash === hash && s.location === 'town', '의뢰 8: 새로 고침 → 이어하기: 같은 해시', { hash: [hash.slice(0, 12), s.hash?.slice(0, 12)] });
  s = await openFacility('pub', 'accept');
  const soupRow = rows(s).find((r) => r.id === SOUP);
  check(soupRow?.mark === '1일 뒤' && soupRow.dim === true, '의뢰 8: 이끼 수프 「1일 뒤」(흐림)', { rows: rows(s) });
  await shot('i05_pub_cooling');
  // 9) 숙박 → 다시 받기.
  await toPlaza();
  await clickButton('Plaza_inn');
  await waitFor((x) => x.town?.page === 'inn', '숙소');
  await clickButton('Inn_stay');
  s = await waitFor((x) => x.town?.dialog?.mode === 'confirm', '숙박 확인');
  const g = s.generation;
  await clickButton('Yes');
  s = await waitFor((x) => x.generation > g && x.day === 2 && !x.busy, '숙박');
  await page.keyboard.press('Escape');
  await waitFor((x) => x.town?.page === 'plaza', '광장');
  s = await openFacility('pub', 'accept');
  const again = rows(s).find((r) => r.id === SOUP);
  check(s.day === 2 && again?.mark === '' && again.dim === false, '의뢰 9: 2일째 이끼 수프 다시 받을 수 있다(NEW 아님)', { day: s.day, rows: rows(s) });
  s = await pickRow(s, SOUP);
  s = await yes(s, '다시 받기 저장');
  check(s.quests[SOUP]?.status === 'accepted' && s.quests[SOUP].reports === 1 && s.quests[SOUP].progress === 0,
    '의뢰 9: 다시 받기(진행 0·보고 1)', { quest: s.quests[SOUP] });
  await shot('i06_pub_again');
  log('부분 I 끝', { battles: battlesI, seconds: Math.round((Date.now() - t0) / 1000) });
}
