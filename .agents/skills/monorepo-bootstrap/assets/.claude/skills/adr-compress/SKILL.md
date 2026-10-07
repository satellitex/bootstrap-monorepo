---
name: adr-compress
description: docs/adr/ の肥大化や、マージ済みなのに Proposed のまま残った ADR に気づいた場合、または routine の定期実行時に使う。Status 追従・INDEX 再構築・stub 化・大型本文の要約を 1 PR にまとめる。新規 ADR の起票は /create-adr、ハーネス文書の整理は /gc-scan の担当
---

# /adr-compress

正本は `docs/harness/skills/adr-compress.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/` 配下 profile を参照する（存在する場合のみ）。

実行基盤の注記（Claude Code）: adr-compactor は Agent tool の `subagent_type: adr-compactor` で起動する。
