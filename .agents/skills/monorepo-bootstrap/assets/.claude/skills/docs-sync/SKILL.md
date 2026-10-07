---
name: docs-sync
description: docs の現状層やルート直下の運用文書が実コード・設定・要件と食い違っている疑いがある場合、または routine の定期実行時に使う。鮮度ドリフト・実装との内容矛盾・「現状の事実のみ」原則違反を検出して修正 PR にまとめる。README は /readme-sync、ソースコメントは /code-sync、harness 文書の重複は /gc-scan の担当
---

# /docs-sync

正本は `docs/harness/skills/docs-sync.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/` 配下 profile を参照する（存在する場合のみ）。
