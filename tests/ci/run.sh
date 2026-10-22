#!/bin/bash
# CI 用スクリプトの単体テストをすべて実行する。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; rc=0
for t in "$HERE"/test_*.sh; do bash "$t" || rc=1; done
[ "$rc" -eq 0 ] && echo "=== CI スクリプトのテスト: すべて成功 ===" || echo "=== CI スクリプトのテスト: 失敗あり ==="
exit "$rc"
