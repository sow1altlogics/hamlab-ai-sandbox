#!/bin/bash
# PR のコミットに bot の作者・コミッターが含まれていないかを調べる。
# 使い方: check_bot_commits.sh <基点SHA> <PRの先端SHA> '<ラベル名のJSON配列>'
# 終了コード: 0=問題なし(または許可ラベルあり) / 1=bot のコミットあり / それ以外=検査自体の失敗(fail-closed)
set -euo pipefail
BASE="${1:?基点SHA}"; HEAD="${2:?先端SHA}"; LABELS="${3:-[]}"

# git log の失敗はここで止める（範囲が読めないのに「OK」としないため）
log="$(git log --format='%H %an <%ae> | %cn <%ce>' "${BASE}..${HEAD}")"

# grep は「該当なし」で終了コード 1 を返す。それは正常、2 以上は異常として扱う
set +e
bad="$(printf '%s\n' "$log" | grep -iE '\[bot\]|codex|chatgpt')"
rc=$?
set -e
[ "$rc" -le 1 ] || { echo "::error::grep が異常終了しました (rc=${rc})"; exit 2; }

if [ -z "$bad" ]; then echo "OK: bot のコミットなし"; exit 0; fi

# ラベルは完全一致だけを許可とみなす（部分一致は許さない）
if printf '%s' "$LABELS" | jq -e 'index("allow-bot-push") != null' >/dev/null; then
  echo "bot のコミットあり（allow-bot-push ラベルあり）"; exit 0
fi
echo "::error::bot によるコミットが含まれています（第1段階では想定外）:"; printf '%s\n' "$bad" | cut -c1-120
exit 1
