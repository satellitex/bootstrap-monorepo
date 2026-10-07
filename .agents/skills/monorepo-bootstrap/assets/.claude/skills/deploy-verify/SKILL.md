---
name: deploy-verify
description: dev または prod へ deploy して検証する場合に使う。prod では release 反映 PR の作成からマージ後の step 単位の確認まで進め、各ステップの成否を明示判定する。失敗時の Issue 起票は /create-issue、個別ステップの実行ロジックは PJ の runbook の担当
---

# /deploy-verify

正本は `docs/harness/skills/deploy-verify.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/` 配下 profile を参照する（存在する場合のみ）。
