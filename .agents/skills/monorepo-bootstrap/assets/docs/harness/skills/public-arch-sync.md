# public-arch-sync（内部正本 → 公開射影の追従）

> **opt-in:public-site** — 本 skill は内部設計文書を外部（顧客・提携組織）へ射影して公開する
> リポジトリでのみ採用する。前提: `docs/product/PUBLIC_ARCHITECTURE.md` と射影ルール profile
> （`.claude/skills/public-arch-sync/references/projection-rules.md`）が存在すること。

この文書は `/public-arch-sync` の手順正本である。内部正本 `docs/product/ARCHITECTURE.md` に射影ルールを適用した「期待射影」と公開版 `docs/product/PUBLIC_ARCHITECTURE.md` を突き合わせ、差分があれば公開版のみ更新して PR にする。射影ルールの中身（削除セクション・抽象化マッピング・禁止語の語彙）は profile を正本とし、本文書には書かない。docs ↔ 実コードの鮮度（`/docs-sync` 担当）は扱わない。

## Purpose

公開版が内部正本の設計変更に追従しないまま古びること、および内部でしか使わない具体サービス名・
内部実装構造が公開版へリークすることを防ぐ。`/docs-sync` が「docs ↔ 実コード」の鮮度を見るのに
対し、本 skill は「内部 md ↔ 公開 md」の**射影整合**を見る（責務は重複しない）。

## Source of truth

- 内容の正本: `docs/product/ARCHITECTURE.md`（内部設計正本。射影で正本を追加する場合は
  profile に定義する）
- 射影ロジックの SSOT: `.claude/skills/public-arch-sync/references/projection-rules.md`
  （削除セクション / サービス名抽象化マッピング / 内部構造リーク処理 / 禁止語 grep パターン /
  保持要素）。本文書に複製しない。

## Compared against

`docs/product/PUBLIC_ARCHITECTURE.md`（公開射影ドキュメント）の現状。

## Scope

- 編集対象は **`docs/product/PUBLIC_ARCHITECTURE.md` のみ**。内部正本は読み取り専用
  （編集・`git add` しない）。
- 公開版が存在しない場合（初回）は、内部正本に射影ルールを適用した全文を新規作成対象とする。

### 自動起動トリガー

内部正本を編集すると PostToolUse hook `.claude/hooks/post-edit-projection-reminder.sh` が
リマインドを注入する（機械実行はしない）。リマインドを受けたら:

- **別ブランチ・別 PR で更新**: `/public-arch-sync` を実行する（本フロー。`origin/main` 基準）
- **同一 PR で更新**: `origin/main` 基準ではローカル編集を拾えないため、本 skill を起動せず
  profile の射影ルールに従って手動で射影する

## Detection

```
/public-arch-sync
  +-- 0. projection-rules.md（profile）を Read（射影ルールの SSOT をロード）
  +-- 1. 共通 prelude（origin/main fetch）
  +-- 2. 内部正本と現公開版を origin/main から取得
  +-- 3. 射影ルールを適用した「期待射影」と現公開版の差分を判定
  +-- 4. 決定論ガード: 禁止語 grep
  +-- 5. 変更なし終了 or 公開版のみ更新 → commit → PR（sync-pr-flow）
```

- **Step 3**: 機械 diff ではなく、射影ルールに照らした内容判断で更新が必要な箇所のみを拾い、
  `projection_drifts:`（kind / location / issue / fix_proposal）として蓄積する。kind は 3 種:
  - **unreflected_change**: 正本で追加 / 変更 / 削除された内容（削除対象セクション以外）が
    公開版に未反映
  - **service_name_leak**: 公開版にマッピング対象の具体サービス名が残存（抽象表現に未置換）
  - **section_discipline**: 削除対象セクションが公開版に出現、または維持すべきセクションが欠落
- **Step 4（決定論ガード）**: 射影判断の取り零しを機械的に検出する二段防御。期待射影
  （または更新後の公開版）に対し **profile の禁止語 grep パターン**を適用し、ヒットは
  `service_name_leak` として `projection_drifts` に加える。禁止語の語彙・表示維持する例外は
  profile を正本とする（本文書に列挙しない）。

## Auto-edit policy

- 差分ありの場合、`fix_proposal` を公開版に適用する: サービス名は profile のマッピングで
  抽象表現に、削除対象セクションは除去、維持セクションは正本の変更を反映、先頭注記コメント
  （「直接編集禁止・内部正本から追従」）と profile が指定する保持要素は保つ。
- 内部正本側の問題（正本自体の誤り）を見つけても正本は編集せず、PR body に指摘として記載する。

## Branch & PR policy

差分 0 件なら何も作らず終了する（sync-prelude の規約）。差分ありの場合は
`docs/harness/skills/shared/sync-pr-flow.md` を Read してその手順に従う。本 skill の差分:

| 項目 | 値 |
|------|-----|
| 変更なしメッセージ | `[public-arch-sync] 変更なし。PUBLIC_ARCHITECTURE.md は内部正本の現状射影と整合しています。` |
| ブランチ | `agent/public-arch-sync-{YYYY-MM-DD}` |
| git add | `docs/product/PUBLIC_ARCHITECTURE.md` のみ |
| commit | `docs: sync PUBLIC_ARCHITECTURE with internal source (YYYY-MM-DD)` |
| PR title | `docs: public-arch-sync (YYYY-MM-DD)` |
| PR body | 下記 Report shape |

## Validation

docs のみの変更のため `pnpm run format:check`
（`docs/harness/skills/shared/verification-gates.md` の「docs のみ変更」組合せ）。
加えて PR 作成前に、更新後の公開版へ profile の禁止語 grep を再適用し 0 件であることを確認する。

## Report shape

PR body は差分種別（unreflected_change / service_name_leak / section_discipline）ごとに
location / 修正内容を整理する。禁止語 grep の最終結果（0 件確認）も記載する。

## Language

報告・PR body・Issue 本文は project language に従う（正本: `docs/harness/OPERATING_MODEL.md` の言語ポリシー節）。セクション名・禁止語パターンは原文のまま保持する。

## Self-check

- [ ] profile（projection-rules.md）を Read してから判定した
- [ ] Step 4 の禁止語 grep をスキップしていない（例外語の扱いは profile に従う）
- [ ] 差分 0 件のとき PR を作成していない
- [ ] 内部正本を編集・`git add` していない（公開版のみ更新）
