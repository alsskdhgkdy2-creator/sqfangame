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
