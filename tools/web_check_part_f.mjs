// web_check 부분 F(M3 A5b, 실제 미궁 arbor: 주소에 &set 없음, 저장 폴더 saves): 채집 지점.
// 1) 새 게임 → 광장 → 마을 캠프 알약 0 / 0 셋 2) 탐사 시작 → B1F (9,18) 북 → 앞, 왼쪽 옆걸음 → g1 (8,17) 채집 물음 「오늘 남은 횟수 2/2」
// 3) Esc → 닫힘, 자동 저장 세대 그대로 4) 조사 → 「예」 → 「…를 얻었다 (남은 횟수 1/2)」, 소재 늘고 gather_used {g1: 1}, IndexedDB = 화면
// 5) 조사 → 「예」 → 0/2(다 쓴 기둥 스크린숏) 6) 옆걸음으로 떠났다 돌아오면 묻지 않고 「오늘은 더 채집할 수 없다…」
// 7) 캠프 알약 채취 0 / 2 8) 마을 문 → 광장 9) 숙소 숙박 → 2일째, 마을 캠프 채취 2 / 2(스크린숏)
// 10) 탐사 시작 → g1 물음 2/2 → Enter(처음 커서 「예」) → 채집 11) 새로 고침 → 이어하기: 같은 해시·물음 없음·소재·gather_used 그대로.
// 걸음에 전투가 나면 battle_finish 로 넘기고(승패에 기대지 않는다, D15), 물음이 없으면 조사로 다시 묻는다.
import {
  W, H, outDir, KEYS, page, check, log, snap, waitFor, waitReady, waitTitle, clickButton, enterLabyrinth, finishBattle, waitIdb,
} from './web_check_common.mjs';

const SPENT = '오늘은 더 채집할 수 없다. 마을에서 하루를 보내면 다시 채집할 수 있다';
let battlesF = 0;

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
    battlesF += 1;
    s = await finishBattle(s, false);
    s = await waitFor((x) => !x.battle?.open && !x.busy, '전투 뒤 탐색');
  }
  return s;
}

// 물음 kind 가 떠 있게 한다(전투가 난 걸음이면 조사로 다시 묻는다).
async function ask(kind) {
  let s = await snap();
  if (s.modal !== kind) {
    s = await step('investigate');
    s = await waitFor((x) => x.modal === kind, `조사로 ${kind} 물음`);
  }
  return s;
}

async function campPills() {
  await clickButton('CampButton');
  const s = await waitFor((x) => x.party_menu?.open && x.party_menu.page === 'root', '캠프 뿌리');
  return s;
}

async function closeCampRoot() {
  await clickButton('VPad_back');
  return waitFor((x) => !x.party_menu?.open && x.modal === '' && !x.busy, '캠프 닫힘');
}

const pillText = (s) => (s.party_menu?.gather_pills ?? []).map((p) => `${p.kind} ${p.left}/${p.max}`).join(', ');
const matSum = (s) => Object.values(s.materials ?? {}).reduce((a, b) => a + b, 0);

export async function partF() {
  let s = await waitReady();
  check(s.set === 'game' && s.save_dir === 'user://saves' && s.location === 'town', '실제 미궁(주소에 set 없음)·저장 폴더 saves·마을 광장',
    { set: s.set, save_dir: s.save_dir, location: s.location });
  // 1) 마을 캠프 알약.
  s = await campPills();
  check(pillText(s) === 'chop 0/0, mine 0/0, take 0/0', '채집 1: 새 게임 마을 캠프 알약 절단·추출·채취 0 / 0', { pills: s.party_menu.gather_pills });
  s = await closeCampRoot();
  // 2) g1 채집 물음.
  s = await enterLabyrinth();
  check(s.floor === 'b1f' && s.at[0] === 9 && s.at[1] === 18 && s.facing === 0, 'B1F 시작 칸 (9,18) 북', { floor: s.floor, at: s.at, facing: s.facing });
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));  // 캔버스에 키 포커스
  await step('forward');
  await step('strafe_left');
  s = await ask('gather');
  check(s.at[0] === 8 && s.at[1] === 17 && s.modal_title === '채취 지점' && s.modal_text === '생체 소재를 채취할 수 있는 곳이다. 채집할까?\n오늘 남은 횟수 2/2'
    && s.buttons.GatherYes && s.buttons.GatherNo && s.gather_here?.point === 'g1' && s.gather_here.left === 2,
  '채집 2: g1 (8,17) 채집 물음 「채취 지점」·「오늘 남은 횟수 2/2」·「예」「아니오」', { at: s.at, title: s.modal_title, text: s.modal_text, here: s.gather_here });
  await shot('f01_gather_question');
  // 3) Esc.
  let g = s.generation;
  await page.keyboard.press('Escape');
  s = await waitFor((x) => x.modal === '' && !x.busy, 'Esc 닫힘');
  await page.waitForTimeout(300);
  s = await snap();
  check(s.generation === g && JSON.stringify(s.gather_used) === '{}', '채집 3: Esc → 닫기만, 자동 저장 세대 그대로', { generation: [g, s.generation], used: s.gather_used });
  // 4) 조사 → 「예」.
  s = await ask('gather');
  const m0 = matSum(s);
  g = s.generation;
  await clickButton('GatherYes');
  s = await waitFor((x) => x.modal === '' && x.generation > g && !x.busy, '채집 「예」');
  check(/^.+를 얻었다 \(남은 횟수 1\/2\)$/.test(s.toast) && matSum(s) > m0 && JSON.stringify(s.gather_used) === '{"g1":1}' && s.generation === g + 1,
    '채집 4: 「예」 → 「…를 얻었다 (남은 횟수 1/2)」·소재 늘어남·gather_used {g1: 1}·자동 저장 하나', { toast: s.toast, materials: s.materials, used: s.gather_used });
  await shot('f02_gathered_toast');
  let idb = await waitIdb(s);
  check(!idb.timeout, '채집 4: 자동 저장이 IndexedDB(saves)에 반영(같은 세대·해시)', idb);
  // 5) 두 번째.
  s = await ask('gather');
  check(s.modal_text.endsWith('오늘 남은 횟수 1/2'), '채집 5: 조사 → 다시 묻는다(1/2)', { text: s.modal_text });
  g = s.generation;
  await clickButton('GatherYes');
  s = await waitFor((x) => x.modal === '' && x.generation > g && !x.busy, '채집 「예」 둘째');
  check(/\(남은 횟수 0\/2\)$/.test(s.toast) && JSON.stringify(s.gather_used) === '{"g1":2}' && s.gather_here.left === 0, '채집 5: 둘째 → 0/2', { toast: s.toast, used: s.gather_used });
  await shot('f03_spent_marker');
  // 6) 떠났다 돌아오기.
  await step('strafe_right');
  s = await step('strafe_left');
  if (s.toast !== SPENT) s = await step('investigate');  // 전투가 난 걸음이면 알림이 없다
  check(s.at[0] === 8 && s.at[1] === 17 && s.modal === '' && s.toast === SPENT, '채집 6: 다 쓴 지점 = 물음 없이 「오늘은 더 채집할 수 없다…」', { at: s.at, modal: s.modal, toast: s.toast });
  // 7) 캠프 알약.
  s = await campPills();
  check(pillText(s) === 'chop 0/0, mine 0/0, take 0/2', '채집 7: 미궁 캠프 알약 채취 0 / 2(서 보지 않은 g2 는 세지 않는다)', { pills: s.party_menu.gather_pills });
  await shot('f04_camp_pills_labyrinth');
  s = await closeCampRoot();
  // 8) 마을 문 → 광장.
  await step('strafe_right');
  await step('back');
  s = await ask('stairs');
  check(s.at[0] === 9 && s.at[1] === 18 && s.buttons.StairsYes, '채집 8: 마을 문 물음', { at: s.at, modal: s.modal });
  await clickButton('StairsYes');
  s = await waitFor((x) => x.location === 'town' && x.town?.open && x.town.page === 'plaza' && !x.busy, '광장');
  // 9) 숙소 숙박.
  await clickButton('Plaza_inn');
  await waitFor((x) => x.town?.page === 'inn' && !x.busy, '숙소');
  await clickButton('Inn_stay');
  await waitFor((x) => x.town?.dialog?.mode === 'confirm', '숙박 확인');
  g = (await snap()).generation;
  await clickButton('Yes');
  s = await waitFor((x) => x.town?.dialog?.mode === '' && x.day === 2 && x.generation > g && !x.busy, '묵음');
  idb = await waitIdb(s);
  check(s.day === 2 && !idb.timeout, '채집 9: 숙박 → 2일째·자동 저장(IndexedDB = 화면)', { day: s.day, idb });
  s = await campPills();
  check(pillText(s) === 'chop 0/0, mine 0/0, take 2/2', '채집 9: 숙박 뒤 마을 캠프 알약 채취 2 / 2', { pills: s.party_menu.gather_pills });
  await shot('f05_camp_pills_town');
  s = await closeCampRoot();
  await clickButton('Inn_leave');
  await waitFor((x) => x.town?.page === 'plaza' && !x.busy, '광장');
  // 10) 다시 g1.
  s = await enterLabyrinth();
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));
  await step('forward');
  await step('strafe_left');
  s = await ask('gather');
  check(s.modal_text.endsWith('오늘 남은 횟수 2/2') && s.gather_here.left === 2, '채집 10: 숙박 뒤 g1 물음 2/2', { text: s.modal_text, here: s.gather_here });
  g = s.generation;
  await page.keyboard.press('Enter');  // 처음 커서 「예」(D25)
  s = await waitFor((x) => x.modal === '' && x.generation > g && !x.busy, 'Enter 「예」');
  check(/\(남은 횟수 1\/2\)$/.test(s.toast) && JSON.stringify(s.gather_used) === '{"g1":1}', '채집 10: Enter(처음 커서 「예」) → 채집', { toast: s.toast, used: s.gather_used });
  idb = await waitIdb(s);
  check(!idb.timeout, '채집 10: 새로 고침 전 IndexedDB = 화면', idb);
  // 11) 새로 고침 → 이어하기.
  const before = s;
  await page.reload();
  await page.waitForFunction(() => window.sqfDebug && window.sqfDebug.ready, null, { timeout: 60000 });
  const t = await waitTitle();
  check(t.buttons.TitleContinue, '채집 11: 새로 고침 → 타이틀 이어하기', { title: t.title });
  await clickButton('TitleContinue');
  s = await waitFor((x) => x.location === 'labyrinth' && !x.busy && !x.title?.open, '이어하기');
  check(s.hash === before.hash && s.modal === '' && JSON.stringify(s.materials) === JSON.stringify(before.materials)
    && JSON.stringify(s.gather_used) === '{"g1":1}' && s.at[0] === 8 && s.at[1] === 17,
  '채집 11: 이어하기 → 같은 해시·물음 없음·소재·gather_used 그대로', { before: before.hash.slice(0, 12), after: s.hash.slice(0, 12), modal: s.modal, used: s.gather_used });
  log('부분 F 끝', { battles: battlesF });
}
