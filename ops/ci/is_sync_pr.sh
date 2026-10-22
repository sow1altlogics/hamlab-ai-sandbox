#!/bin/bash
# この PR が「ai/base を ai/integration に取り込むだけの sync PR」かを、中身で判定する。
# ブランチ名では判定しない（名前は誰でも付けられるため）。
# 使い方: is_sync_pr.sh <PRの先端SHA> '<ラベル名のJSON配列>' <同一リポジトリか: true|false>
# 終了コード: 0=sync PR として免除してよい / 1=免除しない（通常のチェックを受ける）
# 環境変数: BASE_REF(既定 origin/ai/base) / INT_REF(既定 origin/ai/integration)
set -euo pipefail
HEAD_SHA="${1:?先端SHA}"; LABELS="${2:-[]}"; SAME_REPO="${3:-false}"
BASE_REF="${BASE_REF:-origin/ai/base}"; INT_REF="${INT_REF:-origin/ai/integration}"

# フォークからの PR は免除しない
if [ "$SAME_REPO" != "true" ]; then echo "免除しない: 同一リポジトリの PR ではない"; exit 1; fi

# 1) 人間が sync-approved ラベルを付けた PR（コンフリクトを手で解消した sync など）。
#    ラベルを付けられるのは書き込み権限のある人だけ。完全一致のみ。
if printf '%s' "$LABELS" | jq -e 'index("sync-approved") != null' >/dev/null 2>&1; then
  echo "免除: sync-approved ラベルあり（人間が承認した sync PR）"; exit 0
fi

# 2) 構造で判定: 先端が2親の merge コミットで、その内容が
#    「ai/integration と ai/base を merge しただけ」の結果と完全に一致すること。
nparents="$(git rev-list --parents -n 1 "$HEAD_SHA" | wc -w | tr -d ' ')"   # 自分自身 + 親の数
if [ "$nparents" -ne 3 ]; then echo "免除しない: 先端が merge コミット(2親)ではない"; exit 1; fi

if ! trial="$(git merge-tree --write-tree "$INT_REF" "$BASE_REF" 2>/dev/null)"; then
  echo "免除しない: ai/integration と ai/base の merge にコンフリクトがある（解消した sync には sync-approved が必要）"; exit 1
fi
if [ "$(git rev-parse "${HEAD_SHA}^{tree}")" = "$trial" ]; then
  echo "免除: ai/base を取り込んだだけの merge（内容が一致）"; exit 0
fi
echo "免除しない: merge の内容が、純粋な merge の結果と違う（余計な変更が含まれている）"; exit 1
