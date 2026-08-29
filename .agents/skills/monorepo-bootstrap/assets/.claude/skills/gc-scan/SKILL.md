---
name: gc-scan
description: ハーネス文書全体（.claude/agents・.claude/skills・docs/harness/skills）を gc-agent でスキャンし、サイズ超過・Cross-File 重複・孤児/デッド参照の削除修正案をすべて 1 PR にまとめて提案する
---

# /gc-scan

正本は `docs/harness/skills/gc-scan.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/` 配下 profile を参照する（存在する場合のみ）。
