// web_check 부분 J(M3 A9b 설계 §7.3, 실제 미궁 arbor: 주소에 &set 없음, 저장 폴더 saves): 제1계층 보스.
// 1) 새 게임 → 광장 → 캠프 「기록」 → 가져오기: 고정 저장 tools/web_check_boss_save.json(tools/make_boss_save.gd 가 실제 공략으로 만든다,
//    B3F (9,2) 서쪽 = 봉인 앞, 봉인 임무 보고, Lv 10) → B3F (9,2).
// 2) 실제 키 「앞으로」 → 봉인 열림 알림, 제자리, IndexedDB = 화면.
// 3) 앞으로 네 번 → (5,2)(보스 방, 위험도 0 이라 전투 없음).
// 4) 「앞으로」(부딪힘) → 보스 물음 창: 제목·글·경고, 처음 커서 「아니오」 → 「아니오」 → 닫힘, 저장 그대로.
// 5) 다시 「앞으로」 → 「예」 터치 → 보스 전투: 띠 보스 시작 줄·알림, music_cue boss, 도주 줄을 누르면 이유 「도망칠 수 없다」.
// 6) 실제 명령 한 턴(디버그 battle_commands, 모두 적 0 공격) → 새로 고침 → 같은 전투(해시·턴).
// 7) 디버그 battle_finish → 결과 창 「확인」 → 이야기 상자(쪽 셋): 상자 누르기 → 키패드 「선택」 → 넘김 단추 「확인」 → 닫힘.
// 8) 보스 defeated, 표지 없음(foe_mark_list), cleared [b3f], 미니맵 보스 원 없음.
// 9) 새로 고침 → 같은 해시, 이야기 상자 없음.
// 10) 보스 방에서 비콘(디버그 supply) 「쓰기」 흐림 → 누르면 이유 「이곳에서는 비콘 신호가 닿지 않는다」.
// 쪽마다 캡처(build/check/j??_*.png).
import {
  W, H, outDir, KEYS, page, check, log, snap, request, waitFor, waitReady, clickButton, waitIdb, openRecords, finishBattle, reloadInBattle,
} from './web_check_common.mjs';
import path from 'node:path';

const BOSS_SAVE = path.resolve('tools/web_check_boss_save.json');
const BEACON = 'use.ariadne_beacon';
const ASK = '네온 펜리르가 버티고 서 있다. 싸울까?\n이 싸움에서는 도망칠 수 없다';

async function shot(name) {
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/${name}_${W}x${H}.png` });
}

// 행동 하나(키): 세대가 오르고 연출이 끝날 때까지(보스 방 걸음에는 전투가 없다).
async function step(name) {
  const before = await snap();
  await page.keyboard.press(KEYS[name]);
  return waitFor((x) => x.generation > before.generation && !x.busy, `행동 ${name}`);
}

const bossOf = (s) => (s.foes ?? []).find((f) => f.id === 'boss');

export async function partJ() {
  const t0 = Date.now();
  let s = await waitReady();
  check(s.set === 'game' && s.location === 'town', '보스 0: 실제 미궁·마을', { set: s.set, location: s.location });
  // 1) 고정 저장 가져오기.
  s = await openRecords();
  const [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import')]);
  await chooser.setFiles(BOSS_SAVE);
  s = await waitFor((x) => x.location === 'labyrinth' && x.floor === 'b3f' && !x.party_menu?.open && !x.busy, '고정 저장 가져오기', 15000);
  const locks0 = s.locks_open;  // 공략이 연 B3F 열쇠 문(h:12:3)이 이미 있다
  check(s.at[0] === 9 && s.at[1] === 2 && s.facing === 3 && s.flags.includes('permit.boss') && bossOf(s)?.state === 'idle'
    && locks0 === 1 && s.boss_near === '' && JSON.stringify(s.cleared) === '[]',
  '보스 1: 가져오기 → B3F (9,2) 서쪽, permit.boss, 연 문 1(열쇠 문 h:12:3 뿐, 봉인은 닫힘), 보스 idle',
  { at: s.at, facing: s.facing, flags: s.flags, locks: locks0, boss: bossOf(s), toast: s.toast });
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));  // 캔버스에 키 포커스
  await shot('j00_seal');
  // 2) 봉인 열기.
  s = await step('forward');
  check(s.toast === '관리국의 허가 신호에 봉인이 풀렸다' && s.at[0] === 9 && s.locks_open === locks0 + 1, '보스 2: 앞으로 → 봉인 열림 알림, 제자리, 연 문 +1', { toast: s.toast, at: s.at, locks: [locks0, s.locks_open] });
  let idb = await waitIdb(s);
  check(!idb.timeout, '보스 2: 봉인 열림 자동 저장이 IndexedDB 에 반영', idb);
  // 3) 보스 앞까지.
  for (let k = 0; k < 4; k++) s = await step('forward');
  const markBoss = s.foe_mark_list.find((m) => m.id === 'boss');
  check(s.at[0] === 5 && s.at[1] === 2 && !s.battle?.open && s.boss_near === 'boss' && markBoss?.boss === true && Math.abs(markBoss.scale - 1.25) < 1e-6
    && s.minimap_foes.find((f) => f.id === 'boss')?.boss === true,
  '보스 3: (5,2) 보스 앞, 전투 없음, 3D 표지 1.25 배·미니맵 보스 원', { at: s.at, boss_near: s.boss_near, mark: markBoss, minimap: s.minimap_foes });
  await shot('j01_boss_view');
  // 4) 부딪힘 → 물음 → 「아니오」.
  await page.keyboard.press(KEYS.forward);
  s = await waitFor((x) => x.modal === 'boss' && !x.busy, '보스 물음');
  check(s.modal_title === '강대한 기척' && s.modal_text === ASK && s.modal_focus === 'BossNo' && s.buttons.BossYes && s.buttons.BossNo,
    '보스 4: 물음 창(제목·글·경고), 처음 커서 「아니오」', { title: s.modal_title, text: s.modal_text, focus: s.modal_focus });
  await shot('j02_boss_ask');
  const g4 = s.generation;
  const h4 = s.hash;
  await clickButton('BossNo');
  s = await waitFor((x) => x.modal === '' && !x.busy, '물음 닫힘');
  await page.waitForTimeout(300);
  s = await snap();
  check(s.generation === g4 && s.hash === h4 && !s.battle?.open && s.at[0] === 5, '보스 4: 「아니오」 → 닫기만(저장·상태 그대로)', { generation: [g4, s.generation] });
  // 5) 다시 → 「예」.
  await page.keyboard.press(KEYS.forward);
  s = await waitFor((x) => x.modal === 'boss' && !x.busy, '보스 물음 다시');
  await clickButton('BossYes');
  s = await waitFor((x) => x.battle?.open && x.battle.phase === 'command' && !x.busy, '보스 전투');
  check(s.battle.foe === 'boss' && s.battle.music_cue === 'boss' && s.battle.boss === true && s.battle.enemy_hp[0] === 1800
    && s.battle.banner[0] === '네온 펜리르가 앞을 막아선다!' && s.battle.banner[1] === '봉인 너머의 주인이 깨어났다!',
  '보스 5: 「예」 → 보스 전투(펜리르 1800, music_cue boss, 띠·알림)', { battle: { foe: s.battle.foe, music: s.battle.music_cue, hp: s.battle.enemy_hp, banner: s.battle.banner } });
  await shot('j03_boss_battle');
  // 전투 층은 한 프레임에 입력 하나이고 막 열린 층은 미리 받은 입력을 버린다: 이유가 보일 때까지 세 번까지 누른다.
  let why = null;
  for (let k = 0; k < 3 && !why; k++) {
    await clickButton('Cmd_escape');
    why = await waitFor((x) => x.battle?.banner?.[1] === '도망칠 수 없다', '도주 이유', 3000).catch(() => null);
  }
  s = why ?? await snap();
  // 이유가 실제로 보였을 때만 통과한다(세 번 모두 기다림이 끝나 snap() 으로 떨어지면 why 는 null). 도주 줄 흐림은 스냅숏에 없어 띠 이유로 본다.
  check(why !== null && s.battle.banner?.[1] === '도망칠 수 없다' && s.battle.sub === 'menu' && s.battle.phase === 'command',
    '보스 5: 도주 줄 → 이유 「도망칠 수 없다」, 명령 입력 그대로', { why: why !== null, banner: s.battle.banner, sub: s.battle.sub });
  idb = await waitIdb(s);
  check(!idb.timeout, '보스 5: 전투 시작 자동 저장이 IndexedDB 에 반영', idb);
  // 6) 실제 한 턴 → 새로 고침.
  const cmds = s.battle.can_command.map((ok) => (ok ? { kind: 'attack', target: 0 } : null));
  let g = s.generation;
  let rr = null;
  for (let k = 0; k < 3 && !rr?.ok; k++) {
    if (k) await page.waitForTimeout(100);
    rr = await request({ op: 'battle_commands', commands: cmds });
  }
  check(rr?.ok, '보스 6: battle_commands(모두 적 0 공격)', rr);
  s = await waitFor((x) => x.generation > g && x.battle?.phase !== 'anim' && !x.busy, '턴 끝', 30000);
  check(s.battle?.open && s.battle.phase === 'command' && s.battle.turn === 1 && s.battle.enemy_hp[0] < 1800, '보스 6: 한 턴 → 전투 이어짐(턴 1, 펜리르 HP 줄어듦)',
    { turn: s.battle?.turn, hp: s.battle?.enemy_hp, wiped: s.wiped });
  s = await reloadInBattle(s);
  check(s.battle.music_cue === 'boss' && s.battle.foe === 'boss', '보스 6: 새로 고침 뒤에도 보스 전투(music_cue boss)', { music: s.battle.music_cue });
  // 7) 승리 → 이야기 상자.
  s = await finishBattle(s, false);
  s = await waitFor((x) => x.modal === 'clear' && !x.busy, '이야기 상자');
  check(s.story.page === 0 && s.story.pages === 3 && s.story.speaker === '관리국 통신' && s.story.lines.join(' ').startsWith('네온 펜리르의 신호가 끊겼다.')
    && !s.buttons.CampButton && s.buttons.StoryTap && s.buttons.StoryNext && s.buttons.VPad_ok,
  '보스 7: 결과 창 「확인」 → 이야기 상자(관리국 통신, 쪽 셋, 첫 쪽에 보스 이름), HUD 없음', { story: s.story, buttons: Object.keys(s.buttons) });
  await shot('j04_story_1');
  const hClear = s.hash;
  const gClear = s.generation;
  await clickButton('StoryTap');
  s = await waitFor((x) => x.story?.page === 1, '상자 누르기 → 둘째 쪽');
  await shot('j05_story_2');
  await clickButton('VPad_ok');
  s = await waitFor((x) => x.story?.page === 2, '키패드 선택 → 셋째 쪽');
  check(s.story.last === true, '보스 7: 상자 누르기·키패드 선택으로 마지막 쪽', { story: s.story });
  await shot('j06_story_3');
  await clickButton('StoryNext');
  s = await waitFor((x) => x.modal === '' && !x.busy, '이야기 상자 닫힘');
  check(s.hash === hClear && s.generation === gClear, '보스 7: 이야기 상자는 보이기만(해시·세대 그대로)', { generation: [gClear, s.generation] });
  // 8) 클리어 상태.
  check(bossOf(s)?.state === 'defeated' && !s.foe_mark_list.some((m) => m.id === 'boss') && JSON.stringify(s.cleared) === '["b3f"]'
    && !s.minimap_foes.some((f) => f.id === 'boss') && s.boss_near === '' && s.buttons.CampButton,
  '보스 8: 보스 defeated, 3D 표지·미니맵 원 없음, cleared [b3f], HUD 다시', { boss: bossOf(s), cleared: s.cleared, marks: s.foe_mark_list });
  await shot('j07_cleared');
  idb = await waitIdb(s);
  check(!idb.timeout, '보스 8: 승리 자동 저장이 IndexedDB 에 반영', idb);
  // 9) 새로 고침.
  const hash = s.hash;
  await page.reload();
  s = await waitReady();
  check(s.hash === hash && s.modal === '' && JSON.stringify(s.cleared) === '["b3f"]', '보스 9: 새로 고침 → 같은 해시, 이야기 상자 없음', { hash: [hash.slice(0, 12), s.hash.slice(0, 12)], modal: s.modal });
  // 10) 보스 방 비콘.
  const sup = await request({ op: 'supply', item: BEACON, n: 1 });
  check(sup.ok === true, '보스 10: 디버그 supply 비콘 1', sup);
  await clickButton('CampButton');
  await waitFor((x) => x.party_menu?.open && x.party_menu.page === 'root', '캠프 뿌리');
  await clickButton('Camp_items');
  s = await waitFor((x) => x.party_menu?.page === 'sub' && x.party_menu.tab === 'items' && x.party_menu.item_rows?.length > 0, '소지품');
  for (let k = 0; k < 12 && s.party_menu.items.item !== BEACON; k++) {
    await page.keyboard.press('ArrowDown');
    await page.waitForTimeout(100);
    s = await snap();
  }
  check(s.party_menu.items.item === BEACON && s.party_menu.items.use === 'dim', '보스 10: 보스 방에서 비콘 「쓰기」 흐림', { items: s.party_menu.items });
  await page.keyboard.press('Enter');
  s = await waitFor((x) => x.party_menu.items.mode === 'pills', '알약 쪽');
  await page.keyboard.press('Enter');
  s = await waitFor((x) => x.party_menu.notice === '이곳에서는 비콘 신호가 닿지 않는다', '비콘 이유');
  check(s.location === 'labyrinth' && s.party_menu.notice === '이곳에서는 비콘 신호가 닿지 않는다' && s.party_menu.dialog === '', '보스 10: 「쓰기」 → 이유 「이곳에서는 비콘 신호가 닿지 않는다」, 확인 창 없음', { notice: s.party_menu.notice });
  await shot('j08_beacon_sealed');
  log('부분 J 끝', { seconds: Math.round((Date.now() - t0) / 1000) });
}
