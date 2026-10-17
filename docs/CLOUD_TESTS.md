# 클라우드 시험 (무거운 검증은 클라우드, 가벼운 시험은 이 기기)

이 기기(Galaxy S23 proot)는 무거운 실행을 한 번에 하나만 하고 느리다. 그래서 연산이 큰 검증(전투 밸런스 시뮬레이션, 나중의 자동 경로 시험·큰 빌드)은 Claude 클라우드 세션에 맡기고, 이 기기는 에이전트 호출·조정과 가벼운 시험을 맡는다. 공통 규칙은 `~/.config/device-rules/cloud-tests.md`, 클라우드 사용법은 `claude-cloud-test` 스킬에 있다.

- 공급자: Claude 클라우드(`claude --cloud`)만 준비했다. Codex 클라우드는 이 저장소에 환경이 없다. 쓰려면(Claude 크레딧·한도 소진, 비교) 사용자가 정하고, Paseo 로 Codex 에이전트를 불러 그 에이전트가 자기 스킬로 준비·실행한다(교차 실행 규칙).
- 2026-10-16 현재 클라우드로 보낼 시험이 아직 없다(시뮬레이션은 M2 에서 생긴다). 경로만 준비해 두고, 시범 실행 한 번으로 확인한다(아래 「시범 기록」).

## 나눠 맡는 일

바뀐 파일로 범위를 고르는 규칙은 `tools/cloud/scope.sh` 한 곳에 있다.

| 바뀐 곳 | 범위 | 어디서 | 시험 |
|---|---|---|---|
| 노드 없는 규칙 코드 `src/core/`·`src/data/`, 정의 데이터 `data/`, 시뮬레이션 `tests/sim/` | `sim` + `local` | 클라우드 `tools/cloud/test.sh`(시뮬레이션) + 이 기기(규칙 시험) | 가져오기, 규칙 시험, 전투 밸런스 시뮬레이션(M2~) |
| 장면·화면 `src/game/`·`src/ui/`, 그림·글꼴 `assets/`, 도구 `tools/`, 설정 | `local` | 이 기기 | 가져오기, 규칙 시험, 필요하면 웹 빌드·캡처 |
| 문서만 | — | — | 없음 |

- 시뮬레이션은 노드 없는 규칙 코드와 정의 데이터만 읽는다(02 문서 §4). 그 밖의 파일만 바뀐 브랜치는 시뮬레이션 결과가 바뀔 수 없다.
- `tools/cloud/test.sh` 는 origin/main 과 갈라진 곳부터 `sim` 범위 파일이 하나도 안 바뀌었으면 클라우드를 부르지 않고 멈춘다(종료 코드 3, `--force` 로 보낼 수 있다).
- 무거움 판단 참고값: 이 기기에서 5분 넘게 걸리거나 메모리를 1GB 넘게 쓰는 실행(공통 규칙). 지금의 웹 빌드(내보내기 34초, 캡처 포함 72초)는 이 기기에서 한다. 프로젝트가 커져 이 값을 넘으면 웹 빌드도 클라우드로 옮긴다(02 문서 §7).

## 이 기기에서 바로 확인

```sh
godot --headless --import                     # 처음 한 번, 그림·글꼴을 바꾼 뒤
timeout 600 godot --headless -s tests/run.gd  # 규칙 시험(실패하면 종료 코드 1, 시간 초과면 124)
flock /tmp/voxel-test-heavy.lock bash -c 'tools/export_web.sh && xvfb-run -a node tools/shot.mjs build/shot.png 1280x720 20'
flock /tmp/voxel-test-heavy.lock bash -c 'tools/export_web.sh && xvfb-run -a node tools/web_check.mjs 1280x720'  # 브라우저 자동 확인
```

- 브라우저 자동 확인(`tools/web_check.mjs`)은 내보낸 웹 빌드를 헤드리스 Chromium 으로 열어 공략 경로를 걷고, 지도 편집·한국어 메모(브라우저 입력 창)·되돌리기·IndexedDB 자동 저장·새로 고침 뒤 상태 해시·내보내기·가져오기·1MB 초과 거부·파일 고르기 취소를 확인한다. 결과는 `build/check/`(캡처, 내보낸 파일, `report.json`), 실패가 하나라도 있으면 종료 코드 1. 2026-10-17 이 기기에서 빌드 포함 약 1분 50초–2분, 19/19 통과(늦게 끝난 앞 가져오기 버림 포함). 「공략 끝」 기록에 연출 보정 계획 시간(`plan_ms_max` 등)을 남긴다(단언 없음, 05 §9.2.1). 폰 브라우저의 사용자 활성화·IME·실제 손가락 입력은 이것으로 대신하지 못한다(05 §11.3).

- 시험 명령에는 늘 `timeout` 을 붙인다. 실행기(`tests/run.gd`·`tests/harness.gd`)가 컴파일에 실패하면 Godot 가 종료 코드 없이 끝나지 않고 계속 돈다(2026-10-16 확인: 문법 오류 하나로 모든 시험 실행이 멈춤). 클라우드·CI 도 같다.
- 웹 빌드·캡처는 공용 잠금 `/tmp/voxel-test-heavy.lock` 을 잡고 서버 전체에서 한 번에 하나씩 돌린다.
- 이 프로젝트의 Godot 실행(시험·가져오기)끼리는 `flock /tmp/sqfangame-godot.lock` 으로 하나씩 돌린다. 시험이 같은 `user://` 임시 폴더와 가져오기 캐시를 쓰고, 장면 시험은 시작할 때 지난 실행의 임시 폴더를 지우기 때문이다(에이전트 여럿이 함께 일할 때 특히).
- Godot 는 프로젝트 폴더 전체를 가져온다. `node_modules/`(npm `postinstall` 이 만든다)·`build/`(`tools/export_web.sh` 가 만든다)·`tmp/`(`tools/cloud/test.sh` 가 만든다)에는 `.gdignore` 를 둔다. 2026-10-16 `node_modules/` 의 playwright SVG 를 가져오다 같은 파일을 되풀이하며 멈췄고, 그동안 세션이 두 번 끊겼다.
- 휴대폰 확인: `python3 tools/serve_web.py`(127.0.0.1:8765, wasm 39.5MB 를 gzip 으로 약 10MB 로 보낸다)를 띄우고 `cloudflared tunnel --no-autoupdate --url http://localhost:8765 --http-host-header localhost:8765` 로 잠깐 연다. 새 임시 주소는 열린 뒤 30초쯤 지나야 접속된다. 임시 주소는 켜 둔 동안 아는 사람 누구나 열 수 있으니 공개하지 않고, 확인이 끝나면 끈다. 스레드 없는 내보내기라 특별한 헤더가 필요 없다.

## 쓰는 법 (클라우드)

시뮬레이션 범위를 바꾼 브랜치의 작업 폴더에서 변경을 커밋한 뒤:

```sh
tools/cloud/test.sh --push --wait                  # 표준 시험 묶음(tools/cloud/test-prompt.md)
tools/cloud/test.sh --push --wait --extra "godot --headless -s tests/<새 시험>.gd → 종료 코드 0"
tools/cloud/test.sh --push --wait --force          # sim 범위 변경이 없어도 보낸다(시범 실행·정기 점검)
```

- 클라우드는 GitHub `origin`(`alsskdhgkdy2-creator/sqfangame`, 공개)의 그 브랜치를 받는다. 커밋하지 않은 변경은 가지 않고, 있으면 스크립트가 멈춘다. `--push` 는 지금 브랜치를 origin 에 올린다.
- 클라우드 세션은 자기 작업 브랜치로만 `git push` 할 수 있다. 그래서 스크립트가 실행마다 일회용 브랜치 `cloud/run/<브랜치>-<커밋>-<시각>` 을 임시 작업 폴더(`tmp/cloud-run-*`)에 만들어 **추적(upstream)을 걸어** origin 에 올리고, 그 폴더에서 세션을 띄운다. 세션은 그 커밋에서 자기 작업 브랜치 `claude/...` 를 만들어 보고서 `cloud-report.md`(첫 줄에 고유 표지)를 올린다. `--wait` 가 표지로 보고서를 찾아 `tmp/cloud-reports/` 에 받고, 원격의 그 브랜치들을 지운다. 작업 브랜치가 main 이나 시험 대상 브랜치이면 세션은 올리지 않고 대화로만 보고한다(지시문의 안전장치).
- 저장소가 공개라 일회용 브랜치와 보고 브랜치는 지우기 전까지 공개로 보인다. 보고서에는 시험 결과와 머신 정보만 들어간다.
- **Claude GitHub 앱이 이 저장소에 접근할 수 있어야** 세션이 GitHub 에서 받고 보고를 올린다. 앱이 없으면 CLI 가 저장소를 묶음으로 올려 세션에 git 원격이 없고(「'origin' does not appear to be a git repository」), 보고는 세션 대화에만 남는다. 앱 권한은 이 기기에서 볼 수 없어 시범 실행으로 확인한다. 없으면 사용자가 GitHub → Settings → Applications → Installed GitHub Apps → Claude → Repository access 에서 이 저장소(또는 All repositories)를 허용한다.
- `claude --cloud` 는 실제 터미널(TTY)에서만 돈다. 스크립트가 `script` 로 가짜 터미널을 만들고, 새 폴더에서 뜨는 「이 폴더를 믿는가」 창에는 「믿는다」를 고른다.
- 실행 기록(시각·브랜치·커밋·세션 주소)은 `tmp/cloud-reports/runs.tsv` 에 쌓인다. 세션은 claude.ai/code 나 Claude 앱의 Code 탭에서 보인다(Paseo 탭에는 보이지 않는다). 끝난 세션은 CLI 로 지울 수 없고 claude.ai/code 사이드바에서 보관·삭제한다.
- 비용은 Claude 사용량(크레딧·한도)에서 나간다. 참고: lastorigin-fan 의 고도 시험 묶음 1회가 약 1달러였다.
- 늦게 오는 보고: 다른 저장소에서 보고가 45분 넘게 늦게 온 일이 있다. 다시 돌리기 전에 `git ls-remote origin 'refs/heads/claude/*'` 에 남은 보고 브랜치를 표지로 확인한다.
- 보고서의 표지와 커밋이 이번 실행과 맞을 때만 근거로 쓴다. 클라우드 호출 성공은 시험 통과가 아니고, 클라우드 시험 통과는 독립 코드 검토를 대신하지 않는다.

## 클라우드에 없는 자료와 알려진 환경 차이

- git 에 넣지 않는 파일: 사용자가 모은 참고 그림(`reference/`, 이 저장소에 넣지 않는다), `build/`, `node_modules/`, `tmp/`. 표준 시험은 이것들을 읽지 않는다.
- 웹 내보내기 템플릿(약 2GB)은 클라우드에 설치하지 않는다. 웹 빌드가 클라우드로 옮겨 가면 그때 설치 단계를 정한다.
- 같은 시험도 클라우드 머신 상태에 따라 시간이 2배 가까이 달라진다. 시드를 고정한 시뮬레이션도 머신마다 결과가 조금 다를 수 있어 허용 범위로 판정한다(02 문서 §7).

## 쓰지 않는 것

- 끝난 세션에 다음 시험을 넣는 재활용(`claude -p "<지시>" --cloud <세션 id>`): 쉬면 VM 이 멈추고 회수될 수 있어 설치물이 남는다는 보장이 없고, 대화가 쌓여 회차마다 토큰이 는다. 매번 새 세션을 띄운다(`claude-cloud-test` 스킬).
- 환경 설정 스크립트 캐시: 고도 설치가 가벼워(lastorigin-fan 에서 준비 전체 약 8~13초) 지금은 쓰지 않는다. 설치가 무거워지면 프로젝트 전용 환경을 만들어 저장소 `.claude/settings.json` 의 `remote.defaultEnvironmentId` 로 지정하는 방식을 검토한다.

## 시범 기록

| 날짜 | 커밋 | 결과 |
|---|---|---|
| — | — | 아직 없음. 사용자 결정(2026-10-16): 시뮬레이션이 생기는 M2 때 처음 돌린다. 그때 `tools/cloud/test.sh --push --wait` 로 앱 권한·보고 회수를 함께 확인한다 |
