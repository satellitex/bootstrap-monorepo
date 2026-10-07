---
name: review-cycle
description: PR を LGTM まで自律対応させたい場合に使う。判定表に従ってレビュー対応（/handle-review に委譲）・merge conflict の解消・CI 失敗の修正を繰り返し、終了理由を PR author に通知する。単発のコメント対応は /handle-review の担当
---

# /review-cycle

正本は `docs/harness/skills/review-cycle.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/` 配下 profile を参照する（存在する場合のみ）。
