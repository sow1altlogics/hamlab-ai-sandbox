#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../.."; . "$HERE/lib.sh"
. "$ROOT/ops/ai/lib_pre_merge.sh"
echo "== pre_merge の判定ロジック（CI の期待チェック・複数ページのコメント選択）"
EXP="tests gitleaks base-freshness cherry-pick-check no-unexpected-bot-push"
run() { local id="$1" name="$2" st="$3" cc="$4"; printf '{"id":%s,"name":"%s","status":"%s","conclusion":%s}' "$id" "$name" "$st" "$cc"; }
all_ok() { printf '['; local i=1; for n in $EXP; do [ $i -gt 1 ] && printf ','; run $i "$n" completed '"success"'; i=$((i+1)); done; printf ']'; }
v() { ci_verdict $EXP | head -1 || true; }
chk() { local want="$1" name="$2" got="$3"; [ "$got" = "$want" ] && ok "$name → $got" || ng "$name (期待=$want 実際=$got)"; }

chk OK "5つすべて成功" "$(all_ok | v)"
# 新しい指摘: 期待するチェックが欠けていても、無関係なチェックが成功しているだけで通してはいけない
chk NG "期待するチェックが1つ欠けている(無関係なチェックは成功)" "$( (printf '['; run 1 tests completed '"success"'; printf ','; run 2 gitleaks completed '"success"'; printf ','; run 3 other-check completed '"success"'; printf ']') | v)"
chk NG "チェックが1つも無い" "$(echo '[]' | v)"
chk NG "失敗しているチェックがある" "$( (printf '['; i=1; for n in $EXP; do [ $i -gt 1 ] && printf ','; if [ "$n" = gitleaks ]; then run $i "$n" completed '"failure"'; else run $i "$n" completed '"success"'; fi; i=$((i+1)); done; printf ']') | v)"
chk NG "実行中のチェックがある" "$( (printf '['; i=1; for n in $EXP; do [ $i -gt 1 ] && printf ','; if [ "$n" = tests ]; then run $i "$n" in_progress null; else run $i "$n" completed '"success"'; fi; i=$((i+1)); done; printf ']') | v)"
# 再実行: 同名の古い失敗 + 新しい成功 → 最新を見るので OK / 古い成功 + 新しい失敗 → NG
chk OK "再実行で最新が成功(古い失敗があっても)" "$( (printf '['; run 1 tests completed '"failure"'; printf ','; run 9 tests completed '"success"'; for n in gitleaks base-freshness cherry-pick-check no-unexpected-bot-push; do printf ','; run 2 "$n" completed '"success"'; done; printf ']') | v)"
chk NG "最新が失敗(古い成功があっても)" "$( (printf '['; run 1 tests completed '"success"'; printf ','; run 9 tests completed '"failure"'; for n in gitleaks base-freshness cherry-pick-check no-unexpected-bot-push; do printf ','; run 2 "$n" completed '"success"'; done; printf ']') | v)"
chk NG "壊れた入力" "$(echo 'not json' | v)"

# 指摘: 複数ページのコメントから、古い完了済みの状態ではなく「最新」を選ぶ
mkc() { printf '{"created_at":"%s","user":{"login":"%s"},"body":"<!-- codex-review-state:v1 {\\"code_review\\":{\\"commit_sha\\":\\"%s\\",\\"has_any_findings\\":false,\\"has_unresolved_findings\\":false,\\"status\\":\\"%s\\"}} -->"}' "$1" "$2" "$3" "$4"; }
PAGE1="[$(mkc 2026-10-22T01:00:00Z chatgpt-codex-connector[bot] aaaaaaa completed)]"
PAGE2="[$(mkc 2026-10-22T09:00:00Z chatgpt-codex-connector[bot] bbbbbbb running),$(mkc 2026-10-22T10:00:00Z someone-else ccccccc completed)]"
got="$(printf '%s\n%s\n' "$PAGE1" "$PAGE2" | latest_codex_body | sed -n 's/.*commit_sha\\*":\\*"\([a-z0-9]*\).*/\1/p' | head -1)"
chk bbbbbbb "2ページ: 古い完了(1ページ目)ではなく最新(2ページ目)の Codex の状態を選ぶ(他人のコメントは無視)" "$got"
got="$(printf '%s\n' "[]" | latest_codex_body)"; chk "" "コメントが無い→空" "$got"
finish
