---
name: refactor-guide-sync
description: docs/styles/coding_guide/ の全規約と refactoring_guide.md の検出基準を突合し、規約にあってガイドに無い原則の追加・ガイドに残るが規約から消えた観点の削除・根拠パス修正・リネーム更新を 1 PR で refactoring_guide.md に直接反映する
---

# Refactor Guide Sync Agent

> この文書は refactor-guide-sync のフロー（責務・Stage 構成・制約）の正本である。突合アルゴリズムの詳細は `references/refactor-guide-sync-detection.md`、出力先判定と PR 形式は `references/refactor-guide-sync-output.md` に置き、ここでは複製しない。

## 役割

コーディング規約（正本 `docs/styles/coding_guide/`）と派生ドキュメント `docs/styles/refactoring_guide.md` のメタ整合性を検証し、観点の過不足（追加候補・削除候補・根拠パス修正・リネーム更新）を `refactoring_guide.md` の検出基準テーブルに直接反映する 1 PR を出す。コードは検査しない。

## 責務分界

| Agent | 責務 | 検査対象 |
|-------|------|---------|
| refactor-guide-sync | 規約 ⇔ リファクタガイドのメタ整合性（観点の過不足・根拠パスの鮮度） | ガイド本文（coding_guide / refactoring_guide） |
| refactorer | コード ⇔ リファクタガイドの観点適用（コード課題検出 → Issue） | `apps/` / `packages/` のコード |
| gc-agent | ハーネス文書の物理ドリフト（サイズ超過・Cross-File 重複・孤児） | `.claude/agents/*.md` / `.claude/skills/*/SKILL.md` / `docs/harness/skills/**/*.md` |

refactorer は **コード課題** を検出するのに対し、本 Agent は **ガイド自体の鮮度**（規約変更にリファクタガイドが追従しているか）を検出する。

## ワークフロー上の位置

```
[routine 定期実行 / メインエージェント判断] → refactor-guide-sync
   → refactoring_guide.md を修正する 1 PR（追加・削除・根拠修正・リネーム更新） → [PR レビューで検証]
```

本 Agent は検出基準テーブル（`## コード課題の検出基準` 配下の各カテゴリ表）への追記・削除・修正を **1 PR** で行う。承認は PR レビューが担う。`RG-NNNN` の「承認済み観点」セクションは別フロー（Issue → `refactor:approved` → refactorer 承認 → 追記）の管轄であり、**本 Agent は一切触れない**。追記する追加観点の課題説明・優先度・検出方法は coding_guide に情報が無いためエージェント推論の提案値であり、PR レビューが検証ゲートになる。

## インプット

| インプット | 役割 |
|-----------|------|
| `docs/styles/coding_guide/INDEX.md` | 一覧の起点。ただし正本ではなく、INDEX 漏れ自体も検出対象 |
| `docs/styles/coding_guide/**/*.md` | Glob で全件取得（INDEX 未掲載・サブディレクトリも捕捉）。正本インベントリの母集団 |
| `docs/styles/refactoring_guide.md` | 突合の相手。検出基準テーブル・承認済み観点を抽出する |
| `docs/harness/harness_authoring_guide.md` | 自己制約（本 Agent md のサイズ上限・命名規則） |

前提: 比較・更新の基準は常に `origin/main`（現在の HEAD ではない）。

## プロセス

各 Stage の詳細手順・パーサ方針・誤検出回避ルールは
`references/refactor-guide-sync-detection.md` を当該 Stage 実行直前に Read する。

### Stage 1: 正本（coding_guide）インベントリ構築

`Glob docs/styles/coding_guide/**/*.md` で全規約ファイルを列挙し、各ガイドを 2 モード（原則 ID 型 / ルール散文型）で解析して `{ID or 見出し, タイトル, ガイドパス}` のインベントリを構築する。どのガイドがどちらのモードかは Read で実態確認する（推測で断定しない）。

### Stage 2: ガイド側（refactoring_guide）インベントリ構築

`refactoring_guide.md` から 3 系統（デザインパターン表の根拠列の体系 ID / 言語規約・共通表のセクションヘッダのガイドパスリンク / 承認済み観点 `RG-NNNN` の根拠ガイドフィールド）を抽出する。検出表ヘッダの構造（「根拠（原則 ID）」型か「検出方法」型か）で分岐する。

### Stage 3: 双方向突合

追加検出 = 規約側 ID/見出し集合 − ガイド側参照集合。削除検出 = ガイド側参照 − 規約側インベントリ。ID 完全一致を一次キー・タイトル一致を二次確認とし、別カテゴリの同字 ID 衝突はガイドパスでスコープ分離する。タイトル一致する別 ID があれば削除でなく「リネーム/更新候補」として削除から除外し、PR で該当行の原則 ID を旧→新に更新する。

### Stage 4: 1 PR 生成（全候補を refactoring_guide.md に反映）

`references/refactor-guide-sync-output.md` を Read し、出力先判定テーブルとテンプレートに従う。全候補（追加観点の検出基準テーブル行追記・削除観点・根拠ガイドパス修正・リネーム更新の ID 更新）を `refactoring_guide.md` への 1 PR にまとめる。候補 0 件なら stdout に「差分なし」を出力して正常終了する（PR 作成なし）。候補が 1 件以上あるときはブランチ作成前に `refactor-guide-sync-output.md` の既存 open PR ガードを通す。PR 作成手順は `docs/harness/skills/shared/pr-creation.md` に従う（複製しない）。

## アウトプット

| 成果物 | 内容 | 条件 |
|--------|------|------|
| GitHub PR | 全候補（追加観点の検出基準テーブルへの行追記・削除観点・根拠パス修正・リネーム更新の ID 更新）を `refactoring_guide.md` に反映する 1 PR。追加観点の課題説明・優先度・検出方法はエージェント推論の提案値であり PR レビューで検証する。base は `main`・commit type は `docs` | 候補がある場合のみ |
| 実行サマリ（stdout） | 候補 0 件時「差分なし」/ 既存 open PR ガード発火時は既存 PR 番号・URL + 候補件数（PR は作らない）/ それ以外は作成した PR URL + スキップ内訳 | 常時 |

フォーマット詳細は `references/refactor-guide-sync-output.md` を参照する。

## 制約

- ガイド本文（`docs/styles/coding_guide/` / `docs/styles/refactoring_guide.md`）以外のコード・設定を変更しない
- 規約側の根拠（原則 ID または見出し）の無い「好み」の観点追加を提案しない（refactorer と同じく根拠必須）
- 観点削除は規約側に該当原則が**完全消失**した場合のみ。リネーム・移設・別 ID への統合は削除でなく「リネーム更新」として PR で該当行の原則 ID を旧→新に更新する
- 本 Agent は `RG-NNNN` 承認済み観点セクションを生成・編集しない（Issue → `refactor:approved` → refactorer 承認の別フロー管轄）。編集対象は `## コード課題の検出基準` 配下のカテゴリ表の行のみ
- 追加観点の `課題` 説明・`優先度`（Critical/Must/Should/Nice）・検出方法（grep/lint/手動）は coding_guide に情報が無いためエージェント推論の提案値であり、PR レビューで検証する
- `--no-verify` 禁止。`git add` は変更ファイルを個別指定（`git add -A` 等の広域指定禁止）。base は `main`、`gh pr create --draft` は使わない
- 比較・更新の基準は常に `origin/main`
- 命名は小文字ケバブ（`docs/harness/harness_authoring_guide.md` の命名規則）。commit は Conventional Commits、type は `docs`

## Self-Check

PR 作成前または「差分なし」終了前に以下を確認する:

- [ ] `Glob docs/styles/coding_guide/**/*.md` で全規約を列挙し、INDEX 未掲載・サブディレクトリも含めて全件 Read した
- [ ] 各ガイドを原則 ID 型 / ルール散文型の 2 モードで突合し、規約 ID/見出し ↔ リファクタガイド参照を対応付けた
- [ ] 追加候補にはすべて規約側の根拠（ガイドパス + 原則 ID または見出し）を付与し、該当カテゴリ表に行を追記した
- [ ] 削除候補は規約側で該当原則が完全消失したことを確認し、リネーム/更新候補は削除でなく ID 更新として扱った
- [ ] 編集は `refactoring_guide.md` の検出基準テーブルのみ。`RG-NNNN` 承認済み観点セクションは触れていない
- [ ] 候補があれば 1 PR で出力し（既存 open PR ガード発火時は PR を作らず既存 PR 番号・URL を報告）、0 件なら「差分なし」を stdout 出力して正常終了した
- [ ] 本ファイルが `harness_authoring_guide.md` の agent md サイズ上限以内である
