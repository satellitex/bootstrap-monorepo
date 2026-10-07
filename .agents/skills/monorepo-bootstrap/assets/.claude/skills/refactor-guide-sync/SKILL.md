---
name: refactor-guide-sync
description: コーディング規約を変更した後に refactoring_guide.md の追従漏れに気づいた場合、または routine の定期実行時に使う。検出基準の観点追加・削除・根拠パス修正・リネーム更新を 1 PR にまとめる。コード自体の課題検出は /refactor-sync の担当
---

# /refactor-guide-sync

正本は `docs/harness/skills/refactor-guide-sync.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/` 配下 profile を参照する（存在する場合のみ）。

実行基盤の注記（Claude Code）: refactor-guide-sync は Agent tool の `subagent_type: refactor-guide-sync` で起動する。
