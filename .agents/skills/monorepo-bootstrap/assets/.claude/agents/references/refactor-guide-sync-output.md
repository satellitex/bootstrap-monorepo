# Refactor Guide Sync — 出力先判定とテンプレート

> この文書は `.claude/agents/refactor-guide-sync.md` の Stage 4 から Read される出力先判定・open PR ガードの固有パラメータ・PR body テンプレートの正本である。突合アルゴリズムは書かない（`.claude/agents/references/refactor-guide-sync-detection.md` が正本）。
> PR 作成の共通手順は `docs/harness/skills/shared/sync-pr-flow.md` に従い、ここでは複製しない。ブランチ・commit・PR title の値は `docs/harness/skills/refactor-guide-sync.md` の差分表が指定する。

## 出力先判定テーブル

全候補を `refactoring_guide.md` への 1 PR に集約する。編集対象は `## 検出観点` 節（言語・パターン別に追加した表を含む）の観点表の行だけである（`RG-NNNN` 承認済み観点セクション・コード・他規約は変更しない）。

| 候補種別 | 出力先 | 編集内容 |
|---------|--------|---------|
| 追加候補（規約にあってガイドに無い原則） | PR | 該当カテゴリ表に行を追記（課題説明・優先度・検出方法は推論提案） |
| リネーム/更新候補（タイトル一致の別 ID へ移行） | PR | 該当行の原則 ID を旧→新に更新（行を消さない） |
| 削除候補（ガイドに残るが規約から完全消失） | PR | 該当行/セクションを削除 |
| 既存観点の根拠ガイドパス修正 | PR | パス文字列の置換のみ |
| 候補 0 件 | stdout | 「差分なし」を出力して正常終了。PR は作らない |

stdout には PR URL・スキップ内訳を出す。

## 既存 open PR ガード（ブランチ作成前）

候補が 0 件の場合は本ガードを適用せず、上表の「候補 0 件」行（stdout に「差分なし」）に従う。

候補が 1 件以上ある場合は、ブランチを切る前に `docs/harness/skills/shared/sync-pr-flow.md` §1 の手順で既存 open PR の存在を確認する。固有パラメータはブランチ prefix `agent/refactor-guide-sync`（日付・末尾ハイフンを含めない）だけである。

- 絞り込み結果が 1 件以上のときは、ブランチも commit も PR も作らずに終了する（異常ではなく正常終了）。候補は実在するため「差分なし」は出さず、既存 PR の番号・URL と今回の候補件数を stdout に報告する。
- 本フローでは Stage 1〜3 が読み取り専用で、`refactoring_guide.md` への編集は PR 手順で初めて行う。ガード到達時点で未 commit の編集は存在しないため、作業ツリーの復旧は不要である。
- 絞り込み結果が 0 件のときは、次節に進む。

## PR（全候補を refactoring_guide.md に反映）

- ブランチ・commit・PR title・`git add` 対象は `docs/harness/skills/refactor-guide-sync.md` の差分表に従う
- 編集対象は `docs/styles/refactoring_guide.md` の `## 検出観点` 節の観点表だけである（`RG-NNNN` 承認済み観点セクション・コード・他規約は変更しない）

### PR body テンプレート

```markdown
## 概要

`docs/styles/coding_guide/`（正本）と `refactoring_guide.md`（派生）のメタ整合性検証の結果、
以下の追加・削除・根拠パス修正・リネーム更新を `refactoring_guide.md` の検出基準テーブルに反映する。

> 要レビュー: 追加観点の課題説明・優先度・検出方法はエージェントの提案値であり、
> レビューで検証してほしい（coding_guide に情報が無いため推論で埋めている）。

## 追加観点（規約にあってガイドに無い原則）

| 追加先カテゴリ表 | 課題（推論） | 根拠（`ガイドパス#ID`） | 提案優先度（推論） |
|-----------------|------------|----------------------|------------------|
| {言語規約 / デザインパターン / 共通の該当表} | {課題説明 — 推論提案} | {docs/styles/coding_guide/{module}.md#ID} | {Critical / Must / Should / Nice — 推論提案} |

## 削除観点（規約から完全消失）

| refactoring_guide 行 | 観点 | 旧根拠 | 削除理由 |
|---------------------|------|--------|---------|
| L{n} | {観点} | {ガイドパス#ID} | {規約側で当該原則が消失したことの確認} |

## 根拠ガイドパス修正

| refactoring_guide 行 | 旧パス | 新パス | 理由 |
|---------------------|--------|--------|------|
| L{n} | {旧} | {新} | {リネーム/移設の確認} |

## リネーム・更新観点（タイトル一致の別 ID へ移行）

| refactoring_guide 行 | 旧 ID | 新 ID | 確認 |
|---------------------|-------|-------|------|
| L{n} | {ガイドパス#旧ID} | {ガイドパス#新ID} | {タイトルがパラフレーズ一致。行を削除せず ID を更新} |

## 受入チェックリスト

- [ ] 追加観点の根拠（ガイドパス + 原則 ID）は規約側に実在することを確認済み
- [ ] 追加観点の課題説明・優先度・検出方法は推論提案であり、レビューで検証する
- [ ] 削除した観点は規約側で原則が完全消失していることを確認済み（リネームは含まない）
- [ ] 編集は `refactoring_guide.md` の検出基準テーブルのみ。`RG-NNNN` 承認済み観点セクション・コード・他規約は変更していない
- [ ] 検証ゲート（`docs/harness/skills/shared/verification-gates.md` の「docs のみ変更」組合せ）が PASS

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

> 候補が無いセクションは PR body から省略してよい（該当 0 件のセクションを空表のまま残さない）。

## 共通

- 候補 0 件時の stdout は、`docs/harness/skills/refactor-guide-sync.md` の差分表の変更なしメッセージを使う
- スキップした候補があれば stdout に件数と理由内訳を併記する
