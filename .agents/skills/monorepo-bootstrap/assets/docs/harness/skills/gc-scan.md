# gc-scan（ハーネス GC: 重複・孤児）

この文書は `/gc-scan` の手順正本である。ハーネス文書全体を `gc-agent` でスキャンし、Cross-File 重複と孤児（参照されない references・起動経路の無い agent・機械検査に現れないデッド参照）を意味判定で検出して、**すべて 1 つの PR で提案**する。検出・抽出の詳細ロジックは `.claude/agents/gc-agent.md` と `.claude/agents/references/gc-agent-detection.md` を正本とする（本文書には複製しない）。サイズ上限・skill 正本と adapter の 1:1 対応・参照パスの実在は決定論的に判定できるため CI の機械検査（`pnpm harness:test`）が担当し、本 skill は検出しない。docs の内容鮮度（`/docs-sync` 担当）・ADR の圧縮（`/adr-compress` 担当）は扱わない。

## Purpose

ハーネス文書（agent 定義・skill adapter・skill 手順正本）の意味的な劣化 —
複数ファイルへの同一記述の重複、誰からも使われないファイルや起動経路の無い agent — を定期的に検出し、
レビュー可能な変更として提案する。決定論的に判定できる規約は CI が強制する。違反がマージされなくなり、
定期の LLM 走査と判定が重複しないため、本 skill は意味判定が必要な検出に集中する。

## Source of truth

`docs/harness/harness_authoring_guide.md`（分離原則・命名規則の判定基準）。サイズ上限の値も同書の表が正本であり、
機械検査が読む（本文書に数値を複製しない）。

## Compared against

スキャン対象のハーネス文書の実態（重複ブロック・参照グラフ）。

## Scope

スキャン対象:

- `.claude/agents/*.md`（agent 定義）
- `.claude/skills/*/SKILL.md`（thin adapter）
- `docs/harness/skills/**/*.md`（skill 手順の正本）

除外:

- `docs/harness/skills/shared/**` は**孤児判定から除外**する。複数 skill / agent が Read する共有契約置き場であり、
  `/command` として起動しない設計のため、起動経路の不在は異常ではない（重複の検査対象には含める）。
- gc-agent 自身（`.claude/agents/gc-agent.md`）は走査対象に含めるが提案対象から除外する。

孤児判定の追加の除外規定（新規追加直後・`orphan-allow` 宣言・profile）は `.claude/agents/references/gc-agent-detection.md` を正本とする。

## Detection

gc-agent（`.claude/agents/gc-agent.md`）を起動する（引数なし。渡されても無視する。起動手段は `docs/harness/OPERATING_MODEL.md` の「ツール固有手段の読み替え」に従う）。gc-agent が次の 2 種類の候補を
検出する。検出条件・同一性判定・抑制条件・検出証拠の記録は `.claude/agents/gc-agent.md` と
`.claude/agents/references/gc-agent-detection.md` を正本とする。

- **重複**: 2 ファイル以上に存在する意味的に同一・類似のブロック → 共有 references への抽出とポインタ置換を提案する
- **孤児**: inbound 参照の無い references、起動経路の無い agent、機械検査の対象にならない形式（Markdown リンク・
  節名への参照・説明文中の言及）のデッド参照 → 削除・修正の変更を同一 PR に含めて提案する

機械検査との分界:

| 検査                                                                    | 担当                                 |
| ----------------------------------------------------------------------- | ------------------------------------ |
| サイズ上限・description の文字数                                        | CI の機械検査（`pnpm harness:test`） |
| skill 正本と adapter の 1:1 対応・`SKILL.md` の欠け                     | 同上                                 |
| 実在しないパスを指す参照（バッククォート内のパス）                      | 同上                                 |
| agent 定義の起動指定（`subagent_type`）または `orphan-allow` 宣言の有無 | 同上                                 |
| 重複、機械検査に現れない起動経路・デッド参照                            | 本 skill                             |

機械検査の失敗は、その変更を含む PR の CI で検出される。本 skill では扱わない。

## Auto-edit policy

- 重複: 抽出（references ファイルの作成 + 抽出元のポインタ置換）を実行する。
  抽出元に要約を残さない（単一情報源の原則）。
- 孤児: **削除・修正の変更を同一 PR に含める**。孤児ファイルは削除、デッド参照は参照の修正または削除として
  diff を作る。削除の採否は PR レビューで人間が判断する（マージ前に取り消せる形で提案する。Issue 起票では追跡が
  滞留しやすいため、判断材料〔検出証拠: 探索キーワードとヒット状況・最終更新日〕を PR body に添えて diff で提示する）。
- 判定が割れる候補（実運用実績が確認できない agent 等）は削除 diff にせず、PR body の
  「要判断」一覧に検出証拠付きで記載するに留めてよい。

## Branch & PR policy

候補が 0 件なら「抽出対象なし」を console に出力して終了する（ブランチも PR も作らない）。
候補ありの場合は `docs/harness/skills/shared/sync-pr-flow.md` の手順（既存 open PR ガード →
`origin/main` 基点ブランチ → commit → 通常 PR）に従う。本 skill の差分:

| 項目               | 値                                                                                           |
| ------------------ | -------------------------------------------------------------------------------------------- |
| 変更なしメッセージ | `[gc-scan] 抽出対象なし。ハーネス文書に重複・孤児はありません。`                             |
| ブランチ           | `agent/gc-scan-{YYYY-MM-DD}`                                                                 |
| git add            | 新規作成した references / 修正した抽出元 / 削除・修正した孤児候補のみ                        |
| commit             | `refactor(harness): gc-scan (YYYY-MM-DD)`                                                    |
| PR title           | `refactor(harness): gc-scan (YYYY-MM-DD)`                                                    |
| PR ラベル          | `harness:harness`                                                                            |
| PR body            | 標準 5 節（`docs/harness/skills/shared/pr-creation.md`）に、下記 Report shape の区分を加える |

1 回の実行で **1 PR**（重複の抽出と孤児の削除・修正を 1 つにまとめる）。Issue は起票しない。

## Validation

ハーネス文書のみの変更のため、`gate:docs`（`docs/harness/skills/shared/verification-gates.md`）と
機械検査（`pnpm harness:test`）を実行する。加えて PR 作成前に以下を確認する:

- 各抽出先ファイルの内容が抽出元から正しく移動されている（要約を残していない）
- 各抽出元のポインタが正しい配置先を参照している
- 孤児の削除対象を参照している箇所が PR 内で同時に修正されている（削除だけして
  デッド参照を新たに作らない）
- 抽出で増減したファイルが機械検査（サイズ上限・1:1 対応・パス実在）を通る

## Report shape

PR body は標準 5 節に加えて、次の区分で構成する:

1. **検出サマリ**: 重複 / 孤児の件数 + スキップ件数（抑制条件 / 除外規定の内訳）
2. **実行した抽出（重複）**: 候補 ID / 抽出元パス + 行範囲 / 配置先パス
3. **削除・修正の提案（孤児）**: 候補 ID / 対象パス / 検出証拠（探索キーワードと
   ヒット状況・最終更新日）。**削除を確定事項として書かず**、「参照が見つからなかった」事実と
   判断材料を提示する（探索できない経路からの参照があり得るため、採否はレビューに委ねる）
4. **要判断**: 削除 diff にしなかった候補（理由付き）
5. **受入条件チェックリスト**: Validation の 4 項目

## Language

報告・PR body・Issue 本文は project language に従う（正本: `docs/harness/OPERATING_MODEL.md` の言語ポリシー節）。ファイルパス・候補 ID は原文のまま保持する。
