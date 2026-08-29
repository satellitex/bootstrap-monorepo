# Refactor Guide Sync — 出力先判定とテンプレート

> この文書は `refactor-guide-sync.md` の Stage 4 から Read される出力先判定・open PR ガード・PR body テンプレートの正本である。突合アルゴリズムは書かない（`refactor-guide-sync-detection.md` が正本）。
> PR 作成の共通手順は `docs/harness/skills/shared/pr-creation.md` に従う（**ここで複製しない**）。

## 出力先判定テーブル

全候補を `refactoring_guide.md` への **1 PR** に集約する。Issue 経路は持たない。編集対象は `## コード課題の検出基準` 配下のカテゴリ表の行のみ（`RG-NNNN` 承認済み観点セクション・コード・他規約は不変）。

| 候補種別 | 出力先 | 編集内容 |
|---------|--------|---------|
| 追加候補（規約にあってガイドに無い原則） | **PR** | 該当カテゴリ表に行を追記（課題説明・優先度・検出方法は推論提案） |
| リネーム/更新候補（タイトル一致の別 ID へ移行） | **PR** | 該当行の原則 ID を旧→新に更新（行を消さない） |
| 削除候補（ガイドに残るが規約から完全消失） | **PR** | 該当行/セクションを削除 |
| 既存観点の根拠ガイドパス修正 | **PR** | パス文字列の置換のみ |
| 候補 0 件 | **stdout** | 「差分なし」を出力し正常終了。PR 作成なし |

stdout には PR URL・スキップ内訳を出す。

## 既存 open PR ガード（ブランチ作成前）

候補が 0 件の場合は本ガードを適用せず、上表の「候補 0 件」行（stdout に「差分なし」）に従う。

候補が 1 件以上ある場合、ブランチを切る前に prefix `agent/refactor-guide-sync`（日付・末尾ハイフンを含めない）で既存 open PR の**存在**を確認する（内容の包含判定ではない）。

**疎通 canary（fail-closed）**: 絞り込みと直交した最小照会で照会経路の生存を先に確認する。
canary が落ちた場合、「既存 open PR なし」に倒さず**照会経路の異常として非ゼロ終了**する
（`docs/harness/skills/shared/gh-query-fail-closed.md` の規約に従う）:

```bash
[ "$(gh pr list --state all --limit 1 --json number --jq 'length')" -eq 1 ] || {
  echo "ERROR: PR 照会経路の疎通 canary が失敗。既存 open PR なしと解釈せず停止する" >&2
  exit 1
}
```

canary 通過後、**絞り込み前の生 JSON を一度変数に受けてから**ローカルで絞り込む。`--jq` で直接絞り込むと出力が絞り込み後の配列になり、**絞り込み前の取得件数が `--limit` に達したか（打ち切りが起きたか）を観測できない**ため:

```bash
raw="$(gh pr list --state open --limit 1000 --json number,url,headRefName)"

# 打ち切り検知: 取得件数が --limit に達していたら絞り込み前に PR が落ちている可能性がある。
[ "$(jq 'length' <<<"$raw")" -lt 1000 ] || {
  echo "ERROR: 取得件数が --limit に達した。--limit を上げて再取得する" >&2
  exit 1
}

jq '[.[] | select(.headRefName | startswith("agent/refactor-guide-sync"))]' <<<"$raw"
```

- **絞り込み結果が 1 件以上**: ブランチも commit も PR も作らず終了する（**異常ではなく正常終了**）。
  「差分なし」は出さない（候補は実在するため嘘になる）。既存 PR の番号・URL と今回の候補件数を stdout に報告する。作業ツリーの復旧は不要（Stage 1-3 は読み取り専用で、`refactoring_guide.md` への編集は次節の PR 手順で初めて行うため、本ガードに到達した時点で未 commit の編集は存在しない。sync 系 skill 群は検出フェーズで先に編集を適用するため復旧が必須だが、本フローは構造が異なる）。
- **絞り込み結果が 0 件**: 次節「PR（全候補を refactoring_guide.md に反映）」に進む。

## PR（全候補を refactoring_guide.md に反映）

- ブランチ: `agent/refactor-guide-sync-YYYY-MM-DD`（`YYYY-MM-DD` は JST 実行日。同名衝突時は `-2` 等のサフィックス）。`git switch -c <branch> origin/main` で作成
- 編集対象: `docs/styles/refactoring_guide.md` の `## コード課題の検出基準` 配下のカテゴリ表のみ（`RG-NNNN` 承認済み観点セクション・コード・他規約は不変）
- commit type: `docs`（Conventional Commits）。例 `docs: sync refactoring_guide with coding_guide (YYYY-MM-DD)`
- `git add docs/styles/refactoring_guide.md`（変更ファイル個別指定。広域指定禁止）
- base は `main`、`--draft` は使わない、`--no-verify` 禁止
- 起票元 Issue がある場合のみ PR body に `関連: #<番号>` を記載する（定期実行の保守 PR で起票元が無ければ省略する。closing keyword の扱いは `docs/harness/skills/shared/pr-creation.md` に従う）

### PR body テンプレート

```markdown
## 概要

`docs/styles/coding_guide/`（正本）と `refactoring_guide.md`（派生）のメタ整合性検証の結果、
以下の追加・削除・根拠パス修正・リネーム更新を `refactoring_guide.md` の検出基準テーブルに反映する。

> **要レビュー**: 追加観点の課題説明・優先度・検出方法はエージェントの提案値であり、
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
- [ ] 編集は `refactoring_guide.md` の検出基準テーブルのみ。`RG-NNNN` 承認済み観点セクション・コード・他規約は不変
- [ ] `pnpm format:check` パス（検証ゲートの定義は `docs/harness/skills/shared/verification-gates.md`）

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

> 候補が無いセクションは PR body から省略してよい（該当 0 件のセクションを空表のまま残さない）。

## 共通

- PR 作成は `docs/harness/skills/shared/pr-creation.md` の手順に従う
- 編集対象は `docs/styles/refactoring_guide.md` の検出基準テーブルのみ（コード・他規約・`RG-NNNN` 承認済み観点セクションは不変）
- 候補 0 件時の stdout 例: `[refactor-guide-sync] 差分なし。coding_guide と refactoring_guide は整合しています。`
- スキップした候補があれば stdout に件数と理由内訳を併記する
