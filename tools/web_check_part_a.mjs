// web_check 부분 A(탐색·전투): 1) 공략 행동열(첫 전투의 새로 고침·실제 누르기 한 턴·결과 창, 뒤 전투는 battle_finish)
// 2) 지도 편집 3) IndexedDB 반영 4) 새로 고침 뒤 같은 상태·같은 다음 행동 5) 내보내기·가져오기·늦은 앞 가져오기·1MB 거부·고르기 취소.
import fs from 'node:fs';
import {
  W, H, SEED, outDir, route, FOLLOW_UP, page, log, check, snap, request, waitFor, waitReady, clickButton, waitIdb,
  battles, battleTurns, reloadChecked, act,
} from './web_check_common.mjs';

export async function partA() {
  let s = await waitReady();
  check(s.user_dir === '/userfs/sqfangame', 'user:// 경로', { user_dir: s.user_dir });
  check(s.seed === SEED, `새 게임 시드 = 주소의 seed ${SEED}`, { seed: s.seed });
  check(s.autosaves === 1 && s.modal === '', '새 게임 자동 저장', { autosaves: s.autosaves, modal: s.modal });
  await page.screenshot({ path: `${outDir}/01_start.png` });
  // 캔버스에 키 포커스를 준다(3D 시야 영역 클릭은 아무 일도 하지 않는다).
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));

  // ---- 1) 공략 행동열 ----
  const t0 = Date.now();
  let maxGuard = 0;
  let simRest = null;  // 첫 전투가 끝난 뒤 남은 공략의 simulate 결과
  const realRest = [];
  for (let i = 0; i < route.actions.length; i++) {
    s = await act(route.actions[i]);
    if (simRest) realRest.push(s.actionHash);
    if (!simRest && battles >= 1 && !s.battle?.open) {
      const rest = route.actions.slice(i + 1);
      simRest = { actions: rest.length, ...(await request({ op: 'simulate', actions: rest })) };
    }
    maxGuard = Math.max(maxGuard, Math.abs(s.guard_delta));
    const cp = route.checkpoints.find((c) => c.after === i + 1);
    if (cp && (s.at[0] !== cp.at[0] || s.at[1] !== cp.at[1])) check(false, `체크포인트 ${cp.after}`, { want: cp.at, got: s.at });
    // 경계 겉모습 캡처: 숨은 통로 찾기 전후, 일방통행, 지름길 닫힘·열림.
    if (cp && [13, 14, 58, 61, 88, 89].includes(cp.after)) {
      await page.waitForTimeout(150);
      await page.screenshot({ path: `${outDir}/cp${String(cp.after).padStart(2, '0')}.png` });
    }
  }
  check(s.shortcuts_open === 1, '공략 끝: 지름길 열림', { at: s.at, shortcuts_open: s.shortcuts_open, passages_found: s.passages_found, battles, battleTurns, ms: Date.now() - t0 });
  const restOk = simRest && Array.isArray(simRest.hashes) && simRest.hashes.length === simRest.actions && realRest.length === simRest.actions
    && simRest.hashes.every((h, k) => typeof h === 'string' && h === realRest[k]);
  check(battles >= 1 && reloadChecked, '공략 중 전투가 있었고 전투 중 새로 고침을 확인했다', { battles, reloadChecked });
  check(restOk, `첫 전투 뒤 남은 공략 ${simRest?.actions} 행동: battle_finish 로 넘긴 해시 = simulate`, restOk ? { battles } : {
    battles, error: simRest?.error, sim: simRest?.hashes?.map((h) => String(h).slice(0, 8)), real: realRest.map((h) => String(h).slice(0, 8)) });
  log('공략 끝', { at: s.at, steps: s.steps, generation: s.generation, battles, battleTurns, hp: s.hp, materials: s.materials, last_guard_delta: s.guard_delta, guard_radius: s.guard_radius, plan_ms_max: s.plan_ms_max,
    plan_count: s.plan_count, plan_ms_total: s.plan_ms_total, plan_ms_total_max: s.plan_ms_total_max, plan_count_max: s.plan_count_max });
  await page.screenshot({ path: `${outDir}/02_route_end.png` });

  // ---- 2) 지도 편집 ----
  const cellPt = (s2, x, y) => [s2.map.origin[0] + s2.map.cell[0] * x, s2.map.origin[1] + s2.map.cell[1] * y];
  const [px, py] = s.at;
  await clickButton('Tool_wall', s);
  s = await waitFor((x) => x.tool === 'wall', '벽 도구');
  let g = s.generation;
  let e0 = s.edges;
  let pt = cellPt(s, px + 0.5, py + 1);  // 파티 칸 남쪽 변
  await page.mouse.click(pt[0], pt[1]);
  s = await waitFor((x) => x.generation > g, '벽 편집 저장');
  check(s.edges === e0 + 1 || s.edges === e0 - 1, '벽 한 번 클릭 = 경계 하나 바뀜', { before: e0, after: s.edges });
  await clickButton('Tool_color2', s);
  s = await waitFor((x) => x.tool === 'color', '색 도구');
  g = s.generation;
  pt = cellPt(s, px + 0.5, py + 0.5);
  await page.mouse.click(pt[0], pt[1]);
  s = await waitFor((x) => x.generation > g, '바닥 색 저장');
  await clickButton('Tool_memo', s);
  s = await waitFor((x) => x.tool === 'memo', '메모 도구');
  g = s.generation;
  const m0 = s.memos;
  const memoText = '지름길 앞 보물 상자';
  let dialogInfo = null;
  page.once('dialog', async (d) => { dialogInfo = { type: d.type(), message: d.message() }; await d.accept(memoText); });
  pt = cellPt(s, px + 0.5, py + 0.5);
  await page.mouse.click(pt[0], pt[1]);
  s = await waitFor((x) => x.generation > g, '메모 저장');
  check(dialogInfo?.type === 'prompt' && s.memos === m0 + 1, '메모: 브라우저 입력 창 → 한국어 메모 한 단계', { dialogInfo, memos: s.memos });
  const memoKey = `${px},${py}`;
  check(s.memo_texts?.[memoKey] === memoText, '메모: 저장된 글 = 입력한 한국어 글', { want: memoText, got: s.memo_texts?.[memoKey] });
  check(s.at[0] === px && s.at[1] === py, '지도 편집은 파티를 움직이지 않는다', { at: s.at });
  await page.screenshot({ path: `${outDir}/03_map_edit.png` });
  // 되돌림 한 번(자동 저장), 다시 메모.
  g = s.generation;
  await page.keyboard.press('Control+KeyZ');
  s = await waitFor((x) => x.generation > g, 'Ctrl+Z 저장');
  check(s.memos === m0 && s.memo_texts?.[memoKey] === undefined, 'Ctrl+Z 로 메모 되돌림', { memos: s.memos, got: s.memo_texts?.[memoKey] });

  // ---- 3) IndexedDB 반영 ----
  let idb = await waitIdb(s);
  check(!idb.timeout && idb.keys?.[0] === '/userfs/sqfangame/saves/auto.json', 'IndexedDB 자동 저장 = 화면 세대·상태 해시', idb);

  // ---- 4) 새로 고침 → 같은 상태, 다음 행동도 같은 결과 ----
  const sim = await request({ op: 'simulate', actions: FOLLOW_UP });
  const before = s;
  await page.reload();
  s = await waitReady();
  check(s.hash === before.hash && s.generation === before.generation, '새로 고침 뒤 전체 상태 해시·세대 같음', { before: before.hash.slice(0, 12), after: s.hash.slice(0, 12), generation: s.generation });
  await page.mouse.click(Math.round(W * 0.3), Math.round(H * 0.3));
  const real = [];
  for (const a of FOLLOW_UP) {
    s = await act(a);
    real.push(s.actionHash);
  }
  // 길이를 먼저 본다(빈 배열·짧은 배열이면 every 가 참이 되어 비교 없이 통과한다).
  const lengthsOk = Array.isArray(sim.hashes) && Array.isArray(real)
    && sim.hashes.length === FOLLOW_UP.length && real.length === FOLLOW_UP.length;
  const same = lengthsOk && sim.hashes.every((h, i) => typeof h === 'string' && h === real[i]);
  check(same, `새로 고침 뒤 다음 행동 ${FOLLOW_UP.length}개 결과 = 새로 고침 전 모의 결과`, same ? undefined : {
    simLength: Array.isArray(sim.hashes) ? sim.hashes.length : typeof sim.hashes, realLength: real.length,
    sim: Array.isArray(sim.hashes) ? sim.hashes.map((h) => String(h).slice(0, 8)) : sim, real: real.map((h) => String(h).slice(0, 8)),
  });
  await page.screenshot({ path: `${outDir}/04_after_reload.png` });

  // ---- 5) 내보내기 → 이동 → 가져오기 ----
  await clickButton('MenuButton', s);
  s = await waitFor((x) => x.modal === 'menu', '메뉴');
  await page.screenshot({ path: `${outDir}/06_menu.png` });
  const exportHash = s.hash;
  const [download] = await Promise.all([page.waitForEvent('download', { timeout: 10000 }), clickButton('Export', s)]);
  const exportPath = `${outDir}/export.json`;
  await download.saveAs(exportPath);
  const exported = JSON.parse(fs.readFileSync(exportPath, 'utf8'));
  check(exported.format === 'sqfangame-save' && download.suggestedFilename().endsWith('.json'), '내보내기: 단추 처리 안에서 내려받기', { file: download.suggestedFilename(), bytes: fs.statSync(exportPath).size });
  await clickButton('Close');
  s = await waitFor((x) => x.modal === '', '메뉴 닫힘');
  s = await act('turn_right');
  s = await act('forward');
  check(s.hash !== exportHash, '내보낸 뒤 상태가 바뀜');
  await clickButton('MenuButton', s);
  s = await waitFor((x) => x.modal === 'menu', '메뉴');
  let [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import', s)]);
  g = s.generation;
  await chooser.setFiles(exportPath);
  s = await waitFor((x) => x.modal === '' && x.hash === exportHash, '가져오기 결과', 10000);
  check(true, '가져오기: 내보낸 상태 해시로 돌아옴', { generation: s.generation, previous: g });
  idb = await waitIdb(s);
  check(!idb.timeout, '가져오기 직후 자동 저장(세대·상태 해시)이 IndexedDB 에 반영', idb);
  await page.screenshot({ path: `${outDir}/07_imported.png` });
  // 늦게 끝난 앞 가져오기: 첫 파일 읽기(A)를 붙잡아 두고 새 가져오기(B)를 끝낸 뒤 A 를 풀면 상태는 B 그대로다.
  s = await act('turn_right');
  s = await act('forward');
  await clickButton('MenuButton', s);
  s = await waitFor((x) => x.modal === 'menu', '메뉴');
  const [downloadB] = await Promise.all([page.waitForEvent('download', { timeout: 10000 }), clickButton('Export', s)]);
  const exportBPath = `${outDir}/export_b.json`;
  await downloadB.saveAs(exportBPath);
  const hashB = s.hash;
  await clickButton('Close');
  s = await waitFor((x) => x.modal === '', '메뉴 닫힘');
  s = await act('turn_left');
  check(s.hash !== hashB && s.hash !== exportHash, '늦은 읽기 준비: 지금 상태는 A·B 와 다르다');
  const dropped0 = await page.evaluate(() => {
    const h = { orig: File.prototype.text, calls: 0, release: null };
    window.sqfHoldRead = h;
    File.prototype.text = function () {
      h.calls += 1;
      if (h.calls > 1) return h.orig.call(this);
      return new Promise((res, rej) => { h.release = () => h.orig.call(this).then(res, rej); });
    };
    return window.sqfImportState?.dropped ?? 0;
  });
  await clickButton('MenuButton', s);
  s = await waitFor((x) => x.modal === 'menu', '메뉴');
  [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import', s)]);
  await chooser.setFiles(exportPath);  // A: 읽기가 붙잡힌다
  await page.waitForFunction(() => typeof window.sqfHoldRead.release === 'function', null, { timeout: 5000 });
  const heldHash = (await snap()).hash;
  [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import', s)]);
  await chooser.setFiles(exportBPath);  // B: 바로 읽힌다
  s = await waitFor((x) => x.modal === '' && x.hash === hashB, '새 가져오기(B) 결과', 10000);
  const genB = s.generation;
  await page.evaluate(() => window.sqfHoldRead.release());
  await page.waitForFunction((d) => (window.sqfImportState?.dropped ?? 0) > d, dropped0, { timeout: 5000 }).catch(() => {});
  await page.waitForTimeout(300);
  s = await snap();
  const dropped1 = await page.evaluate(() => {
    File.prototype.text = window.sqfHoldRead.orig;
    return window.sqfImportState?.dropped ?? 0;
  });
  check(heldHash !== exportHash && s.hash === hashB && s.generation === genB && s.modal === '' && dropped1 === dropped0 + 1,
    '늦게 끝난 앞 가져오기(A)는 버린다: 상태·세대는 B 그대로', { hash: s.hash.slice(0, 12), hashB: hashB.slice(0, 12), generation: s.generation, genB, modal: s.modal, dropped: dropped1 - dropped0 });
  // 1MB 넘는 파일.
  const bigPath = `${outDir}/too_large.json`;
  fs.writeFileSync(bigPath, 'x'.repeat(1100000));
  const keep = s.hash;
  await clickButton('MenuButton', s);
  s = await waitFor((x) => x.modal === 'menu', '메뉴');
  [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import', s)]);
  await chooser.setFiles(bigPath);
  s = await waitFor((x) => x.modal === 'alert', '크기 초과 알림', 10000);
  check(s.hash === keep, '1MB 넘는 파일 거부, 상태 그대로');
  await page.screenshot({ path: `${outDir}/08_too_large.png` });
  await clickButton('AlertOk', s);
  // 고르기 취소.
  await clickButton('MenuButton');
  s = await waitFor((x) => x.modal === 'menu', '메뉴');
  [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 10000 }), clickButton('Import', s)]);
  await chooser.setFiles([]);
  await page.waitForTimeout(500);
  s = await snap();
  check(s.hash === keep, '파일 고르기 취소: 상태 그대로', { modal: s.modal });
  log('부분 A 끝', { maxGuardDuringRoute: maxGuard });
}
