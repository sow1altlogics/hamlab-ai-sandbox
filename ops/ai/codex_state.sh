#!/bin/bash
# Codex の「サマリーコメント」に埋め込まれた機械可読の状態から、レビューが完了したかを判定する。
# 時間が経ったからではなく、GitHub 上の記録（status / commit_sha / 未解決の指摘）だけで判断する。
#
# 使い方: codex_state.sh verdict <PRの先端SHA>   （標準入力にサマリーコメントの本文）
# 出力:  1行目=判定  2行目以降=理由
#   COMPLETED_CLEAN     … 完了・現在のコミットに対するレビュー・未解決の指摘なし（これだけが「通過」）
#   COMPLETED_FINDINGS  … 完了したが未解決の指摘がある
#   NOT_COMPLETED       … 実行中など、完了していない
#   STALE_COMMIT        … 完了しているが、別のコミットに対するレビュー（新しい push 後に未再レビュー）
#   NO_STATE            … 状態が見つからない/読めない（レビュー未実施として扱う）
# 終了コード: COMPLETED_CLEAN=0 / それ以外=1
set -euo pipefail
cmd="${1:?verdict}"; HEAD_SHA="${2:?先端SHA}"
[ "$cmd" = "verdict" ] || { echo "使い方: $0 verdict <SHA>"; exit 2; }
body="$(cat)"
json="$(printf '%s\n' "$body" | sed -n 's/.*<!-- codex-review-state:v1 \(.*\) -->.*/\1/p' | head -1)"
if [ -z "$json" ] || ! printf '%s' "$json" | jq -e '.code_review' >/dev/null 2>&1; then
  echo "NO_STATE"; echo "Codex の状態を読み取れません（レビュー未実施として扱う）"; exit 1
fi
status="$(printf '%s' "$json" | jq -r '.code_review.status // "none"')"
sha="$(printf '%s' "$json" | jq -r '.code_review.commit_sha // ""')"
# 注意: jq の // は false も「値なし」扱いにするので使わない（false は「未解決なし」という有効な値）
unresolved="$(printf '%s' "$json" | jq -r 'if .code_review.has_unresolved_findings == null then "unknown" else (.code_review.has_unresolved_findings | tostring) end')"
if [ "$status" != "completed" ]; then echo "NOT_COMPLETED"; echo "status=${status}"; exit 1; fi
if [ "$sha" != "$HEAD_SHA" ]; then echo "STALE_COMMIT"; echo "レビュー済み=${sha:0:7} / 現在の先端=${HEAD_SHA:0:7}"; exit 1; fi
if [ "$unresolved" = "true" ]; then echo "COMPLETED_FINDINGS"; echo "未解決の指摘あり"; exit 1; fi
if [ "$unresolved" != "false" ]; then echo "NO_STATE"; echo "未解決の指摘の有無が読み取れません(${unresolved})"; exit 1; fi
echo "COMPLETED_CLEAN"; echo "完了・現在のコミットに対するレビュー・未解決の指摘なし"; exit 0
