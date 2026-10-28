// 웹 빌드 자동 확인(05 §11.3): ?debug=1 의 window.sqfDebug 로 상태를 읽으며 실제 키·마우스·파일 고르기로 조작한다.
// 전투 승패(밸런스)에 기대지 않는다(D15): 실제 누르기 한 턴은 어떻게 끝나도 그 끝에 맞는 화면·저장을 보고 공략을 잇는다.
// 그 밖의 전투는 디버그 요청 battle_finish 로 넘긴다(전투 층이 규칙의 finish 「승리」 → 저장 → 연출 → 결과 창).
// 1) 고정 공략 행동열로 지름길을 열 때까지 걷는다. 첫 전투(06 §10.4): 전투 시작 저장(IndexedDB)을 따로 둔다 → 새로 고침 → 같은
//    해시·명령 입력 처음 → 전투 층 캡처 → 한 턴을 실제 누르기로(공격 → 적 칸 → … → 실행 → 누르기로 연출 건너뛰기) → 저장·해시
//    (이어지면 턴 +1·로그) 확인 → 그 턴의 끝에 따라: 이어짐 → battle_finish → 결과 창 「확인」 / 승리·도주 → 결과 창 「확인」 /
//    전멸 → M1 전멸 창 확인 → 「새 게임」 → 캠프 「기록」 「가져오기」로 전투 시작 저장 → 같은 전투(턴 0) → battle_finish → 결과 창.
//    그 뒤 전투도 battle_finish, 남은 공략의 행동마다 해시 = 첫 전투 뒤 simulate(전투는 같은 finish 로 넘긴다).
//    2) 지도 편집(벽·바닥 색·메모 입력 창).
// 3) IndexedDB 의 자동 저장(세대와 저장 글의 상태 해시)이 화면과 같아질 때까지 기다린다. 「저장 중」 표시는 자동 저장 직후(2 의 Ctrl+Z)
//    보이고, 그 사이 약 50ms 표본마다 IndexedDB 에 그 세대가 없으면 남아 있고, 들어간 뒤 사라진다(05 §8.3).
//    게임의 IndexedDB 읽기를 직접 불러 읽을 수 없는 기록(내용 없음·Blob)은 false, 없는 열쇠만 null 인지 본다. 4) 새로 고침 → 전체 해시와 다음 행동 결과 비교.
// 5) 캠프 「기록」 화면에서(M2.7 R2-d: 「캠프」 단추 → 「기록」 줄) 내보내기(내려받기) → 이동 → 가져오기(파일 고르기) → 해시 비교. 늦게 끝난 앞 가져오기(A)는 새 가져오기(B) 결과를
//    덮지 않는다. 1MB 넘는 파일은 거부.
// 6) 가져오기로 준비한 저장(전투 중, 넷 쓰러짐, 하나 HP 1 독) → 방어 → 실행 → 전멸 창(규칙 기능 확인).
// 7) 성장(07 §10.5): 전멸 창 「새 게임」 → 「캠프」 단추 → 명령 줄 → 대원 카드 → grant_exp → 스킬 배분 취소(버리기)·확정(실제 누르기, IndexedDB 확인)
//    → supply → 장비 화면에서 이온 세이버 장착 → 새로 고침(같은 해시·캠프 닫힘) → 고정 저장 tools/web_check_victory_save.json 가져오기
//    (편성 rats, 쥐 0·1 HP 0·처치 기록, 쥐 2 살아 있음·처치 기록 없음, 대원 가득, 듀얼리스트 A exp 26) → 전투 중 「캠프」 없음·P 무시
//    → battle_finish → 결과 창 「경험치 +4」「레벨 업」「듀얼리스트 A  Lv 1 → 2  SP +1」 → 상태 화면 Lv 2·SP 1. 승패에 기대지 않는다(D15).
// 새 게임 시드는 SEED(디버그 주소 &seed=)로 고정한다: 실행마다 같은 인카운트·같은 첫 턴이 되게 하는 재현용이고, 값에 다른 뜻은 없다
// (그 시드의 첫 턴이 이어지든 이기든 전멸하든 위 길로 통과해야 한다).
// 두 부분으로 나뉜다(한 번 실행을 이 기기 5분 한도 아래로): A = 1)~5) 탐색·전투(web_check_part_a.mjs),
// B = 6)~7) 전멸·성장(web_check_part_b.mjs, 새 게임을 내보낸 저장으로 전멸 저장을 만든다). 공통 준비는 web_check_common.mjs.
// 부분마다 새 브라우저(빈 IndexedDB)로 돈다. 확인 이름과 개수는 나누기 전과 같다(A + B).
// M3 A2: 시작은 타이틀이다(waitReady 가 「이어하기」 또는 「새 게임」으로 지난다, 새 게임은 마을 광장). C = 마을 고리(web_check_part_c.mjs, A2b 숙소 포함).
// M3 A2b: 전멸 창 「처음부터」 뒤에는 지도 물음(answerWipeMap)이 있다.
// M3 A3: 게임은 실제 미궁(arbor)이다. A·B·C 는 시험 층(주소 &set=test, 저장 폴더 saves_test)으로 돌고, D = 실제 미궁 B1F~B3F
// (상자·계단·잠긴 문·귀중품·옛 저장 옮김, web_check_part_d.mjs, 주소에 set 없음·저장 폴더 saves).
// M3 A4b: E = 소모품·공용 가방·귀환 비콘(web_check_part_e.mjs, 시험 층): 상점 「아이템」·판매 「소모품」, 캠프 소지품 쓰기·버리기, 비콘으로 마을.
// M3 A5b: F = 채집 지점(web_check_part_f.mjs, 실제 미궁): 채집 물음·안내·다 쓴 지점, 캠프 채집 알약, 숙박으로 되돌아오는 횟수, 새로 고침.
// M3 A6c: G = FOE(web_check_part_g.mjs, 실제 미궁): 숫양 순회·접촉 전투·전투 중 새로 고침·쓰러짐·숙박 되살아남·합류 알약·합류.
// 실행: flock /tmp/voxel-test-heavy.lock xvfb-run -a node tools/web_check.mjs [너비x높이] [a|b|c|d|e|f|g|all]  (기본 all = A, B, C, D, E, F, G 차례)
// 결과: build/check/ 에 캡처·내보낸 파일, 부분마다 report_a.json·report_b.json, 이번 실행 전체 report.json.
import { runPart, finish } from './web_check_common.mjs';
import { partA } from './web_check_part_a.mjs';
import { partB } from './web_check_part_b.mjs';
import { partC } from './web_check_part_c.mjs';
import { partD } from './web_check_part_d.mjs';
import { partE } from './web_check_part_e.mjs';
import { partF } from './web_check_part_f.mjs';
import { partG } from './web_check_part_g.mjs';

const which = (process.argv[3] ?? 'all').toLowerCase();
// 부분 이름은 이 목록에만 있다(Map: 「constructor」 같은 객체 기본 이름이 부분으로 통과하지 않는다). 브라우저를 띄우기 전에 거른다.
// 값 = [본문, 층 묶음].
const PARTS = new Map([['a', [partA, 'test']], ['b', [partB, 'test']], ['c', [partC, 'test']], ['d', [partD, 'game']], ['e', [partE, 'test']], ['f', [partF, 'game']], ['g', [partG, 'game']]]);
const names = which === 'all' ? [...PARTS.keys()] : [which];
if (!names.every((n) => PARTS.has(n))) {
  console.log(`모르는 부분: ${which}\n사용: node tools/web_check.mjs [너비x높이] [a|b|c|d|e|f|g|all]`);
  process.exit(2);
}
for (const n of names) await runPart(n, ...PARTS.get(n));
process.exit(finish());
