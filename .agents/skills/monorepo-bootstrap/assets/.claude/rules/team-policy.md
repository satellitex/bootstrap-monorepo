# チーム横断方針

この文書は全領域の作業に常時適用される横断方針の pointer 層である。個別 rule の本文はここに書かず、`docs/styles/team-feedback/` 配下に置く（一覧は [INDEX](../../docs/styles/team-feedback/INDEX.md)）。

> 本ファイルの frontmatter は `paths:` を持たない。`paths:` なしの `.claude/rules/*.md` は
> session 起動時に常時ロードされ、横断方針は全領域（apps / packages / infra / docs / .claude）の
> 作業で効く。領域特化 rule は `harness-development.md` / `product-development.md` /
> `infra-development.md`（いずれも `paths:` 指定あり）に置く。

## 承認モデル

正本は `docs/harness/OPERATING_MODEL.md`「承認モデル」である（運用 rule → [自律実行の既定](../../docs/styles/team-feedback/autonomous-flow.md)）。

## secret の取り扱い

- secret / token / credential を commit しない（`.env` 実値・API key・私有鍵を含む）。設定へ投入する操作の承認は上記承認モデルに従う。機械強制は pre-push hook（`.claude/hooks/pre-push-ci-check.sh`）の gitleaks による秘密検知が担う（効く範囲 → `docs/harness/skills/shared/verification-gates.md`「ゲートごとの実行先」）。

## 横断判断 rule

各 rule の概要は [INDEX](../../docs/styles/team-feedback/INDEX.md) に書く。

- [長期的自動化を最優先](../../docs/styles/team-feedback/long-term-automation.md)
- [自律実行の既定](../../docs/styles/team-feedback/autonomous-flow.md)
- [解決策は 1 案に確定して書く](../../docs/styles/team-feedback/single-solution.md)
- [PR レビューコメントは批判的に評価](../../docs/styles/team-feedback/review-comments.md)
- [Issue scope を超える指摘は scope 内で対応しない](../../docs/styles/team-feedback/scope-boundary.md)
- [PR body に closing keyword を記載](../../docs/styles/team-feedback/pr-closing-keyword.md)
- [PR を出す前にリファクタパスを 1 回入れる](../../docs/styles/team-feedback/refactor-before-pr.md)
- [実装フローの切替](../../docs/styles/team-feedback/implementation-flow-switch.md)
- [共有集約ファイル（INDEX.md）は実装 PR で編集しない](../../docs/styles/team-feedback/shared-aggregate-single-writer.md)

## 機械検証可能 rule（hook / CI で強制）

hook と CI の分担と、hook にだけ置かれた検査は `docs/harness/skills/shared/verification-gates.md`「ゲートごとの実行先」が正本である（hook の外部契約 → `.claude/hooks/README.md`）。本ファイルには強制機構の名前だけを列挙する:

- [commit 前に format を通す](../../docs/styles/team-feedback/format-check.md) — `.claude/hooks/pre-format-check.sh` と CI の format job
- push 前の秘密検知 + CI 同等検査（`gate:push`）— `.claude/hooks/pre-push-ci-check.sh`
- 編集ファイルの拡張子別検査 — `.claude/hooks/post-edit-check.sh`
- CI（`gate:ci`）・hooks のテスト・ハーネス機械検査 — `.github/workflows/ci.yml`

## 領域別 rule

読み場面の正本は `docs/harness/OPERATING_MODEL.md`「領域別 rule の読み場面」。

- ハーネス開発（`.claude/**/*` / `docs/harness/**/*`）→ [harness-development.md](harness-development.md)
- プロダクト開発（`apps/**/*` / `packages/**/*`）→ [product-development.md](product-development.md)
- インフラ開発（`infra/**/*`）→ [infra-development.md](infra-development.md)

## 新規 feedback の追加経路

1. 個人 memory に feedback を蓄積する
2. team-shared 化すべきと判断したら `/promote-memory <name>` Skill を実行する
3. Skill が `docs/styles/team-feedback/<name>.md` の生成、本ファイル等への pointer 追記、個人 memory の pointer 化、PR 作成までを一括実行する
