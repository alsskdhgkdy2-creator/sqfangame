[클라우드 시험 — 시험 실행·보고 전용, tools/cloud/test.sh 가 보낸 지시]
역할: 시험을 돌리고 결과·시간을 보고한다. 코드 수정·PR·배포 금지. 비밀 값 접근 금지. 보고는 한국어로.

저장소: 「세계수의 미궁」 비공식 팬게임 「아보르 프로토콜」(가제), 고도 4.7.2 GDScript 프로젝트(저장소 루트가 고도 프로젝트).
시험 대상: 브랜치 `{{BRANCH}}`, 커밋 `{{COMMIT}}`. `git log --oneline -1` 로 확인하고, 다르면 그대로 보고한다.
모든 단계 앞뒤로 `date +%s` 를 찍어 걸린 초를 잰다(준비와 시험을 나눠 기록, 비용 비교 기준).

준비(실패하면 어디서 왜 실패했는지 그대로 보고):
1. `uname -m`·`nproc` 기록.
2. 고도 4.7.2 x86_64(이미 있으면 버전만 확인): `curl -fL -o /tmp/godot.zip https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`, SHA-256 이 `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4` 인지 확인 → 풀어서 `godot` 이름으로 PATH 에. `godot --version` = `4.7.2.stable.official.ed1daf0bf`.
3. 덧붙인 시험이 `xvfb-run` 을 쓰고 xvfb·Mesa(llvmpipe)가 없으면 `apt-get install -y xvfb xauth libgl1-mesa-dri`.
4. 모든 고도 실행에 `export XDG_DATA_HOME=/tmp/xdg GODOT_SILENCE_ROOT_WARNING=1`.

표준 시험(저장소 루트 기준, 차례로. 통과 판정은 로그 문구와 종료 코드로. 시험 파일이 이 커밋에 아예 없으면 「해당 없음」으로 적고 실패로 세지 않는다):
a. `godot --headless --import` 를 두 번(두 번째가 오류 없이 끝나야 한다)
b. `timeout 600 godot --headless -s tests/run.gd` → 「결과: N개 중 0개 실패」 및 종료 코드 0 (종료 코드 124 는 시간 초과로, 실행기가 컴파일에 실패해 멈춘 것일 수 있다. 실패로 보고한다)
c. 전투 밸런스 시뮬레이션 `godot --headless -s tests/sim/run.gd`(M2 에서 생긴다) → 마지막 요약 줄을 원문으로 보고하고 종료 코드 0

덧붙인 시험(있으면 표준 시험 뒤에 같은 방식으로):
{{EXTRA}}

알려진 환경 차이: git 에 넣지 않는 파일(`reference/` 같은 사용자 참고 그림, `build/`, `node_modules/`)은 이 환경에 없다. 그 밖의 실패는 전체 오류 문구와 로그 30줄 안팎을 붙인다.

보고: 맨 앞 한 줄 결론(모두 통과 / 코드 실패 n건 / 환경 실패 n건). 시험별 표(시험·결과·판정 근거 로그 한 줄·걸린 초). 준비 단계별 걸린 초와 합계, 시험 합계, 전체 합계. 머신 정보. 확인하지 못한 것은 미확인.
결과 전달: 보고를 저장소 루트의 `cloud-report.md` 한 파일로 쓰고 **첫 줄에 `{{TOKEN}}` 을 그대로** 넣는다. 지금 작업 브랜치(`git branch --show-current`, 보통 `{{RUN_BRANCH}}` 또는 이 세션의 `claude/...` 브랜치)에 그 파일 하나만 커밋하고 `git push origin HEAD` 로 올린다(클라우드는 작업 브랜치로만 푸시할 수 있다). 작업 브랜치가 `main` 이거나 `{{BRANCH}}` 이면 올리지 말고 대화에만 보고한다. 원격이 없거나 푸시가 거절되면 그 이유를 적고 대화에만 보고한다.
