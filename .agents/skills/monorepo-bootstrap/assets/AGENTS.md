# AGENTS.md

この文書は {{PRODUCT_NAME}} リポジトリにおける Codex 入口の薄い adapter である。運用の詳細はここに書かない。

- リポジトリ概要・docs 正本 pointer・エージェントフロー・skill 一覧・ブランチ / commit 規約 → `docs/harness/OPERATING_MODEL.md`
- 各 session では必ず最新の `origin/main` から作業ブランチを切り、変更を伴う作業は Pull Request として提出する。
- 承認モデル（要旨）: 既定は open PR 提出までの自律実行。人間の明示承認が必須なのは課金が発生する操作と秘密値の挿入・変更のみ。
- 言語ポリシー: 会話・docs・Issue / PR・レポートの既定言語と原文保持の例外は `docs/harness/OPERATING_MODEL.md`「言語ポリシー」節に従う。
- secret / token / credential は commit しない。
