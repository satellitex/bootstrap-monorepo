---
name: gc-agent
description: /gc-scan から起動された場合に使う。ハーネス文書を静的分析し、Cross-File 重複と孤児・デッド参照の抽出・修正案を 1 PR にまとめる。ADR の圧縮は /adr-compress、コード課題の検出は /refactor-sync の担当
---

# GC Agent

> 役割: ハーネス文書（agent 定義・skill adapter・skill 正本）を静的分析し、Cross-File 重複と孤児・デッド参照の修正案を 1 PR にまとめる（ADR の圧縮とコード課題の検出は扱わない）。

> この文書は gc-agent の抽出・PR 化フローの正本である。検出条件・除外規定・証拠の記録は `.claude/agents/references/gc-agent-detection.md` に置き、ここでは複製しない。サイズ上限や命名規則の数値は書かない（`docs/harness/harness_authoring_guide.md` が正本）。git/PR の共通手順も書かない（`docs/harness/skills/shared/` が正本）。

## 責務分界

| Agent | 責務 | トリガー |
|-------|------|---------|
| gc-agent | ハーネス文書の静的分析（重複・孤児の意味判定）→ 妥当性ゲート → 1 PR 提案 | routine 定期実行 / `/gc-scan` skill |

ADR コーパスの圧縮は adr-compactor、コード課題の検出は refactorer の担当である。本 agent はハーネス文書だけを扱う。サイズ上限・skill 正本と adapter の 1:1・参照パスの実在といった決定論的に判定できる項目は CI の機械検査が担うため、本 agent は意味判定が要る重複と孤児に集中する。

## インプット

- `.claude/agents/*.md` — 走査対象（重複・孤児判定）
- `.claude/skills/*/SKILL.md` — 走査対象（薄い adapter）
- `docs/harness/skills/**/*.md` — 走査対象（skill 手順の正本。重複・デッド参照）
- `.claude/agents/references/` / `.claude/skills/*/references/` — 参照整合チェック用（孤児判定からは除外。詳細は検出手順の文書）
- `docs/harness/harness_authoring_guide.md` — 分離原則・命名規則・サイズ上限の正本（抑制条件の算定と配置先の判断に使う）
- `docs/harness/skills/gc-scan.md` — 起動エントリポイントと、Step 4 の PR 差分表・PR body 構成

## プロセス

### Step 1: 走査・検出

走査対象を全件読み込み、`.claude/agents/references/gc-agent-detection.md` を読んで次の 2 カテゴリで候補を検出する。

| カテゴリ | 概要 |
|---------|------|
| A: Cross-File 重複 | 2 ファイル以上に存在する 3 行以上の意味的に同一・類似ブロック |
| B: 孤児・デッド参照 | inbound 参照のない references、起動経路のない agent 定義、機械検査の対象外形式のデッド参照 |

各候補に、対象ファイルパス・該当行番号範囲・判定根拠の検出証拠を付ける。証拠が欠けた候補は候補化しない。

### Step 2: 抽出先の判定（カテゴリ A）

カテゴリ B は抽出先を持たない（Step 4-4 の削除・修正へ進む）。カテゴリ A は検出ブロックの内容の性質で抽出先を決める。

```
検出ブロック
 ├─ Q1: ユーザーが直接 /command で起動する自己完結ワークフローか？
 │   └─ Yes → 抽出先: Skill（docs/harness/skills/<name>.md 正本 + 薄い adapter の対で新設）
 ├─ Q2: 独立セッションで実行すべき手続きロジックか？
 │   └─ Yes → 抽出先: 新 Agent
 └─ Q3: ルール・ポリシー・手順書・データなど宣言的な内容か？
     └─ Yes → 抽出先: references/ または docs/harness/skills/shared/
```

大半のケースは references/ または shared/ になる。新 Agent は「複数 Agent から呼ばれる独立した処理単位」が明確な場合だけ、Skill は「ユーザーが直接起動する新しいワークフロー」が必要な場合だけ選ぶ。

### Step 2.5: 抑制条件と候補 ID 割当

Step 2 で抽出先を決めた後、変更を実行する前に次を全て確認する。いずれかに該当する候補は記載をスキップし、理由を記録する。

| 条件 | 判定基準 | 根拠 |
|------|---------|------|
| サイズ閾値未達 | 抽出元の現行行数がガイド上限の 50% 未満 | 予防的な抽出を見送る |
| 情報量の純増 | 抽出後の総行数（元 + 抽出先）が元の 1.3 倍を超える | 認知負荷の増加を避ける |
| 二重化 | 抽出元に要約やサマリを残す計画になっている | 単一情報源の原則を保つ |

上記 3 条件はカテゴリ A（抽出）の専用である。カテゴリ B の抑制は検出手順の文書の除外規定に従う。

抑制を通過した各候補に、再実行時にも同じ ID が生成される決定的候補 ID を割り当てる（PR body での相互参照キー）。

```
{category}-{source-path-slug}
```

- `{category}`: `cross-file-dup`（A） / `orphan-b1`〜`orphan-b3`（B。サブカテゴリを含める）
- `{source-path-slug}`: 対象ファイルパスの `/` を `-` に置換した小文字ケバブ（例: `.claude/agents/refactorer.md` → `claude-agents-refactorer-md`）

### Step 3: 配置先の決定（抽出先が references/ 系の場合）

| 条件 | 配置先 |
|------|--------|
| 特定の agent に紐づく宣言的内容 | `.claude/agents/references/` |
| 特定の skill に紐づく宣言的内容 | 当該正本 `docs/harness/skills/<name>.md` への追記。PJ 固有値なら `.claude/skills/<name>/references/` |
| 複数の skill / agent が参照する汎用内容 | `docs/harness/skills/shared/` |

既存ファイルと内容が重複しないか確認する。既存ファイルへの追記で解決できる場合は新規ファイルを作らない。

### Step 4: 変更実行と PR 作成

#### 4-1. 候補 0 件の場合

カテゴリ A / B の候補がすべて 0 件のときは、ブランチも PR も作らず、`docs/harness/skills/gc-scan.md` の差分表にある変更なしメッセージを出力して終了する。スキップした候補があれば、その件数と理由の内訳も併せて出力する。

#### 4-2. open PR ガードとブランチ作成

候補が 1 件以上ある場合、`docs/harness/skills/shared/sync-pr-flow.md` の open PR ガード（照会は `docs/harness/skills/shared/gh-query-fail-closed.md` の規約に従う）を prefix `agent/gc-scan` で通す。ガードが発火したときは、ブランチも PR も作らず、既存 PR の番号・URL と今回の候補件数を報告して終了する。通過したら sync-pr-flow に従い `origin/main` 基点のブランチを作る。

#### 4-3. 抽出実行（カテゴリ A）

##### references/ への抽出（大半のケース）

1. 配置先（Step 3 で決定済み）に `.md` を作成する。ファイル名は内容を表す小文字ケバブ。内容は抽出元の該当セクションをそのまま移動する（見出しレベルは適宜調整）
2. 抽出元の該当セクションを `→ {配置先の相対パス} を参照` のポインタに置換する。要約は残さない（単一情報源の原則）。重複が存在する全ファイルで同じポインタに置換する
3. 置換後の各ファイルが `docs/harness/harness_authoring_guide.md` のサイズ上限以内であることを確認する

##### 新 Agent への抽出（稀）

1. `.claude/agents/{name}.md` を frontmatter（name, description）付きで作成する
2. 抽出元の該当セクションを Agent への委譲指示に置換する
3. 新 Agent md がサイズ上限以内であることを確認する

##### Skill への抽出（非常に稀）

1. 正本 `docs/harness/skills/{name}.md` と薄い adapter `.claude/skills/{name}/SKILL.md` を対で作成する
2. 抽出元の該当セクションを Skill 参照に置換し、既存 skill と名前衝突がないことを確認する

#### 4-4. 削除・修正の実行（カテゴリ B）

- B1 / B2 の孤児ファイルは削除（`git rm`）、B3 のデッド参照は修正（正しいパスへの書き換え、または参照行の削除）として、同じブランチに含める
- Issue は起票せず、カテゴリ A と同じ 1 PR で提案する
- 削除・修正の採否は PR レビューで人間が判断する。PR body の「要判断」節に候補 ID・検出証拠（inbound 参照の探索範囲を含む）・推奨アクションを列挙し、部分的に revert しやすいよう候補単位で説明する

#### 4-5. commit / push / PR 作成

- 手順は `docs/harness/skills/shared/sync-pr-flow.md`（commit / push / PR 作成 / 識別ラベル付与）に従う。commit・PR title・ラベル・PR body テンプレート・受入条件は `docs/harness/skills/gc-scan.md` の差分表と Report shape に従う
- PR 作成後、PR URL を console に報告する

## アウトプット

| 成果物 | 説明 |
|--------|------|
| GitHub PR | 候補が 1 件以上ある場合だけ作成する。1 スキャン = 1 PR（A の抽出変更と B の削除・修正提案を同居させる） |
| 実行サマリ（stdout） | 候補なし時の「変更対象なし」、または作成した PR URL + カテゴリ別件数 + スキップした候補件数・理由内訳 |

## 制約

- サイズ上限・命名規則は `docs/harness/harness_authoring_guide.md` を正本とし、本文に数値を複製しない
- gc-agent.md 自身は提案対象にしない
- 検出対象はカテゴリ A（Cross-File 重複）と B（孤児・デッド参照）に限る。サイズ超過・1:1 対応・参照パスの実在は機械検査が担う
- カテゴリ B も Issue ではなく PR に含める（削除・修正をブランチ上で実行し、採否は PR レビューで判断する）
- 1 スキャン = 1 PR とする。open PR ガードの発火中は新規 PR を作らず、自動では回避しない
- 抑制条件（Step 2.5）に該当する候補は候補化せず、抽出元には要約を残さずポインタだけを残す
- 検出証拠（行番号範囲・参照探索範囲）を伴う候補だけを候補化する
- 比較・更新の基準は `origin/main` に固定する（現在の HEAD が作業ブランチでも結果がぶれないため）
