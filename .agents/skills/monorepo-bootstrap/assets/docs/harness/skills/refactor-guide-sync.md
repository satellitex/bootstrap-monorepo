# refactor-guide-sync（規約正本 ↔ リファクタガイドの整合）

この文書は `/refactor-guide-sync` の手順正本である。実体は `refactor-guide-sync` agent への委譲エントリポイントであり、走査・突合・PR 化の詳細ロジックは `.claude/agents/refactor-guide-sync.md` を正本とする（本文書には複製しない）。コードそのものの検査（refactorer agent 担当）は扱わない。

## Purpose

コーディング規約正本（`docs/styles/coding_guide/`）と派生ドキュメント
`docs/styles/refactoring_guide.md` のメタ整合性を守る。規約に追加・削除・リネームされた原則に
リファクタガイドの検出基準が追従しないまま形骸化するのを防ぐ。routine による定期実行を想定した
エントリポイント。

## Source of truth

`docs/styles/coding_guide/**/*.md`（規約正本。INDEX 漏れ自体も検出対象のため一覧の起点は
INDEX ではなく Glob 全件）。

## Compared against

`docs/styles/refactoring_guide.md` の検出基準テーブル（根拠の原則 ID・ガイドパス参照）。

## Scope

- 編集対象は `refactoring_guide.md` の検出基準テーブルのみ。
- 承認済み観点セクション（承認フローを経て追記される観点）は**一切触れない**（別フロー管轄）。
- ガイド本文以外のコード・設定を変更しない。

## Detection

1. Agent tool で `subagent_type: refactor-guide-sync` を起動する（引数なし。渡されても無視する）。
2. agent が実行する内容（概要。詳細は `.claude/agents/refactor-guide-sync.md`）:
   - 規約正本の全件走査と 2 モード解析（原則 ID 型 / ルール散文型）でインベントリ構築
   - ガイド側の参照抽出と**双方向突合**: 追加候補 = 規約側 − ガイド側、削除候補 = ガイド側 − 規約側
   - リネーム判定: タイトル一致する別 ID があれば削除でなく「リネーム更新」（該当行の ID を旧→新に更新）
   - 比較・更新の基準は常に `origin/main`

## Auto-edit policy

- 検出基準テーブルへの行追記（追加観点）・行削除（規約側で完全消失した観点のみ）・
  根拠パス修正・リネーム更新の 4 種を agent が直接反映する。
- 追加観点の課題説明・優先度・検出方法は規約側に情報が無いため agent 推論の提案値であり、
  **PR レビューが検証ゲート**になる。
- 規約側の根拠（原則 ID または見出し）の無い「好み」の観点追加は提案しない。

## Branch & PR policy

候補 0 件なら「差分なし」を stdout に出力して終了する（ブランチも PR も作らない）。
候補ありの場合は `docs/harness/skills/shared/sync-pr-flow.md` の手順（既存 open PR ガード →
`origin/main` 基点ブランチ → commit → 通常 PR）に従う。本 skill の差分:

| 項目 | 値 |
|------|-----|
| 変更なしメッセージ | `[refactor-guide-sync] 差分なし。refactoring_guide.md は coding_guide の現状と整合しています。` |
| ブランチ | `agent/refactor-guide-sync-{YYYY-MM-DD}` |
| git add | `docs/styles/refactoring_guide.md` のみ |
| commit | `docs: sync refactoring_guide with coding_guide (YYYY-MM-DD)` |
| PR title | `docs: refactor-guide-sync (YYYY-MM-DD)` |
| PR body | 追加 / 削除 / 根拠修正 / リネーム更新の候補別一覧（各候補に規約側の根拠パスを併記） |

1 回の実行で **1 PR**（全候補を 1 PR にまとめる）。

## Validation

docs のみの変更のため `pnpm run format:check`
（`docs/harness/skills/shared/verification-gates.md` の「docs のみ変更」組合せ）。

## Report shape

- 候補あり: 反映を含む PR の URL + スキップした候補一覧（理由付き）
- 候補なし: 「差分なし」メッセージ
- 既存 open PR ガード発火時: 既存 PR の番号・URL + 今回の候補件数（PR は作らない）

## Language

報告・PR body・Issue 本文は project language に従う（正本: `docs/harness/OPERATING_MODEL.md` の言語ポリシー節）。原則 ID・ガイドパスは原文のまま保持する。
