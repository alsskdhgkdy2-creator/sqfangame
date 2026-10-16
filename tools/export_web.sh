#!/usr/bin/env bash
# 웹 빌드: build/web/ 에 내보낸다. 사용: tools/export_web.sh [release|debug]
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-release}"
GODOT="${GODOT:-godot}"
export GODOT_SILENCE_ROOT_WARNING=1
mkdir -p build/web
touch build/.gdignore  # 빌드 산출물(아이콘·캡처 PNG)을 Godot 가 가져오지 않게
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless --export-"$mode" "Web" build/web/index.html
ls -la build/web
