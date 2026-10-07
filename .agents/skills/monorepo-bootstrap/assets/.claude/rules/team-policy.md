# チーム横断方針

この文書は全領域の作業に常時適用される横断方針の pointer 層である。個別 rule の本文はここに書かず、`docs/styles/team-feedback/` 配下に置く（一覧は [INDEX](../../docs/styles/team-feedback/INDEX.md)）。

> 本ファイルは `paths:` frontmatter を意図的に持たない。Claude Code の仕様上、
> `paths:` なしの `.claude/rules/*.md` は session 起動時に常時ロードされる。横断方針は
> 全領域（apps / packages / infra / docs / .claude）の作業で常に効くべきため、
> path-scoped にしない設計。領域特化 rule は `harness-development.md` /
> `product-development.md` / `infra-development.md`（いずれも `paths:` 指定あり）に分離している。

## 承認モデル（要旨）

- 既定は自律実行: 明示的な指示がない限り、変更の実装から open PR の提出までを自律的に行う。PR のマージは人間の操作だが、明示的に指示された場合はマージまで行ってよい
- 人間の明示承認が必須なのは次の 2 つのみ: (1) 課金が発生する操作 (2) 秘密値の挿入・変更
- main = dev 環境 / release = prod 環境。prod リリースのみ手順（main の安全性確認 → release への反映手順の確認）を踏む

全文は `docs/harness/OPERATING_MODEL.md`「承認モデル」、運用 rule 本文は [autonomous-flow](../../docs/styles/team-feedback/autonomous-flow.md) を参照。

## secret の取り扱い

- secret / token / credential を commit しない（`.env` 実値・API key・私有鍵を含む）。設定へ投入する操作自体も人間の明示承認が必須（上記承認モデル）。機械強制は pre-push hook（`.claude/hooks/pre-push-ci-check.sh`）の gitleaks による秘密検知が担う。この検知は Claude Code 経由の push にだけ効き、CI は秘密検知を実行しない（→ `.claude/hooks/README.md`）。

## 横断判断 rule

- [長期的自動化を最優先](../../docs/styles/team-feedback/long-term-automation.md) — 短期的な楽な実装は選択肢から除外し、自動化される案を複数パターン検討する
- [フロー Skill は自律判断で end-to-end 実行](../../docs/styles/team-feedback/autonomous-flow.md) — 途中で人間入力を待たず、調査と保守的 default で自律判断し open PR まで進む
- [解決策は 1 案に確定して書く](../../docs/styles/team-feedback/single-solution.md) — 3 条件（現状の仕様を保つ・根本的・シンプル）で 1 案に決め、理由を記録する。人間へ引き渡す範疇は `docs/harness/OPERATING_MODEL.md` の「人間引き渡し境界」（既定: なし）が定める
- [実装フローの切替](../../docs/styles/team-feedback/implementation-flow-switch.md) — 判定は Issue 全体の性質。実装 Issue は /multi-issue、それ以外はメインエージェント判断
- [共有集約ファイル（INDEX.md）は実装 PR で編集しない](../../docs/styles/team-feedback/shared-aggregate-single-writer.md) — INDEX の行は更新主体が更新し、実装 PR は追加する文書の冒頭見出しとリード文を自己記述にする
- [PR レビューコメントは批判的に評価](../../docs/styles/team-feedback/review-comments.md) — ベストプラクティス / 既存スタイル / 技術正確性 / scope の 4 観点で判定する
- [Issue scope を超える指摘は scope 内で対応しない](../../docs/styles/team-feedback/scope-boundary.md) — scope 外は既存 Issue への追記 or 新規 Issue 起票で追跡する
- [PR body に closing keyword を記載](../../docs/styles/team-feedback/pr-closing-keyword.md) — `Closes #<num>` を起票元 issue 番号から注入する。起票元 Issue が無い保守 PR は省略
- [PR を出す前にリファクタパスを 1 回入れる](../../docs/styles/team-feedback/refactor-before-pr.md) — green 直後に差分を簡素化し、振る舞い不変を確認して `refactor:` コミットに分ける

## 機械検証可能 rule（hook / CI で強制）

以下は、hook が Claude Code 経由の操作に、CI が全経路に強制する。本ファイルでは概要と強制機構のみを列挙する（外部契約の正本 → `.claude/hooks/README.md`、コマンド定義 → `docs/harness/skills/shared/verification-gates.md`）:

- [commit 前に format を通す](../../docs/styles/team-feedback/format-check.md) — hook（Claude Code 経由）と CI の format job（全経路）の 2 段で強制する
- commit 前の staged 限定フォーマット — `.claude/hooks/pre-format-check.sh`（Claude Code 経由のみ）
- push 前の秘密検知 + CI 同等検査（`gate:push`）— `.claude/hooks/pre-push-ci-check.sh`（Claude Code 経由のみ）
- 編集ファイルの拡張子別検査 — `.claude/hooks/post-edit-check.sh`（Claude Code 経由のみ）
- CI（`gate:ci`）・hooks のテスト・ハーネス機械検査 — `.github/workflows/ci.yml`（全経路）

lint・typecheck・秘密検知は CI の対象外で、hook を経由しない push では担保されない。

## 領域別 rule

読み場面の正本は `docs/harness/OPERATING_MODEL.md`「領域別 rule の読み場面」。

- ハーネス開発（`.claude/**/*` / `docs/harness/**/*`）→ [harness-development.md](harness-development.md)
- プロダクト開発（`apps/**/*` / `packages/**/*`）→ [product-development.md](product-development.md)
- インフラ開発（`infra/**/*`）→ [infra-development.md](infra-development.md)

## 新規 feedback の追加経路

1. 個人 memory に feedback を蓄積する
2. team-shared 化すべきと判断したら `/promote-memory <name>` Skill を実行する
3. Skill が `docs/styles/team-feedback/<name>.md` の生成、本ファイル等への pointer 追記、個人 memory の pointer 化、PR 作成までを一括実行する
