#!/bin/bash
# ai/base を「本番に配布済みのコミット」に同期する、正規の更新手段（sandbox 版）。
#
# 使い方:  ops/ai/sync.sh --deployed <コミット> [--go]     （--go なしは dry-run）
#
# 【できないこと】GitHub Free の非公開リポジトリでは、このスクリプト以外からの push を
#   技術的に禁止できない。ここにあるのは「期待値の確認」「push 後の検証」「取り違えの検出」で、
#   他の更新手段を防止する仕組みではない。
# 【ローカルの update-ref の期待値指定】はローカルの参照を守るだけ。リモートの競合更新は、
#   リモートの期待値を指定した push と、push 後の ls-remote による検証で守る。
set -euo pipefail

REMOTE="${REMOTE:-origin}"
BASE="ai/base"
DEPLOYED=""; GO=0
while [ $# -gt 0 ]; do
  case "$1" in
    --deployed) DEPLOYED="${2:-}"; shift 2;;
    --go) GO=1; shift;;
    *) echo "不明な引数: $1"; exit 2;;
  esac
done
[ -n "$DEPLOYED" ] || { echo "使い方: $0 --deployed <コミット> [--go]"; exit 2; }
die() { echo "❌ $*" >&2; exit 1; }

P="$(git rev-parse --verify "${DEPLOYED}^{commit}" 2>/dev/null)" || die "配布コミット ${DEPLOYED} がこのリポジトリにありません"

# 1) リモートの現在値を取り直す（古い手元の情報で判断しない）
git fetch -q "$REMOTE" "refs/heads/${BASE}:refs/remotes/${REMOTE}/${BASE}" || die "リモートの ${BASE} を取得できません"
OLD_REMOTE="$(git rev-parse "refs/remotes/${REMOTE}/${BASE}")"
if git rev-parse -q --verify "refs/heads/${BASE}" >/dev/null; then
  OLD_LOCAL="$(git rev-parse "refs/heads/${BASE}")"
  [ "$OLD_LOCAL" = "$OLD_REMOTE" ] || die "手元の ${BASE} (${OLD_LOCAL:0:7}) とリモート (${OLD_REMOTE:0:7}) が違います。原因を確認してください（自動では直しません）"
else
  OLD_LOCAL=""
fi

# 2) すでに本番と同じ内容なら何もしない
if [ "$(git rev-parse "${OLD_REMOTE}^{tree}")" = "$(git rev-parse "${P}^{tree}")" ]; then
  echo "✅ ${BASE} はすでに配布コミット ${P:0:7} と同じ内容です。何もしません。"; exit 0
fi

# 3) 同期コミット: 内容=配布コミット、親=旧 ai/base と 配布コミット
S="$(git commit-tree "${P}^{tree}" -p "$OLD_REMOTE" -p "$P" -m "sync: 本番 ${P:0:7} に ai/base を合わせる" -m "Deployed-Commit: ${P}")"
git diff --quiet "$S" "$P" || die "同期コミットの内容が配布コミットと一致しません"
git merge-base --is-ancestor "$P" "$S" || die "配布コミットが祖先になっていません"
git merge-base --is-ancestor "$OLD_REMOTE" "$S" || die "旧 ${BASE} が祖先になっていません"
TAG="prod/$(date +%Y%m%d)-${P:0:7}"

echo "=== 同期の計画 ==="
echo "  配布コミット : ${P:0:7} $(git log -1 --format=%s "$P" | cut -c1-60)"
echo "  旧 ${BASE}   : ${OLD_REMOTE:0:7}（リモートの期待値）"
echo "  新 ${BASE}   : ${S:0:7}（内容は配布コミットと一致を確認済み）"
echo "  付けるタグ   : ${TAG}"
if [ "$GO" -ne 1 ]; then echo "（dry-run です。実行するには --go）"; exit 0; fi

# 4) リモートの期待値を指定して push → 5) push 後にリモートの値を検証 → 6) 手元の参照を更新
git push --porcelain "$REMOTE" "${S}:refs/heads/${BASE}" --force-with-lease="refs/heads/${BASE}:${OLD_REMOTE}" || die "push に失敗しました（リモートの ${BASE} が期待値と違う可能性）。手元は変更していません"
GOT="$(git ls-remote "$REMOTE" "refs/heads/${BASE}" | cut -f1)"
[ "$GOT" = "$S" ] || die "push 後の検証に失敗: リモートの ${BASE} が ${GOT:0:7}（期待 ${S:0:7}）。他の更新が割り込んだ可能性があります"
if [ -n "$OLD_LOCAL" ]; then git update-ref "refs/heads/${BASE}" "$S" "$OLD_LOCAL"; else git update-ref "refs/heads/${BASE}" "$S"; fi
git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null || git tag "$TAG" "$P"
git push -q "$REMOTE" "refs/tags/${TAG}" || echo "⚠️ タグの push に失敗（${TAG}）。手で push してください"
echo "✅ ${BASE} を ${S:0:7} に更新しました（リモート検証済み）。次: ai/integration に取り込む sync PR（ai/sync-<日付>）を出してください。"
