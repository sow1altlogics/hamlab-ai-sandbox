#!/bin/bash
# ai/base の更新後に、ai/integration 宛ての開いている PR の base-freshness を再実行する。
# （PR のイベントが無いと GitHub は再実行しないため、古い「合格」が残るのを防ぐ。ベストエフォート）
set -uo pipefail
command -v gh >/dev/null 2>&1 || { echo "⚠️ gh が無いので再実行できません。開いている PR の base-freshness を手で再実行してください"; exit 0; }
REPO="${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)}"
[ -n "$REPO" ] || { echo "⚠️ リポジトリを特定できません"; exit 0; }
gh pr list -R "$REPO" --base ai/integration --state open --json number,headRefName -q '.[]|"\(.number) \(.headRefName)"' | while read -r n br; do
  [ -n "$n" ] || continue
  id="$(gh run list -R "$REPO" --workflow base-freshness.yml --branch "$br" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null)"
  if [ -n "$id" ] && gh run rerun "$id" -R "$REPO" >/dev/null 2>&1; then echo "再実行: PR#${n} (${br}) run ${id}"
  else echo "⚠️ PR#${n} の base-freshness を再実行できませんでした（実行中、または権限不足。手で再実行してください）"; fi
done
