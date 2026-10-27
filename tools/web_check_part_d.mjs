// web_check 부분 D(M3 A3b, 실제 미궁 arbor: 주소에 &set 없음, 저장 폴더 saves): 새 게임 → 광장 → 탐사 시작 → B1F 를 고정 공략
// (data/floors/arbor_route.json)으로 B3F 도착까지 걷는다. 전투는 battle_finish 로 넘긴다(승패에 기대지 않는다, D15).
// 1) B1F 장소 글 2) 상자 c1: 물음 → 「예」 → 「…3개를 얻었다」·소재 +3·자동 저장, 떠났다 돌아오면 묻지 않고 조사는 「빈 상자다」
// 3) B1F 계단(A1 에서 미룬 실제 층 확인): 「아니오」(그대로·저장 없음) → 조사로 다시 → 「예」 → B2F 4) B2F 에서 새로 고침: 같은 해시·물음 없음
// 5) 열쇠 없이 잠긴 문 6) 열쇠 상자 → 귀중품 7) 캠프 소지품의 귀중품 줄·설명·띠 8) 열쇠로 문 열기 → 지나감 9) B2F 계단 → B3F
// 10) 캠프 「기록」 가져오기로 시험 층 3판 저장(tools/web_check_victory_save.json) → 옮김 알림 → 광장.
// 공략이 묻는 물음(계단·상자) 가운데 공략이 답하지 않는 것은 「아니오」로 닫고, 공략의 open·stairs 는 물음이 없으면(전투가 난 걸음) 조사로 다시 묻는다.
import fs from 'node:fs';
import {
  W, H, outDir, KEYS, page, check, log, snap, waitFor, waitReady, clickButton, enterLabyrinth, openRecords, finishBattle,
  waitIdb, VICTORY_SAVE,
} from './web_check_common.mjs';

const routeD = JSON.parse(fs.readFileSync('data/floors/arbor_route.json', 'utf8'));
// B3F 도착(체크포인트 「B3F 도착」)까지만 걷는다.
const STOP = routeD.checkpoints.find((c) => c.floor === 'b3f').after;
let battlesD = 0;

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
    battlesD += 1;
    s = await finishBattle(s, false);
    s = await waitFor((x) => !x.battle?.open && !x.busy, '전투 뒤 탐색');
  }
  return s;
}

// 공략의 open·stairs: 물음이 떠 있지 않으면(전투가 난 걸음) 조사로 다시 묻고 「예」.
async function answerYes(kind, yes) {
  let s = await snap();
  if (s.modal !== kind) {
    s = await step('investigate');
    s = await waitFor((x) => x.modal === kind, `조사로 ${kind} 물음`);
  }
  const g = s.generation;
  await clickButton(yes);
  return waitFor((x) => x.modal === '' && x.generation > g && !x.busy, `${kind} 「예」`);
}

async function answerNo(no) {
  await clickButton(no);
  return waitFor((x) => x.modal === '' && !x.busy, `${no}`);
}

export async function partD() {
  let s = await waitReady();
  check(s.set === 'game' && s.save_dir === 'user://saves' && s.location === 'town', '실제 미궁(주소에 set 없음)·저장 폴더 saves·마을 광장',
    { set: s.set, save_dir: s.save_dir, location: s.location });
  s = await enterLabyrinth();
  check(s.floor === 'b1f' && s.at[0] === 9 && s.at[1] === 18 && s.toast === '네온 이끼숲 / B1F' && s.modal === '',
    'B1F 시작 칸, 장소 글 「네온 이끼숲 / B1F」', { floor: s.floor, at: s.at, toast: s.toast });
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));  // 캔버스에 키 포커스
  const t0 = Date.now();
  for (let i = 0; i < STOP; i++) {
    const a = routeD.actions[i];
    const after = i + 1;
    if (a === 'open') {
      if (after === 4) {
        // 2) c1: 걸어 들어온 물음을 본다 → 「예」.
        const q = await snap();
        check(q.modal === 'chest' && q.modal_title === '보물상자' && q.modal_text === '보물상자가 있다. 열어 볼까?' && q.buttons.ChestYes && q.buttons.ChestNo
          && q.chest_here === 'c1', 'c1 에 서면 상자 물음(「예」「아니오」)', { modal: q.modal, title: q.modal_title, text: q.modal_text, chest_here: q.chest_here });
        await shot('d01_chest_question');
        s = await answerYes('chest', 'ChestYes');
        check(s.toast === '네온 쥐 꼬리 3개를 얻었다' && s.materials['item.neon_rat_tail'] === 3 && s.chests_opened === 1 && s.generation === q.generation + 1,
          '「예」 → 「네온 쥐 꼬리 3개를 얻었다」·소재 +3·연 상자 1·자동 저장', { toast: s.toast, materials: s.materials, chests_opened: s.chests_opened, generation: s.generation });
        const idb = await waitIdb(s);
        check(!idb.timeout, '상자 열기 자동 저장이 IndexedDB(saves)에 반영', idb);
        s = await step('strafe_left');
        s = await step('strafe_right');
        check(s.at[0] === 10 && s.at[1] === 16 && s.modal === '', '연 상자 칸에 다시 서면 묻지 않는다', { at: s.at, modal: s.modal });
        s = await step('investigate');
        check(s.toast === '빈 상자다' && s.modal === '', '연 상자 조사 = 「빈 상자다」', { toast: s.toast });
      } else {
        s = await answerYes('chest', 'ChestYes');
      }
      if (after === 58) {
        check(JSON.stringify(s.key_items) === '["key.moss_card"]' && s.toast === '이끼 낀 출입 카드를 얻었다', 'B2F 열쇠 상자 → 귀중품', { key_items: s.key_items, toast: s.toast });
        // 7) 캠프 소지품: 귀중품 줄은 마지막, 설명·띠.
        await clickButton('CampButton');
        await waitFor((x) => x.party_menu?.open && x.party_menu.page === 'root', '캠프 뿌리');
        await clickButton('Camp_items');
        let m = await waitFor((x) => x.party_menu?.page === 'sub' && x.party_menu.tab === 'items' && x.party_menu.item_rows?.length >= 2, '소지품(줄이 찬 뒤)');
        const rows = m.party_menu.item_rows;
        // ↓ 로 귀중품 줄(마지막)까지: 설명 상자 머리가 그 이름이 될 때까지(줄 수 + 1 번까지).
        for (let k = 0; k <= rows.length && (await snap()).party_menu.item_desc?.[0] !== '이끼 낀 출입 카드'; k++) {
          await page.keyboard.press('ArrowDown');
          await page.waitForTimeout(120);
        }
        m = await waitFor((x) => x.party_menu.item_desc?.[0] === '이끼 낀 출입 카드', '귀중품 줄 커서(설명 상자)', 3000);
        check(rows[rows.length - 1] === 'key.moss_card' && m.party_menu.item_desc[0] === '이끼 낀 출입 카드'
          && m.party_menu.item_desc[2] === '귀중품 · 팔 수 없다' && / · 귀중품 1$/.test(m.party_menu.strip),
        '소지품: 귀중품 줄(마지막)·설명 상자·띠 「귀중품 1」', { rows, desc: m.party_menu.item_desc, strip: m.party_menu.strip });
        await shot('d04_items_key');
        await clickButton('VPad_back');
        await waitFor((x) => x.party_menu?.page === 'root', '캠프 뿌리');
        await clickButton('VPad_back');
        s = await waitFor((x) => !x.party_menu?.open && x.modal === '', '캠프 닫힘');
        await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));
      }
    } else if (a === 'stairs') {
      if (after === 29) {
        // 3) B1F 계단: 「아니오」 → 그대로 → 조사로 다시 → 「예」.
        let q = await snap();
        if (q.modal !== 'stairs') {
          await step('investigate');
          q = await waitFor((x) => x.modal === 'stairs', '조사로 계단 물음');
        }
        check(q.modal_title === '계단' && q.modal_text === '아래층으로 내려가는 계단이 있다. 내려갈까?' && q.at[0] === 17 && q.at[1] === 1,
          'B1F (17,1) 계단 물음', { title: q.modal_title, text: q.modal_text, at: q.at });
        s = await answerNo('StairsNo');
        check(s.floor === 'b1f' && s.generation === q.generation && s.hash === q.hash, '「아니오」: 그대로, 저장 없음', { floor: s.floor, generation: s.generation });
        s = await step('investigate');
        s = await waitFor((x) => x.modal === 'stairs', '조사로 다시 묻는다');
        s = await answerYes('stairs', 'StairsYes');
        check(s.floor === 'b2f' && s.at[0] === 17 && s.at[1] === 1 && s.toast === '네온 이끼숲 / B2F', '「예」 → B2F (17,1), 장소 글',
          { floor: s.floor, at: s.at, toast: s.toast });
        await shot('d02_b2f');
        // 4) B2F 에서 새로 고침: 같은 해시, 물음 없음.
        const idb = await waitIdb(s);
        check(!idb.timeout, '새로 고침 전 IndexedDB = 화면', idb);
        const before = s;
        await page.reload();
        s = await waitReady();
        check(s.hash === before.hash && s.floor === 'b2f' && s.modal === '', 'B2F 새로 고침: 같은 해시, 물음 없음', { before: before.hash.slice(0, 12), after: s.hash.slice(0, 12), modal: s.modal });
        await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));
      } else {
        s = await answerYes('stairs', 'StairsYes');
      }
      if (after === 96) {
        check(s.floor === 'b3f' && s.at[0] === 17 && s.at[1] === 18 && s.toast === '네온 이끼숲 / B3F', 'B2F 계단 → B3F (17,18)', { floor: s.floor, at: s.at, toast: s.toast });
        await shot('d06_b3f');
      }
    } else {
      s = await step(a);
    }
    if (after === 34) {
      check(s.toast === '잠긴 문이다. 열쇠가 필요하다' && s.locks_open === 0 && s.at[0] === 16 && s.at[1] === 3, '열쇠 없이 잠긴 문: 안내, 막힘',
        { toast: s.toast, locks_open: s.locks_open, at: s.at });
      await shot('d03_lock');
    }
    if (after === 80) {
      check(s.toast === '이끼 낀 출입 카드로 문을 열었다' && s.locks_open === 1 && s.at[0] === 16 && s.at[1] === 3, '열쇠로 문을 연다(움직이지 않음)',
        { toast: s.toast, locks_open: s.locks_open, at: s.at });
      await shot('d05_unlocked');
    }
    if (after === 81) check(s.at[0] === 16 && s.at[1] === 4, '연 문을 지나간다', { at: s.at });
    // 공략이 바로 답하지 않는 물음(지나가는 상자·계단)은 「아니오」로 닫는다.
    const next = routeD.actions[i + 1];
    s = await snap();
    if (s.modal === 'chest' && next !== 'open') s = await answerNo('ChestNo');
    if (s.modal === 'stairs' && next !== 'stairs') s = await answerNo('StairsNo');
    const cp = routeD.checkpoints.find((c) => c.after === after);
    if (cp) check(s.floor === cp.floor && s.at[0] === cp.at[0] && s.at[1] === cp.at[1], `체크포인트 「${cp.note}」`, { floor: s.floor, at: s.at });
  }
  log('공략 끝', { ms: Date.now() - t0, battles: battlesD });
  // 10) 시험 층 3판 저장 가져오기 → 옮김 알림 → 광장.
  const file = JSON.parse(fs.readFileSync(VICTORY_SAVE, 'utf8'));
  s = await openRecords();
  const [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import')]);
  await chooser.setFiles(VICTORY_SAVE);
  s = await waitFor((x) => x.modal === 'alert', '옮김 알림', 10000);
  check(s.modal_title === '알림' && s.modal_text.startsWith('가져왔다\n시험 층에서 남긴 기록이라 새 미궁에 맞춰 옮겼다') && s.toast === ''
    && s.location === 'town' && s.floor === 'b1f' && !s.pending && s.battle?.open !== true,
    '시험 층 저장 가져오기 → 안내와 옮김을 한 알림(알림 줄 없음, 마을, 전투 없음)', { title: s.modal_title, text: s.modal_text, toast: s.toast, location: s.location, pending: s.pending });
  const exps = file.state.party.members.map((m) => m.exp);
  check(JSON.stringify(s.members.map((m) => m.exp)) === JSON.stringify(exps) && s.money === 200 && JSON.stringify(s.key_items) === '[]',
    '파티 경험치는 파일 그대로, 소지금 200(3판 이전), 귀중품 없음', { exp: s.members.map((m) => m.exp), want: exps, money: s.money });
  await shot('d07_relocated');
  await clickButton('AlertOk');
  s = await waitFor((x) => x.modal === '' && x.town?.open && x.town.page === 'plaza', '알림 닫힘 → 광장');
  check(s.location === 'town' && s.town.page === 'plaza', '알림을 닫으면 광장', { town: s.town?.page });
}
