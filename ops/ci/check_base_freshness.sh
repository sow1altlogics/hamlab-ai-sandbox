#!/bin/bash
# ai/integration が ai/base（本番基準）を取り込み済みか。取り込んでいなければ、先に sync PR が必要。
# 使い方: check_base_freshness.sh <PRの先端SHA>     終了コード: 0=OK / 1=古い
set -euo pipefail
HEAD_SHA="${1:?先端SHA}"
BASE_REF="${BASE_REF:-origin/ai/base}"; INT_REF="${INT_REF:-origin/ai/integration}"
if git merge-base --is-ancestor "$BASE_REF" "$INT_REF"; then echo "OK: ai/integration は ai/base を取り込み済み"; exit 0; fi
if git merge-base --is-ancestor "$BASE_REF" "$HEAD_SHA"; then echo "OK: この PR が ai/base を取り込む（sync PR）"; exit 0; fi
echo "::error::ai/integration が ai/base（本番基準）より古い。先に ai/base を取り込む sync PR を出してください。"; exit 1
