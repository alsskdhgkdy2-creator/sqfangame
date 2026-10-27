// web_check 부분 E(M3 A4b, 시험 층 &set=test, 저장 폴더 saves_test, 새 브라우저): 소모품·공용 가방·귀환 비콘(설계 §8.3).
// 0) 새 게임 소지금 200 으로는 설계의 사기(60 + 150 + 40)가 모자라, 디버그 supply 로 받은 이온 세이버 하나를 공방 「팔기」 → 「장비」 탭에서 판다(+180).
// 1) 정크 공방 「사기」 → 「아이템」: 줄 넷 → 메디카 수량 창(「예」 먼저) → 3 → 「예」 → 소모품 3·돈 −60·가방 3·IndexedDB = 화면
// 2) 비콘·테리아카 A 사기 3) 「팔기」 → 「소모품」 탭 → 테리아카 A 팔기 → 돈 +20
// 4) 광장 캠프 → 소지품: 띠 「소지품   4/60」, 메디카 「쓰기」 → 카드 → 「HP가 가득하다」(개수 그대로), 비콘 「쓰기」 흐림 → 「마을에서는 쓸 수 없다」
// 5) 탐사 시작 → 지도 메모 → 공략 몇 걸음 → 캠프 → 소지품: 메디카 「버리기」 → 수량 창(「아니오」 먼저) → 1 → 「예」 → 2개·띠 「3/60」
// 6) 비콘 「쓰기」 → 확인 창(첫 커서 「돌아가기」) → 「돌아간다」 → 광장·첫 층 시작 칸·날·걸음·지도 메모 그대로·안내 없음(관문 도착과 같다)·IndexedDB = 화면
// 5b) (M3 A4c) 공략을 이어 걸어 첫 전투: 대원 1 「아이템」 → 메디카 → 자기 카드, 대원 2 「아이템」 → 줄어든 수를 보고 뒤로, 나머지 방어 → 실행 →
//     소모품 = 전 − item_used(어떻게 끝나도 통과, D15) → battle_finish → 「확인」. 그 뒤 캠프로 돌아가 6) 을 잇는다.
// 7) 새로 고침 → 이어하기: 같은 해시, 마을. 전투는 battle_finish 로 넘긴다(승패에 기대지 않는다, D15).
import {
  W, H, outDir, KEYS, page, check, log, snap, request, waitFor, waitReady, waitTitle, clickButton, enterLabyrinth, finishBattle, waitIdb, route,
  ION_SABER,
} from './web_check_common.mjs';

const MEDICA = 'use.medica';
const BEACON = 'use.ariadne_beacon';
const THERIACA_A = 'use.theriaca_a';

async function shot(name) {
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/${name}_${W}x${H}.png` });
}

// 행동 하나(키): 세대가 오르고 연출이 끝날 때까지. 전투가 열리면 battle_finish → 결과 창 「확인」.
async function step(name) {
  const before = await snap();
  await page.keyboard.press(KEYS[name]);
  let s = await waitFor((x) => x.generation > before.generation && !x.busy, `행동 ${name}`);
  if (s.battle?.open) {
    s = await finishBattle(s, false);
    s = await waitFor((x) => !x.battle?.open && !x.busy, '전투 뒤 탐색');
  }
  return s;
}

// 구매 목록에서 줄 이름으로 사기(수량 창 → ↑ 를 n−1 번 → 「예」).
async function buy(name, n) {
  let s = await snap();
  const i = s.shop.rows.findIndex((r) => r.name === name);
  await clickButton(`Row_${i}`);
  s = await waitFor((x) => x.shop?.dialog?.mode === 'qty' && x.shop.dialog.ask === 'buy_item', `${name} 수량 창`);
  for (let k = 1; k < n; k++) {
    await page.keyboard.press('ArrowUp');
    await page.waitForTimeout(100);
  }
  s = await waitFor((x) => x.shop.dialog.qty === n, `${name} ${n}개`);
  const g = s.generation;
  await clickButton('Yes');
  return waitFor((x) => x.generation > g && x.shop?.dialog?.mode === '' && !x.busy, `${name} 사기 저장`);
}

// 캠프 → 소지품(줄이 찬 뒤).
async function openItems() {
  await clickButton('CampButton');
  await waitFor((x) => x.party_menu?.open && x.party_menu.page === 'root', '캠프 뿌리');
  await clickButton('Camp_items');
  return waitFor((x) => x.party_menu?.page === 'sub' && x.party_menu.tab === 'items' && x.party_menu.item_rows?.length > 0, '소지품');
}

async function key(k, pred, what) {
  await page.keyboard.press(k);
  return waitFor(pred, what, 5000);
}

export async function partE() {
  // 1) 새 게임 → 광장 → 정크 공방 → 사기 → 아이템.
  let s = await waitReady();
  check(s.set === 'test' && s.location === 'town' && s.town?.page === 'plaza' && JSON.stringify(s.consumables) === '{}' && s.bag_used === 0,
    '아이템 1: 새 게임 광장, 소모품 없음·가방 0', { set: s.set, location: s.location, consumables: s.consumables, bag_used: s.bag_used });
  // 0) 사기 밑천: 이온 세이버(값 360)를 받아 판다.
  await request({ op: 'supply', item: ION_SABER, n: 1 });
  s = await waitFor((x) => x.gear_bag?.[ION_SABER] === 1 && !x.busy, '디버그 supply 이온 세이버');
  await clickButton('Plaza_shop');
  await waitFor((x) => x.shop?.open && x.shop.page === 'root', '상점 뿌리');
  await clickButton('Root_sell');
  await waitFor((x) => x.shop?.page === 'sell', '판매 목록');
  await clickButton('Tab_gear');
  s = await waitFor((x) => x.shop?.tab === 'gear' && x.shop.rows.length === 1, '장비 탭');
  await clickButton('Row_0');
  s = await waitFor((x) => x.shop?.dialog?.ask === 'sell', '판매 확인 창');
  let g = s.generation;
  await clickButton('Yes');
  s = await waitFor((x) => x.generation > g && x.shop?.dialog?.mode === '' && !x.busy, '이온 세이버 판매 저장');
  check(s.money === 380 && s.bag_used === 0, '아이템 0: 이온 세이버 팔기 → 소지금 380(사기 밑천)', { money: s.money, bag_used: s.bag_used });
  await clickButton('VPad_back');
  await waitFor((x) => x.shop?.page === 'root', '뿌리로');
  await clickButton('Root_buy');
  await waitFor((x) => x.shop?.page === 'branch', '구매 갈래');
  await clickButton('Branch_item');
  s = await waitFor((x) => x.shop?.page === 'buy' && x.shop.branch === 'item' && x.shop.rows.length > 0, '아이템 목록');
  const names = s.shop.rows.map((r) => r.name);
  check(JSON.stringify(names) === JSON.stringify(['메디카', '테리아카 A', '테리아카 B', '아리아드네 비콘']) && s.shop.tab === '',
    '아이템 1: 「아이템」 갈래 = 늘 파는 소모품 넷(탭 없음)', { names, tab: s.shop.tab });
  const money0 = s.money;
  const medica = s.shop.rows.findIndex((r) => r.name === '메디카');
  await clickButton(`Row_${medica}`);
  s = await waitFor((x) => x.shop?.dialog?.mode === 'qty', '메디카 수량 창');
  check(s.shop.dialog.ask === 'buy_item' && s.shop.dialog.pick === 0 && s.shop.dialog.qty === 1 && s.buttons.Yes && s.buttons.No,
    '아이템 1: 메디카 → 수량 창(「예」 먼저, 1개부터)', { dialog: s.shop.dialog });
  await page.keyboard.press('ArrowUp');
  await page.keyboard.press('ArrowUp');
  s = await waitFor((x) => x.shop.dialog.qty === 3, '메디카 3개');
  await shot('e01_shop_item_qty');
  g = s.generation;
  await clickButton('Yes');
  s = await waitFor((x) => x.generation > g && x.shop?.dialog?.mode === '' && !x.busy, '메디카 사기 저장');
  let idb = await waitIdb(s);
  check(s.consumables[MEDICA] === 3 && s.money === money0 - 60 && s.bag_used === 3 && s.generation === g + 1 && !idb.timeout,
    '아이템 1: 「예」 → 메디카 3·돈 −60·가방 3, 자동 저장 하나, IndexedDB = 화면', { consumables: s.consumables, money: s.money, bag_used: s.bag_used, idb });
  // 2) 비콘·테리아카 A.
  s = await buy('아리아드네 비콘', 1);
  s = await buy('테리아카 A', 1);
  check(s.consumables[BEACON] === 1 && s.consumables[THERIACA_A] === 1 && s.money === money0 - 60 - 150 - 40 && s.bag_used === 5,
    '아이템 2: 비콘·테리아카 A 사기', { consumables: s.consumables, money: s.money, bag_used: s.bag_used });
  // 3) 팔기 → 소모품 탭 → 테리아카 A.
  await clickButton('BuyBack');
  await waitFor((x) => x.shop?.page === 'branch', '갈래로');
  await clickButton('VPad_back');
  await waitFor((x) => x.shop?.page === 'root', '뿌리로');
  await clickButton('Root_sell');
  await waitFor((x) => x.shop?.page === 'sell', '판매 목록');
  await clickButton('Tab_consumable');
  s = await waitFor((x) => x.shop?.tab === 'consumable' && x.shop.rows.length === 3, '소모품 탭');
  check(JSON.stringify(s.shop.rows.map((r) => [r.name, r.count, r.right])) === JSON.stringify([['메디카', '3개', '10'], ['테리아카 A', '1개', '20'], ['아리아드네 비콘', '1개', '75']]),
    '아이템 3: 판매 「소모품」 탭 = 가진 소모품(정의 차례)·판매값 = 값 ÷ 2', { rows: s.shop.rows });
  await shot('e02_shop_sell_consumable');
  const money1 = s.money;
  await clickButton(`Row_${s.shop.rows.findIndex((r) => r.name === '테리아카 A')}`);
  s = await waitFor((x) => x.shop?.dialog?.ask === 'sell', '판매 확인 창');
  g = s.generation;
  await clickButton('Yes');
  s = await waitFor((x) => x.generation > g && x.shop?.dialog?.mode === '' && !x.busy, '판매 저장');
  check(s.money === money1 + 20 && s.consumables[THERIACA_A] === undefined && s.bag_used === 4, '아이템 3: 테리아카 A 팔기 → 돈 +20',
    { money: s.money, consumables: s.consumables });
  await clickButton('VPad_back');
  await waitFor((x) => x.shop?.page === 'root', '뿌리로');
  await clickButton('VPad_back');
  await waitFor((x) => !x.shop?.open && x.town?.open && !x.town.covered, '상점 닫힘');

  // 4) 광장 캠프 → 소지품.
  s = await openItems();
  check(s.party_menu.strip === '소지품   4/60' && JSON.stringify(s.party_menu.item_rows) === JSON.stringify([MEDICA, BEACON]),
    '아이템 4: 띠 「소지품   4/60」, 줄 = 메디카·비콘', { strip: s.party_menu.strip, rows: s.party_menu.item_rows });
  await shot('e03_camp_items_list');
  s = await key('Enter', (x) => x.party_menu.items.mode === 'pills', '알약 쪽');
  check(s.party_menu.items.pill === 0 && s.party_menu.items.use === 'on' && s.party_menu.items.drop === 'on', '아이템 4: Enter → 「쓰기」(알약 둘)',
    { items: s.party_menu.items });
  await shot('e04_camp_items_pills');
  s = await key('Enter', (x) => x.party_menu.items.mode === 'pick', '고르기');
  check(s.party_menu.strip === '메디카: 누구에게 쓸까?' && s.party_menu.items.pick >= 0, '아이템 4: 「쓰기」 → 대원 고르기(띠 물음)', { items: s.party_menu.items, strip: s.party_menu.strip });
  await shot('e05_camp_items_pick');
  const gen4 = s.generation;
  await clickButton('VPad_ok');
  s = await waitFor((x) => x.party_menu.notice === 'HP가 가득하다', '가득한 대원');
  check(s.party_menu.items.mode === 'pick' && s.consumables[MEDICA] === 3 && s.generation === gen4, '아이템 4: HP 가득 → 이유만, 고르기 그대로, 개수·저장 그대로',
    { items: s.party_menu.items, consumables: s.consumables });
  await key('Escape', (x) => x.party_menu.items.mode === 'pills', '알약 쪽');
  await key('Escape', (x) => x.party_menu.items.mode === 'list', '목록 쪽');
  s = await key('ArrowDown', (x) => x.party_menu.items.item === BEACON, '비콘 줄');
  check(s.party_menu.items.use === 'dim', '아이템 4: 마을에서 비콘 「쓰기」 흐림', { items: s.party_menu.items });
  await clickButton('ItemUse');
  s = await waitFor((x) => x.party_menu.notice === '마을에서는 쓸 수 없다', '비콘 이유');
  check(s.party_menu.dialog === '' && s.consumables[BEACON] === 1, '아이템 4: 흐린 비콘 → 「마을에서는 쓸 수 없다」만', { dialog: s.party_menu.dialog });
  await clickButton('VPad_back');
  await waitFor((x) => x.party_menu?.items?.mode === 'list', '목록 쪽');
  await clickButton('VPad_back');
  await waitFor((x) => x.party_menu?.page === 'root', '캠프 뿌리');
  await clickButton('VPad_back');
  await waitFor((x) => !x.party_menu?.open && x.town?.open, '캠프 닫힘');

  // 5) 탐사 시작 → 지도 메모 → 몇 걸음 → 소지품 버리기.
  s = await enterLabyrinth();
  const start = s.at;
  const startFloor = s.floor;
  await clickButton('MapButton');
  s = await waitFor((x) => x.map_open && Array.isArray(x.map.origin) && !!x.buttons.Tool_memo, '지도 판');
  await clickButton('Tool_memo');
  s = await waitFor((x) => x.tool === 'memo', '메모 도구');
  g = s.generation;
  const memoText = '비콘 시험';
  page.once('dialog', async (d) => { await d.accept(memoText); });
  await page.mouse.click(s.map.origin[0] + s.map.cell[0] * (start[0] + 0.5), s.map.origin[1] + s.map.cell[1] * (start[1] + 0.5));
  s = await waitFor((x) => x.generation > g && !x.busy, '메모 저장');
  const memoKey = `${start[0]},${start[1]}`;
  check(s.memo_texts?.[memoKey] === memoText, '아이템 5: 시작 칸에 지도 메모', { memo: s.memo_texts?.[memoKey] });
  await clickButton('MapBack');
  await waitFor((x) => !x.map_open && !x.busy, '지도 닫힘');
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));  // 캔버스에 키 포커스
  for (const a of route.actions.slice(0, 3)) s = await step(a);
  s = await openItems();
  s = await key('Enter', (x) => x.party_menu.items.mode === 'pills', '알약 쪽');
  s = await key('ArrowDown', (x) => x.party_menu.items.pill === 1, '「버리기」');
  s = await key('Enter', (x) => x.party_menu.items.qty > 0, '버리기 수량 창');
  check(s.party_menu.items.qty === 1 && s.party_menu.items.qty_pick === 1 && s.buttons.Yes && s.buttons.No,
    '아이템 5: 메디카 3개 「버리기」 → 수량 창(「아니오」 먼저, 1개부터)', { items: s.party_menu.items });
  await shot('e06_camp_discard_qty');
  g = s.generation;
  await clickButton('Yes');
  s = await waitFor((x) => x.generation > g && x.party_menu.items.qty === 0 && !x.busy, '버림 저장');
  check(s.consumables[MEDICA] === 2 && s.party_menu.strip === '메디카 1개를 버렸다' && s.party_menu.items.mode === 'list' && s.bag_used === 3,
    '아이템 5: 1개 버림 → 2개·띠에 결과(D2)·목록 쪽', { consumables: s.consumables, strip: s.party_menu.strip, items: s.party_menu.items });

  // 결과 안내가 2.5초 뒤 사라지면 띠는 다시 칸 수.
  s = await waitFor((x) => x.party_menu.strip !== '메디카 1개를 버렸다', '안내가 사라짐', 5000);
  check(s.party_menu.strip === '소지품   3/60', '아이템 5: 띠 「소지품   3/60」', { strip: s.party_menu.strip });
  await clickButton('VPad_back');
  await waitFor((x) => x.party_menu?.page === 'root', '캠프 뿌리');
  await clickButton('VPad_back');
  await waitFor((x) => !x.party_menu?.open && !x.busy, '캠프 닫힘');

  // 5b) 첫 전투의 「아이템」(M3 A4c).
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));  // 캔버스에 키 포커스
  for (let i = 3; i < route.actions.length; i++) {
    const b0 = await snap();
    if (b0.battle?.open) break;
    await page.keyboard.press(KEYS[route.actions[i]]);
    const b1 = await waitFor((x) => (x.generation > b0.generation || x.battle?.open) && !x.busy, `걸음 ${i + 1}`);
    if (b1.battle?.open) break;
    if (b1.modal !== '') {
      await page.keyboard.press('Escape');
      await waitFor((x) => x.modal === '' && !x.busy, '물음 닫기');
    }
  }
  let b = await waitFor((x) => x.battle?.open && x.battle.phase === 'command' && x.battle.sub === 'menu' && !x.busy, '첫 전투 명령 단계');
  const med0 = b.consumables[MEDICA];
  check(b.battle.member === 0 && b.buttons.Cmd_item && b.buttons.Cmd_escape && med0 === 2, '아이템 5b: 첫 전투 — 다섯 줄(「아이템」·「도주」), 메디카 2',
    { member: b.battle.member, med0, buttons: Object.keys(b.buttons).filter((n) => n.startsWith('Cmd_')) });
  await clickButton('Cmd_item');
  b = await waitFor((x) => x.battle?.sub === 'items', '아이템 목록');
  const mk = b.battle.items.findIndex((r) => r.id === MEDICA);
  check(mk >= 0 && b.battle.items[mk].count === med0 && b.battle.items[mk].reason === '' && b.buttons[`Item_${mk}`],
    '아이템 5b: 대원 1 아이템 목록 — 메디카 2(고를 수 있다)', { items: b.battle.items });
  await shot('e07a_battle_items');
  await clickButton(`Item_${mk}`);
  b = await waitFor((x) => x.battle?.sub === 'target', '대상 고르기');
  await clickButton('Member_0');
  b = await waitFor((x) => x.battle?.member === 1 && x.battle.sub === 'menu', '대원 2');
  const c0 = b.battle.commands[0];
  check(c0?.kind === 'item' && c0.item === MEDICA && c0.target === 0 && Object.keys(c0).length === 3 && b.consumables[MEDICA] === med0,
    '아이템 5b: 대원 1 = 메디카 → 자기 카드(실행 전이라 소모품 그대로)', { command: b.battle.commands[0], consumables: b.consumables });
  await clickButton('Cmd_item');
  b = await waitFor((x) => x.battle?.sub === 'items', '대원 2 아이템 목록');
  check(b.battle.items.find((r) => r.id === MEDICA)?.count === med0 - 1, '아이템 5b: 대원 2 — 보이는 메디카가 하나 줄었다(대원 1 의 예약)', { items: b.battle.items });
  await shot('e07b_battle_items_member2');
  await clickButton('VPad_back');
  b = await waitFor((x) => x.battle?.sub === 'menu' && x.battle.member === 1, '대원 2 메뉴');
  for (let k = 0; k < 6; k++) {
    b = await snap();
    if (b.battle.sub === 'confirm') break;
    const m = b.battle.member;
    await clickButton('Cmd_guard');
    await waitFor((x) => x.battle.sub === 'confirm' || x.battle.member !== m, '방어');
  }
  b = await waitFor((x) => x.battle?.sub === 'confirm' && x.buttons.Execute, '모든 명령');
  const gb = b.generation;
  await clickButton('Execute');
  b = await waitFor((x) => x.generation > gb, '제출 저장');
  if (b.battle?.phase === 'anim') await page.keyboard.press('Enter');
  b = await waitFor((x) => !x.battle?.open || x.battle.phase !== 'anim', '연출 끝');
  const used = b.battle?.item_used ?? -1;
  const medAfter = b.consumables[MEDICA] ?? 0;
  check(used >= 0 && used <= 1 && medAfter === med0 - used, '아이템 5b: 실행 뒤 메디카 = 전 − item_used(결과에 기대지 않는다, D15)',
    { med0, used, medAfter, phase: b.battle?.phase, outcome: b.battle?.outcome });
  b = await finishBattle(b, false);
  b = await waitFor((x) => !x.battle?.open && x.modal === '' && !x.busy, '전투 끝 → 탐색');

  // 6) 비콘 → 마을.
  s = await openItems();
  check(s.party_menu.strip === `소지품   ${3 - (med0 - medAfter)}/60` && s.bag_used === 3 - (med0 - medAfter), '아이템 6: 전투 뒤 띠 = 공용 가방 칸 수',
    { strip: s.party_menu.strip, bag_used: s.bag_used });
  await key('ArrowDown', (x) => x.party_menu.items.item === BEACON, '비콘 줄');
  s = await snap();
  check(s.party_menu.items.use === 'on', '아이템 6: 미궁에서 비콘 「쓰기」 켜짐', { items: s.party_menu.items });
  await key('Enter', (x) => x.party_menu.items.mode === 'pills', '알약 쪽');
  s = await key('Enter', (x) => x.party_menu.dialog === 'beacon', '비콘 확인 창');
  check(s.party_menu.dialog_pick === 0 && s.buttons.DialogBack && s.buttons.DialogOk, '아이템 6: 비콘 확인 창, 첫 커서 「돌아가기」', { pick: s.party_menu.dialog_pick });
  await shot('e07_beacon_dialog');
  const before = s;
  g = s.generation;
  await clickButton('DialogOk');
  s = await waitFor((x) => x.generation > g && x.location === 'town' && x.town?.open && !x.party_menu?.open && !x.busy, '비콘 → 광장');
  idb = await waitIdb(s);
  check(s.town.page === 'plaza' && s.floor === startFloor && s.at[0] === start[0] && s.at[1] === start[1] && s.day === before.day && s.steps === before.steps
    && s.memo_texts?.[memoKey] === memoText && s.consumables[BEACON] === undefined && s.consumables[MEDICA] === medAfter && s.generation === g + 1 && !idb.timeout,
  '아이템 6: 「돌아간다」 → 광장·첫 층 시작 칸·날·걸음·지도 메모 그대로, 비콘 −1, 자동 저장 하나, IndexedDB = 화면',
  { page: s.town.page, floor: s.floor, at: s.at, day: [before.day, s.day], steps: [before.steps, s.steps], memo: s.memo_texts?.[memoKey], consumables: s.consumables, idb });
  check(s.town.notice === '' && s.toast === '' && s.warning === '' && s.modal === '' && s.town.place === '뿌리마을 광장',
    '아이템 6: 관문 도착과 같다 — 광장 안내 줄·토스트 없음(장소 문패 「뿌리마을 광장」이 있다)', { notice: s.town.notice, toast: s.toast, warning: s.warning, modal: s.modal, place: s.town.place });
  await shot('e08_beacon_town');

  // 7) 새로 고침 → 이어하기.
  const hash = s.hash;
  await page.reload();
  await page.waitForFunction(() => window.sqfDebug && window.sqfDebug.ready, null, { timeout: 60000 });
  const t = await waitTitle();
  check(t.buttons.TitleContinue, '아이템 7: 새로 고침 → 타이틀 이어하기', { title: t.title });
  await clickButton('TitleContinue');
  s = await waitFor((x) => x.town?.open && !x.busy && !x.title?.open, '이어하기');
  check(s.hash === hash && s.location === 'town' && s.consumables[MEDICA] === medAfter, '아이템 7: 이어하기 → 같은 해시·마을', { before: hash.slice(0, 12), after: s.hash.slice(0, 12) });
  log('부분 E 끝');
}
