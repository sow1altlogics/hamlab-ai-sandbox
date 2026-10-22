#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../.."; . "$HERE/lib.sh"
SCRIPT="$ROOT/ops/ci/check_base_freshness.sh"
export BASE_REF=base INT_REF=integration
echo "== check_base_freshness"
new_repo; git branch base; git branch integration
git switch -q -c feat integration; echo f > f.txt; git add -A; git commit -q -m "feat"; FEAT="$(git rev-parse HEAD)"
expect_rc 0 "base が integration と同じ位置→OK" -- bash "$SCRIPT" "$FEAT"

# base が進んだが integration は取り込んでいない（指摘1の状況: 古い合格が残る場面を、その時点の状態で再評価する）
git switch -q base; echo p > p.txt; git add -A; git commit -q -m "本番の更新"
expect_rc 1 "base が進み、integration も PR も取り込んでいない→NG(再評価で検出)" -- bash "$SCRIPT" "$FEAT"

# PR が base を取り込んでいる(sync PR)
git switch -q -c sync integration; git merge -q --no-ff -m sync base; SYNC="$(git rev-parse HEAD)"
expect_rc 0 "PR が base を取り込む(sync PR)→OK" -- bash "$SCRIPT" "$SYNC"

# integration が base を取り込んだ後は、古い PR でも OK（integration 側が最新のため）
git switch -q integration; git merge -q --no-ff -m "sync マージ済み" base
expect_rc 0 "integration が base を取り込み済み→OK" -- bash "$SCRIPT" "$FEAT"
finish
