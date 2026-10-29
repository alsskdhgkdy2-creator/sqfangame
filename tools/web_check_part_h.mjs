// web_check 부분 H(M3 A7c 설계 §7 A7c, 실제 미궁 arbor: 주소에 &set 없음, 저장 폴더 saves): 모험가 길드.
// 1) 새 게임 → 광장 「모험가 길드」 → 길드 뿌리.
// 2) 「모험가 등록」: 레일 레인저 외형 B(브라우저 입력 창 → 「레인저」) → 확인 「예」, 헥스 해커 외형 A(「해커」) → 「예」. 둘 다 길드(파티 밖).
// 3) 「편성과 순서」: 후열 칸 3(나노 메딕)·칸 4(글리프 위저드)에 레인저·해커 → 「결정」 → 파티·길드(메딕·위저드), IndexedDB = 화면.
// 4) 캠프 「스킬」: 레인저 플래시 애로, 해커 글리치 헥스를 「+」 → 「확정」 → 「확정」.
// 5) 아보르 입구 → 탐사 시작 → 디버그 battle_start → battle_commands(해커 글리치 헥스·레인저 플래시 애로 → 적 0, 나머지는 방어):
//    전투 기록에 혼란·맹목 상태이상 줄(걸림 또는 버팀)이 나올 때까지 세 턴까지. 나머지를 공격이 아니라 방어로 둔 것은 적 0 이 먼저
//    쓰러져 상태이상 줄이 나오지 않는 경우를 없애려는 것이다(설계의 「나머지는 공격」과 다른 점).
// 6) IndexedDB 자동 저장 = 화면 → 새로 고침 → 이어하기: 같은 해시, 같은 전투·파티·이름.
// 7) battle_finish → 결과 → 캠프 「대열」: 칸 3 ↔ 칸 4 → 「결정」 → 파티 차례가 바뀌고 IndexedDB = 화면. 길드에는 메딕·위저드가 그대로.
import {
  W, H, outDir, page, check, log, snap, request, waitFor, waitReady, waitTitle, clickButton, enterLabyrinth, finishBattle, waitIdb,
} from './web_check_common.mjs';

const FLASH = 'skill.rail_ranger.flash_arrow';
const GLITCH = 'skill.hex_hacker.glitch_hex';
// 혼란 = 「신호 교란」, 맹목 = 「센서 차단」(ko.json ailment.*). 걸림(battle.event.ailment) 또는 버팀(ailment_resisted) 줄.
const AILMENT_LINE = /(신호 교란|센서 차단).*(상태가 되었다|버텼다)/;

async function shot(name) {
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${outDir}/${name}_${W}x${H}.png` });
}

const ids = (list) => (list ?? []).map((m) => m.id);

// 길드 등록 하나: 직업 줄 두 번(커서 → 외형), 외형 띠 두 번(커서 → 이름). 이름은 브라우저 입력 창(page.once('dialog')).
async function register(classRow, look, name) {
  await clickButton('Guild_register');
  await waitFor((x) => x.guild_screen?.page === 'class', '직업 고르기');
  await clickButton(`Class_${classRow}`);
  await waitFor((x) => x.guild_screen?.class_cursor === classRow, '직업 커서');
  await clickButton(`Class_${classRow}`);
  let s = await waitFor((x) => x.guild_screen?.page === 'look', '외형');
  if (s.guild_screen.look !== look) {
    await clickButton(`Look_${look}`);
    await waitFor((x) => x.guild_screen?.look === look, '외형 커서');
  }
  let asked = null;
  page.once('dialog', async (d) => {
    asked = { type: d.type(), message: d.message(), def: d.defaultValue() };
    await d.accept(name);
  });
  await clickButton(`Look_${look}`);
  s = await waitFor((x) => x.guild_screen?.dialog?.mode === 'confirm', `${name} 확인 창`);
  return { s, asked };
}

// 편성 판 등록부에서 대원 id 줄로 커서를 옮기고(↑↓, 다섯 줄 밖은 내려야 보인다) 선택.
async function pickRoster(id) {
  let s = await snap();
  const want = s.guild_screen.roster.indexOf(id);
  const d = want - s.guild_screen.roster_cursor;
  for (let k = 0; k < Math.abs(d); k++) await page.keyboard.press(d > 0 ? 'ArrowDown' : 'ArrowUp');
  await waitFor((x) => x.guild_screen?.roster_cursor === want, `등록부 커서 ${id}`);
  await page.keyboard.press('Enter');
  return waitFor((x) => x.guild_screen?.form?.focus === 'board', `${id} 넣음`);
}

// 캠프 스킬: 대원 i 의 스킬 화면 → (노드 누르기) → 「+」 → 「확정」 → 확인 「확정」.
async function learn(i, skill) {
  await clickButton('Camp_skills');
  await waitFor((x) => x.party_menu?.page === 'pick', '대원 고르기');
  await clickButton(`Member_${i}`);
  let s = await waitFor((x) => x.party_menu?.tab === 'skills' && x.party_menu?.member === i, `스킬 ${i}`);
  if (s.party_menu.cursor.skill !== skill) {
    const p = s.party_menu.nodes[skill];
    await page.mouse.click(p[0], p[1]);
    await waitFor((x) => x.party_menu?.cursor?.skill === skill, `${skill} 노드`);
  }
  await clickButton('SkillPlus');
  await waitFor((x) => x.party_menu?.draft?.[skill] === 1, `${skill} 초안`);
  const g = (await snap()).generation;
  await clickButton('SkillCommit');
  await waitFor((x) => x.party_menu?.dialog === 'commit', '확정 확인 창');
  await clickButton('DialogOk');
  s = await waitFor((x) => x.generation > g && x.party_menu?.dialog === '', '배분 확정 저장');
  await clickButton('VPad_back');
  await waitFor((x) => x.party_menu?.page === 'root', '캠프 뿌리');
  return s;
}

export async function partH() {
  let s = await waitReady();
  check(s.set === 'game' && s.location === 'town' && s.town?.page === 'plaza', '길드 0: 실제 미궁·마을 광장', { set: s.set, location: s.location });
  check(s.town.dim[3] === false && s.buttons.Plaza_guild, '길드 0: 광장 「모험가 길드」 줄은 흐리지 않다', { dim: s.town.dim });
  const party0 = ids(s.members);
  // 1) 길드.
  await clickButton('Plaza_guild');
  s = await waitFor((x) => x.guild_screen?.open && x.guild_screen.page === 'root' && !x.busy, '길드 뿌리');
  check(s.guild_screen.band[0] === '새 모험가를 길드에 등록한다' && s.buttons.Guild_register && s.buttons.GuildPlate && !s.buttons.Plaza_guild,
    '길드 1: 광장 → 길드 뿌리(띠·줄·캠프 문패, 덮인 광장 줄 없음)', { band: s.guild_screen.band });
  await shot('h01_guild_root');
  // 2) 등록 둘.
  let g = s.generation;
  let r = await register(2, 1, '레인저');
  check(r.asked?.type === 'prompt' && r.asked.def === '레인저1' && r.s.guild_screen.dialog.text === '레일 레인저 레인저를 등록할까?' && r.s.buttons.Yes,
    '길드 2: 레인저 외형 B → 브라우저 입력 창(기본 「레인저1」) → 확인 창', { asked: r.asked, text: r.s.guild_screen.dialog.text });
  await shot('h02_register_confirm');
  await clickButton('Yes');
  s = await waitFor((x) => x.generation > g && x.guild_screen?.page === 'root', '레인저 등록');
  g = s.generation;
  r = await register(5, 0, '해커');
  check(r.asked?.def === '해커1', '길드 2: 해커 기본 이름 「해커1」', { asked: r.asked });
  await clickButton('Yes');
  s = await waitFor((x) => x.generation > g && x.guild_screen?.page === 'root', '해커 등록');
  const gm = s.guild.members;
  const ranger = gm.find((m) => m.name === '레인저');
  const hacker = gm.find((m) => m.name === '해커');
  check(ranger?.class === 'class.rail_ranger' && ranger.look === 1 && hacker?.class === 'class.hex_hacker' && hacker.look === 0
    && ranger.level === 1 && JSON.stringify(ids(s.members)) === JSON.stringify(party0),
  '길드 2: 레인저(외형 B)·해커(외형 A) Lv1 이 길드에, 파티 그대로', { guild: gm, members: ids(s.members) });
  let idb = await waitIdb(s);
  check(!idb.timeout, '길드 2: 등록 자동 저장이 IndexedDB 에 반영', idb);
  // 3) 편성.
  await clickButton('Guild_form');
  s = await waitFor((x) => x.guild_screen?.page === 'form', '편성');
  check(JSON.stringify([...s.guild_screen.form.front, ...s.guild_screen.form.back]) === JSON.stringify(party0) && s.buttons.FormSlot_3 && s.buttons.FormDecide,
    '길드 3: 편성 판 = 지금 파티', { form: s.guild_screen.form });
  await clickButton('FormSlot_3');
  await waitFor((x) => x.guild_screen?.form?.focus === 'roster', '칸 3 → 등록부');
  await pickRoster(ranger.id);
  await clickButton('FormSlot_4');
  await waitFor((x) => x.guild_screen?.form?.focus === 'roster', '칸 4 → 등록부');
  s = await pickRoster(hacker.id);
  check(JSON.stringify(s.guild_screen.form.back) === JSON.stringify([ranger.id, hacker.id]), '길드 3: 후열 초안 = 레인저·해커', { form: s.guild_screen.form });
  await shot('h03_form_draft');
  g = s.generation;
  await clickButton('FormDecide');
  s = await waitFor((x) => x.generation > g && x.guild_screen?.page === 'root', '편성 결정');
  const party1 = [party0[0], party0[1], party0[2], ranger.id, hacker.id];
  check(JSON.stringify(ids(s.members)) === JSON.stringify(party1) && s.members[3].row === 'back' && s.members[4].row === 'back'
    && JSON.stringify(ids(s.guild.members).sort()) === JSON.stringify([party0[3], party0[4]].sort()) && s.guild_screen.notice === '파티를 편성했다',
  '길드 3: 결정 → 파티(레인저·해커 후열), 메딕·위저드는 길드로', { members: ids(s.members), guild: ids(s.guild.members) });
  idb = await waitIdb(s);
  check(!idb.timeout, '길드 3: 편성 자동 저장이 IndexedDB 에 반영', idb);
  // 4) 캠프 스킬(길드 뿌리에서 「캠프」 문패).
  await clickButton('GuildPlate');
  await waitFor((x) => x.party_menu?.open && x.party_menu.page === 'root', '캠프 뿌리');
  await learn(3, FLASH);
  s = await learn(4, GLITCH);
  check(s.members[3].skills[FLASH] === 1 && s.members[4].skills[GLITCH] === 1, '길드 4: 레인저 플래시 애로·해커 글리치 헥스 배움',
    { ranger: s.members[3].skills, hacker: s.members[4].skills });
  await clickButton('VPad_back');
  s = await waitFor((x) => !x.party_menu?.open && x.guild_screen?.open && !x.guild_screen.covered, '캠프 닫힘 → 길드');
  await clickButton('VPad_back');
  s = await waitFor((x) => !x.guild_screen?.open && x.town?.page === 'plaza', '길드 → 광장');
  check(s.town.cursor === 3 && s.town.band[0] !== '', '길드 4: 길드 「나간다」 → 광장(커서 「모험가 길드」 그대로)', { cursor: s.town.cursor });
  // 5) 전투.
  s = await enterLabyrinth();
  let st = await request({ op: 'battle_start' });
  s = await waitFor((x) => x.battle?.open && x.battle.phase === 'command' && !x.busy, '전투 명령');
  check(st.ok && JSON.stringify(ids(s.members)) === JSON.stringify(party1), '길드 5: battle_start, 파티 = 편성대로', { st, members: ids(s.members) });
  let lines = [];
  for (let turn = 0; turn < 3 && !lines.some((l) => AILMENT_LINE.test(l)); turn++) {
    s = await snap();
    const cmds = s.battle.can_command.map((ok, i) => {
      if (!ok) return null;
      if (i === 3) return { kind: 'skill', skill: FLASH, target: 0 };
      if (i === 4) return { kind: 'skill', skill: GLITCH, target: 0 };
      return { kind: 'guard' };
    });
    g = s.generation;
    let rr = null;
    for (let k = 0; k < 3 && !rr?.ok; k++) {
      if (k) await page.waitForTimeout(100);
      rr = await request({ op: 'battle_commands', commands: cmds });
    }
    check(rr?.ok, `길드 5: 턴 ${turn + 1} 명령(해커 글리치 헥스·레인저 플래시 애로)`, rr);
    s = await waitFor((x) => x.generation > g && x.battle?.phase !== 'anim' && !x.busy, '턴 끝');
    lines = s.battle?.log_tail ?? [];
    log('턴', { turn: turn + 1, phase: s.battle?.phase, tail: lines.slice(-6) });
    if (s.battle?.phase !== 'command') break;
  }
  check(lines.some((l) => AILMENT_LINE.test(l)), '길드 5: 전투 기록에 혼란·맹목 상태이상 줄', { tail: lines });
  await shot('h05_battle_ailment');
  // 6) 새로 고침.
  idb = await waitIdb(s);
  check(!idb.timeout, '길드 6: 전투 자동 저장이 IndexedDB 에 반영(= 화면)', idb);
  const before = { hash: s.hash, names: s.members.map((m) => m.name), ids: ids(s.members), battle: !!s.battle?.open };
  await page.reload();
  await page.waitForFunction(() => window.sqfDebug && window.sqfDebug.ready, null, { timeout: 60000 });
  const t = await waitTitle();
  await clickButton('TitleContinue');
  s = await waitFor((x) => x.location === 'labyrinth' && !x.busy && !x.title?.open, '이어하기');
  check(t.buttons.TitleContinue && s.hash === before.hash && JSON.stringify(s.members.map((m) => m.name)) === JSON.stringify(before.names)
    && JSON.stringify(ids(s.members)) === JSON.stringify(before.ids) && !!s.battle?.open === before.battle,
  '길드 6: 새로 고침 → 이어하기 = 같은 해시·파티·이름', { hash: [s.hash?.slice(0, 12), before.hash?.slice(0, 12)], names: s.members.map((m) => m.name) });
  // 7) 전투를 마치고 캠프 「대열」.
  if (s.battle?.open && s.battle.phase !== 'result') {
    s = await waitFor((x) => x.battle?.phase === 'command', '명령 단계');
  }
  if (s.battle?.open) s = await finishBattle(s, false);
  s = await waitFor((x) => !x.battle?.open && !x.busy, '전투 뒤 탐색');
  await clickButton('CampButton');
  await waitFor((x) => x.party_menu?.open && x.party_menu.page === 'root', '캠프 뿌리');
  await clickButton('Camp_arrange');
  s = await waitFor((x) => x.party_menu?.tab === 'arrange', '캠프 대열');
  check(s.party_menu.strip === '대열 바꾸기' && s.buttons.FormSlot_3 && s.buttons.FormDecide && !s.buttons.Roster_0,
    '길드 7: 캠프 「대열」 = 같은 편성 판, 등록부 없음', { strip: s.party_menu.strip, arrange: s.party_menu.arrange });
  await clickButton('FormSlot_3');
  await waitFor((x) => x.party_menu?.arrange?.held === 3, '칸 3 고름');
  await clickButton('FormSlot_4');
  await waitFor((x) => x.party_menu?.arrange?.held === -1, '칸 4 와 바꿈');
  await shot('h07_camp_arrange');
  g = (await snap()).generation;
  await clickButton('FormDecide');
  s = await waitFor((x) => x.generation > g, '대열 결정');
  const party2 = [party0[0], party0[1], party0[2], hacker.id, ranger.id];
  check(JSON.stringify(ids(s.members)) === JSON.stringify(party2) && s.party_menu.notice === '대열을 바꿨다'
    && JSON.stringify(ids(s.guild.members).sort()) === JSON.stringify([party0[3], party0[4]].sort()),
  '길드 7: 대열 결정 → 해커·레인저 차례, 길드에는 메딕·위저드 그대로', { members: ids(s.members), guild: ids(s.guild.members) });
  idb = await waitIdb(s);
  check(!idb.timeout, '길드 7: 대열 자동 저장이 IndexedDB 에 반영', idb);
  log('부분 H 끝');
}
