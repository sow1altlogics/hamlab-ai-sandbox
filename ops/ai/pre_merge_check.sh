#!/bin/bash
# マージ直前に、その時点の状態を再確認する（人間が実行。このスクリプトはマージしない）。
# 使い方: ops/ai/pre_merge_check.sh <PR番号>      終了コード: 0=すべて OK / 1=NG あり
#  確認する項目:
#   1) CI のチェックがすべて成功している（実行中・失敗・未実行は NG）
#   2) Codex のレビューが「完了」し、現在のコミットに対するもので、未解決の指摘がない（時間の経過では判断しない）
#   3) ai/integration が ai/base（本番基準）を取り込み済みか（その時点の状態で再評価）
#   4) bot のコミットが含まれていない
set -uo pipefail
PR="${1:?PR番号}"; DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib_pre_merge.sh"
REPO="${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
NG=0; line() { printf '%-4s %s\n' "$1" "$2"; [ "$1" = "NG" ] && NG=1; }

info="$(gh api "repos/${REPO}/pulls/${PR}")"
HEAD_SHA="$(printf '%s' "$info" | jq -r .head.sha)"; BASE_BR="$(printf '%s' "$info" | jq -r .base.ref)"
LABELS="$(printf '%s' "$info" | jq -c '[.labels[].name]')"
echo "PR#${PR}  先端=${HEAD_SHA:0:7}  ベース=${BASE_BR}"
git fetch -q origin 2>/dev/null || line NG "git fetch に失敗（最新の状態を確認できない）"

# 1) CI（期待する5つのチェックがすべて存在し、最新の実行が成功していること）
runs="$(gh api "repos/${REPO}/commits/${HEAD_SHA}/check-runs" --paginate | jq -s '[.[].check_runs[]]')"
ci="$(printf '%s' "$runs" | ci_verdict || true)"
if [ "$(printf '%s\n' "$ci" | head -1)" = "OK" ]; then line OK "CI: $(printf '%s\n' "$ci" | sed -n 2p)"; else line NG "CI: $(printf '%s\n' "$ci" | sed -n 2p)"; fi

# 2) Codex（完了の確認。elapsed time では判断しない）
body="$(gh api "repos/${REPO}/issues/${PR}/comments" --paginate | latest_codex_body)"
verdict="$(printf '%s' "$body" | bash "$DIR/codex_state.sh" verdict "$HEAD_SHA" || true)"
v1="$(printf '%s\n' "$verdict" | head -1)"; v2="$(printf '%s\n' "$verdict" | sed -n 2p)"
if [ "$v1" = "COMPLETED_CLEAN" ]; then line OK "Codex: ${v2}"; else line NG "Codex: ${v1} — ${v2}"; fi

# 3) 本番基準の鮮度（その時点の状態）
if BASE_REF=origin/ai/base INT_REF="origin/${BASE_BR}" bash "$DIR/../ci/check_base_freshness.sh" "$HEAD_SHA" >/dev/null 2>&1; then line OK "鮮度: ai/base を取り込み済み"; else line NG "鮮度: ai/integration が ai/base より古い（先に sync PR）"; fi

# 4) bot のコミット
basesha="$(printf '%s' "$info" | jq -r .base.sha)"
if bash "$DIR/../ci/check_bot_commits.sh" "$basesha" "$HEAD_SHA" "$LABELS" >/dev/null 2>&1; then line OK "bot のコミットなし"; else line NG "bot のコミットあり（または検査に失敗）"; fi

[ "$NG" -eq 0 ] && echo "=> すべて OK（マージの判断は人間が行う）" || echo "=> NG あり。マージしないでください"
exit "$NG"
