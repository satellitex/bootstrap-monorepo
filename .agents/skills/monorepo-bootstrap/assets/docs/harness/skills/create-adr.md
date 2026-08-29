# create-adr — ADR の構造的記録

この文書は `/create-adr` の tool-neutral な正本手順である。ADR の運用ポリシー（命名規約の背景・Status 遷移・INDEX 形式・圧縮運用）は `docs/adr/README.md` が正本であり、ここには手順のみを書く。

## 目的

REJECT/REVISE や設計判断が発生した際に、ADR (Architecture Decision Record) を構造的に記録する。

## 入力

| 項目 | 必須 | 説明 |
|------|------|------|
| 問題の概要 | Yes | 何が問題だったか（人間の入力、レビュー指摘、実装中の設計判断など） |
| 関連 Issue 番号 | No | GitHub Issue `#<N>` |
| 関連要件 | No | `docs/requirements/` 配下の要件 ID への参照 |

引数例: `/create-adr "リトライ方針の変更判断" #<N>`

引数が不足している場合は、起票文脈（レビューコメント・実装中の判断内容）から補完し、補完できない必須項目のみユーザに質問する。

## フロー

### Step 1: ファイル名の決定

パターン: `ADR-{YYYYMMDD}_{branch_name}_{slug}.md`

- `{YYYYMMDD}`: 実行日
- `{branch_name}`: 現在の git ブランチ名（`/` は `-` に置換して正規化する）
- `{slug}`: 問題の概要から英語 kebab-case（簡潔に）で生成

例: `ADR-20260101_agent-example-branch_retry-policy-change.md`

### Step 2: ADR ファイルの生成

`docs/adr/template.md` を Read し、その構造で `docs/adr/<ファイル名>` を生成する（テンプレートの SSOT は template.md。本文書に複製しない）。

- **Status**: `Proposed` で固定（PR マージ時に `Accepted` へ更新）
- **Author**: 起票元に応じて設定（例: `Agent (Review Comment)`, `Human`, `Agent (Planner)`）
- **Context**: 問題の背景・制約・前提条件。関連する要件 ID（SEC-NNNN, FR-NNNN 等）があれば言及
- **Decision**: 選択した方針と根拠
- **Consequences**: Positive（メリット）と Negative（トレードオフ・リスク）の両面で記述
- **Related Issues**: 関連 Issue 番号と要件ドキュメントへのリンク

### Step 3: INDEX.md の更新

`docs/adr/INDEX.md` のテーブルに行を追記する:

```markdown
| ADR-{date}_{branch}_{slug} | タイトル | Proposed | YYYY-MM-DD |
```

初回の場合はプレースホルダ行（`| — | （まだ ADR はありません） | — | — |`）を削除してから追記する。

## 出力

完了後、作成した ADR ファイルのパス、INDEX.md の更新、ADR の概要（タイトル・Status・Related Issues）をユーザに報告する。

## 関連

- `docs/adr/README.md` — ADR 運用の正本（命名・Status 遷移・圧縮）
- `docs/adr/template.md` — 本文テンプレートの SSOT
- `docs/harness/skills/handle-review.md` — レビュー対応時の ADR 記録の呼び出し元
