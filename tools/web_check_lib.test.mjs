// web_check_lib 판정 함수 시험(node 만): node tools/web_check_lib.test.mjs
import assert from 'node:assert/strict';
import { idbMatches } from './web_check_lib.mjs';

const want = { generation: 12, hash: 'aaa111' };
assert.equal(idbMatches({ generation: 12, hash: 'aaa111' }, want), true, '세대·해시 같음');
// 반례: 세대는 같은데 내용이 다른 기록(예: 같은 세대 번호로 다른 상태가 저장됨)은 같다고 보지 않는다.
assert.equal(idbMatches({ generation: 12, hash: 'bbb222' }, want), false, '같은 세대·다른 내용');
assert.equal(idbMatches({ generation: 11, hash: 'aaa111' }, want), false, '세대 다름');
assert.equal(idbMatches({ generation: 12 }, want), false, '해시 없음(읽기 전 기록)');
assert.equal(idbMatches({ generation: 12, hash: '' }, want), false, '빈 해시');
assert.equal(idbMatches({ generation: 12, hash: 'aaa111', error: 'decode' }, want), false, '읽기 오류');
assert.equal(idbMatches({ keys: [] }, want), false, '자동 저장 없음');
assert.equal(idbMatches(null, want), false, '기록 없음');
assert.equal(idbMatches({ generation: 12, hash: 'aaa111' }, { generation: 12 }), false, '화면 해시 없음');
console.log('web_check_lib: OK');

// planOpen(검토 M1·R1): 처음 걷기·되풀이의 open 판정. 옛 도우미(상자 물음이 있거나 닫힌 상자가 있으면 연다, 없으면 말없이 지나간다)가 받아들이던 두 경우가 실패해야 하고,
// 되풀이에서 「상자가 안 보인다」는 열린 상자와 없는 상자를 가르지 못하므로 층 정의와 저장 상태의 열린 상자 목록이 있어야만 건너뛴다.
import { planOpen } from './web_check_lib.mjs';
const oldOpen = (s) => (s.modal === 'chest' || s.chest_here ? 'open' : 'skip');
const at = (chest, extra = {}) => ({ floor: 'b1f', at: [10, 16], facing: 0, chest_here: chest, modal: '', ...extra });
const rec = { kind: 'chest', pos: ['b1f', 10, 16, 0], id: 'c1' };
// 증거 어댑터: 층 정의에는 b1f 10:16 에 c1, 18:9 에 c3 가 있다. 저장 문서의 열린 상자 목록은 opened 로 바꿔 쓴다.
const env = (opened) => ({
  chestAt: (f, x, y) => ({ 'b1f 10:16': 'c1', 'b1f 18:9': 'c3' })[`${f} ${x}:${y}`] ?? '',
  opened: (f) => (f === 'b1f' ? opened : []),
});
let r = planOpen(null, 3, at('c1'), 'T', env([]));
assert.equal(r.act, 'open', '처음 걷기: 닫힌 상자는 연다');
assert.deepEqual(r.record, rec, '처음 걷기: 상자를 적는다');
r = planOpen(null, 3, at(''), 'T', env([]));
assert.equal(r.act, 'fail', '처음 걷기: 상자가 없으면 실패');
assert.match(r.error, /#4 open/, '처음 걷기 실패에 행동 번호');
r = planOpen(null, 3, at('c9'), 'T', env([]));
assert.equal(r.act, 'fail', '처음 걷기: 층 정의에 없는 상자 물음은 실패');
assert.equal(oldOpen(at('')), 'skip', '옛 도우미는 없는 목표를 말없이 지나갔다(회귀 사례 1)');
assert.equal(oldOpen(at('c1')), 'open', '옛 도우미는 닫힌 목표를 열었다(회귀 사례 2)');
// 되풀이 — 열린 목표는 건너뛴다(층 정의에 있고, 저장 상태의 열린 목록에 있고, 닫힌 상자가 안 보일 때).
r = planOpen(rec, 3, at(''), 'T', env(['c1']));
assert.equal(r.act, 'skip', '되풀이: 열린 목표는 건너뛴다');
// 되풀이 — 없는 목표: 요약은 같은 빈 글이지만 층 정의에 그 상자가 없다.
r = planOpen(rec, 3, at(''), 'T', { chestAt: () => '', opened: () => ['c1'] });
assert.equal(r.act, 'fail', '되풀이: 층 정의에 없는 목표는 실패(열린 목록에 이름이 있어도)');
assert.match(r.error, /#4 open.*없는 목표/, '없는 목표 오류에 행동 번호');
r = planOpen(rec, 3, at(''), 'T', { chestAt: () => 'c3', opened: () => ['c1', 'c3'] });
assert.equal(r.act, 'fail', '되풀이: 그 칸에 다른 상자가 정의돼 있으면 실패');
// 되풀이 — 닫힌 목표: 닫힌 상자가 보이거나, 안 보여도 저장 상태의 열린 목록에 없다.
r = planOpen(rec, 3, at('c1'), 'T', env(['c1']));
assert.equal(r.act, 'fail', '되풀이: 닫힌 상자가 보이면 실패');
assert.match(r.error, /#4 open.*닫혀/, '닫힘 오류에 행동 번호');
r = planOpen(rec, 3, at(''), 'T', env([]));
assert.equal(r.act, 'fail', '되풀이: 안 보여도 저장 상태의 열린 목록에 없으면 실패');
assert.match(r.error, /#4 open.*열린 상자 목록/, '목록에 없음 오류');
r = planOpen(rec, 3, at('c3'), 'T', env(['c1']));
assert.equal(r.act, 'fail', '되풀이: 다른 상자면 실패');
assert.match(r.error, /다른 상자/, '다른 상자 오류');
r = planOpen(rec, 3, { ...at(''), at: [10, 15] }, 'T', env(['c1']));
assert.equal(r.act, 'fail', '되풀이: 자리가 다르면 실패');
assert.match(r.error, /자리가/, '자리 오류');
r = planOpen(rec, 3, { ...at(''), facing: 2 }, 'T', env(['c1']));
assert.equal(r.act, 'fail', '되풀이: 방향이 다르면 실패');
r = planOpen(rec, 3, at(''), 'T');
assert.equal(r.act, 'fail', '되풀이: 근거 어댑터가 없으면 건너뛰지 않는다');
console.log('web_check_lib planOpen: OK');
