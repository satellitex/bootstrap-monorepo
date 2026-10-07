---
name: gc-scan
description: ハーネス文書（agent 定義・skill 正本・adapter）に Cross-File 重複や孤児が溜まっている疑いがある場合、または routine の定期実行時に使う。重複の抽出と孤児の削除案を 1 PR にまとめて提案する。サイズや 1:1 対応は CI の機械検査、docs の鮮度は /docs-sync の担当
---

# /gc-scan

正本は `docs/harness/skills/gc-scan.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/` 配下 profile を参照する（存在する場合のみ）。

実行基盤の注記（Claude Code）: gc-agent は Agent tool の `subagent_type: gc-agent` で起動する。
