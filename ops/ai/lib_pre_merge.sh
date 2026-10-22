#!/bin/bash
# pre_merge_check.sh の判定ロジック（gh を呼ばない純粋な関数。単体テストできるように分けてある）。

# 期待するチェック名（環境変数 EXPECTED_CHECKS で上書き可）
EXPECTED_CHECKS_DEFAULT="tests gitleaks base-freshness cherry-pick-check no-unexpected-bot-push"

# ci_verdict <check-runs の JSON 配列(標準入力)> [期待するチェック名...]
#  - 期待するチェックが1つでも欠けていたら NG（無関係なチェックが成功していても通さない）
#  - 同じ名前のチェックが複数ある場合（再実行）は、最新(id が最大)のものだけを見る
#  - 成功(completed/success)以外は NG
# 出力: 1行目=OK|NG、2行目=理由   終了コード: OK=0 / NG=1
ci_verdict() {
  local expected=("$@"); [ "${#expected[@]}" -gt 0 ] || read -ra expected <<< "${EXPECTED_CHECKS:-$EXPECTED_CHECKS_DEFAULT}"
  local runs; runs="$(cat)"
  if ! printf '%s' "$runs" | jq -e 'type=="array"' >/dev/null 2>&1; then echo NG; echo "チェックの一覧を読み取れません"; return 1; fi
  local missing="" bad="" n latest
  for n in "${expected[@]}"; do
    latest="$(printf '%s' "$runs" | jq -c --arg n "$n" '[.[]|select(.name==$n)]|max_by(.id) // empty')"
    if [ -z "$latest" ]; then missing="${missing} ${n}"; continue; fi
    printf '%s' "$latest" | jq -e '.status=="completed" and .conclusion=="success"' >/dev/null || bad="${bad} ${n}=$(printf '%s' "$latest" | jq -r '.status+"/"+(.conclusion // "none")')"
  done
  if [ -n "$missing" ]; then echo NG; echo "期待するチェックが存在しない:${missing}"; return 1; fi
  if [ -n "$bad" ]; then echo NG; echo "成功していないチェック:${bad}"; return 1; fi
  echo OK; echo "期待する ${#expected[@]} 件すべて成功"; return 0
}

# latest_codex_body: ページごとに分かれた JSON 配列の列（gh api --paginate の出力）を標準入力から受け、
# 全ページを結合してから「Codex の最新のサマリーコメント」の本文を返す。
# （ページごとに last を取ると、複数ページのとき古い完了済みの状態を拾ってしまう）
latest_codex_body() {
  jq -s 'add // [] | [ .[] | select(.user.login=="chatgpt-codex-connector[bot]") | select(.body|contains("codex-review-state")) ] | sort_by(.created_at) | last | .body // ""' -r
}
