---
paths:
  - ".claude/**/*"
  - "docs/harness/**/*"
---

# ハーネス設計指針

この文書はハーネス（`.claude/` と `docs/harness/`）の編集時のみロードされる rule である。オーサリング規約の本文はここに書かず、正本へ誘導する。

- ハーネス文書の書き方規約（サイズ上限・分離原則・description の書式・fail 方向の設計）→ `docs/harness/harness_authoring_guide.md`
- skill / agent / adapter の本文はモデルへのプロンプトであり、`docs/harness/harness_authoring_guide.md` の「プロンプト記述のベストプラクティス」に従う

## 2 層規約（neutral 正本 + thin adapter）

→ `docs/harness/harness_authoring_guide.md`「2 層規約: neutral 正本 + 薄い adapter」

## 同時更新と確認

- skill の追加・削除: 正本と adapter を 1:1 で揃え、`docs/harness/OPERATING_MODEL.md` の skill コマンド一覧を同一 PR で更新する
- 定期実行に載せる場合は `docs/harness/scheduled-operations.md` の routine カタログも同一 PR で更新する
- rule の追加・削除: `docs/harness/OPERATING_MODEL.md` の「領域別 rule の読み場面」表を同一 PR で更新する
- 入口 adapter（`AGENTS.md` / `CLAUDE.md`）・rules・skill 一覧を変更したら、adapter が `docs/harness/OPERATING_MODEL.md` とずれていないか確認する
- ハーネス文書・設定・workflow を変更したら、`pnpm harness:test` を実行する。検査の一覧と追加手順は `tests/harness/README.md`

横断的な team rule は [team-policy.md](team-policy.md) を参照。
