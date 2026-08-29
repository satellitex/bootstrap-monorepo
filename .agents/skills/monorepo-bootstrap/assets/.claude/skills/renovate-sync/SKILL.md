---
name: renovate-sync
description: Renovate が依存 pin 箇所を漏れなく検知できているか・cross-manager dual-pin が同一 PR に束ねられているかを 3 検査で検証し、renovate.json の改善 PR を作成する。open Renovate PR の LGTM ラベルを毎回の検査結果に同期する（opt-in:renovate）
---

# /renovate-sync

正本は `docs/harness/skills/renovate-sync.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/` 配下 profile を参照する（存在する場合のみ）。
