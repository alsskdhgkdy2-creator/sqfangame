// web_check 의 판정 함수(브라우저 없이 node 로 시험한다: node tools/web_check_lib.test.mjs).

// IndexedDB 의 자동 저장 기록이 화면 상태와 같은지: 세대만이 아니라 저장 글의 상태 해시도 같아야 한다.
// rec = { generation, hash }(저장 글을 게임의 hash_save 로 읽은 값), want = 화면 상태 요약 { generation, hash }.
export function idbMatches(rec, want) {
  if (!rec || rec.error || !want) return false;
  if (typeof rec.generation !== 'number' || rec.generation !== want.generation) return false;
  return typeof rec.hash === 'string' && rec.hash.length > 0 && rec.hash === want.hash;
}
