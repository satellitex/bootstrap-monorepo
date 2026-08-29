# ハーネスオーサリングガイド

> この文書はハーネス文書（skill 正本・thin adapter・agent 定義・OPERATING_MODEL / CLAUDE.md / AGENTS.md）の作成・編集規約である。
> 個々の skill / agent の内容はここに書かない。運用モデル自体は [OPERATING_MODEL.md](OPERATING_MODEL.md) が正本。

## 背景

Agent = Model + Harness（Martin Fowler, 2025）。
モデルの能力を最大限に引き出すには、ハーネス（プロンプト・ツール・オーケストレーション）の設計品質が鍵となる。
本ガイドは、認知負荷の最小化・関心の分離・コンテキスト効率を軸に、ハーネスの設計指針を定める。

## 2 層規約: neutral 正本 + 薄い adapter

skill の手順は tool-neutral な正本と、AI ツールごとの薄い adapter の 2 層で管理する。

| 層 | 配置 | 内容 |
|----|------|------|
| **neutral 正本** | `docs/harness/skills/<name>.md` | 手順・判断基準・制約の全文。特定の AI ツールに依存しない記述 |
| **薄い adapter** | `.claude/skills/<name>/SKILL.md` | frontmatter + 正本へのポインタのみ（≤20 行） |

- 正本と adapter は **同名で 1:1 対応** させる。片方だけの追加・削除・リネームを禁止する
- 手順の実体は必ず正本側に書く。adapter に手順を書き足さない（二重管理の温床になる）
- sync 系 skill に共通する契約（origin/main 基準・0 件終了・open PR ガード等）は `docs/harness/skills/shared/` に置き、各正本から参照して本文に複製しない
- プロジェクト固有値（ID・マッピング等の magic value）は `.claude/skills/<name>/references/` 配下の profile に分離する
- 同様に、リポジトリ入口の `CLAUDE.md` / `AGENTS.md` は薄い adapter とし、運用の実体は [OPERATING_MODEL.md](OPERATING_MODEL.md)（neutral 正本）に置く

thin adapter の正準形:

```markdown
---
name: <skill-name>
description: <1 行説明（project language。正本: OPERATING_MODEL.md の言語ポリシー節）>
---

# /<skill-name>

正本は `docs/harness/skills/<skill-name>.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/` 配下 profile を参照する（存在する場合のみ）。
```

## サイズ制約

| ファイル種別 | 上限 | 根拠 |
|-------------|------|------|
| OPERATING_MODEL.md / CLAUDE.md / AGENTS.md | ≤200 行 | 全セッションで常に読み込まれる（または常時参照される）ため最小限に |
| skill 正本（`docs/harness/skills/<name>.md`） | ≤500 行 | 超過時は `references/` または `shared/` に分離 |
| thin adapter（`.claude/skills/<name>/SKILL.md`） | ≤20 行 | ポインタ以上の内容を持たせない |
| Agent 定義（`.claude/agents/*.md`） | ≤250 行 | 単一責務の原則。超過は責務肥大化の兆候 |
| Skill description（frontmatter） | ≤250 文字 | skill 選択時に読まれるメタデータ |

本表の上限は `/gc-scan`（定期実行）が検査し、超過を PR で提案する。**上限値の正本は本表のみ**であり、gc-scan の正本（`skills/gc-scan.md`）は本表を参照する（数値を複製しない）。

### 超過時の対処

1. **skill 正本が 500 行を超える場合**: 詳細仕様・ポリシー・参照テーブルを `.claude/skills/<name>/references/`（プロジェクト固有値）または `docs/harness/skills/shared/`（skill 横断の共通契約）に分離する
   - コアの正本にはフロー定義・ステップ手順・判断基準のみを残す
2. **Agent が 250 行を超える場合**: 責務の分割を検討する（例: 生成役と評価役の分離）
   - もしくは詳細を `.claude/agents/references/` に分離する（下記「Agent 定義の references/ 分離パターン」参照）
3. **OPERATING_MODEL.md / CLAUDE.md が 200 行を超える場合**: 詳細をリンク先に移動し、ポインタのみを残す

#### Agent 定義の references/ 分離パターン

Agent 定義（`.claude/agents/*.md`）が肥大化すると、subagent 起動時の inference リクエストサイズが大きくなり、応答時間が長くなる。責務分割が難しい場合、詳細を `.claude/agents/references/` に分離する。

| 分離対象（references/ へ） | コアに残す（agent.md 内） |
|--------------------------|--------------------------|
| Stage 別の番号付き手順詳細 | 役割・ワークフロー上の位置・インプット |
| Self-check 全項目チェックリスト | Phase 概要 + 各 Stage 見出しと 1 行説明 |
| 完全なテンプレート・YAML 例 | アウトプット先パスと参照先リンク |
| アウトプット構造の詳細表 | Self-check 要約と参照先リンク |
| 検査手順の詳細・判定基準 | 制約・禁止事項・言語表記 |

分離原則:
- agent prompt には「`references/<file>.md` を Stage 実行直前に Read する」と明示する（必要時にオンデマンドで Read されることをモデルが理解できる文言）
- references/ 配下のファイルに frontmatter は不要（agent から Read されるだけで、subagent として spawn されない）
- 元 agent の全 Stage 番号・Self-check 項目・テンプレート例が「コア残し」または「references 分離」のいずれかにマップされ、振る舞いが等価であることを保証する

## 自由度のスペクトラム（Degrees of Freedom）

> Anthropic, "Skill authoring best practices" — Agent への指示は「自由度」を意識して書く。

Agent / skill への指示を書くとき、**すべてのステップを同じ粒度で記述してはいけない**。
タスクの性質に応じて、指示の自由度を使い分ける。

| 自由度 | いつ使うか | 書き方 | 例 |
|--------|-----------|--------|-----|
| **Low**（厳密） | 操作が脆く、特定の値・順序が必須。モデルが推論できない magic value を含む | 定数テーブル、exact ID | Project ID、フィールド ID、API endpoint |
| **Medium**（構造） | パターンはあるが、多少の変形は許容 | テンプレート構造、判断基準テーブル | Issue body テンプレート、ラベル選択基準 |
| **High**（自然言語） | 複数のアプローチが妥当、文脈依存の判断が必要 | ゴール・制約を自然言語で記述 | 「概要から適切なラベルを推定する」「依存関係を考慮して優先度を判断する」 |

### アンチパターン

**過剰な命令的指示（Over-prescription）**

```markdown
# BAD: シェルコマンドで全ステップを記述
ASSIGNEE=$(gh api user --jq '.login')
ISSUE_URL=$(gh issue create --repo ... --title ... --assignee "$ASSIGNEE" ...)
ISSUE_NUMBER=${ISSUE_URL##*/}
NODE_ID=$(gh api repos/.../issues/"$ISSUE_NUMBER" --jq '.node_id')
```

問題点:
- モデルが知っている `gh` CLI の使い方を冗長に再説明している
- エッジケース（引数の有無、エラー処理）にコマンドが対応しきれず脆くなる
- コマンドの「写経」を強制し、文脈に応じた柔軟な判断を阻害する

**過剰に曖昧な指示（Under-specification）**

```markdown
# BAD: magic value がなく、モデルが推論不可能
Issue を適切なプロジェクトに追加してステータスを設定してください。
```

問題点:
- Project ID やフィールド ID はモデルが推論できない（ハルシネーションの原因になる）
- 「適切な」の判断基準が不明

### 推奨パターン: ハイブリッド

```markdown
# GOOD: 自然言語フロー + magic value は外部参照
## Step 4: Project への追加
`references/project-fields.md` を読み込み、ラベルに基づいてプロジェクトを振り分ける。
GraphQL API の `addProjectV2ItemById` mutation で追加し、Status を Todo に設定する。
```

- **フロー（何をすべきか）** は自然言語で記述 → モデルの文脈判断力を活用
- **magic value（推論不可能な値）** は `references/` に分離 → 正確性を担保
- **API 名・mutation 名** は記載 → 正しいエンドポイントへの誘導（medium freedom）

### 分離の原則

| 情報の種類 | 配置先 | 理由 |
|-----------|--------|------|
| フロー・判断ロジック | skill 正本 / Agent 定義（自然言語） | モデルが柔軟に解釈すべき |
| magic value（ID、定数） | `references/`（`TODO(取得方法: ...)` 形式で収録し、検証済みの実値のみ埋める） | モデルが推論不可能。正確な値が必要 |
| テンプレート構造 | skill 正本内 or `docs/issues/templates/` | 出力形式の統一のため構造は示す |
| 実装詳細（コマンド） | 記載しない | モデルが CLI・API の使い方を知っている |

> **判断基準**: 「モデルはこの情報なしに正しく実行できるか？」
> Yes → 書かない。No → magic value なら `references/` に、判断基準なら自然言語で正本に書く。

## 関心の分離

### Decomposed Prompting（DecomP）原則

> Khot et al., "Decomposed Prompting: A Modular Approach for Solving Complex Tasks", ICLR 2023

1 つのプロンプトに複数の役割を詰め込まない。タスクをサブタスクに分解し、各サブタスクに専用のハンドラ（Agent / skill）を割り当てる。

| 原則 | 説明 | 例 |
|------|------|-----|
| 単一責務 | 1 Agent = 1 つの明確な役割 | 生成役 ≠ 評価役 |
| 入出力の明確化 | 各 Agent のインプット / アウトプットを明示 | ハンドオフ情報テーブル |
| 永続的成果物 | Agent 間の受け渡しはファイルベース | `docs/issues/<number>_<scope>/` 配下の成果物 |
| 構造的制約 | 手続き的なルールは時間的順序で強制 | テストを書いてから実装する順序の強制 |

### Agent 設計の指針

- **入力セクション**: Agent が何を読むかを明示する（ファイルパス、データ形式）
- **プロセスセクション**: 何をするかをステップで記述する
- **出力セクション**: 何を生成するかを明示する（ファイルパス、データ形式）
- **制約セクション**: 禁止事項・判断基準を明示する
- **テンプレートは外部ファイル**: `docs/issues/templates/` 等に置き、Agent 定義内にテンプレートを埋め込まない

## コンテキスト効率

### MECW（Maximum Effective Context Window）

> 実効的なコンテキストウィンドウは物理的な上限より大幅に小さい。Primacy bias（冒頭）と Recency bias（末尾）が最も注意を集める。

- **冒頭に配置**: 役割定義、最重要ルール、フロー概要
- **末尾に配置**: 制約、Self-check、次のアクション
- **中間部は構造化**: テーブル、YAML、番号付きリストで認知負荷を軽減
- **オンデマンド読み込み**: 全セッションで必要でない情報は `references/` や `docs/` に外出しし、必要時に Read する

### 情報の層別化

| 層 | 読み込みタイミング | 配置先 |
|----|-------------------|--------|
| 常時参照 | セッション開始時 | CLAUDE.md / AGENTS.md（adapter 経由で OPERATING_MODEL.md） |
| フェーズ参照 | 特定ステップ実行時 | skill 正本、Agent 定義、templates/ |
| オンデマンド | 明示的に参照された時 | references/、docs/requirements/ |

## 命名規則

| 対象 | 規則 | 例 |
|------|------|-----|
| skill 名 | 小文字ケバブ / 略語 | `multi-issue`, `create-adr` |
| skill 正本 | skill 名と同名の `.md` | `docs/harness/skills/gc-scan.md` |
| Agent ファイル | 小文字ケバブ `.md` | `gc-agent.md`, `architecture-sync.md` |
| references/ | 内容を表す小文字ケバブ `.md` | `pr-creation.md`, `project-fields.md` |
| テンプレート | 内容を表す小文字スネーク `.md` | `task-note.md` |

## Hook 条件記法

### `if` の配置レベル

`settings.json` の PreToolUse / PostToolUse フックで条件フィルタ（`if`）を使う場合、
**hook handler レベル**（`hooks[]` 配列の各要素内）に配置する。
matcher group レベルに置くとパーサに無視され、全マッチで発火してしまう。

```jsonc
// BAD: matcher group レベル — if が無視され全 Bash で発火
{
  "matcher": "Bash",
  "if": "Bash(git commit *)",
  "hooks": [
    { "type": "command", "command": "..." }
  ]
}

// GOOD: hook handler レベル — git commit 時のみ発火
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "if": "Bash(git commit *)",
      "command": "..."
    }
  ]
}
```

### Permission rule syntax

`if` の値は **スペース区切り** で記述する。コロン区切り（`git commit:*`）ではない。

| 記法 | 正否 |
|------|------|
| `Bash(git commit *)` | OK |
| `Bash(git commit:*)` | NG（マッチしない） |

### 防御的二段構え

`if` フィルタが仕様変更やパーサのバグで失効した場合に備え、
シェルスクリプト側にも冒頭ガードを入れる二段構えを推奨する。

```bash
input="$(cat)"
cmd="$(jq -r '.tool_input.command // ""' <<< "$input")"
if [[ "$cmd" != git\ commit* ]]; then
  exit 0
fi
```

## チェックリスト

skill 正本 / adapter / Agent / OPERATING_MODEL / CLAUDE.md を新規作成・編集する際は以下を確認する:

- [ ] サイズ制約を満たしている（上記テーブル参照。定期検査は `/gc-scan`）
- [ ] neutral 正本と thin adapter が 1:1 対応している（片方だけの追加・削除・リネームをしていない）
- [ ] adapter に手順を書き足していない（実体は正本側）
- [ ] 単一責務の原則を守っている（1 ファイル = 1 つの明確な関心事）
- [ ] 入力・プロセス・出力が明示されている
- [ ] テンプレート・magic value・プロジェクト固有値は外部ファイル（templates/ / references/）に分離されている
- [ ] 常時読み込み vs オンデマンドの層別化が適切
- [ ] 冒頭に役割 / 目的、末尾に制約 / チェックリストを配置している

## 参考文献

- Martin Fowler, "Building Effective Agents: Harness Engineering" (2025)
- Khot et al., "Decomposed Prompting: A Modular Approach for Solving Complex Tasks", ICLR 2023
- Anthropic, "Claude Code: Best practices for agentic coding"
- Anthropic, "Effective context engineering for AI agents" (2025)
- Anthropic, "Skill authoring best practices"
- Anthropic, "Demystifying evals for AI agents" (2025)
