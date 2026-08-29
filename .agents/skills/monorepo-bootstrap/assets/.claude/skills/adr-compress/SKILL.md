---
name: adr-compress
description: docs/adr/ の肥大化を adr-compactor エージェントで圧縮し 1 PR にまとめる。INDEX の Status 別再構築・無効化/プロセス記録 ADR の in-place スタブ化・大型本文の要約（同一 issue 統合は opt-in）。routine 定期実行向け
---

# /adr-compress

正本は `docs/harness/skills/adr-compress.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/` 配下 profile を参照する（存在する場合のみ）。
