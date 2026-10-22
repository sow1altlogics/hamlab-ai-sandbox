#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../.."; . "$HERE/lib.sh"
SCRIPT="$ROOT/ops/ci/is_sync_pr.sh"
export BASE_REF=base INT_REF=integration
echo "== is_sync_pr / check_cherry_pick"

# 準備: main から base と integration を作る。base は「本番の更新」、integration は「AI の未配布変更」を持つ
new_repo
git branch base; git branch integration
git switch -q base; echo "prod" > prod.txt; git add -A; git commit -q -m "本番の更新"
git switch -q integration; echo "ai" > ai.txt; git add -A; git commit -q -m "AI の未配布変更"

# --- 純粋な sync: integration に base を merge しただけ
git switch -q -c sync-pure integration; git merge -q --no-ff -m "sync" base; PURE="$(git rev-parse HEAD)"
expect_rc 0 "純粋な sync(同一リポジトリ)→免除" -- bash "$SCRIPT" "$PURE" '[]' true
expect_rc 1 "同じ内容でもフォークの PR→免除しない" -- bash "$SCRIPT" "$PURE" '[]' false

# --- 指摘2: ブランチ名を ai/sync-* にしただけの通常の変更は免除しない
git switch -q -c ai/sync-spoof integration; echo "不正" > evil.txt; git add -A; git commit -q -m "通常の変更(名前だけ sync)"; SPOOF="$(git rev-parse HEAD)"
expect_rc 1 "ブランチ名 ai/sync-* の通常の変更→免除しない(なりすまし)" -- bash "$SCRIPT" "$SPOOF" '[]' true

# --- merge に余計な変更を紛れ込ませた(evil merge)
git switch -q -c sync-evil integration; git merge -q --no-ff --no-commit base; echo "紛れ込み" > sneaky.txt; git add -A; git commit -q -m "sync に見せかけた変更"; EVIL="$(git rev-parse HEAD)"
expect_rc 1 "merge に余計な変更が混ざっている→免除しない" -- bash "$SCRIPT" "$EVIL" '[]' true

# --- ラベルの扱い
expect_rc 1 "別のラベル(sync-approved-x)では免除しない" -- bash "$SCRIPT" "$SPOOF" '["sync-approved-x"]' false
git switch -q -c sync-labeled integration; echo "手で解消した内容" > resolved.txt; git add -A; git commit -q -m "手で解消した sync"; LAB="$(git rev-parse HEAD)"
expect_rc 0 "sync-approved(完全一致・同一リポジトリ)→免除" -- bash "$SCRIPT" "$LAB" '["sync-approved"]' true
expect_rc 1 "sync-approved でもフォークなら免除しない" -- bash "$SCRIPT" "$LAB" '["sync-approved"]' false
expect_rc 1 "壊れたラベル JSON は免除しない" -- bash "$SCRIPT" "$SPOOF" 'JSONではない' true

# --- コンフリクトする場合(同じファイルを両方で変更)は、ラベルなしでは免除しない
new_repo; git branch base; git branch integration
git switch -q base; echo "base 側" > same.txt; git add -A; git commit -q -m "base"
git switch -q integration; echo "integration 側" > same.txt; git add -A; git commit -q -m "integration"
git switch -q -c sync-conf integration; git merge -q --no-commit base 2>/dev/null || true; echo "解消" > same.txt; git add -A; git commit -q -m "コンフリクトを解消した sync"; CONF="$(git rev-parse HEAD)"
expect_rc 1 "コンフリクトを手で解消した sync はラベルなしだと免除しない" -- bash "$SCRIPT" "$CONF" '[]' true
expect_rc 0 "同じ sync に sync-approved を付ければ免除" -- bash "$SCRIPT" "$CONF" '["sync-approved"]' true

# --- check_cherry_pick: 本番基準に当たる変更 / 当たらない変更
CP="$ROOT/ops/ci/check_cherry_pick.sh"
new_repo; git branch base; git branch integration
git switch -q integration; echo "v1" > dep.txt; git add -A; git commit -q -m "integration だけにある変更"
git switch -q -c feat-ok integration; echo "x" > other.txt; git add -A; git commit -q -m "独立した変更"; OKH="$(git rev-parse HEAD)"
git switch -q integration; git switch -q -c feat-dep integration; echo "v2" > dep.txt; git add -A; git commit -q -m "未配布の dep.txt に依存"; DEP="$(git rev-parse HEAD)"
expect_rc 0 "独立した変更は本番基準に当たる" -- bash "$CP" "$OKH"
expect_rc 1 "未配布の変更に依存する変更は当たらない" -- bash "$CP" "$DEP"
finish
