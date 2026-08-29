---
paths:
  - ".claude/**/*"
  - "docs/harness/**/*"
---

# ハーネス設計指針

この文書はハーネス（`.claude/` と `docs/harness/`）の編集時のみロードされる rule である。オーサリング規約の本文はここに書かず、正本へ誘導する。

- ハーネス文書の書き方規約（サイズ上限・分離原則・fail 方向の設計）→ `docs/harness/harness_authoring_guide.md`

## 2 層規約（neutral 正本 + thin adapter）

- 手順・判断基準の正本は tool-neutral に `docs/harness/` へ置く（skill 手順は `docs/harness/skills/<name>.md`、sync 系の共通契約は `docs/harness/skills/shared/`）
- `.claude/skills/<name>/SKILL.md` と `AGENTS.md` / `CLAUDE.md` は正本参照だけを持つ薄い adapter とし、詳細手順を二重管理しない。手順の変更は必ず正本側を編集する
- adapter 側の link を実体ファイルで置き換えない
- プロジェクト固有値（ID・マッピング・対象マップ等）は `.claude/skills/<name>/references/` の profile に分離する

## skill 追加・削除時の同時更新

- `docs/harness/skills/<name>.md`（正本）と `.claude/skills/<name>/SKILL.md`（adapter）の 1:1 対応を保つ
- `docs/harness/OPERATING_MODEL.md` の skill コマンド一覧を同一 PR で更新する
- 定期実行に載せる場合は `docs/harness/scheduled-operations.md` の routine カタログも同一 PR で更新する
- テンプレート資産台帳（bootstrap 元 skill の MANIFEST）を持つリポジトリでは、その台帳も同時に更新する

横断的な team rule は [team-policy.md](team-policy.md) を参照。
