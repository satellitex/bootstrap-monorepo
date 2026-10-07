---
name: renovate-sync
description: Renovate の依存 pin 検知に漏れがないか確認したい場合、または routine の定期実行時に使う。スコープ漏れ・dual-pin 未束ね・未管理 pin を検出して renovate.json の改善 PR にまとめ、open な Renovate PR の LGTM ラベルを同期する。依存の更新自体は Renovate 本体の担当
---

# /renovate-sync

正本は `docs/harness/skills/renovate-sync.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/` 配下 profile を参照する（存在する場合のみ）。
