#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../.."; . "$HERE/lib.sh"
SCRIPT="$ROOT/ops/ci/check_bot_commits.sh"
echo "== check_bot_commits"
new_repo; BASE="$(git rev-parse HEAD)"

echo b > b.txt; git add -A; git commit -q -m "人間のコミット"; HUMAN="$(git rev-parse HEAD)"
expect_rc 0 "人間だけのコミット→OK" -- bash "$SCRIPT" "$BASE" "$HUMAN" '[]'

# 指摘3: git log が失敗したら「OK」にせず異常終了する（fail-closed）
expect_rc 128 "存在しない範囲(git log が失敗)→異常終了。OK と誤判定しない" -- bash "$SCRIPT" "$BASE" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" '[]'
expect_rc 128 "基点が不正でも同様" -- bash "$SCRIPT" "0000000000000000000000000000000000000000" "$HUMAN" '[]'

# bot のコミット
git -c user.name="chatgpt-codex-connector[bot]" -c user.email="bot@example.invalid" commit -q --allow-empty -m "bot のコミット"; BOT="$(git rev-parse HEAD)"
expect_rc 1 "bot のコミット(許可ラベルなし)→NG" -- bash "$SCRIPT" "$BASE" "$BOT" '[]'
expect_rc 1 "別のラベルだけ→NG" -- bash "$SCRIPT" "$BASE" "$BOT" '["bug","enhancement"]'

# 指摘4: ラベルは完全一致のみ。部分一致の別ラベルでは通さない
expect_rc 1 "do-not-allow-bot-push では通らない" -- bash "$SCRIPT" "$BASE" "$BOT" '["do-not-allow-bot-push"]'
expect_rc 1 "allow-bot-push-disabled では通らない" -- bash "$SCRIPT" "$BASE" "$BOT" '["allow-bot-push-disabled"]'
expect_rc 1 "ALLOW-BOT-PUSH(大文字)では通らない" -- bash "$SCRIPT" "$BASE" "$BOT" '["ALLOW-BOT-PUSH"]'
expect_rc 0 "allow-bot-push(完全一致)なら通る" -- bash "$SCRIPT" "$BASE" "$BOT" '["x","allow-bot-push"]'
expect_rc 1 "ラベルの JSON が壊れていても通さない(許可とみなさず NG)" -- bash "$SCRIPT" "$BASE" "$BOT" 'これはJSONではない'
finish
