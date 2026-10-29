// web_check 부분 C(마을 고리, M3 A2): 빈 IndexedDB 의 타이틀(이어하기 없음) → 「새 게임」 → 마을 광장(줄·흐림·띠·1일째) → 캠프 장소 띠 →
// 「아보르 입구」 → 「탐사 시작」 → B1F 시작 칸 → 한 칸 나갔다 돌아옴 → 마을 문 물음 「예」 → 광장(IndexedDB = 화면) → 「정크 공방」 → 뒤로 광장
// → 「캡슐 숙소」(A2b): 숙박 확인 「예」 → 2일째(IndexedDB) → 「기록한다」 슬롯 1 → 나간다 → 광장에서 연 캠프 「기록」은 「저장」 흐림(D30 = R-B)
// → 새로 고침 → 타이틀 「이어하기」(같은 해시) → 새로 고침 → 타이틀 「불러오기」 → 슬롯 1(같은 해시).
import {
  W, H, outDir, page, log, check, snap, waitFor, clickButton, waitIdb, waitTitle, enterLabyrinth, openRecords, closeCamp,
} from './web_check_common.mjs';

const PLAZA = ['Plaza_inn', 'Plaza_shop', 'Plaza_pub', 'Plaza_guild', 'Plaza_council', 'Plaza_entrance'];

export async function partC() {
  const tag = `${W}x${H}`;
  await page.waitForFunction(() => window.sqfDebug && window.sqfDebug.ready, null, { timeout: 60000 });
  // 1. 타이틀(이어하기 없음) → 새 게임 → 광장.
  let t = await waitTitle();
  check(t.hash === '' && t.title.page === 'menu' && !t.title.continue && JSON.stringify(t.title.rows) === JSON.stringify(['load', 'new_game', 'settings'])
    && !t.buttons.TitleContinue && t.buttons.TitleLoad && t.buttons.TitleNewGame && t.buttons.TitleSettings && !t.buttons.CampButton,
  '마을 1: 빈 저장소 타이틀 = 불러오기·새 게임·설정(이어하기 없음, 상태 없음)', { title: t.title, buttons: Object.keys(t.buttons) });
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/c01_title_${tag}.png` });
  await clickButton('TitleNewGame');
  let s = await waitFor((x) => x.location === 'town' && x.town?.open && !x.busy, '새 게임 → 광장');
  check(s.town.page === 'plaza' && JSON.stringify(s.town.rows) === JSON.stringify(PLAZA)
    && JSON.stringify(s.town.dim) === JSON.stringify([false, false, true, false, true, false]) && s.town.band[0] === '묵어서 쉬고, 진행을 기록한다'
    && s.day === 1 && s.town.day === '1일째' && s.autosaves === 1 && s.town.art === 'plaza' && !s.buttons.MapButton && !s.buttons.Pad_forward
    && s.buttons.CampButton && PLAZA.every((n) => s.buttons[n]),
  '마을 1: 광장 — 원작 차례 여섯 줄·흐림(정보상 바·관리국, 길드는 A7c 에서 연다)·띠·1일째, 새 게임 자동 저장, 탐색 HUD 없음',
  { town: s.town, day: s.day, autosaves: s.autosaves, buttons: Object.keys(s.buttons) });
  let idb = await waitIdb(s);
  check(!idb.timeout, '마을 1: 새 게임 자동 저장이 IndexedDB 에 반영', idb);
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/c02_plaza_${tag}.png` });
  await clickButton('Plaza_pub');
  s = await waitFor((x) => x.town?.notice !== '', '흐린 줄 이유');
  check(s.town.band[1] === '아직 문을 열지 않았다' && s.town.page === 'plaza' && s.town.cursor === 2 && !s.shop?.open && s.autosaves === 1,
    '마을 1: 흐린 줄 「정보상 바」 → 띠 둘째 줄에 이유만', { town: s.town });
  await clickButton('CampButton');
  s = await waitFor((x) => x.party_menu?.open && x.party_menu.page === 'root', '캠프(광장)');
  check(s.party_menu.ribbon === '뿌리마을 광장' && !s.buttons.Plaza_shop && s.town.covered,
    '마을 1: 다이얼 자리 「캠프」 → 캠프 장소 띠 「뿌리마을 광장」(광장 줄은 덮임)', { ribbon: s.party_menu.ribbon, covered: s.town.covered });
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/c03_camp_in_town_${tag}.png` });
  await clickButton('VPad_back');
  s = await waitFor((x) => !x.party_menu?.open && x.town?.open && !x.town.covered, '캠프 닫힘');

  // 2. 입구 → 탐사 시작 → 한 칸 나갔다 돌아옴 → 마을 문 물음 「예」 → 광장.
  await clickButton('Plaza_entrance');
  s = await waitFor((x) => x.town?.page === 'entrance', '아보르 입구');
  check(s.town.band[0] === '아보르 B1F로 내려간다' && s.buttons.Entrance_start && s.buttons.Entrance_back && !s.buttons.Plaza_shop,
    '마을 2: 아보르 입구 — 띠·줄 둘', { town: s.town });
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/c04_entrance_${tag}.png` });
  await clickButton('VPad_back');
  s = await waitFor((x) => x.town?.page === 'plaza' && x.town.cursor === 5, '입구 취소 → 광장');
  s = await enterLabyrinth();
  check(s.at[0] === 2 && s.at[1] === 18 && s.modal === '' && s.autosaves === 2 && s.buttons.MapButton && s.buttons.Pad_forward && !s.town.open,
    '마을 2: 탐사 시작 → B1F 시작 칸(물음 없음), 탐색 HUD, 자동 저장', { at: s.at, modal: s.modal, autosaves: s.autosaves });
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));  // 캔버스에 키 포커스
  let g = s.generation;
  await page.keyboard.press('KeyW');
  s = await waitFor((x) => x.generation > g && !x.busy, '한 칸 나감');
  g = s.generation;
  await page.keyboard.press('KeyS');
  s = await waitFor((x) => x.generation > g && x.modal === 'stairs', '문으로 돌아옴 → 물음');
  check(s.modal_title === '아보르 입구' && s.at[0] === 2 && s.at[1] === 18, '마을 2: 시작 칸으로 돌아오면 마을 문 물음', { modal_title: s.modal_title, at: s.at });
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/c05_gate_prompt_${tag}.png` });
  g = s.generation;
  await clickButton('StairsYes');
  s = await waitFor((x) => x.generation > g && x.location === 'town' && x.town?.open && x.modal === '' && !x.busy, '「예」 → 광장');
  idb = await waitIdb(s);
  check(s.town.page === 'plaza' && s.town.cursor === 0 && !s.buttons.MapButton && !idb.timeout, '마을 2: 「예」 → 광장, 자동 저장이 IndexedDB 에 반영',
    { town: s.town, idb });

  // 3. 정크 공방 → 뒤로 → 광장(커서 그대로).
  await clickButton('Plaza_shop');
  s = await waitFor((x) => x.shop?.open && x.shop.page === 'root', '상점 뿌리');
  check(!s.buttons.Plaza_shop && s.buttons.Root_buy && s.town.covered && s.town.art === 'plaza', '마을 3: 「정크 공방」 → 상점(광장 덮임)', { town: s.town });
  await clickButton('VPad_back');
  s = await waitFor((x) => !x.shop?.open && x.town?.open && !x.town.covered, '상점 닫힘');
  check(s.town.page === 'plaza' && s.town.cursor === 1 && s.buttons.Plaza_shop, '마을 3: 상점 닫기 → 광장, 커서 「정크 공방」', { town: s.town });

  // 4. 캡슐 숙소(M3 A2b): 줄 넷(대화 흐림)·띠(설명 / 숙박비)·그림 → 숙박 확인(「예」 먼저) → 「예」 = 2일째·돈 −10·자동 저장(IndexedDB)
  //    → 「기록한다」 = 기록 판(「저장」만) → 슬롯 1 → 취소 → 나간다. 광장에서 연 캠프 「기록」은 「저장」이 흐리다(D30 = R-B).
  const INN = ['Inn_stay', 'Inn_save', 'Inn_talk', 'Inn_leave'];
  await clickButton('Plaza_inn');
  s = await waitFor((x) => x.town?.page === 'inn', '캡슐 숙소');
  check(JSON.stringify(s.town.rows) === JSON.stringify(INN) && JSON.stringify(s.town.dim) === JSON.stringify([false, false, true, false])
    && s.town.band[0] === '하룻밤 묵어 모두의 HP·TP를 회복하고 날을 넘긴다' && s.town.band[1] === '숙박비 10엔' && s.town.price === 10
    && s.town.art === 'inn' && s.town.place === '캡슐 숙소' && INN.every((n) => s.buttons[n]) && s.buttons.CampButton && !s.buttons.Plaza_inn,
  '마을 4: 캡슐 숙소 — 줄 넷(대화 흐림)·띠(설명 / 숙박비 10엔)·숙소 그림', { town: s.town, buttons: Object.keys(s.buttons) });
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/c07_inn_${tag}.png` });
  const money0 = s.town.money;
  const saves0 = s.autosaves;
  await clickButton('Inn_stay');
  s = await waitFor((x) => x.town?.dialog?.mode === 'confirm', '숙박 확인');
  check(s.town.dialog.pick === 0 && s.town.dialog.text === '10엔에 하룻밤 묵을까?' && s.buttons.Yes && s.buttons.No && !s.buttons.Inn_stay,
    '마을 4: 숙박 확인 창 — 「예」 먼저(D25), 창 단추만', { dialog: s.town.dialog, buttons: Object.keys(s.buttons) });
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/c08_inn_confirm_${tag}.png` });
  await clickButton('Yes');
  s = await waitFor((x) => x.town?.dialog?.mode === '' && x.day === 2 && !x.busy, '묵음');
  check(s.town.money === money0 - 10 && s.autosaves === saves0 + 1 && s.town.day === '2일째' && s.town.band[1] === '하룻밤 묵었다. HP·TP가 모두 회복됐다',
    '마을 4: 「예」 → 2일째·돈 −10·안내·자동 저장', { money: s.town.money, autosaves: s.autosaves, day: s.town.day, band: s.town.band });
  idb = await waitIdb(s);
  check(!idb.timeout, '마을 4: 숙박 자동 저장이 IndexedDB 에 반영', idb);
  await clickButton('Inn_save');
  s = await waitFor((x) => x.town?.page === 'inn_save', '숙소 기록');
  check(s.town.records?.rows === 'inn_save' && s.buttons.Save_slot1 && s.buttons.Save_slot3 && !s.buttons.Load_slot1 && !s.buttons.Export && !s.buttons.Inn_stay,
    '마을 4: 「기록한다」 → 기록 판(「저장」만)', { town: s.town, buttons: Object.keys(s.buttons) });
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/c09_inn_save_${tag}.png` });
  await clickButton('Save_slot1');
  s = await waitFor((x) => x.town?.records?.cards?.[0]?.[1] !== '', '슬롯 1 기록');
  const slotHash = s.hash;
  check(s.town.records.cards[0][1].startsWith('뿌리마을 광장 · 걸음'), '마을 4: 슬롯 1 기록(장소 = 광장)', { cards: s.town.records.cards });
  await clickButton('VPad_back');
  s = await waitFor((x) => x.town?.page === 'inn' && x.town.cursor === 1, '숙소로');
  await clickButton('Inn_leave');
  s = await waitFor((x) => x.town?.page === 'plaza' && x.town.cursor === 0, '광장');
  s = await openRecords();
  check(!s.party_menu.records.save_ok && s.party_menu.records.help === '기록은 캡슐 숙소에서 한다',
    '마을 4: 광장에서 연 캠프 「기록」 — 「저장」 흐림, 도움말 = 숙소에서 기록', { records: s.party_menu.records });
  s = await closeCamp();
  idb = await waitIdb(s);

  // 5. 새로 고침 → 타이틀 「이어하기」 → 광장, 같은 해시.
  const before = s;
  await page.reload();
  await page.waitForFunction(() => window.sqfDebug && window.sqfDebug.ready, null, { timeout: 60000 });
  t = await waitTitle();
  check(t.title.continue && t.title.rows[0] === 'continue' && t.buttons.TitleContinue, '마을 5: 새로 고침 → 타이틀(이어하기 첫 줄)', { title: t.title });
  await clickButton('TitleContinue');
  s = await waitFor((x) => x.town?.open && !x.busy, '이어하기 → 광장');
  check(s.hash === before.hash && s.location === 'town' && s.town.page === 'plaza' && s.autosaves === 0, '마을 5: 이어하기 → 광장, 같은 해시(저장 안 함)',
    { before: before.hash.slice(0, 12), after: s.hash.slice(0, 12), autosaves: s.autosaves });

  // 6. 새로 고침 → 타이틀 「불러오기」 → 슬롯 1 → 같은 해시.
  await page.reload();
  await page.waitForFunction(() => window.sqfDebug && window.sqfDebug.ready, null, { timeout: 60000 });
  t = await waitTitle();
  await clickButton('TitleLoad');
  await page.waitForTimeout(150);
  t = await snap();
  check(t.title.page === 'load' && t.buttons.Load_slot1 && t.buttons.Import && !t.buttons.Save_slot1 && !t.buttons.Export && !t.buttons.NewGame,
    '마을 6: 타이틀 불러오기 = 슬롯 「불러오기」·「가져오기」만', { title: t.title, buttons: Object.keys(t.buttons) });
  await page.screenshot({ path: `${outDir}/c06_title_load_${tag}.png` });
  await clickButton('Load_slot1');
  s = await waitFor((x) => x.town?.open && !x.busy && !x.title?.open, '슬롯 1 불러오기');
  check(s.hash === slotHash && s.location === 'town' && s.autosaves === 1, '마을 6: 슬롯 1 → 광장, 같은 해시(불러오기 자동 저장)',
    { slot: slotHash.slice(0, 12), now: s.hash.slice(0, 12), autosaves: s.autosaves });
  idb = await waitIdb(s);
  check(!idb.timeout, '마을 6: 불러오기 자동 저장이 IndexedDB 에 반영', idb);
  log('부분 C 끝');
}
