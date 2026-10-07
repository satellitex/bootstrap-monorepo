---
name: refactor-sync
description: 規約違反と、効いていない・非推奨・冗長なコードを観点ごとの Issue にしたい場合、または routine の定期実行時に使う。refactorer エージェントを起動し、コード量を減らす観点を含めて最大 3 件を起票する。規約ガイドの追従は /refactor-guide-sync、コメントは /code-sync の担当
---

# /refactor-sync

正本は `docs/harness/skills/refactor-sync.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値（検出コマンド・必読ガイド）は `.claude/agents/references/refactorer-profile.md` を参照する。

実行基盤の注記（Claude Code）: refactorer は Agent tool の `subagent_type: refactorer` で起動する。
