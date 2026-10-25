// web_check 부분 B(전멸·성장): 새 게임을 내보낸 저장을 바탕으로 6) 준비한 저장(전투 중, 넷 쓰러짐, 하나 HP 1 독) → 방어 → 실행 →
// 전멸 창 7) 성장(전멸 창 「새 게임」 → 캠프(「캠프」 단추 → 명령 줄 → 대원 카드) → grant_exp → 스킬 배분 취소·확정 → supply → 장착 →
// 새로 고침 → 승리 경로 결과 창). 내보내기·가져오기는 캠프 「기록」 화면에서(M2.7 R2-d).
import fs from 'node:fs';
import {
  W, H, outDir, page, log, check, snap, request, waitFor, waitReady, clickButton, waitIdb,
  HIGH_SLASH, LEG_CUTTER, ION_SABER, VICTORY_SAVE, openRecords, closeCamp,
} from './web_check_common.mjs';

export async function partB() {
  let s = await waitReady();
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));  // 캔버스에 키 포커스
  // 준비(확인 아님): 새 게임 상태를 내보내 전멸 저장의 바탕으로 쓴다.
  s = await openRecords();
  const [download] = await Promise.all([page.waitForEvent('download', { timeout: 10000 }), clickButton('Export', s)]);
  const basePath = `${outDir}/wipe_base.json`;
  await download.saveAs(basePath);
  s = await closeCamp();

  // ---- 6) 준비한 저장으로 전멸 (06 §10.4 5) ----
  const wipeDoc = JSON.parse(fs.readFileSync(basePath, 'utf8'));
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
  s = await openRecords();
  const [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import', s)]);
  await chooser.setFiles(wipePath);
  s = await waitFor((x) => x.battle?.open && x.battle.phase === 'command' && !x.party_menu?.open, '준비한 전투 가져오기', 10000);
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
  s = await growthChecks(s);
  log('부분 B 끝');
}

// 성장(07 §10.5). s 는 전멸 창이 떠 있는 상태.
async function growthChecks(s) {
  const tag = `${W}x${H}`;
  await clickButton('WipeNewGame');
  s = await waitFor((x) => x.modal === '' && !x.wiped && !x.battle?.open && !x.busy, '새 게임');
  // 1. 「캠프」 단추를 실제로 눌러 연다 → 「상태」 줄 → 대원 카드 0.
  await clickButton('CampButton');
  s = await waitFor((x) => x.party_menu?.open && x.party_menu.page === 'root', '캠프');
  check(!s.buttons.Pad_forward && !s.buttons.CampButton && s.buttons.Camp_status && s.buttons.Camp_records,
    '성장 1: 「캠프」 단추 → 캠프 뿌리(명령 줄), 덮인 탐색 단추는 요약에 없다', { page: s.party_menu.page });
  await clickButton('Camp_status');
  s = await waitFor((x) => x.party_menu?.page === 'pick', '대원 고르기');
  // 고르기 중에도 명령 줄이 일한다(휴대폰 확인 2026-10-25): 「장비」 줄 → 장비 고르기, 「상태」 줄 → 다시 상태 고르기.
  check(s.buttons.Camp_equip && s.buttons.Camp_items && s.buttons.VPad_back && !s.buttons.Camp_close, '성장 1: 고르기 중에도 명령 줄을 누를 수 있다(뒤로 = 키패드 「취소」)', { buttons: Object.keys(s.buttons) });
  await clickButton('Camp_equip');
  s = await waitFor((x) => x.party_menu?.pick === 'equip', '장비 고르기로 바꿈');
  const equipBanner = s.party_menu.banner[0];
  await clickButton('Camp_status');
  s = await waitFor((x) => x.party_menu?.pick === 'status', '상태 고르기로 돌아옴');
  check(s.party_menu.page === 'pick' && equipBanner !== s.party_menu.banner[0], '성장 1: 고르기 중 「장비」·「상태」 줄 → 고르기와 물음이 바뀐다',
    { pick: s.party_menu.pick, banner: [equipBanner, s.party_menu.banner[0]] });
  await clickButton('Member_0');
  s = await waitFor((x) => x.party_menu?.page === 'sub', '상태 화면');
  check(s.party_menu.tab === 'status' && s.party_menu.member === 0 && s.buttons.StatusNext && s.buttons.StatusBack,
    '성장 1: 「상태」 → 카드 0 → 상태 화면·칸 0', { tab: s.party_menu.tab, member: s.party_menu.member });
  await page.screenshot({ path: `${outDir}/10_party_status_${tag}.png` });
  // 1b. 캠프 가상 키패드(P3): 상태에서 ←→ = 앞·다음 대원(↑↓ 흐림), 실제 누르기.
  const padState = s.party_menu.pad;
  await clickButton('VPad_right');
  s = await waitFor((x) => x.party_menu?.member === 1, '키패드 → 다음 대원');
  await clickButton('VPad_left');
  s = await waitFor((x) => x.party_menu?.member === 0, '키패드 ← 앞 대원');
  check(padState && !padState.up && !padState.down && padState.left && padState.right && padState.ok && padState.back && !s.buttons.VPad_up
    && s.party_menu.tab === 'status', '성장 1: 상태 화면 키패드 ←→ = 대원 넘기기, ↑↓ 흐림(요약에 없음)', { pad: padState, member: s.party_menu.member });
  // 2. grant_exp(듀얼리스트 A, cum(3) = 115).
  let g = s.generation;
  let r = await request({ op: 'grant_exp', member: 1, n: 115 });
  s = await waitFor((x) => x.generation > g, 'grant_exp 저장');
  check(r.ok && s.members[1].level === 3 && s.members[1].sp_left === 2, '성장 2: grant_exp → Lv3·남은 SP 2', { r: r.ok ?? r, level: s.members[1].level, sp_left: s.members[1].sp_left });
  const base = { hash: s.hash, generation: s.generation };
  // 3. 취소 먼저: 초안 → 「뒤로」 → 버리기 확인 창 → 「버리기」.
  await clickButton('StatusBack');
  s = await waitFor((x) => x.party_menu?.page === 'root', '캠프 뿌리');
  await clickButton('Camp_skills');
  s = await waitFor((x) => x.party_menu?.page === 'pick', '대원 고르기');
  await clickButton('Member_1');
  s = await waitFor((x) => x.party_menu?.tab === 'skills' && x.party_menu?.member === 1, '스킬·듀얼리스트 A');
  check(s.party_menu.cursor.skill === HIGH_SLASH, '성장 3: 스킬 커서는 트리 첫 항목', { cursor: s.party_menu.cursor });
  await clickButton('SkillPlus');
  s = await waitFor((x) => x.party_menu?.draft?.[HIGH_SLASH] === 1, '초안 +1');
  check(s.party_menu.sp_line === '남은 SP 2 → 1' && s.hash === base.hash, '성장 3: 「+」 → 초안만(남은 SP 줄)', { sp_line: s.party_menu.sp_line });
  await clickButton('SkillBack');
  s = await waitFor((x) => x.party_menu?.dialog === 'discard', '버리기 확인 창');
  check(s.party_menu.dialog_pick === 0 && s.buttons.DialogOk && !s.buttons.SkillPlus && !s.buttons.SkillBack, '성장 3: 버리기 확인 창(처음 고른 쪽 「돌아가기」, 뒤 단추는 요약에 없다)');
  await clickButton('DialogOk');
  s = await waitFor((x) => x.party_menu?.open && x.party_menu.page === 'root' && x.party_menu.dialog === '', '버린 뒤 캠프 뿌리');
  check(s.hash === base.hash && s.generation === base.generation && s.members[1].sp_left === 2, '성장 3: 「버리기」 → 상태·세대 그대로', { generation: s.generation });
  // 4. 확정: 하이 슬래시 「+」 → 레그 커터 「+」(선행을 같은 초안이 채움) → 「확정」 → 확정 확인 창 → 「확정」.
  await clickButton('Camp_skills');
  s = await waitFor((x) => x.party_menu?.page === 'pick', '대원 고르기 다시');
  await clickButton('Member_1');
  s = await waitFor((x) => x.party_menu?.tab === 'skills' && x.party_menu?.member === 1, '스킬·듀얼리스트 A');
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
  // 5. supply → 「뒤로」 → 「장비」 줄 → 카드 1 → 칸 0 → 이온 세이버 줄.
  g = s.generation;
  r = await request({ op: 'supply', item: ION_SABER, n: 1 });
  s = await waitFor((x) => x.generation > g, 'supply 저장');
  check(r.ok && s.gear_bag[ION_SABER] === 1, '성장 5: supply → 가방', { gear_bag: s.gear_bag });
  const atk0 = s.members[1].gear.atk;
  await clickButton('SkillBack');
  s = await waitFor((x) => x.party_menu?.page === 'root', '캠프 뿌리');
  await clickButton('Camp_equip');
  s = await waitFor((x) => x.party_menu?.page === 'pick', '대원 고르기');
  await clickButton('Member_1');
  s = await waitFor((x) => x.party_menu?.tab === 'equip' && x.party_menu?.member === 1, '장비·듀얼리스트 A');
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
  // 7. 승리 경로: 고정 저장 가져오기 → 전투 중 「캠프」 없음·P 무시 → battle_finish → 결과 창 줄 → 상태 화면.
  s = await openRecords();
  const [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import', s)]);
  await chooser.setFiles(VICTORY_SAVE);
  s = await waitFor((x) => x.battle?.open && x.battle.phase === 'command' && !x.party_menu?.open, '승리 경로 저장 가져오기', 10000);
  check(!s.buttons.CampButton && s.members[1].exp === 26, '성장 7: 전투 중 「캠프」 단추 없음·듀얼리스트 A exp 26', { exp: s.members[1].exp });
  await page.keyboard.press('KeyP');
  await page.waitForTimeout(300);
  s = await snap();
  check(!s.party_menu?.open && s.battle?.open, '성장 7: 전투 중 P 는 캠프를 열지 않는다');
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
  await clickButton('CampButton');
  s = await waitFor((x) => x.party_menu?.open && x.party_menu.page === 'root', '캠프(승리 뒤)');
  await clickButton('Camp_status');
  s = await waitFor((x) => x.party_menu?.page === 'pick', '대원 고르기');
  await clickButton('Member_1');
  s = await waitFor((x) => x.party_menu?.tab === 'status' && x.party_menu?.member === 1, '상태 화면(승리 뒤)');
  check(s.party_menu.tab === 'status' && s.members[1].level === 2 && s.members[1].sp_left === 1, '성장 7: 상태 화면 Lv 2·SP 1',
    { level: s.members[1].level, sp_left: s.members[1].sp_left });
  await page.screenshot({ path: `${outDir}/14_after_victory_${tag}.png` });
  idb = await waitIdb(s);
  check(!idb.timeout, '성장 7: 승리 자동 저장이 IndexedDB 에 반영', idb);
  return s;
}
