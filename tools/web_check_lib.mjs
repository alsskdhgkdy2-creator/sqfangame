// web_check 의 판정 함수(브라우저 없이 node 로 시험한다: node tools/web_check_lib.test.mjs).

// IndexedDB 의 자동 저장 기록이 화면 상태와 같은지: 세대만이 아니라 저장 글의 상태 해시도 같아야 한다.
// rec = { generation, hash }(저장 글을 게임의 hash_save 로 읽은 값), want = 화면 상태 요약 { generation, hash }.
export function idbMatches(rec, want) {
  if (!rec || rec.error || !want) return false;
  if (typeof rec.generation !== 'number' || rec.generation !== want.generation) return false;
  return typeof rec.hash === 'string' && rec.hash.length > 0 && rec.hash === want.hash;
}

// 공략의 open 행동 하나를 어떻게 할지(M3 A10a 검토 M1·R1): 브라우저 없이 시험한다(web_check_lib.test.mjs).
// rec = 처음 걷기에서 적은 {kind, pos, id}(없으면 처음 걷기), s = 상태 요약(floor·at·facing·chest_here = 이 칸의 닫힌 상자 id 또는 빈 글),
// env = 증거 어댑터: chestAt(floor, x, y) = 층 정의(data/floors/<층>.json)에서 그 칸에 정의된 상자 id(없으면 ''), opened(floor) = 저장 문서(IndexedDB 자동 저장)의
// state.floor_states.<층>.world.chests_opened 의 상자 id 목록. 요약의 chest_here 는 「열린 상자」와 「상자가 없는 칸」을 가르지 못하므로(둘 다 빈 글) 근거로 쓰지 않는다.
// 처음 걷기: 이 칸에 닫힌 상자가 있어야 하고(정의된 상자와 같아야 한다) 그 상자를 적어 연다.
// 되풀이: 같은 층·칸·방향에서 ① 닫힌 상자가 보이면 실패(같은 상자면 닫힘, 다르면 다른 상자) ② 적어 둔 상자가 층 정의의 그 칸에 없으면 실패(없는 목표)
// ③ 저장 상태의 열린 상자 목록에 없으면 실패(닫힘) ④ 그 밖에는 건너뛴다. 돌려주는 값: {act: 'open'|'skip'|'fail', error, record}.
export function planOpen(rec, i, s, tag = '', env = null) {
  const pos = [s.floor, s.at[0], s.at[1], s.facing];
  const here = s.chest_here || '';
  const head = `${tag} #${i + 1} open`;
  if (!rec) {
    if (!here) return { act: 'fail', error: `${head}: 처음 걷기인데 이 칸 ${JSON.stringify(pos)} 에 닫힌 상자가 없다` };
    if (env && env.chestAt(pos[0], pos[1], pos[2]) !== here) return { act: 'fail', error: `${head}: 처음 걷기의 상자 ${here} 가 층 정의 ${pos[0]} ${pos[1]}:${pos[2]} 에 없다` };
    return { act: 'open', error: '', record: { kind: 'chest', pos, id: here } };
  }
  if (pos.some((v, k) => v !== rec.pos[k])) return { act: 'fail', error: `${head}: 자리가 처음 걷기와 다르다 기대 ${JSON.stringify(rec.pos)} 실제 ${JSON.stringify(pos)}` };
  if (here && here !== rec.id) return { act: 'fail', error: `${head}: 다른 상자다 기대 ${rec.id} 실제 ${here}` };
  if (here) return { act: 'fail', error: `${head}: 열려 있어야 할 상자 ${rec.id} 가 닫혀 있다` };
  if (!env) return { act: 'fail', error: `${head}: 되풀이를 판정할 층 정의·저장 상태 근거가 없다` };
  const defined = env.chestAt(rec.pos[0], rec.pos[1], rec.pos[2]);
  if (defined !== rec.id) return { act: 'fail', error: `${head}: 적어 둔 상자 ${rec.id} 가 층 정의 ${rec.pos[0]} ${rec.pos[1]}:${rec.pos[2]} 에 없다(없는 목표${defined ? `, 거기엔 ${defined}` : ''})` };
  if (!env.opened(rec.pos[0]).includes(rec.id)) return { act: 'fail', error: `${head}: 저장 상태의 열린 상자 목록에 ${rec.id} 가 없다(닫혀 있다)` };
  return { act: 'skip', error: '' };
}
