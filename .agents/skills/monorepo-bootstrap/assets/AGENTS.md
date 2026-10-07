# AGENTS.md

この文書は {{PRODUCT_NAME}} リポジトリにおける Codex 入口の薄い adapter である。運用の詳細はここに書かない。

## 最初に読む正本

- `docs/harness/OPERATING_MODEL.md` — リポジトリ概要・docs 正本 pointer・エージェントフロー・skill 一覧・承認モデル・ブランチ / commit 規約。最初に読む
- `.claude/rules/team-policy.md` — 横断方針。常時読む
- `docs/harness/OPERATING_MODEL.md`「領域別 rule の読み場面」— Codex など `paths:` の自動ロードを持たない実行環境は、作業するスコープに応じて、この表の rule を読む
- `docs/harness/OPERATING_MODEL.md`「ツール固有手段の読み替え」— skill 起動・タスク管理・対話確認・subagent・hooks など、Claude Code 固有の手段の読み替え

## 運用（要旨）

- 各 session では必ず最新の `origin/main` から作業ブランチを切り、変更を伴う作業は Pull Request として提出する。
- 承認モデル（要旨）: 既定は open PR 提出までの自律実行。人間の明示承認が必須なのは課金が発生する操作と秘密値の挿入・変更のみ（→ `docs/harness/OPERATING_MODEL.md`「承認モデル」）。
- 言語ポリシー: 会話・docs・Issue / PR・レポートの既定言語と原文保持の例外は `docs/harness/OPERATING_MODEL.md`「言語ポリシー」節に従う。
- secret / token / credential は commit しない。
