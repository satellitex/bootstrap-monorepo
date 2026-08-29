# promote-memory — 個人 memory → team rule 昇格

この文書は `/promote-memory` の tool-neutral な正本手順である。現状層 3 原則の定義は `docs/styles/coding_guide/docs.md` が SSOT であり、ここには複製しない。

## 目的

個人 memory（`~/.claude/projects/<project-slug>/memory/feedback_*.md`）に蓄積された feedback のうち team-shared 性質のものを `docs/styles/team-feedback/` に正本化し、`.claude/rules/` から pointer を貼り、個人 memory を pointer のみに置換して drift を防ぐ。1 回の実行で 1 件のみ昇格し、1 件 1 PR とする。

## 入力

| 引数 | 必須 | 説明 |
|------|------|------|
| memory file 名 | No | 昇格対象の個人 memory ファイル名（例: `feedback_format_check.md`）。省略時は候補一覧を提示して 1 件選択させる |

## フロー

### Step 1: 昇格候補の確定

引数指定があればそれを採用。省略時は `~/.claude/projects/<project-slug>/memory/feedback_*.md` を列挙し、次を除外して候補を提示する:

- 既に `docs/styles/team-feedback/` に正本がある（drift の sync は本 skill の責務外）
- 個人作業環境固有（エージェントセッション固有制約、ローカル開発手順）
- 時限ルールで適用期間が明示されており既に失効している

### Step 2: メタ情報の決定

選択された memory を Read し、以下を決める。category 推定は次の判断基準を使う:

| category | 振り分け先 rule ファイル | 該当する rule の性質 |
|----------|------------------------|-------------------|
| 横断方針 | `.claude/rules/team-policy.md` | 全領域に効く判断・運用方針 |
| ハーネスフロー固有 | `.claude/rules/harness-development.md` | 実装フロー / Skill / Agent 設計関連 |
| プロダクト設計固有 | `.claude/rules/product-development.md` | apps / packages / 要件マッピング関連 |
| インフラ固有 | `.claude/rules/infra-development.md` | IaC / CI / deploy 関連 |
| 機械検証可能 | `.claude/rules/team-policy.md` の機械検証セクション | hook / CI / lint で強制可能なもの |

決めるもの: `slug`（`feedback_` プレフィックスを除いて kebab-case 化）、`target_path = docs/styles/team-feedback/<slug>.md`、`category` と振り分け先 rule、人間が読める rule タイトル。

機械検証可能カテゴリで強制機構が未整備の場合、PR 本文に「強制機構 Issue の起票候補」として記載する（skill 自身は Issue を切らない）。

### Step 3: team-feedback 正本ファイルを生成

`target_path` を次の構造で生成する:

```markdown
# <人間が読める rule タイトル>

<rule 本文 — 命令形 / 宣言形で 1〜3 段落>

## How to apply

- <適用ガイド 1>
- <適用ガイド 2>

## Why

<理由 — 現状の事実として記述する>

## 関連

- <他 rule への相対リンク>
- <関連 skill / hook / workflow へのパス参照>
```

本ファイルは `docs/styles/coding_guide/docs.md` で定義される「現状層」に属するため、**現状層 3 原則（No-Time / No-Ticket-In-Prose / No-Counterfactual）を必ず遵守する**。原則の詳細・例外規定は同ファイルを SSOT として参照すること（本文書には複写しない）。

個人 memory には日付・PR 番号等の経緯が含まれている前提で、書き直しは必須。経緯を残したい場合は末尾「関連」節での外部事象 ID 参照（例: 外部サービスのエラーコード名）のみ許容。

### Step 4: INDEX.md にカテゴリ別の行を追加

`docs/styles/team-feedback/INDEX.md` の Step 2 で決めた category に対応するセクション表に 1 行追加する。機械検証可能カテゴリの場合は「強制機構」列に hook / CI のパスを記載する。

### Step 5: `.claude/rules/<scope>.md` に pointer を追加

Step 2 で決めた振り分け先 rule ファイルに次の形式で pointer 行を追加する。既存セクション見出しがあればその末尾に、なければ新規見出しを設けて配置する:

```markdown
- [<人間が読める rule タイトル>](../../docs/styles/team-feedback/<slug>.md) — <1 行概要>
```

### Step 6: 個人 memory の pointer 化

ローカル個人 memory ファイル（git 対象外）の本文を以下の pointer 構造に置換する:

```markdown
---
name: <元の name 値>
description: team-shared rule に昇格済み。docs/styles/team-feedback/<slug>.md を参照
metadata:
  type: feedback
  promoted_to: docs/styles/team-feedback/<slug>.md
---

team-shared rule として `docs/styles/team-feedback/<slug>.md` に昇格済み。
本ファイルは drift 防止のため pointer のみ保持する。
```

`MEMORY.md` 索引の該当行も「Promoted to team rules」セクションに移動する。

### Step 7: ブランチ → commit → push → PR

`agent/promote-memory-YYYY-MM-DD` ブランチ（同日重複は `-2`）を `origin/main` から切り、編集した 3 種類のファイル（target_path / INDEX.md / 振り分け先 rule.md）のみを add、`docs(team-feedback): promote <slug> from personal memory` で commit、push する。pre-push hook が検証ゲート（`docs/harness/skills/shared/verification-gates.md`）を自動実行する。

`gh pr create` で PR を起票し（規約: `docs/harness/skills/shared/pr-creation.md`）、本文に次を含める:

- 昇格した rule の概要
- category（横断 / ハーネス / プロダクト / インフラ / 機械検証可能）
- pointer を追加した `.claude/rules/<file>.md`
- 個人 memory が pointer 化された旨（drift 防止）
- 機械検証可能カテゴリの場合、強制機構（hook / CI）の有無、未整備なら Issue 候補

完了後、PR URL をユーザに報告する。

## 制約

- 個人 memory 本体は git 対象外のため、Step 6 のローカル編集は PR に含まれない（drift 防止には pointer 化が必要なため必ず実行する）
- target_path は「現状層」に属する。原則違反は `/docs-sync` が自動検出する
- 昇格対象は team-shared 性質のもののみ。個人作業環境固有・時限ルールは昇格しない
- `--no-verify` 禁止
- 1 回の実行で 1 件のみ昇格する（review 単位を rule 単位に保つ）

## チェックリスト

実行終了前に次を満たすこと:

- [ ] target_path が現状層 3 原則を遵守している
- [ ] INDEX.md にカテゴリ別の行が追加されている
- [ ] 該当 `.claude/rules/<file>.md` に pointer が追加されている
- [ ] 個人 memory ファイルが pointer のみに置換され、MEMORY.md 索引も更新されている
- [ ] PR が作成され URL がユーザに報告されている

## 関連

- `docs/styles/team-feedback/INDEX.md` — 昇格先 rule 一覧
- `docs/styles/coding_guide/docs.md` — 現状層 3 原則 SSOT
- `.claude/rules/team-policy.md` — 横断方針 pointer 集約
- `docs/harness/skills/docs-sync.md` — 昇格後 rule の drift 自動検出
- `docs/harness/harness_authoring_guide.md` — ハーネス文書の設計指針
