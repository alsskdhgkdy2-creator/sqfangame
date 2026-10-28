// web_check 부분 G(M3 A6c 설계 §7.6, 실제 미궁 arbor: 주소에 &set 없음, 저장 폴더 saves): FOE.
// 1) 새 게임 → 광장 → 탐사 시작 → B1F (9,18) 북. 스냅숏 foes 에 숫양 f1 (12,9) 동, 미니맵 기록에 그 원.
// 2) 앞으로 아홉 → (9,9). 걸음마다 숫양이 고정 순회(파티 걸음에 맞춰 (13,9) … (17,9) 돌기 … (14,9))를 따르고 위험도는 한계값 아래.
// 3) 오른쪽으로 돌아 앞으로 둘 → (11,9)(숫양 (12,9) 서쪽) → 앞으로 = 부딪힘 접촉 전투: 전투 층, battle.foe f1, 띠 「FOE 에테르 숫양!」·
//    「FOE와 마주쳤다!」, IndexedDB 자동 저장 = 화면.
// 4) 전투 중 새로 고침 → 이어하기: 같은 해시, 전투 그대로(숫양 카드 하나, FOE 하나).
// 5) battle_finish → 결과 창 → 확인: 숫양 쓰러짐(1일째), 원·표지 없음, IndexedDB = 화면.
// 6) 마을 문(뒤로 둘, 오른쪽으로 돌아 앞으로 아홉) → 광장 → 숙소 숙박 → 2일째 → 탐사 시작: 숫양이 (12,9)에 되살아났다.
// 7) 앞으로 아홉 → (9,9), 오른쪽으로 돌아 앞(10,9)·뒤(9,9)·앞(10,9): 숫양 (12,9) 동쪽(거리 2) → 디버그 battle_start(인카운트) →
//    알약 「FOE 2턴 뒤 합류」 → battle_commands(명령 받는 대원 모두 방어) → 「FOE 1턴 뒤 합류」·미니맵 원 (11,9) → 다시 →
//    띠에 합류 줄을 지나 적 수 + 1, joined f1, 알약 숨음, 미니맵 원은 파티 옆 (11,9).
// 8) 전투 중 새로 고침 → 같은 해시·합류 카드 그대로 → battle_finish → 숫양 쓰러짐.
// 9) 마지막 새로 고침 → 같은 해시·창 없음.
// 걸음에 인카운트가 나면 battle_finish 로 넘긴다(승패에 기대지 않는다, D15). 그런 걸음은 기록에 남긴다.
import {
  W, H, outDir, KEYS, page, check, log, snap, request, waitFor, tryWait, waitReady, waitTitle, clickButton, enterLabyrinth, finishBattle, waitIdb,
} from './web_check_common.mjs';

let encountersG = 0;

async function shot(name) {
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/${name}_${W}x${H}.png` });
}

const ram = (s) => (s.foes ?? []).find((f) => f.id === 'f1');
const at = (f) => (f ? `${f.at[0]},${f.at[1]}` : '-');

// 행동 하나(키). keepBattle 이 아니면 인카운트는 battle_finish 로 넘긴다.
async function step(name, keepBattle = false) {
  const before = await snap();
  await page.keyboard.press(KEYS[name]);
  let s = await waitFor((x) => x.generation > before.generation && !x.busy, `행동 ${name}`);
  if (s.battle?.open && !keepBattle) {
    encountersG += 1;
    log('걸음 인카운트', { at: s.at, foe: s.battle.foe });
    s = await finishBattle(s, false);
    s = await waitFor((x) => !x.battle?.open && !x.busy, '전투 뒤 탐색');
  }
  return s;
}

async function reloadContinue(tag) {
  await page.reload();
  await page.waitForFunction(() => window.sqfDebug && window.sqfDebug.ready, null, { timeout: 60000 });
  const t = await waitTitle();
  check(t.buttons.TitleContinue, `${tag}: 새로 고침 → 타이틀 이어하기`, { title: t.title });
  await clickButton('TitleContinue');
  return waitFor((x) => x.location === 'labyrinth' && !x.busy && !x.title?.open, `${tag}: 이어하기`);
}

// 명령 받는 대원 모두 방어로 한 턴(battle_commands) → 연출 끝·명령 입력.
async function guardTurn() {
  let s = await snap();
  const g = s.generation;
  const cmds = s.battle.can_command.map((ok) => (ok ? { kind: 'guard' } : null));
  let r = null;
  for (let k = 0; k < 3 && !r?.ok; k++) {
    if (k) await page.waitForTimeout(100);
    r = await request({ op: 'battle_commands', commands: cmds });
  }
  if (!r.ok) throw new Error(`battle_commands 거부: ${JSON.stringify(r)}`);
  s = await waitFor((x) => x.generation > g, 'battle_commands 저장');
  return s;
}

const RAM_CYCLE = ['13,9', '14,9', '15,9', '16,9', '17,9', '17,9', '16,9', '15,9', '14,9'];

export async function partG() {
  let s = await waitReady();
  check(s.set === 'game' && s.location === 'town', '실제 미궁·마을 광장', { set: s.set, location: s.location });
  // 1) B1F 시작.
  s = await enterLabyrinth();
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));  // 캔버스에 키 포커스
  s = (await tryWait((x) => x.minimap_foes?.length === 1 && x.foe_marks === 1, '미니맵 원', 5000)) ?? await snap();
  const disc = (s.minimap_foes ?? [])[0];
  check(s.floor === 'b1f' && s.at[0] === 9 && s.at[1] === 18 && at(ram(s)) === '12,9' && ram(s).facing === 1 && ram(s).state === 'patrol'
    && ram(s).threat === 'red' && s.foe_marks === 1 && s.minimap_foes?.length === 1 && disc.id === 'f1' && disc.cell.join() === '12,9' && disc.color === 'ff291f',
  'FOE 1: B1F (9,18), 숫양 f1 (12,9) 동·순회·빨강, 3D 표지 하나, 미니맵 원', { at: s.at, ram: ram(s), marks: s.foe_marks, disc: s.minimap_foes });
  // 2) 앞으로 아홉.
  const seen = [];
  let calm = true;
  for (let i = 0; i < 9; i++) {
    s = await step('forward');
    seen.push(at(ram(s)));
    calm = calm && !s.pending;
  }
  check(s.at.join() === '9,9' && JSON.stringify(seen) === JSON.stringify(RAM_CYCLE) && ram(s).facing === 3 && calm && encountersG === 0,
    'FOE 2: (9,9)까지 숫양이 걸음마다 고정 순회(… (17,9) 돌기 … (14,9) 서쪽), 인카운트 없음', { at: s.at, seen, facing: ram(s).facing, danger: s.danger });
  // 3) 접촉.
  await step('turn_right');
  await step('forward');
  s = await step('forward');
  check(s.at.join() === '11,9' && at(ram(s)) === '12,9' && ram(s).facing === 3, 'FOE 3: (11,9), 숫양 (12,9) 서쪽', { at: s.at, ram: ram(s) });
  s = await step('forward', true);
  s = await waitFor((x) => x.battle?.open && x.battle.phase === 'command', '접촉 전투');
  check(s.battle.foe === 'f1' && s.battle.enemy_count === 1 && ram(s).state === 'battle' && s.at.join() === '11,9'
    && JSON.stringify(s.battle.banner) === JSON.stringify(['FOE 에테르 숫양!', 'FOE와 마주쳤다!']) && s.foe_marks_shown === false,
  'FOE 3: 부딪힘 → 접촉 전투(battle.foe f1, 적 하나, 띠 「FOE 에테르 숫양!」·「FOE와 마주쳤다!」, 3D 표지 감춤)',
  { battle: { foe: s.battle.foe, n: s.battle.enemy_count, banner: s.battle.banner }, at: s.at, shown: s.foe_marks_shown });
  await shot('g01_contact_battle');
  let idb = await waitIdb(s);
  check(!idb.timeout, 'FOE 3: 전투 시작 자동 저장이 IndexedDB 에(같은 세대·해시)', idb);
  // 4) 전투 중 새로 고침.
  let before = s;
  s = await reloadContinue('FOE 4');
  s = await waitFor((x) => x.battle?.open && x.battle.phase === 'command', '전투 층 다시');
  check(s.hash === before.hash && s.battle.enemy_count === 1 && s.battle.foe === 'f1' && s.foes.filter((f) => f.state === 'battle').length === 1
    && s.foe_marks_shown === false,
    'FOE 4: 새로 고침 → 같은 해시, 숫양 카드 하나, battle 상태 FOE 하나, 3D 표지 감춤',
    { before: before.hash.slice(0, 12), after: s.hash.slice(0, 12), n: s.battle.enemy_count, shown: s.foe_marks_shown });
  // 5) 승리.
  s = await finishBattle(s, false);
  s = await waitFor((x) => !x.battle?.open && !x.busy, '전투 뒤');
  s = (await tryWait((x) => x.minimap_foes?.length === 0, '원 지움', 5000)) ?? await snap();
  check(ram(s).state === 'defeated' && s.day === 1 && s.minimap_foes.length === 0 && s.foe_marks === 0 && s.foe_marks_shown === true,
    'FOE 5: 숫양 쓰러짐(1일째), 원·표지 없음, 표지 층 다시 보임', { ram: ram(s), disc: s.minimap_foes, marks: s.foe_marks, shown: s.foe_marks_shown });
  idb = await waitIdb(s);
  check(!idb.timeout, 'FOE 5: IndexedDB = 화면', idb);
  // 6) 마을 문 → 숙박 → 되살아남.
  await step('back');
  await step('back');
  await step('turn_right');
  for (let i = 0; i < 9; i++) s = await step('forward');
  if (s.modal !== 'stairs') s = await step('investigate');
  check(s.at.join() === '9,18' && s.modal === 'stairs', 'FOE 6: 마을 문 물음', { at: s.at, modal: s.modal });
  await clickButton('StairsYes');
  await waitFor((x) => x.location === 'town' && x.town?.open && x.town.page === 'plaza' && !x.busy, '광장');
  await clickButton('Plaza_inn');
  await waitFor((x) => x.town?.page === 'inn' && !x.busy, '숙소');
  await clickButton('Inn_stay');
  await waitFor((x) => x.town?.dialog?.mode === 'confirm', '숙박 확인');
  const g = (await snap()).generation;
  await clickButton('Yes');
  s = await waitFor((x) => x.town?.dialog?.mode === '' && x.day === 2 && x.generation > g && !x.busy, '묵음');
  await clickButton('Inn_leave');
  await waitFor((x) => x.town?.page === 'plaza' && !x.busy, '광장');
  s = await enterLabyrinth();
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));
  s = (await tryWait((x) => x.minimap_foes?.length === 1 && x.foe_marks === 1, '되살아난 원', 5000)) ?? await snap();
  check(s.day === 2 && at(ram(s)) === '12,9' && ram(s).state === 'patrol' && s.foe_marks === 1 && s.minimap_foes.length === 1,
    'FOE 6: 숙박(2일째) 뒤 들어가면 숫양이 (12,9)에 되살아났다', { day: s.day, ram: ram(s) });
  // 7) 합류.
  for (let i = 0; i < 9; i++) s = await step('forward');
  await step('turn_right');
  await step('forward');
  await step('back');
  s = await step('forward');
  check(s.at.join() === '10,9' && at(ram(s)) === '12,9' && ram(s).facing === 1 && !s.pending, 'FOE 7: (10,9), 숫양 (12,9) 동쪽으로 돌았다(거리 2)',
    { at: s.at, ram: ram(s), encounters: encountersG });
  let r = await request({ op: 'battle_start' });
  check(r.ok && r.open, 'FOE 7: 디버그 battle_start → 인카운트 전투', r);
  s = await waitFor((x) => x.battle?.open && x.battle.phase === 'command' && !x.busy, '인카운트 전투');
  const n0 = s.battle.enemy_count;
  check(s.battle.foe === '' && s.battle.join_pill === 'FOE 2턴 뒤 합류' && JSON.stringify(s.battle.joins) === '[{"foe":"f1","n":2,"wait":false}]',
    'FOE 7: 알약 「FOE 2턴 뒤 합류」', { pill: s.battle.join_pill, joins: s.battle.joins, n: n0 });
  await shot('g02_join_pill');
  s = await guardTurn();
  s = await waitFor((x) => x.battle?.phase === 'command' && !x.busy, '1턴 뒤');
  check(s.battle.join_pill === 'FOE 1턴 뒤 합류' && s.battle.minimap_foes.map((d) => d.cell.join()).join() === '11,9' && s.battle.enemy_count === n0,
    'FOE 7: 1턴 뒤 「FOE 1턴 뒤 합류」, 전투 미니맵 원 (11,9)', { pill: s.battle.join_pill, disc: s.battle.minimap_foes });
  s = await guardTurn();
  s = await waitFor((x) => x.battle?.phase === 'command' && !x.busy, '2턴 뒤');
  check(s.battle.enemy_count === n0 + 1 && JSON.stringify(s.battle.joined.map((j) => j.foe)) === '["f1"]' && s.battle.join_pill === ''
    && s.battle.log_lines > 0 && s.battle.minimap_foes.map((d) => d.cell.join()).join() === '11,9' && ram(s).state === 'battle',
  'FOE 7: 2턴 끝에 합류(적 수 + 1, joined f1, 알약 숨음, 원은 파티 옆 (11,9))', { n: [n0, s.battle.enemy_count], joined: s.battle.joined, pill: s.battle.join_pill });
  await shot('g03_joined');
  idb = await waitIdb(s);
  check(!idb.timeout, 'FOE 7: 합류 턴 자동 저장이 IndexedDB 에', idb);
  // 8) 새로 고침 → 승리.
  before = s;
  s = await reloadContinue('FOE 8');
  s = await waitFor((x) => x.battle?.open && x.battle.phase === 'command', '전투 층 다시');
  check(s.hash === before.hash && s.battle.enemy_count === n0 + 1 && JSON.stringify(s.battle.joined.map((j) => j.foe)) === '["f1"]',
    'FOE 8: 새로 고침 → 같은 해시·합류 카드 그대로', { before: before.hash.slice(0, 12), after: s.hash.slice(0, 12), n: s.battle.enemy_count });
  s = await finishBattle(s, false);
  s = await waitFor((x) => !x.battle?.open && !x.busy, '전투 뒤');
  s = (await tryWait((x) => x.minimap_foes?.length === 0, '원 지움', 5000)) ?? await snap();
  check(ram(s).state === 'defeated' && s.minimap_foes.length === 0, 'FOE 8: 승리 → 숫양 쓰러짐', { ram: ram(s) });
  idb = await waitIdb(s);
  // 9) 마지막 새로 고침.
  before = s;
  s = await reloadContinue('FOE 9');
  check(!idb.timeout && s.hash === before.hash && s.modal === '' && !s.battle?.open, 'FOE 9: 새로 고침 → 같은 해시·창 없음',
    { before: before.hash.slice(0, 12), after: s.hash.slice(0, 12), modal: s.modal });
  log('부분 G 끝', { encounters: encountersG });
}
