# adr-compress（ADR コーパスの定期圧縮）

この文書は `/adr-compress` の手順正本である。`docs/adr/` の Status 追従・INDEX 再構築・stub 化・本文要約を `adr-compactor` agent で実行し、変更を 1 PR にまとめる。検出と安全ゲートのオーケストレーションは `.claude/agents/adr-compactor.md`、圧縮の規則と形式は `docs/harness/skills/adr-compress/compression-rules.md`、PR 本文の構成と受入条件は `docs/harness/skills/adr-compress/pr-output-format.md` を正本とし、本文書には複製しない。新規 ADR の起票（`/create-adr` 担当）とハーネス文書の整理（`/gc-scan` 担当）は扱わない。

## Purpose

ADR コーパス（`docs/adr/` の本体と `INDEX.md`）の鮮度と大きさを保つ。次の 3 点を定期的に実行する。

1. マージ済みなのに Proposed のまま残った ADR の Status を Accepted に追従させる。
2. `INDEX.md` の唯一の writer として、ADR 本体から行を起こして Status 別に再構築する。
3. 決定（Decision）を失わない形で、無効化済み ADR の stub 化と大型本文の要約を行う。

## Source of truth

- `docs/adr/README.md`: ADR の status model と INDEX 規約
- `docs/harness/skills/adr-compress/compression-rules.md`: カテゴリ別の圧縮規則・stub 形式・INDEX の構造
- `docs/harness/skills/shared/index-writer-policy.md`: INDEX の更新主体の割当

## Compared against

`origin/main` 上の `docs/adr/ADR-*.md` の実態（Status・行数・サイズ・marker）と、`docs/adr/INDEX.md` の現状の構造。

## Scope

- 対象は `docs/adr/` 配下のみ（ADR 本体と `INDEX.md`）。
- 圧縮カテゴリは 0 Status 追従、I INDEX 再構築、II in-place stub 化、III 同一 Issue 統合（opt-in）、IV 本文要約。各カテゴリの検出と手順は compression-rules.md に従う。
- Proposed の ADR は、0 の Status 追従を除いて本体を変更しない（レビュー進行中の可能性があるため）。

## Detection

adr-compactor agent（`.claude/agents/adr-compactor.md`）を起動し、`consolidate` 引数の有無を伝える（起動手段は `docs/harness/OPERATING_MODEL.md` の「ツール固有手段の読み替え」に従う）。

| 引数          | 動作                                                                                     |
| ------------- | ---------------------------------------------------------------------------------------- |
| なし          | 0 / I / II / IV を実行する（III は無効）                                                 |
| `consolidate` | III も有効にする（「1 ADR = 1 決定」の規約を変える操作のため、明示的に指定したときだけ） |

走査・抑制条件の検証・圧縮は agent が行う。ガードレール・実行順・各カテゴリの規則は compression-rules.md が正本であり、agent 定義が持つのは候補除外ゲートの手順と記録キーである。

## Auto-edit policy

- 編集してよいのは `docs/adr/` 配下の ADR 本体と `INDEX.md` だけである。
- カテゴリごとの編集内容、実行順、カテゴリの所有規則は compression-rules.md に従う。
- `INDEX.md` を書くのは本 skill だけである。実装 PR は INDEX を変更しないため、行は ADR 本体の冒頭見出しと Status 表から起こす。経過措置として実装 PR が行を足している場合も、再構築は既存行を保つため競合しない。

## Branch & PR policy

候補が 0 件で INDEX が既に canonical 形なら、「変更なし」を stdout に出力して終了する。候補がある場合は `docs/harness/skills/shared/sync-pr-flow.md` の手順（既存 open PR ガード → `origin/main` 基点のブランチ → commit → 通常 PR）に従う。本 skill の差分:

| 項目               | 値                                                                                           |
| ------------------ | -------------------------------------------------------------------------------------------- |
| 変更なしメッセージ | `[adr-compress] 変更なし。docs/adr/ は圧縮閾値を超えておらず INDEX は canonical 形です。`    |
| ブランチ           | `agent/adr-compress-{YYYY-MM-DD}`                                                            |
| git add            | 変更・新規作成した ADR / `INDEX.md` を個別指定                                               |
| commit             | `refactor(adr): adr-compress (YYYY-MM-DD)`                                                   |
| PR title           | `refactor(adr): adr-compress (YYYY-MM-DD)`                                                   |
| PR ラベル          | `harness:harness`                                                                            |
| PR body            | `docs/harness/skills/adr-compress/pr-output-format.md` の構成（標準 5 節 + 本 skill の区分） |

1 回の実行で 1 PR にまとめる（全カテゴリの候補を同じ PR に入れる）。既存 open PR ガードが発火したときは、新規 PR を作らず既存 PR の番号と URL を報告して終了する。人間が既存 PR をマージまたはクローズするまで、新規 PR は作らない。

## Validation

- `gate:docs`（`docs/harness/skills/shared/verification-gates.md`）を実行する。
- IV を実行した場合は、要約した ADR ごとに `node tests/harness/check-adr-compression-lossless.mjs <before> <after>` が通ることを確認する。通らない ADR は要約を破棄して PR 本文に記録する（手順は compression-rules.md のカテゴリ IV）。
- 受入条件は pr-output-format.md のチェックリストを満たす。

## Report shape

PR body の構成は pr-output-format.md を正本とする。カテゴリ別件数・変更一覧・INDEX drift・Decision 保全の証拠・スキップした候補・受入条件の順に書く。

## Language

報告・PR body・Issue 本文は project language に従う（正本: `docs/harness/OPERATING_MODEL.md` の言語ポリシー節）。ADR の id と Status キーワード（Accepted / Proposed / Superseded / Deprecated）は原文のまま保つ。
