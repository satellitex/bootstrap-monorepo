---
name: readme-sync
description: README が origin/main の現状コードと食い違っている疑いがある場合、または routine の定期実行時に使う。README 側が古い食い違いだけを更新する PR にまとめ、実装側の疑いは編集せず PR 本文に記録する。README 以外の docs は /docs-sync、ソースコメントは /code-sync の担当
---

# /readme-sync

正本は `docs/harness/skills/readme-sync.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/` 配下 profile を参照する（存在する場合のみ）。
