# sqfangame — 「아보르 프로토콜」(가제)

아틀라스 「세계수의 미궁(Etrian Odyssey)」 시리즈의 비공식 팬게임. 신작을 기다리던 팬이 직접 만드는 2차 창작 후속작으로, 1인칭 그리드 탐사·손으로 그리는 지도·FOE·5인 직업 파티와 원작의 그림체를 이어받아 "사이버네틱한 세계수의 미궁"을 그린다: 사이버네틱 몸 위에 홀로그램으로 판타지 기사·마법사의 모습을 투사한다.

- 비영리 팬 프로젝트이며 ATLUS·SEGA와 관계없는 비공식 2차 창작이다.
- 원작 스타일(그림체·UI 문법·세계관 모티브·시리즈 용어)을 레퍼런스로 삼아 드러낸다. 그림·음악·문장은 새로 만들고, 원작 게임에서 추출한 파일은 넣지 않는다.
- 엔진: Godot 4.7.2-stable (`godot` 명령, 경로를 바꿀 때는 `${GODOT:-godot}`)
- 1차 대상: 웹 빌드 (확인 편의). 렌더러는 웹에서 동작하는 Compatibility(WebGL 2)를 쓴다.

## 문서

- `docs/design/00-decisions.md`: 사용자 결정 기록
- `docs/research/`: 원작 시리즈 시스템 조사 자료 (`README.md`에 작성 경위와 원문 대조 기록)
- `docs/design/01-game-design.md`: 게임 기획 (방향, 범위, 탐색·전투·직업·마을·성장·저장 규칙)
- `docs/design/02-tech-plan.md`: 기술 계획 (Godot 웹, 코드 구조, 데이터, 시험, 배포)
- `docs/design/03-production-plan.md`: 그림 에셋 제작과 단계(M0~M3)별 수용 기준
- `docs/design/04-world-and-art-direction.md`: 세계관(사이버펑크 + 마법)과 아트 방향

## 개발

| 할 일 | 명령 |
|---|---|
| 처음 한 번(가져오기) | `godot --headless --import` |
| 규칙 시험 | `godot --headless -s tests/run.gd` (실패하면 종료 코드 1) |
| 웹 빌드 | `tools/export_web.sh` → `build/web/` |
| 웹 캡처 | `npm install` 뒤 `flock /tmp/voxel-test-heavy.lock xvfb-run -a node tools/shot.mjs build/shot.png 1280x720 20` |
| 컨셉 그림 비교 시트 | `python3 tools/concept_sheet.py <출력.jpg> "<이름>=<그림>" ...` (아랫줄에 게임 화면 크기 판을 붙임, `assets/concept/compare/`) |

- 글꼴: `assets/fonts/NotoSansKR-Regular-subset.otf` (Noto Sans CJK KR에서 ASCII·한글 음절·자모·문장부호만 남김, SIL OFL 1.1, `assets/fonts/OFL.txt`).
