#!/usr/bin/env bash
# 연산이 큰 시험(전투 밸런스 시뮬레이션 등)을 Claude 클라우드(claude --cloud)에서 돌린다(이 기기는 호출만, docs/CLOUD_TESTS.md).
# 규칙 시험·웹 빌드·캡처처럼 가벼운 시험은 이 기기에서 바로 돌린다(README 「개발」).
# 본보기: ~/projects/lastorigin-fan/tools/cloud/test.sh 의 Claude 경로(일회용 브랜치·추적 push·TTY·믿음 창·표지 회수·브랜치 정리).
# 사용(시험할 브랜치의 작업 폴더에서): tools/cloud/test.sh [--push] [--wait[=분]] [--extra "<덧붙일 시험 지시>"] [--force]
#   지금 폴더의 브랜치·커밋을 시험한다. 클라우드는 origin(GitHub)의 그 브랜치를 받으므로 origin 이 지금 커밋과 같아야 한다.
#   origin/main 과 갈라진 곳부터 시뮬레이션 범위 파일(tools/cloud/scope.sh 의 sim)이 바뀌지 않았으면 클라우드를 부르지 않고 멈춘다(종료 코드 3).
#   --force        그래도 보낸다(시범 실행·main 정기 점검 등)
#   --push         지금 브랜치를 origin 에 올린다
#   --wait[=분]    보고를 기다려(기본 60분) tmp/cloud-reports/ 에 받는다
#   --extra "…"    표준 시험 뒤에 덧붙일 시험
# 실행 기록(시각·브랜치·커밋·세션 주소)은 tmp/cloud-reports/runs.tsv 에 쌓인다(비용 비교용).
# 보고 회수: 클라우드 세션은 자기 작업 브랜치로만 푸시할 수 있어서, 실행마다 일회용 브랜치 cloud/run/... 를 임시 작업 폴더에 만들어
#   그 폴더에서 세션을 띄운다. 세션은 보고서(첫 줄에 고유 표지)를 자기 작업 브랜치(claude/...)에 올리고, 여기서 표지로 찾아 받은 뒤 지운다.
#   main·시험 대상 브랜치에는 클라우드가 아무것도 올리지 않는다. 저장소가 공개라 일회용·보고 브랜치는 지우기 전까지 공개로 보인다.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
prompt_template="$here/test-prompt.md"
cd "$(git rev-parse --show-toplevel)"

push=0; wait_min=0; extra=""; force=0
while [ $# -gt 0 ]; do
  case "$1" in
    --push) push=1 ;;
    --wait) wait_min=60 ;;
    --wait=*) wait_min="${1#--wait=}" ;;
    --extra) shift; extra="${1:-}" ;;
    --force) force=1 ;;
    *) echo "모르는 인자: $1" >&2; exit 1 ;;
  esac
  shift
done

branch=$(git symbolic-ref --short HEAD 2>/dev/null) || { echo "브랜치를 체크아웃한 폴더에서 실행하세요(분리된 HEAD 는 클라우드가 받을 수 없습니다)" >&2; exit 1; }
commit=$(git rev-parse HEAD)
short=${commit:0:7}
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "커밋하지 않은 변경이 있습니다. 클라우드는 커밋된 내용만 받습니다" >&2
  exit 1
fi
git remote get-url origin >/dev/null 2>&1 || { echo "origin(GitHub) 원격이 없습니다" >&2; exit 1; }

# 시뮬레이션 범위가 바뀐 브랜치만 클라우드로
if [ "$force" = 0 ]; then
  . "$here/scope.sh"
  git fetch -q origin main 2>/dev/null || true
  sim=()
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case " $(scope_of "$f") " in *" sim "*) sim+=("$f") ;; esac
  done < <(changed_files origin/main)
  if [ ${#sim[@]} -eq 0 ]; then
    echo "origin/main 과 갈라진 곳부터 시뮬레이션 범위 변경이 없어 클라우드 시험 대상이 아닙니다." >&2
    echo "이 기기에서 바로: timeout 900 godot --headless -s tests/run.gd   (그래도 클라우드로 보내려면 --force)" >&2
    exit 3
  fi
  echo "시뮬레이션 범위 변경 ${#sim[@]}개: ${sim[*]:0:4}$([ ${#sim[@]} -gt 4 ] && echo ' …')"
fi
remote=$(git ls-remote origin "refs/heads/$branch" | cut -f1)
if [ "$remote" != "$commit" ]; then
  if [ "$push" = 1 ]; then
    git push origin "HEAD:refs/heads/$branch"
  else
    echo "origin 의 $branch(${remote:0:7}) 가 지금 커밋($short)과 다릅니다. --push 를 붙이거나 git push origin $branch" >&2
    exit 1
  fi
fi

stamp=$(date +%m%d%H%M%S)
token="CLOUD-RUN-$short-$stamp-$RANDOM"
run_branch="cloud/run/${branch//\//-}-$short-$stamp"
mkdir -p tmp/cloud-reports
touch tmp/.gdignore  # 임시 작업 폴더(저장소 사본)를 Godot 가 가져오지 않게
report_out="tmp/cloud-reports/report-${branch//\//-}-$short-$stamp.md"

prompt_file=$(mktemp /tmp/cloud-test-prompt.XXXXXX)
TEMPLATE="$prompt_template" BRANCH="$branch" COMMIT="$commit" RUN="$run_branch" TOKEN="$token" EXTRA="${extra:-(없음)}" node -e '
const fs = require("fs");
const e = process.env;
const v = { BRANCH: e.BRANCH, COMMIT: e.COMMIT, RUN_BRANCH: e.RUN, TOKEN: e.TOKEN, EXTRA: e.EXTRA };
process.stdout.write(fs.readFileSync(e.TEMPLATE, "utf8").replace(/\{\{(\w+)\}\}/g, (m, k) => (k in v ? v[k] : m)));
' > "$prompt_file"

log_run() { printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%F %T')" claude "$branch" "$short" "$1" "$2" "$token" >> tmp/cloud-reports/runs.tsv; }
save_report() {
  # $1: 보고서 내용이 든 파일. 첫 줄 표지가 맞아야 이 실행의 보고다
  head -1 "$1" | grep -qF "$token" || return 1
  cp "$1" "$report_out"
  echo "보고서: $report_out"
  cat "$report_out"
}

wt="tmp/cloud-run-$stamp"
git worktree add -q -b "$run_branch" "$wt" "$commit"
cleanup() { git worktree remove --force "$wt" 2>/dev/null || true; git branch -q -D "$run_branch" 2>/dev/null || true; }
trap cleanup EXIT
# 추적(upstream)을 걸어 올린다: 걸지 않으면 CLI 가 기본 브랜치에서 세션을 시작했다(lastorigin-fan 2026-10-01)
git -C "$wt" push -q -u origin "$run_branch"

# claude --cloud 는 실제 터미널(TTY)에서만 돈다: script 로 가짜 터미널을 만든다.
# 새 폴더면 「이 폴더를 믿는가」 창이 뜨므로, 그 창이 보이면 아래 화살표·Enter 로 「믿는다」를 고른다.
# 세션이 만들어지거나 오류가 날 때까지 입력을 열어 둔다(입력이 먼저 닫히면 CLI 가 멈출 수 있다)
log=$(mktemp /tmp/cloud-test-launch.XXXXXX)
echo "클라우드 세션을 만드는 중… ($branch @ $short, 일회용 브랜치 $run_branch)"
(
  answered=0
  # CLI 2.1.310(2026-10-25)은 낱말 사이를 공백 대신 커서 이동(ESC[nG·ESC[nC)으로 그린다: 공백으로 바꾼 뒤 나머지 제어 글자를 지운다
  plain() { sed 's/\x1b\[[0-9]*[CG]/ /g; s/\x1b\[[0-9;?<>=]*[A-Za-z~]//g' "$log" 2>/dev/null | tr -s ' '; }
  for _ in $(seq 1 360); do
    if [ "$answered" = 0 ] && plain | grep -qi "trust this folder"; then
      sleep 1; printf '\033[B'; sleep 1; printf '\r'; answered=1
    fi
    plain | grep -qE "Created cloud session|Error:|Script done" && break
    sleep 0.5
  done
  sleep 2
) | (cd "$wt" && timeout 240 script -qfec "claude --cloud \"\$(cat $prompt_file)\"" "$log") >/dev/null 2>&1 || true
rm -f "$prompt_file"

clean=$(sed 's/\x1b\[[0-9]*[CG]/ /g; s/\x1b\[[0-9;?<>=]*[A-Za-z~]//g; s/\x1b[()][A-Za-z0-9]//g' "$log" | tr '\r' '\n' | tr -s ' ')
session=$(printf '%s\n' "$clean" | grep -o 'session_[A-Za-z0-9]*' | head -1 || true)
if [ -z "$session" ]; then
  echo "클라우드 세션을 만들지 못했습니다. 실행 기록: $log" >&2
  printf '%s\n' "$clean" | grep -v '^\s*$' | tail -15 >&2
  git push -q origin --delete "$run_branch" 2>/dev/null || true
  exit 1
fi
url="https://claude.ai/code/$session"
cp "$log" "tmp/cloud-reports/launch-$stamp.log"; rm -f "$log"
log_run "$url" "$run_branch"
echo "세션: $url"
[ "$wait_min" -gt 0 ] || { echo "보고는 $run_branch(또는 세션의 claude/... 브랜치)에 올라옵니다. 표지: $token"; trap - EXIT; cleanup; exit 0; }

# 보고 찾기: 일회용 브랜치가 앞으로 나아갔거나 새 claude/... 브랜치가 생겼으면 받아서 표지를 확인한다
echo "보고를 기다리는 중(최대 ${wait_min}분)…"
declare -A seen=()
for _ in $(seq 1 "$wait_min"); do
  while read -r sha ref; do
    [ -n "$sha" ] && [ -z "${seen[$sha]:-}" ] || continue
    seen[$sha]=1
    [ "$sha" = "$commit" ] && continue
    git fetch -q origin "$ref" 2>/dev/null || continue
    rep=$(mktemp /tmp/cloud-test-report.XXXXXX)
    git show "$sha:cloud-report.md" > "$rep" 2>/dev/null || { rm -f "$rep"; continue; }
    if save_report "$rep"; then
      rm -f "$rep"
      git push -q origin --delete "${ref#refs/heads/}" 2>/dev/null || true
      [ "$ref" = "refs/heads/$run_branch" ] || git push -q origin --delete "$run_branch" 2>/dev/null || true
      exit 0
    fi
    rm -f "$rep"
  done < <(git ls-remote origin "refs/heads/$run_branch" 'refs/heads/claude/*')
  sleep 60
done
echo "${wait_min}분 안에 보고가 올라오지 않았습니다. 세션에서 직접 확인하세요: $url" >&2
echo "(세션에 git 원격이 없다고 나오면 Claude GitHub 앱이 이 저장소에 설치되지 않아 CLI 가 저장소를 묶음으로 올린 것입니다 — docs/CLOUD_TESTS.md)" >&2
git push -q origin --delete "$run_branch" 2>/dev/null || true
exit 2
