# Team Feedback Rules

> この文書は team-shared rule（チームメンバー全員と AI agent の双方に適用される運用・実装判断 rule）の一覧である。
> rule の本文は各ファイルに置き、本書には概要行のみを載せる。個人 memory から昇格された rule はここに集約される。
> 機械検証可能な rule は hook / CI で強制され、判断系 rule は本ファイル経由で参照される。`.claude/rules/team-policy.md` から本ディレクトリへの pointer が貼られている。

## 横断方針

| ガイド | 概要 |
|--------|------|
| [長期的自動化を最優先](long-term-automation.md) | 短期的な楽な実装は選択肢から除外し、自動化される案を複数パターン検討する。workaround は限定条件下のみ許容 |
| [自律実行の既定](autonomous-flow.md) | 変更の実装から open PR の提出までは自律実行が既定。人間の明示承認が必須なのは課金と秘密値のみ。main = dev / release = prod |
| [PR レビューコメントは批判的に評価](review-comments.md) | レビューコメントは鵜呑みにせず、ベストプラクティス / 既存スタイル / 技術正確性 / scope の 4 観点で判定する |
| [Issue scope を超える指摘は scope 内で対応しない](scope-boundary.md) | scope 外コメントは既存 Issue 追記 or 新規 Issue 起票で追跡する |
| [PR body に closing keyword を記載](pr-closing-keyword.md) | 起票元 Issue を close する PR は body に `Closes #<num>` を注入。partial PR は `関連: #<親>`、保守 PR は省略 |
| [PR を出す前にリファクタパスを 1 回入れる](refactor-before-pr.md) | green の直後に差分を見直し、振る舞い不変を確認して `refactor:` コミットに分ける |

## 実装フロー

| ガイド | 概要 |
|--------|------|
| （未登録） | 実装フローに関する rule が昇格されたらここに追記する |

## プロダクト設計

| ガイド | 概要 |
|--------|------|
| （未登録） | プロダクト設計に関する rule が昇格されたらここに追記する |

<!-- この分類にはプロジェクト固有のドメイン設計 rule が溜まっていく。追記例:
| [storage-scope-audit.md](storage-scope-audit.md) | ストレージ設計時に scope（レコード単位 / 全体共有）と書き込み頻度を明示して監査する |
| [auth-boundary.md](auth-boundary.md) | 認証境界ごとに適用する要件 ID（SEC-XXXX）の範囲を限定する |
-->

## 機械検証可能 rule（hook / CI で強制）

判断ではなく機械検査で強制できる rule はこの分類に置き、強制機構の実体（hook / CI job / sync skill）を必ず併記する。強制機構のない rule はこの分類に登録しない。

| ガイド | 概要 | 強制機構 |
|--------|------|----------|
| （未登録） | | |

<!-- 追記例（強制機構列には実在する hook / CI job / skill を書く）:
| [format-check.md](format-check.md) | format 違反のままコミット・push しない | `.claude/hooks/pre-format-check.sh` + `pre-push-ci-check.sh` + CI |
| [doc-comment-internal-refs.md](doc-comment-internal-refs.md) | doc-style コメント内に内部参照を書かない | `/code-sync`（内部参照検出） |
-->

## 運用（新規 rule の追加経路）

1. 開発中に個人 memory（`~/.claude/projects/.../memory/`）に feedback を蓄積する
2. team-shared 化すべきと判断したら `/promote-memory <name>` で本ディレクトリに昇格する
3. skill が `<name>.md` 生成、本 INDEX への追記、`.claude/rules/` 配下への pointer 追記、個人 memory の pointer 化、PR 作成までを一括実行する

`/docs-sync` は本ディレクトリを INCLUDE スコープ（`docs/styles/**/*.md`）として scan するため、現状層 3 原則違反・鮮度ドリフトは定期検査で自動検出される。

## 関連

- [コーディングガイド](../coding_guide/INDEX.md) — 言語規約・テスト設計・ドキュメント規約
- `.claude/rules/team-policy.md` — 本ディレクトリへの pointer 集約
- `docs/harness/skills/promote-memory.md` — 個人 memory → team rule 昇格 skill の正本
