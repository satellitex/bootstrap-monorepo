---
name: multi-issue
description: 新機能・仕様変更・ハーネス整備など複数ファイルにまたがる実装 Issue（複数・単一とも可。バグ修正・リファクタ・小規模変更は対象外）を実装する場合に使う。Planner–Worker のエージェントスウォームで worktree 隔離の TDD 実装を並列に行い、Issue ごとに 1 本の PR を作成する。Issue の起票は /create-issue、PR の LGTM までの反復対応は /review-cycle の担当
---

# /multi-issue

正本は `docs/harness/skills/multi-issue.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/` 配下 profile を参照する（存在する場合のみ）。

実行基盤の注記（Claude Code）: worker と Reviewer は subagent として起動し、Architecture Sync は Agent tool の `subagent_type: architecture-sync` で起動する。モデル指定と起動パラメータは `references/model-profile.md` に置く。
