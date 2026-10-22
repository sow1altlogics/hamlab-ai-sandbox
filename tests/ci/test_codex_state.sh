#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../.."; . "$HERE/lib.sh"
SCRIPT="$ROOT/ops/ai/codex_state.sh"
echo "== codex_state（レビュー完了の判定。時間の経過では判断しない）"
HEAD="1111111111111111111111111111111111111111"; OTHER="2222222222222222222222222222222222222222"
# Codex が実際に付けるサマリーコメントと同じ形式（機械可読の状態を HTML コメントに埋め込む）
mk() { printf '<!-- codex-pull-request-review-summary -->\n<!-- codex-review-state:v1 {"code_review":{"commit_sha":"%s","has_any_findings":%s,"has_unresolved_findings":%s,"status":"%s"},"security_review":{"commit_sha":null,"has_any_findings":null,"has_unresolved_findings":null,"status":null}} -->\n\n## Codex Review Summary\n' "$1" "$2" "$3" "$4"; }
verdict() { mk "$@" | bash "$SCRIPT" verdict "$HEAD" | head -1; }
check() { local want="$1" name="$2"; shift 2; local got; got="$(verdict "$@" || true)"; [ "$got" = "$want" ] && ok "$name → $got" || ng "$name (期待=$want 実際=$got)"; }

check COMPLETED_CLEAN    "完了・現在のコミット・指摘なし"            "$HEAD"  false false completed
check COMPLETED_FINDINGS "完了・未解決の指摘あり"                  "$HEAD"  true  true  completed
check COMPLETED_CLEAN    "指摘はあったが全て解決済み"              "$HEAD"  true  false completed
check STALE_COMMIT       "完了しているが別のコミットのレビュー"    "$OTHER" false false completed
check NOT_COMPLETED      "実行中(running)"                          "$HEAD"  null  null  running
check NOT_COMPLETED      "状態が不明な値(failed)でも完了と見なさない" "$HEAD" false false failed
check NOT_COMPLETED      "status が空"                              "$HEAD"  false false ""

# 状態が読めない場合は「完了」にしない(fail-closed)
r="$(printf '👀 レビュー中です' | bash "$SCRIPT" verdict "$HEAD" | head -1 || true)"; [ "$r" = "NO_STATE" ] && ok "状態の記載なし → NO_STATE" || ng "状態の記載なし ($r)"
r="$(printf '<!-- codex-review-state:v1 {壊れたJSON -->' | bash "$SCRIPT" verdict "$HEAD" | head -1 || true)"; [ "$r" = "NO_STATE" ] && ok "壊れた JSON → NO_STATE" || ng "壊れた JSON ($r)"
r="$(printf '' | bash "$SCRIPT" verdict "$HEAD" | head -1 || true)"; [ "$r" = "NO_STATE" ] && ok "空の入力 → NO_STATE" || ng "空の入力 ($r)"
r="$(mk "$HEAD" false null completed | bash "$SCRIPT" verdict "$HEAD" | head -1 || true)"; [ "$r" = "NO_STATE" ] && ok "未解決の指摘の有無が不明(null) → NO_STATE（通さない）" || ng "未解決 null ($r)"

# 終了コードは COMPLETED_CLEAN だけが 0
set +e; mk "$HEAD" false false completed | bash "$SCRIPT" verdict "$HEAD" >/dev/null; a=$?; mk "$HEAD" true true completed | bash "$SCRIPT" verdict "$HEAD" >/dev/null; b=$?; set -e
[ "$a" = 0 ] && [ "$b" = 1 ] && ok "終了コード: CLEAN=0 / 指摘あり=1" || ng "終了コード (clean=$a findings=$b)"
finish
