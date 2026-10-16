# sqfangame

아틀라스 「세계수의 미궁(Etrian Odyssey)」 시리즈의 시스템을 참고한 1인칭 그리드 던전 탐사 팬게임.

- 비영리 팬 프로젝트다. 원작의 이름·문장·그림·음악을 그대로 쓰지 않고 시스템만 참고한다.
- 엔진: Godot 4.7.2-stable (`godot` 명령, 경로를 바꿀 때는 `${GODOT:-godot}`)
- 1차 대상: 웹 빌드 (확인 편의). 렌더러는 웹에서 동작하는 Compatibility(WebGL 2)를 쓴다.

## 문서

- `docs/research/`: 원작 시리즈 시스템 조사 자료 (`README.md`에 작성 경위와 원문 대조 기록)
- `docs/design/01-game-design.md`: 게임 기획 (방향, 범위, 탐색·전투·직업·마을·성장·저장 규칙)
- `docs/design/02-tech-plan.md`: 기술 계획 (Godot 웹, 코드 구조, 데이터, 시험, 배포)
- `docs/design/03-production-plan.md`: 그림 에셋 제작과 단계(M0~M3)별 수용 기준
- `docs/design/04-world-and-art-direction.md`: 세계관(사이버펑크 + 마법)과 아트 방향
