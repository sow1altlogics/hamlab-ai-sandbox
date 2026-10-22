#!/bin/bash
# CI 用スクリプトの単体テストの共通部品。テストごとに使い捨ての git リポジトリを作る。
FAILED=0
ok()   { echo "  ok  $1"; }
ng()   { echo "  NG  $1"; FAILED=$((FAILED+1)); }
# expect_rc <期待する終了コード> <説明> -- <コマンド...>
expect_rc() {
  local want="$1" name="$2"; shift 3
  local out rc
  set +e; out="$("$@" 2>&1)"; rc=$?; set -e
  if [ "$rc" = "$want" ]; then ok "$name"; else ng "$name (期待=${want} 実際=${rc})"; echo "$out" | sed 's/^/      /' | head -5; fi
}
new_repo() {  # 使い捨てリポジトリを作って cd する
  TMP="$(mktemp -d)"; cd "$TMP"
  git init -q -b main .; git config user.name "tester"; git config user.email "tester@example.invalid"
  echo a > a.txt; git add -A; git commit -q -m "初期"
}
finish() { [ "$FAILED" -eq 0 ] && echo "PASSED" || { echo "${FAILED} FAILED"; exit 1; }; }
