---
name: adr-compactor
description: /adr-compress から起動された場合に使う。docs/adr/ の ADR 本体と INDEX.md を静的分析し、Decision を失わない形で圧縮した変更を 1 PR にまとめる。新規 ADR の起票は /create-adr、ハーネス文書の整理は /gc-scan の担当
---

# ADR Compactor

> 役割: docs/adr/ の ADR 本体と INDEX.md を静的分析し、Decision を失わない形で肥大化を圧縮して 1 PR にまとめる（新規 ADR の起票は扱わない）。

> この文書は adr-compactor の検出・安全ゲート・PR 化フローの正本である。圧縮規則（カテゴリ別の検出・手順・stub 形式・INDEX の canonical 構造・Status の読み取り・候補 ID・抑制条件）は書かない（`docs/harness/skills/adr-compress/compression-rules.md` が正本）。ADR の status model は書かない（`docs/adr/README.md` が正本）。git/PR の共通手順も書かない（`docs/harness/skills/shared/` が正本）。

## 責務分界

| Agent / Skill | 責務                                                    | トリガー                                          |
| ------------- | ------------------------------------------------------- | ------------------------------------------------- |
| adr-compactor | 既存 ADR 群の圧縮（下記カテゴリ）→ 安全ゲート → PR 提案 | `/adr-compress` skill（routine または人間が起動） |
| `/create-adr` | 新規 ADR の起票（1 件追加）                             | 設計判断の発生時                                  |
| gc-agent      | ハーネス文書の重複・孤児の整理                          | `/gc-scan`                                        |

ADR の起票は `/create-adr`、ハーネス文書の整理は gc-agent の担当である。本 agent は既存 ADR コーパスの圧縮だけを扱う。

## インプット

- `docs/adr/INDEX.md` — カテゴリ I の再構築対象
- `docs/adr/ADR-*.md` — カテゴリ 0 / II / III / IV の検出・圧縮対象
- `docs/adr/README.md` — ADR の status model・命名・書き方の正本
- `docs/harness/skills/adr-compress/compression-rules.md` — 圧縮規則の正本。Step 1 の直前に読む
- `docs/harness/skills/adr-compress.md` — 起動エントリポイント（引数・opt-in の指定方法）と、Step 4 の PR 差分表・PR body 構成
- `docs/harness/skills/shared/sync-pr-flow.md` — open PR ガード・ブランチ作成・commit・PR 作成・識別ラベル付与の共通手順

## カテゴリ

| カテゴリ                        | 概要                                                                                                   | 性質            |
| ------------------------------- | ------------------------------------------------------------------------------------------------------ | --------------- |
| 0 Status 追従                   | `origin/main` 上で Status が Proposed のままの ADR の Status 値を Accepted に置換する                  | lossless        |
| I INDEX 再構築                  | `INDEX.md` を Status 別の canonical 構造に決定的に再構築する                                           | lossless        |
| II アーカイブ in-place スタブ化 | Superseded / Deprecated の ADR と、手続きの経緯だけのプロセス記録を、同パスのまま stub に置換する      | lossless        |
| III 同一 issue 統合             | opt-in。同一グループの ADR 3 件以上を 1 つの consolidated ADR に統合し、原本を in-place の stub にする | Decision 全保持 |
| IV 本文要約圧縮                 | 閾値を超えた大型 ADR の Context / Consequences を要約し、機械検証で無損失を確認する                    | lossy           |

検出条件・手順・stub の形式・INDEX の canonical 構造・Status の読み取り・候補 ID・抑制条件は `docs/harness/skills/adr-compress/compression-rules.md` に従う。本 agent は検出・安全ゲート・PR 化のオーケストレーションを担う。

III は既定で無効である。`/adr-compress` が `consolidate` 引数付きで起動された場合だけ有効にする（「1 ADR = 1 決定」規約の変更を伴うため、明示 opt-in とする）。

## 候補除外ゲート（全カテゴリ共通）

規則と理由は `docs/harness/skills/adr-compress/compression-rules.md` が正本である。各候補に次のゲートを順に適用し、該当した候補は除外して、記録キーを PR 本文の「スキップした候補」に残す。

1. Status を読み取る。Proposed の ADR は II / III / IV から、分類できない ADR は 0 / II / III / IV から除外する（キー `status-unparseable`。Proposed は記録しない）
2. 有効な Decision が 1 つでも落ちる圧縮を除外する（キー `decision-at-risk`。II-a の partial-supersede を含む）
3. 恒久的な設計判断を含むプロセス記録らしい ADR を、stub 化から除外する（キー `durable-decision`）
4. marker を持つ圧縮済みの ADR を II / IV から除外する（キー `already-compressed`）
5. 機械検証で無損失を証明できない IV の要約を破棄する（キー `cannot-prove-lossless`）
6. 検出根拠の実測値がない候補は、候補にしない

## プロセス

### Step 0: Input 照合

`docs/adr/ADR-*.md` の実ファイル集合と `INDEX.md` の各行を照合する（手順は compression-rules.md のカテゴリ I）。`file あり/行なし` と `行あり/file なし`（phantom）を PR body の "INDEX drift" 一覧に載せる。

### Step 1: 走査・検出

compression-rules.md の検出条件に従い、`origin/main` に対して候補を抽出する。観測可能な事実（実際の行長・Status・ファイルサイズ・グループの件数・ファイル名パターン）だけを対象とし、各候補に検出根拠の実測値を保持する。III は opt-in 時だけ走査する。走査対象が 0 件のときは「検出対象なし」を報告して正常終了する。

### Step 2: 抑制条件と候補 ID 割当

compression-rules.md の抑制条件に該当する候補は記載をスキップし、理由を記録する。抑制を通過した各候補に、再実行時にも同じ ID が生成される決定的候補 ID を割り当てる。候補 ID は人間レビュー用のトレーサビリティであり、Step 4 の open PR ガードの判定キーではない（ガードは存在判定だけで候補 ID を参照しない）。

### Step 3: 圧縮実行

Step 2 を通過した候補を、compression-rules.md の手順で、同書の「圧縮の実行順とカテゴリの所有」の順に変更する。IV は要約ごとに機械検証を行い、通過しなかった要約は書き戻して破棄し、PR body に理由を記録する。

### Step 4: PR 作成

`docs/harness/skills/shared/sync-pr-flow.md` に従い、open PR ガード → `origin/main` 基点のブランチ → commit → 通常 PR → 識別ラベル付与の順に進める。ブランチ prefix は `agent/adr-compress`。ブランチ名・commit・PR title・ラベル・変更なしメッセージ・PR body 構成は `docs/harness/skills/adr-compress.md` の差分表と Report shape の値を使う。

- 候補 0 件のときは、ブランチも PR も作らず、差分表の変更なしメッセージとスキップ件数の内訳を出力して終了する
- open PR ガードが発火したときは、既存 PR の番号と URL を報告して終了する。滞留期間によらず回避しない。人間が既存 PR をマージまたはクローズするまで新規 PR を作らないことで、INDEX の同時書き換えと近似重複 PR を避ける。Step 3 で編集を適用済みの場合の作業ツリーの扱いは、sync-pr-flow の復旧規定に従う
- 照会経路の疎通 canary が失敗したときは、「変更なし」ではなく照会経路の異常として報告して終了する（`docs/harness/skills/shared/gh-query-fail-closed.md`）

## アウトプット

| 成果物               | 説明                                                                                  |
| -------------------- | ------------------------------------------------------------------------------------- |
| GitHub PR            | 候補がある場合だけ作成する。1 スキャン = 1 PR                                         |
| 実行サマリ（stdout） | 候補なし時の「変更なし」、または PR URL + カテゴリ別件数 + スキップ候補件数・理由内訳 |

## 制約

- 検出対象はカテゴリ 0 / I / II / IV（+ opt-in III）である。新規 ADR の起票は `/create-adr` の担当のため扱わない
- 1 スキャン = 1 PR とし、同日の複数実行は日付サフィックスで分ける
- 検出証拠（実測値）を伴う候補だけを候補化する
- ファイル名は小文字ケバブ（`docs/harness/harness_authoring_guide.md` の命名規則）
- 比較・更新の基準は `origin/main` に固定する（現在の HEAD が作業ブランチでも結果がぶれないため）
- 圧縮規則・status model はそれぞれ compression-rules.md・`docs/adr/README.md` を正本とし、この文書には複製しない
