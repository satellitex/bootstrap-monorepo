---
name: handle-review
description: PR のレビューコメントに対応する場合に使う。ADR 既決を最優先にする判定表で批判的に評価し、修正・push・スレッドへの返信と resolve・ADR 記録までを自律的に行う。LGTM までの反復・conflict 解消・CI 失敗の修正は /review-cycle の担当
---

# /handle-review

正本は `docs/harness/skills/handle-review.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/` 配下 profile を参照する（存在する場合のみ）。
