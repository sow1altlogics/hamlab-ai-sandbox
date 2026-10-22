# sandbox 検証記録（2026-10-22）

目的: 無料プランの GitHub で、ドナ(実装)・ジョージ(Codex レビュー)の一方向連携が成り立つかを、ダミーコードで確かめる。
前提: GitHub Pro は使わない。公開リポジトリは Ruleset が無料で使えるため、保護設定の挙動はここで確認する（非公開の無料リポジトリでは使えない）。

## 結果（実施済み）
| # | 内容 | 結果 |
|---|---|---|
| T4a | 管理者(所有者)が `ai/integration` へ直接 push | **拒否**（GH013: PR 経由が必須）。バイパス一覧が空なら管理者にも適用される |
| T4b | force push | **拒否** |
| T4c | ブランチ削除 | **拒否** |
| T6a | 自分の PR を承認 | **不可**（"Can not approve your own pull request"） |
| T6b | 承認1名必須のとき、承認なしでマージ／`--admin` でマージ | **どちらも拒否**。1アカウントだと誰もマージできない＝承認人数は 0 にするしかない |
| T6c | 承認人数 0 に変更後、通常マージ | **成功**（管理者権限は使っていない） |
| T7a | `ops/ai/sync.sh --go` で `ai/base` を本番相当コミットへ同期 | 成功。リモート検証済み。親は旧 base と配布コミットの2つ。内容は配布コミットと一致。タグ `prod/<日付>-<短縮>` が付く |
| T7b | 同期 PR で `ai/integration` へ取り込み（未配布の AI 変更あり） | **衝突なし**。本番側の変更が入り、未配布の変更も残った。`ai/base` が `ai/integration` の祖先になった |
| T7c | 同期の途中で別の担当者が `ai/base` を更新（競合） | push が**サーバー側で拒否**（ref が期待値と違う）。手元の `ai/base` は変更されず、タグも push されず、再実行も拒否 |

## 未実施（ユーザーの操作待ち）
- T1/T2/T3/T8: Codex の接続（GitHub App のインストールは本人の操作が必要）
- CI（tests / gitleaks / base-freshness / cherry-pick-check / no-unexpected-bot-push）の実行確認:
  ワークフローの push には gh トークンの `workflow` スコープが必要。一時的に付与し、検証後に外す。


## CI の検証（ブートストラップ PR #3、2026-10-22）
| チェック | 結果 | 備考 |
|---|---|---|
| tests | 成功 | PHP 8.4 で構文チェックとテストが通る |
| gitleaks | 成功 | PR のコミット範囲を検査（バージョン固定・チェックサム検証でインストール） |
| cherry-pick-check | 成功 | PR の差分が、本番基準(ai/base)にそのまま当てられる |
| no-unexpected-bot-push | 成功 | bot のコミットなし |
| base-freshness | **最初は失敗 → sync PR で解消 → 再実行で成功** | T7c の割り込み更新が `ai/base` に残り、`ai/integration` が遅れていたのを正しく検出した（意図した動作） |

### 分かったこと
- ワークフローは、その PR のブランチにあるものが動く。**ブートストラップ PR をマージするまで、`ai/integration` にはワークフローが無い**ので、先にマージした sync PR にはチェックが付かなかった。必須チェックは、ブートストラップ PR のマージ後に Ruleset へ追加する。
- ワークフローの push には、Fine-grained PAT の「Workflows: Read and write」が必要だった（Contents だけでは通らない、と実際に確認はしていない。付けて push が通った）。PAT は sandbox の1リポジトリだけ・7日で期限切れ・検証後に失効する。


## Codex（ChatGPT Codex Connector）の検証（2026-10-22）
bot のアカウント名: `chatgpt-codex-connector[bot]`

| # | 内容 | 結果 |
|---|---|---|
| T1a | PR #3 に `@codex review`（手動） | 約15秒で 👀、サマリーコメントは14秒後。**レビュー完了まで約3分51秒**。P1 の指摘が4件付いた |
| T1b | `ai/integration` 宛ての新規 PR（#5, #6）の**自動**レビュー | **約10分たっても起動しなかった**（反応なし） |
| 切り分け | `main` 宛ての PR（#7）／通常の OAuth 認証で作った PR（#8）／ドラフト→レビュー可の切り替え（#7） | **いずれも自動では起動しなかった**。ベース・作成方法・イベントの違いでは説明できない。Codex 側の「自動レビュー」の設定が効いていない可能性が高い（設定画面の確認が必要） |
| T2 | 意図的な欠陥（承認トークン未設定のとき許可する fail-open）を含む PR #6 に `@codex review`（手動） | **約55秒で P1 を指摘**。「`null` のとき `ok: true` を返すのは不可。fail-closed に戻す」と、AGENTS.md の該当行を引用 |
| T2' | 問題のない PR #5 に `@codex review`（手動） | 8分以上「実行中」のまま（👀）。結果は後で追記する |
| T3 | AGENTS.md の見出し | `## Review guidelines` の内容は効いている（指摘が AGENTS.md の L3-L5 を引用）。`## Code Review Rules` 側のみに書いた規則は未検証 |
| T8 | 権限・アカウント名 | アカウント名は上記。権限一覧は、インストール画面でユーザーが確認（スクリーンショット未提供）。レビュー中に Codex が push したコミットは無し |

### PR #3 への Codex の指摘（P1 が4件、いずれも妥当）
1. `base-freshness`: `ai/base` が更新されても再評価されず、古い合格が残る
2. `cherry-pick-check`: ブランチ名 `ai/sync-*` だけで免除しており、なりすませる（フォークの PR など）
3. `no-unexpected-bot-push`: `git log` の失敗が `|| true` に飲み込まれ、失敗しても「OK」になる
4. `no-unexpected-bot-push`: ラベルの部分一致で、`allow-bot-push` を含む別のラベルでも通ってしまう

※ 指摘が自分のワークフローの実際の欠陥だった。Codex のレビューは、少なくともこの種の fail-open の見落としに有効だった。ただし検出を保証するものではない。

## 設定（再現手順）
1. 公開リポジトリを作成（ダミーのみ）。`main` を既定、`ai/base` と `ai/integration` を同じ位置に作る。
2. Ruleset `ai-integration`（`docs/rulesets/ai-integration.json`）: 削除禁止・force push 禁止・PR 必須（承認 0・会話の解決必須）・バイパスなし。
   `gh api -X POST repos/<owner>/<repo>/rulesets --input docs/rulesets/ai-integration.json`
3. `.github/workflows/` の5つ。必須チェックは、ワークフローが一度走ってから Ruleset に追加する。

## 限界（正直に）
- `ops/ai/sync.sh` は「正規の更新手段」であって、他の push を防ぐ仕組みではない。無料の非公開リポジトリでは他の push を禁止できない。
- Codex が重大な問題を必ず見つける保証はない。T2 は「指摘されるかを観察する」項目で、指摘されなくても連携の失敗とは判断しない。
