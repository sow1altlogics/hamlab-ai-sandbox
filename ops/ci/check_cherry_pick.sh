#!/bin/bash
# この PR の変更を、いまの本番基準(ai/base)にそのまま当てられるかを調べる。
# 使い方: check_cherry_pick.sh <PRの先端SHA>      終了コード: 0=当たる / 1=当たらない
set -euo pipefail
HEAD_SHA="${1:?先端SHA}"
BASE_REF="${BASE_REF:-origin/ai/base}"; INT_REF="${INT_REF:-origin/ai/integration}"
patch="$(mktemp)"; trap 'rm -f "$patch"' EXIT
git diff "${INT_REF}...${HEAD_SHA}" -- . ':!.github' ':!AGENTS.md' ':!docs' > "$patch"
if [ ! -s "$patch" ]; then echo "対象の差分なし"; exit 0; fi
tmpwt="$(mktemp -d)"; git worktree add -q --detach "$tmpwt" "$BASE_REF"
trap 'git worktree remove --force "$tmpwt" >/dev/null 2>&1 || true; rm -f "$patch"' EXIT
if (cd "$tmpwt" && git apply --check "$patch"); then echo "OK: 本番基準にそのまま当てられる"; exit 0; fi
echo "NG: この PR の変更は、いまの本番基準(ai/base)に当てられない。未配布の変更に依存していないか確認してください。"; exit 1
