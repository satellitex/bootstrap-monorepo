---
name: public-arch-sync
description: docs/product/ARCHITECTURE.md が変わった場合、または routine の定期実行時に使う。射影ルールを適用して PUBLIC_ARCHITECTURE.md への未反映変更とサービス名のリークを検出し、公開版だけを更新する PR にまとめる。docs と実コードの鮮度は /docs-sync の担当
---

# /public-arch-sync

正本は `docs/harness/skills/public-arch-sync.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/` 配下 profile を参照する（存在する場合のみ）。
