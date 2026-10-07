<!-- opt-in:traceability — traceability グループ採用時のみ収録する。 -->

# traceability matrix（受入条件とテストの対応）

> この文書は `docs/product/tests/`（要件の受入条件 AC とテストの対応を機械可読に記録する matrix の置き場）の最小スキーマと更新規約の正本である。
> テストの書き方は `docs/styles/coding_guide/testing_principles.md`、テストレベルと網羅基準は `docs/product/TEST_STRATEGY.md` が正本であり、ここには書かない。

## 置き場と命名

- 置き場: 本ディレクトリ。matrix の雛形は [`traceability-matrix.example.yaml`](./traceability-matrix.example.yaml)
- ファイル名: `<issue番号>_<scope>.traceability-matrix.yaml`（`<scope>` は Issue タイトルを短縮した英語 kebab-case）
- 本ディレクトリは `INDEX.md` を持たない。matrix は Issue 番号で一意に特定でき、検査と生成の入力として機械が読む
- 人間向けのカバレッジ表が必要な場合は、matrix から都度生成する。生成物は commit しない（matrix と食い違う複製を作らないため）

## 最小スキーマ

| キー | 内容 |
| --- | --- |
| `spec_ref` | 受入条件の出典（元 Issue の URL など） |
| `mappings[].ac_id` | 受入条件の ID。Issue 本文の受入条件から採番する。受入条件が無い対応（不具合修正など）は、方針と検証内容から AC 相当を採番し、`rationale` にその旨を書く |
| `mappings[].category` | 区分。語彙は project で決める（例: 正常系 / 異常系 / 境界値 / 権限） |
| `mappings[].test_file` | テストファイルのパス |
| `mappings[].test_name` | テストの識別子。テストランナーが報告する完全修飾名（階層を持つ場合は連結した形）と完全一致させる。突合キーである |
| `mappings[].rationale` | その AC をそのテストが担保すると判断した根拠 |
| `uncovered_acs` | テストが無い AC の ID（無ければ空配列） |
| `orphan_tests` | どの AC にも対応しないテスト（無ければ空配列） |
| `summary` | 件数の集計（`total_acs` / `covered_acs` / `total_tests` / `orphan_count`）。`mappings` から導出できる値で、ずれたら `mappings` を正とする |

## 更新規約

テストを追加・変更・リネーム・削除したら、同一 PR で matrix を更新する。実装した担当が自分で更新する。

- 同一 PR が唯一の同期タイミングである。後から更新すると、対応付けの根拠（なぜそのテストがその AC を担保するか）を思い出せない
- `test_name` が突合キーのため、テストのリネームは黙って不一致になる。リネーム・削除したら、参照元の matrix をすべて検索して付け替える
  ```bash
  grep -rn "<旧テスト名>" docs/product/tests/*.traceability-matrix.yaml
  ```
- 1 つのテストが複数の Issue の matrix から参照されていることがある。触ったテストの参照元は、自分の matrix に限らず確認する
- 集計値（件数）を固定値でロックするテストを作らない。全 Issue が同じ値を書き換える衝突点になるため、集計は `mappings` から導出する

## 不一致の検査（差し替え点）

matrix とテストの突合検査は、言語とテストランナーに依存するため、この資産には同梱しない。採用するスタックに合わせて実装し、検査コマンドを `docs/harness/skills/shared/verification-gates.md` のゲート定義へ追加する。検査の最小契約は次のとおり。

| 項目 | 内容 |
| --- | --- |
| 入力 | 本ディレクトリの matrix 全件と、テストランナーが列挙するテスト識別子 |
| 突合キー | `test_file` と `test_name` の組 |
| 判定 | matrix にあるがテストに無い組、テストにあるが matrix に無い組を不一致として数える。不一致の純増を失敗にする |
| 既存の不一致 | 記録ファイル（baseline）に件数を保持し、減少のみ許す。引き上げは追跡 Issue を明記した例外手続きに限る |

検査を導入するまでは、この規約を PR レビューで確認する。検査が無い matrix は、リネームの見落としで実態とずれていく。検査を実装したら、ゲート定義に追加してローカル検証と CI の両方で実行する。
