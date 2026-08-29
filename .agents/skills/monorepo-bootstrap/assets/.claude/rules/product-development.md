---
paths:
  - "apps/**/*"
  - "packages/**/*"
---

# プロダクト開発 rule（skeleton）

この文書はプロダクトコード（`apps/` / `packages/`）の編集時のみロードされる rule の skeleton である。rule 本文はここに書かず、正本への pointer だけを持つ。bootstrap 後にプロジェクト固有 rule の pointer を追記して育てる。

## 開発スコープ

開発スコープ・責任分界の正本は `docs/product/ARCHITECTURE.md`。これに従い、正本に無い構造変更は先に ARCHITECTURE.md 側の合意を取る。

## セキュリティ

コード変更時は `docs/styles/coding_guide/INDEX.md` から辿れるコーディング規約（セキュリティ規約を含む）を遵守する。

<!-- TODO(bootstrap 後): セキュリティガイドを docs/styles/coding_guide/ 配下に追加したら、ここへ直接 pointer を張る -->

## プロダクト設計固有 rule

<!-- TODO(bootstrap 後): /promote-memory で昇格したプロダクト固有 rule の pointer をここに追記する。形式:
- [<rule 名>](../../docs/styles/team-feedback/<name>.md) — <1 行要旨>
-->

横断的な team rule は [team-policy.md](team-policy.md) を参照。

## コマンド

検証ゲートのコマンド定義（build / test / lint / typecheck / format / format:check）の正本は `docs/harness/skills/shared/verification-gates.md`。名前を変える場合は正本と hooks を同時更新する。

<!-- TODO(bootstrap 後): workspace 個別の起動・テスト・生成コマンドが増えたらここに追記する -->
