# adr-compress PR 出力形式

> この文書は `/adr-compress` が作る PR の本文構成と受入条件の正本である。ブランチ・commit・PR title の値は `docs/harness/skills/adr-compress.md` の差分表、圧縮の規則と形式は `docs/harness/skills/adr-compress/compression-rules.md` が担当する。共通の PR 作成手順は `docs/harness/skills/shared/sync-pr-flow.md` に従う。

## PR 本文の構成

PR 本文は、標準 5 節（背景 / 方針と却下案 / スコープ外 / 検証結果 / リスク。`docs/harness/skills/shared/pr-creation.md`）に、次の区分をこの順で加える。件数が 0 の区分は「なし」と書き、区分そのものは省かない。

1. **カテゴリ別件数**: 0 / I / II / III / IV の実行件数。III は `consolidate` で起動したときだけ数える。
2. **変更一覧**: 対象 ADR・カテゴリ・変更内容（Status 追従・stub 化・統合・要約）・検出根拠の実測値（行数・サイズ・Status 値）の表。
3. **INDEX drift**: 実ファイルと INDEX 行の不整合（file あり・行なし、行あり・file なし）の一覧。
4. **Decision 保全の証拠**: IV を実行した ADR ごとの、要約前後の行数・サイズと検証スクリプトの結果の表。
5. **スキップした候補**: 抑制条件・ガードレール別の理由の内訳（`status-unparseable`、`decision-at-risk`、`durable-decision`、`already-compressed`、`cannot-prove-lossless`）。`cannot-prove-lossless` は ADR と失敗内容を併記する。
6. **受入条件のチェックリスト**: 下記。

IV で削除した詳細を git 履歴で追える旨は、PR 本文の末尾に明記する（各 ADR の本文にも要約注記として書く）。

### 本文の雛形

```markdown
（標準 5 節: 背景 / 方針と却下案 / スコープ外 / 検証結果 / リスク）

## カテゴリ別件数

| カテゴリ | 件数 |
|----------|------|
| 0 Status 追従 | <n> |
| I INDEX 再構築 | <n> |
| II stub 化 | <n> |
| III 同一 Issue 統合 | <n または 実行せず> |
| IV 本文要約 | <n> |

## 変更一覧

| ADR | カテゴリ | 変更内容 | 検出根拠 |
|-----|----------|----------|----------|

## INDEX drift

## Decision 保全の証拠（IV）

| ADR | 行数（前 → 後） | サイズ（前 → 後） | 検証結果 |
|-----|-----------------|-------------------|----------|

## スキップした候補

| 候補 ID | 理由 | 備考 |
|---------|------|------|

IV で削除した詳細は git 履歴で追える。

## 受入条件

（下記のチェックリスト）
```

## 受入条件

- [ ] 変更したファイルが `docs/adr/` 配下の ADR 本体と `INDEX.md` だけである
- [ ] 0 の変更が Status 値の置換だけで、Date など他のセルを変えていない
- [ ] 0 を適用していない Proposed と `status-unparseable` の ADR は、本体が変わっていない
- [ ] II / III の stub が元と同じパスにあり、marker を持つ。ファイルを移動していない
- [ ] II-a の partial 判定で、有効な Decision を落としていない。II-b は durable-decision ガードを通した
- [ ] IV の ADR ごとに検証スクリプトが通った。通らなかった ADR は要約を破棄し、PR 本文に記録した
- [ ] IV で削除した詳細を git 履歴で追える旨を、ADR 本文と PR 本文の双方に書いた
- [ ] INDEX の表が canonical 構造どおりで、すべての ADR ファイルがちょうど 1 回現れる
- [ ] `gate:docs`（`docs/harness/skills/shared/verification-gates.md`）が通った
