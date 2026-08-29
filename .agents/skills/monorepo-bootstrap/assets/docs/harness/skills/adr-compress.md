# adr-compress（ADR コーパスの定期圧縮）

この文書は `/adr-compress` の手順正本である。`docs/adr/` の肥大化を `adr-compactor` agent で検出・圧縮し、変更を 1 PR にまとめる。検出条件・圧縮メカニズム・安全ガードレールの詳細は `.claude/agents/adr-compactor.md` を正本とする（本文書には複製しない）。新規 ADR の起票（`/create-adr` 担当）・ハーネス文書の圧縮（`/gc-scan` 担当）は扱わない。

## Purpose

ADR コーパス（`docs/adr/` の本体・`INDEX.md`）が時間とともに肥大化し、現行の決定を探す
コストが増えるのを防ぐ。決定（Decision）を失わない形で、無効化済み ADR のスタブ化・INDEX の
再構築・大型本文の要約を定期実行する。

## Source of truth

- `docs/adr/README.md`（ADR の status model・INDEX 規約の正本）
- 圧縮メカニズムの詳細は `.claude/agents/adr-compactor.md` とその参照先を正本とする

## Compared against

`docs/adr/ADR-*.md` の実態（Status・行数・サイズ）と `docs/adr/INDEX.md` の現状構造。

## Scope

- 対象は `docs/adr/` 配下のみ（ADR 本体 + `INDEX.md`）。
- **Proposed の ADR は本体を変更しない**（レビュー進行中）。INDEX 分類のみ行う。

圧縮カテゴリ:

| カテゴリ | 対象 | 性質 |
|---------|------|------|
| **I** INDEX 再構築 | `INDEX.md` を Status 別（現行: Accepted / Proposed ／ アーカイブ: Superseded・Deprecated / プロセス記録）に決定的再構築。各行はリンク + 1 行要旨 | lossless |
| **II** in-place スタブ化 | Superseded / Deprecated、および恒久的決定を含まないプロセス記録を**同パスのまま** stub に置換 | lossless（ファイル移動なし = 参照保全） |
| **III** 同一 issue 統合 | 同一 issue 番号の複数 ADR を 1 ファイルに統合（原本は in-place stub） | **opt-in**・全 Decision 保持 |
| **IV** 本文要約圧縮 | サイズ閾値超過の大型 ADR 本体 | lossy（要点に短縮。原文は git 履歴が究極の正本） |

## Detection

1. Agent tool で `subagent_type: adr-compactor` を起動する（`consolidate` 引数の有無を伝達する）。
   - 引数なし: I / II / IV を実行（III は無効）
   - `consolidate`: III も有効化する（「1 ADR = 1 決定」規約の変更を伴うため明示 opt-in）
2. agent が走査・抑制条件・安全ガードレール検証を行う。主要な安全ガードレール（正本は agent 定義):
   - **Proposed 不可侵**: Status が読み取れない ADR も Proposed 相当として II / III / IV から除外する
   - **Decision を消さない**: 有効な Decision が 1 つでも落ちる圧縮は候補から外す
   - **durable-decision ガード**: プロセス記録に見えても恒久的な設計判断を含むものは stub 化しない
   - **in-place 維持**: II / III はファイルを移動しない（bare-id 参照・相互リンクを構造的に保つ）

## Auto-edit policy

- 実行順は **II → III（opt-in）→ IV → I**（本体変更を先に、INDEX 再構築を最終状態に対して 1 回）。
- 1 つの ADR が複数カテゴリに該当する場合、優先順位 II > III > IV で最大 1 つが本体を所有する。
- 各圧縮は idempotent にする（stub は marker を持ち再 stub 化されない / I は決定的再構築で
  未変更コーパスでは diff なし / IV 要約済みは閾値未満で再検出されない）。

## Branch & PR policy

候補 0 件かつ INDEX が既に canonical 形なら「変更なし」を stdout に出力して終了する。
候補ありの場合は `docs/harness/skills/shared/sync-pr-flow.md` の手順（既存 open PR ガード →
`origin/main` 基点ブランチ → commit → 通常 PR）に従う。本 skill の差分:

| 項目 | 値 |
|------|-----|
| 変更なしメッセージ | `[adr-compress] 変更なし。docs/adr/ は圧縮閾値を超えておらず INDEX は canonical 形です。` |
| ブランチ | `agent/adr-compress-{YYYY-MM-DD}` |
| git add | 変更・新規作成した ADR / `INDEX.md` を個別指定 |
| commit | `refactor(adr): adr-compress (YYYY-MM-DD)` |
| PR title | `refactor(adr): adr-compress (YYYY-MM-DD)` |
| PR ラベル | `harness:harness` |
| PR body | 下記 Report shape |

1 回の実行で **1 PR**（全カテゴリの候補を 1 PR にまとめる）。既存 open PR ガード発火時は
新規 PR を作らず既存 PR の番号 / URL を報告して終了する（自動 bypass は設けない。人間が既存 PR を
merge / close するまで新規 PR は作らない）。

## Validation

docs のみの変更のため `pnpm run format:check`
（`docs/harness/skills/shared/verification-gates.md` の「docs のみ変更」組合せ）。
加えて PR 作成前に、IV（lossy）で削除した詳細が git 履歴で追える旨を ADR 本文と PR body の
双方に明記していることを確認する。

## Report shape

PR body の構成:

1. **カテゴリ別件数**: I / II / III / IV の実行件数
2. **変更一覧**: 対象 ADR / カテゴリ / 変更内容（stub 化・統合・要約）
3. **INDEX drift**: 実ファイルと INDEX 行の不整合（file あり / 行なし、行あり / file なし）の一覧
4. **スキップした候補**: 抑制条件・ガードレール別の理由内訳

## Language

報告・PR body・Issue 本文は project language に従う（正本: `docs/harness/OPERATING_MODEL.md` の言語ポリシー節）。ADR の id・Status キーワード（Accepted / Proposed / Superseded /
Deprecated）は原文のまま保持する。
