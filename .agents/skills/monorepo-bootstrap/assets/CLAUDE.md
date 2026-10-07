# CLAUDE.md

この文書は {{PRODUCT_NAME}} リポジトリにおける Claude Code 入口の薄い adapter である。運用の詳細はここに書かず、正本を参照する。

## 正本

- リポジトリ概要・docs 正本 pointer・エージェントフロー・skill コマンド一覧・承認モデル・ブランチ / commit 規約 → `docs/harness/OPERATING_MODEL.md`

## rules の読み込まれ方

- `paths:` frontmatter を持たない rule は全セッションで常時ロードされ、`paths:` を持つ rule は該当ファイルの編集時にロードされる
- rule の一覧・スコープ・読む場面の正本は `docs/harness/OPERATING_MODEL.md`「領域別 rule の読み場面」

## skill

- 入口は `.claude/skills/<name>/SKILL.md`（薄い adapter）。手順の正本は `docs/harness/skills/<name>.md`
- プロジェクト固有値は `.claude/skills/<name>/references/` 配下の profile に置く

## 運用（要旨）

- 各 session では必ず最新の `origin/main` から作業ブランチを切り、変更を伴う作業は Pull Request として提出する。
- 承認モデル（要旨）: 既定は open PR 提出までの自律実行。人間の明示承認が必須なのは課金が発生する操作と秘密値の挿入・変更のみ。
- 言語ポリシー: 会話・docs・Issue / PR・レポートの既定言語と原文保持の例外は `docs/harness/OPERATING_MODEL.md`「言語ポリシー」節に従う。
- secret / token / credential は commit しない。
