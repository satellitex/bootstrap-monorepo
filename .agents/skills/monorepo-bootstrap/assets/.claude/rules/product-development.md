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

<!-- TODO(記入方法: セキュリティガイドを docs/styles/coding_guide/ 配下に追加したら、ここへ直接 pointer を張る) -->

## プロダクト設計固有 rule

<!-- TODO(記入方法: /promote-memory で昇格したプロダクト固有 rule の pointer をここに追記する。形式は
`- [<rule 名>](../../docs/styles/team-feedback/<name>.md)`。概要は INDEX に書く) -->

横断的な team rule は [team-policy.md](team-policy.md) を参照。

## コマンド

検証ゲートのコマンド定義（build / test / lint / typecheck / format / format:check）と用途別の組合せの正本は `docs/harness/skills/shared/verification-gates.md`。名前を変える場合は正本と hooks を同時更新する。

| 用途                | コマンド                                                                                                                                                                                |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 依存のインストール  | `pnpm install --frozen-lockfile`                                                                                                                                                        |
| 全体の検証          | 検証ゲートの組合せを使う（上記の正本）                                                                                                                                                  |
| 開発サーバの起動    | TODO(取得方法: スタック確定後に実コマンドを確認して記入する)                                                                                                                            |
| 単一 package の実行 | `pnpm --filter <package> run <script>`（`<package>` は `apps/*` または `packages/*` の package.json の name）。pnpm・turbo を差し替えた導入先は、差し替えた実コマンドをこの表に記入する |

<!-- TODO(記入方法: workspace 個別の生成・テスト・起動コマンドが増えたら、上の表に行を足す) -->
