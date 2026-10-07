---
name: multi-issue
description: 複数（単一も可）の GitHub Issue を実装する場合に使う。Planner–Worker のエージェントスウォームで worktree 隔離の TDD 実装を並列に行い、Issue ごとに 1 本の PR を作成する。Issue の起票は /create-issue、PR の LGTM までの反復対応は /review-cycle の担当
---

# /multi-issue

正本は `docs/harness/skills/multi-issue.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/` 配下 profile を参照する（存在する場合のみ）。

実行基盤の注記（Claude Code）: worker と Reviewer は subagent（バックグラウンド実行）として起動し、worker・Reviewer には実装モデル、Planner と sub-planner には上位モデルを指定する。review skill は subagent の中で実行する。
