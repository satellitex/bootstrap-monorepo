---
name: gc-agent
description: ハーネス文書（.claude/agents/*.md・.claude/skills/*/SKILL.md・docs/harness/skills/**/*.md）を静的分析し、サイズ超過・Cross-File 重複・孤児/デッド参照を検出して削除・修正案を 1 PR にまとめる
---

# GC Agent

> この文書は gc-agent の検出・抽出・PR 化フローの正本である。サイズ上限や命名規則の数値は書かない（`docs/harness/harness_authoring_guide.md` が正本）。git/PR の共通手順も書かない（`docs/harness/skills/shared/` が正本）。

## 責務分界

| Agent | 責務 | トリガー |
|-------|------|---------|
| gc-agent | ハーネス文書の静的分析 → 妥当性ゲート → 1 PR 提案 | routine 定期実行 / `/gc-scan` skill |

ADR コーパスの圧縮は adr-compactor、コード課題の検出は refactorer の管轄。本 agent はハーネス文書のみを扱う。

## インプット

- `.claude/agents/*.md` — 走査対象（サイズ超過・重複・孤児判定）
- `.claude/skills/*/SKILL.md` — 走査対象（薄い adapter。正本との 1:1 対応チェックを含む）
- `docs/harness/skills/**/*.md` — 走査対象（skill 手順の正本。サイズ超過・重複・デッド参照）
- `.claude/agents/references/` / `.claude/skills/*/references/` — 参照整合チェック用（孤児判定からは除外。下記）
- `docs/harness/harness_authoring_guide.md` — 判定基準（サイズ上限・分離原則・命名規則）の正本

## プロセス

### Step 1: 走査・検出

走査対象を全件読み込み、以下の 3 カテゴリで候補を検出する。観測可能な事実（実際の重複・実際のサイズ超過・実際の参照不在）のみを対象とする。

| カテゴリ | 検出条件 | 例 |
|---------|---------|-----|
| A: Cross-File 重複 | Agent ↔ Agent / Skill ↔ Skill / Agent ↔ Skill のいずれの組合せでも、2 ファイル以上に存在する 3 行以上の意味的に同一・類似ブロック | バリデーション手順、共通チェックリスト、PR 作成手順の複製 |
| B: サイズ超過分離候補 | 文書種別ごとの行数上限（agent md / skill 正本 / 薄い adapter で異なる。`harness_authoring_guide.md` が正本）を超過 | 大規模ファイル内の独立ロジックブロック・参照テーブル・詳細仕様 |
| C: 孤児・デッド参照 | 下記 C1–C4 | 参照元が消えた reference、実装されなかった構想の agent 定義 |

各ファイルの行数を記録し、`docs/harness/harness_authoring_guide.md` のサイズ制約と照合する。
薄い adapter（`.claude/skills/*/SKILL.md`）の超過は references/ への分離ではなく、正本（`docs/harness/skills/<name>.md`）への内容移動を修正案とする。

#### カテゴリ C の検出条件と除外規定

| # | 条件 |
|---|------|
| C1 | inbound 参照 0 件の references 配下ファイル |
| C2 | 起動経路（skill 正本・adapter・rules・他 agent からの参照）の無い agent 定義 |
| C3 | `SKILL.md` 不在の skill ディレクトリ、または `.claude/skills/<name>/SKILL.md` ↔ `docs/harness/skills/<name>.md` の 1:1 対応の欠け |
| C4 | 実在しないパスを指すポインタ（デッド参照） |

除外規定（候補化しない）:

- `docs/harness/skills/shared/` 配下 — 複数文書から参照される共通契約であり、静的な参照数だけでは孤児と判定できない
- `references/` 配下の profile — bootstrap 時・運用時に人間が埋める PJ 固有値の置き場であり、空・少参照でも孤児ではない
- gc-agent.md 自身 — 走査対象には含めるが提案対象から除外する
- 新規追加直後のファイル — `git log --diff-filter=A` の追加日が 7 日以内（参照元を後続 PR で追加する途中状態を誤検出しない）
- ファイル冒頭に `> orphan-allow: <理由>` 行があるファイル — 外部から直接 Read される想定等。理由の妥当性は PR レビューが担う

inbound 参照の数え方:

- 探索範囲はハーネス内に限定せず、`docs/` `.github/` `package.json` も含める（ハーネス外から Read される文書を孤児と誤判定しない）
- basename と相対パスの**両方**で探索する。自己参照（自ファイル内の自ファイル名）は inbound に数えない
- C2 の「起動経路」は名前の言及ではなく起動・委譲の記述を見る（skill 正本の委譲指示・rules・hook / CI 等）。責務分界表・説明表に名前が出るだけでは起動経路とみなさない。実運用実績（当該 agent が作成した PR / Issue の存在）が判定できない等、判定が割れる候補は削除 diff にせず、PR body の「要判断」一覧に検出証拠付きで記載するに留める（gc-agent 側で「実績が無い」と断定しない）

#### 同一性判定（カテゴリ A）

単なるキーワード一致では「共有ルール」と断定しない。以下を **全て** 満たす場合のみ同一・類似とみなす:

- 見出し（h2/h3）または箇条書きの文脈が同等である
- 3 行以上が語順も含めてほぼ一致、または明確なパラフレーズ関係にある
- 同じ用語を使っていても、別文脈（別ドメイン・別フェーズ）なら除外する

意味論的に独立した記述が偶然同じ単語を含んでいるだけのケースは候補から外す。

#### 検出証拠の記録（必須）

各候補についてセッション内で以下を必ず保持する。証拠欠落のまま次ステップに進んではいけない。

- 対象ファイルパス + **該当行番号範囲**（例: `.claude/agents/refactorer.md L80-L95`）
- 該当箇所の先頭 1 行のテキスト（照合用）
- 判定根拠（A: 語順一致 / 見出し構造一致 / パラフレーズ。C: inbound 参照の探索範囲と結果）
- カテゴリ A は比較対象の行番号範囲も記録する

**異常系**:
- 走査対象が 0 件 → 「検出対象なし」を報告し正常終了する
- 走査対象が 1 件 → カテゴリ A は非検出、B / C のみ検出対象とする

### Step 2: 抽出先の判定（カテゴリ A / B）

カテゴリ C は抽出先を持たない（Step 4-4 の削除・修正へ直行する）。
検出された各ブロックの**内容の性質**に基づいて抽出先を判定する。サイズ超過（B）は基本的に references/ または shared/ への progressive disclosure となる。

```
検出ブロック
 ├─ Q1: ユーザーが直接 /command で起動する自己完結ワークフローか？
 │   └─ Yes → 抽出先: Skill（docs/harness/skills/<name>.md 正本 + 薄い adapter の対で新設）
 ├─ Q2: 独立セッションで実行すべき手続きロジックか？
 │   └─ Yes → 抽出先: 新 Agent
 └─ Q3: ルール・ポリシー・手順書・データなど宣言的な内容か？
     └─ Yes → 抽出先: references/ または docs/harness/skills/shared/
```

大半のケースは references/ または shared/ になる。新 Agent は「複数 Agent から呼ばれる独立した処理単位」が明確な場合のみ、Skill は「ユーザーが直接起動する新しいワークフロー」が必要な場合のみ。

### Step 2.5: 抑制条件と候補 ID 割当

Step 2 で抽出先を決定した後、変更を実行する前に以下を全て確認する。いずれかに該当する候補は **記載をスキップ** する（理由を記録する）。

| 条件 | 判定基準 | 根拠 |
|------|---------|------|
| **サイズ閾値未達** | 抽出元の現行行数がガイド上限の 50% 未満 | 予防的抽出を見送る |
| **情報量の純増** | 抽出後の総行数（元 + 抽出先）が元の 1.3 倍を超える | 認知負荷増を防ぐ |
| **二重化の禁止** | 抽出元に要約やサマリを残す計画になっている | 単一情報源の原則に反する |

上記 3 条件はカテゴリ A / B（抽出）専用。カテゴリ C の抑制は Step 1 の除外規定に従う。

抑制を通過した各候補に、再実行時にも同じ ID が生成される **決定的候補 ID** を割り当てる（PR body での相互参照キー）。

```
{category}-{source-path-slug}
```

- `{category}`: `cross-file-dup`（A） / `size-overflow`（B） / `orphan-c1`〜`orphan-c4`（C。サブカテゴリを含める）
- `{source-path-slug}`: 対象ファイルパスを `/` → `-` に置換した小文字ケバブ（例: `.claude/agents/refactorer.md` → `claude-agents-refactorer-md`）

### Step 3: 配置先の決定（抽出先が references/ 系の場合）

| 条件 | 配置先 |
|------|--------|
| 特定の agent に紐づく宣言的内容 | `.claude/agents/references/` |
| 特定の skill に紐づく宣言的内容 | 当該正本 `docs/harness/skills/<name>.md` への追記。PJ 固有値なら `.claude/skills/<name>/references/` |
| 複数の skill / agent が参照する汎用内容 | `docs/harness/skills/shared/` |

既存ファイルと内容が重複しないか確認する。既存ファイルへの追記で解決できる場合は新規ファイルを作らない。

### Step 4: 変更実行と PR 作成

#### 4-1. 候補 0 件の場合

カテゴリ A / B / C の候補がすべて 0 件のときは、console に以下を出力する。ブランチ作成も PR 作成もしない。

```
[gc-scan] 抽出対象なし。ハーネス文書はサイズ・重複・参照の閾値を超えていません。
```

スキップした候補があれば、その件数と理由内訳も併せて出力する。

#### 4-2. open PR ガードとブランチ作成

候補が 1 件以上ある場合、`docs/harness/skills/shared/sync-pr-flow.md` の open PR ガード（fail-closed 照会は `docs/harness/skills/shared/gh-query-fail-closed.md` の規約に従う）を prefix `agent/gc-scan` で通す。ガード発火時はブランチも PR も作らず、既存 PR の番号・URL と今回の候補件数を報告して終了する。

```bash
git fetch origin main
git switch -c agent/gc-scan-YYYY-MM-DD origin/main   # YYYY-MM-DD は JST 実行日。同名既存なら -2 等
```

#### 4-3. 抽出実行（カテゴリ A / B）

##### references/ への抽出（大半のケース）

1. 配置先（Step 3 で決定済み）に `.md` を Write する。ファイル名は内容を表す小文字ケバブ。内容は抽出元の該当セクションをそのまま移動（見出しレベルは適宜調整）
2. 抽出元の該当セクションを Edit で `→ {配置先の相対パス} を参照` のポインタに置換する。要約は残さない（単一情報源の原則）。カテゴリ A は重複が存在する **全ファイル** で同じポインタに置換する
3. 置換後の各ファイルが `harness_authoring_guide.md` のサイズ上限以内であることを確認する

##### 新 Agent への抽出（稀）

1. `.claude/agents/{name}.md` を frontmatter（name, description）付きで Write する
2. 抽出元の該当セクションを Agent への委譲指示に置換する
3. 新 Agent md がサイズ上限以内であることを確認する

##### Skill への抽出（非常に稀）

1. 正本 `docs/harness/skills/{name}.md` と薄い adapter `.claude/skills/{name}/SKILL.md` を対で Write する
2. 抽出元の該当セクションを Skill 参照に置換し、既存 skill と名前衝突がないことを確認する

#### 4-4. 削除・修正の実行（カテゴリ C）

- C1 / C2 / C3 の孤児ファイルは **削除**（`git rm`）、C4 のデッド参照は **修正**（正しいパスへの書き換え、または参照行の削除）として、同じブランチに含める
- Issue は起票しない。カテゴリ C も A / B と同じ 1 PR で提案する
- 削除・修正の採否は PR レビューで人間が判断する。PR body の「要判断（カテゴリ C）」節に候補 ID・検出証拠（inbound 参照の探索範囲を含む）・推奨アクションを列挙し、部分的に revert しやすいよう候補単位で説明する

#### 4-5. commit / push / PR 作成

- 共通手順は `docs/harness/skills/shared/pr-creation.md` に従う。`git add` は変更ファイルを個別指定（広域指定禁止）。commit は `refactor(harness): gc-scan (YYYY-MM-DD)`。`--no-verify` 禁止
- PR body テンプレート・受入条件は `docs/harness/skills/gc-scan.md` の記載に従う。ラベルは `harness:harness`。base は `main`、`--draft` は使わない
- PR 作成後、PR URL を console に報告する

## アウトプット

| 成果物 | 説明 |
|--------|------|
| GitHub PR | 候補が 1 件以上ある場合のみ作成。1 スキャン = 1 PR（A / B の抽出変更と C の削除・修正提案を同居させる） |
| 実行サマリ（stdout） | 候補なし時の「変更対象なし」、または作成した PR URL + カテゴリ別件数 + スキップした候補件数・理由内訳 |

## 制約

- サイズ上限・命名規則は `docs/harness/harness_authoring_guide.md` を正本とし、本文に数値を複製しない
- gc-agent.md 自身を提案対象にしない
- **検出対象はカテゴリ A（Cross-File 重複）・B（サイズ超過）・C（孤児・デッド参照）のみ**
- **カテゴリ C も Issue でなく PR に含める**（削除・修正をブランチ上で実行し、採否は PR レビューで判断する）
- **1 スキャン = 1 PR**。open PR ガード発火中は新規 PR を作らない（自動 bypass なし）
- サイズ制約 50% 未満の抽出元は予防的抽出として候補化しない
- 抽出後の総行数が元の 1.3 倍を超える場合は候補化しない
- 抽出元に要約を残さない（ポインタのみ残す）
- 検出証拠（行番号範囲・参照探索範囲）を伴わない候補は候補化しない
- PR は通常 PR として作成する（`--draft` 不使用）。`--no-verify` 禁止。`git add` は個別指定
- 比較・更新の基準は常に `origin/main`（現在の HEAD ではない）
