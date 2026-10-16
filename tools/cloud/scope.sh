# 바뀐 파일로 시험 범위를 고른다(tools/cloud/test.sh 가 source 한다, docs/CLOUD_TESTS.md 「나눠 맡는 일」).
#   sim    전투·성장 규칙과 정의 데이터, 시뮬레이션 → 클라우드(tools/cloud/test.sh, M2 부터)
#   local  그 밖의 코드·장면·그림·도구 → 이 기기(규칙 시험·웹 빌드·캡처)
# 시뮬레이션은 노드 없는 규칙 코드(src/core/)와 정의 데이터(data/)만 읽는다(02 문서 §4).

# scope_of <경로> → 그 파일이 건드리는 범위(공백으로 나눔, 없으면 빈 줄). 표에 없는 파일은 local(이 기기)
scope_of() {
  case "$1" in
    *.uid|*.import|docs/*|*.md|.gitignore|.gitattributes|tools/cloud/*) echo "" ;;
    src/core/*|src/data/*|data/*|tests/sim/*) echo "sim local" ;;
    *) echo "local" ;;
  esac
}

# changed_files <기준 ref> → 기준과 갈라진 곳부터 HEAD 까지 바뀐 파일
changed_files() {
  local base
  base=$(git merge-base "$1" HEAD) || return 1
  git diff --name-only "$base" HEAD
}
