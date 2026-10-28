# sqfangame — 「아보르 프로토콜」(가제)

아틀라스 「세계수의 미궁(Etrian Odyssey)」 시리즈의 비공식 팬게임. 신작을 기다리던 팬이 직접 만드는 2차 창작 후속작으로, 1인칭 그리드 탐사·손으로 그리는 지도·FOE·5인 직업 파티와 원작의 그림체를 이어받아 "사이버네틱한 세계수의 미궁"을 그린다: 사이버네틱 몸 위에 홀로그램으로 판타지 기사·마법사의 모습을 투사한다.

- 비영리 팬 프로젝트이며 ATLUS·SEGA와 관계없는 비공식 2차 창작이다.
- 원작 스타일(그림체·UI 문법·세계관 모티브·시리즈 용어)을 레퍼런스로 삼아 드러낸다. 그림·음악·문장은 새로 만들고, 원작 게임에서 추출한 파일은 넣지 않는다.
- 엔진: Godot 4.7.2-stable (`godot` 명령, 경로를 바꿀 때는 `${GODOT:-godot}`)
- 1차 대상: 웹 빌드 (확인 편의). 렌더러는 웹에서 동작하는 Compatibility(WebGL 2)를 쓴다.

## 상태

**M3(수직 슬라이스) 진행 중(2026-10-26, D29).** M2(전투)·M2.5(성장)·M2.6(UI 다듬기) 뒤 2026-10-18~10-24 일시 중지(D22)했다가, M2.7(화면 위에 뜨는 UI·원작 배치, D23)로 다시 시작해 탐색·전투·캠프 화면과 상점을 원작 짜임으로 옮겼다. 이제 시스템(여러 층·마을·FOE·채집·의뢰·보스·직업 여섯)부터 넣고, 생성 그림은 그 뒤에 넣는다(`docs/design/03-production-plan.md` §2 M3). 지금까지 A1(여러 층·계단, 저장 5판)과 A2(제목 → 마을 광장 → 미궁 입구 → B1F와 돌아오는 길, 광장에서 상점, 여관 숙박·하루·여관 기록, 전멸 뒤 지도 남기기, 저장 6판)와 A3(실제 1~3층 「네온 이끼숲」, 보물상자·잠긴 문·열쇠, 저장 7판과 옛 시험 층 저장 옮기기)를 마쳤다. A4(소모품 여섯·공용 가방 60칸·저장 8판, 캠프 소지품의 쓰기·버리기, 비콘으로 돌아오기, 상점 소모품, 전투 「아이템」 명령)도 마쳤다. A5(채집 3종: 채집 지점 8곳·채집 표·소재 15종·장비 25종·저장 9판, 채집 물음·알림·3D 표지·캠프 채집 알약)도 마쳤다. A6(FOE 3종: B1F~B3F의 FOE 셋, 접촉 전투·되살아남·저장 10판, 전투 난입 「N턴 뒤 합류」, 3D 표지·지도·알림·합류 알약)도 마쳤다. A7(길드·새 직업 둘)은 A7a(등록부·편성 규칙·캠프 대열·저장 11판)와 A7b(레일 레인저·헥스 해커, 활·총, 혼란·맹목)까지 했고, 다음은 A7c(길드 화면·캠프 대열 화면·웹 H)다.

## 문서

- `docs/design/00-decisions.md`: 사용자 결정 기록
- `docs/research/`: 원작 시리즈 시스템 조사 자료 (`README.md`에 작성 경위와 원문 대조 기록)
- `docs/design/01-game-design.md`: 게임 기획 (방향, 범위, 탐색·전투·직업·마을·성장·저장 규칙)
- `docs/design/02-tech-plan.md`: 기술 계획 (Godot 웹, 코드 구조, 데이터, 시험, 배포)
- `docs/design/03-production-plan.md`: 그림 에셋 제작과 단계(M0~M3)별 수용 기준
- `docs/design/04-world-and-art-direction.md`: 세계관(사이버펑크 + 마법)과 아트 방향
- `docs/design/05-m1-exploration.md`: M1 탐색 시제품 명세 (층 정의 형식, 이동 규칙, 지도, 저장, 화면, 시험)
- `docs/design/06-m2-combat.md`: M2 전투 시제품 명세 (전투 규칙, 정의 데이터, 첫 수치, 시뮬레이션, 저장 2판, 화면, 시험)
- `docs/design/07-growth.md`: M2.5 성장 시스템 시제품 명세 (경험치·레벨업, 스킬 트리, 장비, 파티 메뉴, 저장 3판)
- `docs/design/08-town-shop.md`: M3 마을·상점 명세 (상점 자료·소지금·상점 규칙, 저장 4판. 화면은 단계마다 더함)
- `docs/CLOUD_TESTS.md`: 무거운 시험을 클라우드로 보내는 기준과 방법

## 개발

| 할 일 | 명령 |
|---|---|
| 처음 한 번(가져오기) | `godot --headless --import` |
| 규칙 시험 | `timeout 600 godot --headless -s tests/run.gd` (실패하면 종료 코드 1, 시간 초과면 124). 파일 하나만: 끝에 `-- <파일 이름 일부>` |
| 웹 빌드 | `tools/export_web.sh` → `build/web/` |
| 웹 캡처 | `npm install` 뒤 `flock /tmp/voxel-test-heavy.lock xvfb-run -a node tools/shot.mjs build/shot.png 1280x720 20` |
| 브라우저 자동 확인 | 웹 빌드 뒤 `flock /tmp/voxel-test-heavy.lock flock /tmp/sqfangame-godot.lock xvfb-run -a node tools/web_check.mjs 1280x720 [a|b|c|all]` → `build/check/` (A = 탐색·전투, B = 성장·전멸, C = 마을 고리(제목·광장·입구·문·상점·이어하기·불러오기), 기본 `all`은 A, B, C 차례. 2400×1000은 5분 한도 때문에 `a`·`b`를 따로 돌린다. 공략·전투·지도 편집·저장·새로 고침·내보내기·가져오기·전멸 창, 실패하면 종료 코드 1. 느린 기기 상태면 `WEB_CHECK_IDB_MS=60000`, `docs/CLOUD_TESTS.md`) |
| 컨셉 그림 비교 시트 | `python3 tools/concept_sheet.py <출력.jpg> "<이름>=<그림>" ...` (아랫줄에 게임 화면 크기 판을 붙임, `assets/concept/compare/`) |
| 텍스처 이음새 | `python3 tools/tile_check.py check <그림>...` / `preview <그림> <출력>` / `fix <그림> <출력> --size 512` |
| 휴대폰 확인 | `python3 tools/serve_web.py` (127.0.0.1:8765, 큰 파일 gzip) 뒤 `cloudflared` 임시 주소 (`docs/CLOUD_TESTS.md`) |
| 클라우드 시험 | `tools/cloud/test.sh --push --wait` (`docs/CLOUD_TESTS.md`) |

- 글꼴: `assets/fonts/NotoSansKR-Regular-subset.otf` (Noto Sans CJK KR에서 ASCII·한글 음절·자모·문장부호만 남김, SIL OFL 1.1, `assets/fonts/OFL.txt`).
- 그림의 `.import` 설정을 손으로 고치면 `godot --headless --import` 가 다시 가져오지 않는다. `.godot/imported/<파일 이름>-*` 를 지우고 가져온다.
- Godot 는 프로젝트 폴더 전체를 가져온다. `node_modules/`·`build/`·`tmp/` 에는 `.gdignore` 를 둔다(`docs/CLOUD_TESTS.md`).
