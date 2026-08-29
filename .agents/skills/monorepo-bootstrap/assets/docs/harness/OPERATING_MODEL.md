# 運用モデル（neutral 正本）

この文書はリポジトリ運用の tool-neutral な正本であり、`AGENTS.md` / `CLAUDE.md` 両 adapter から参照される。docs の正本 pointer・ハーネス構成・エージェントフロー・skill コマンド一覧・承認モデル・言語ポリシー・ブランチ / commit 規約を定める。個別 skill の手順本文は `docs/harness/skills/` に置き、ここには書かない。

## プロダクト

{{PRODUCT_NAME}} — TODO(取得方法: Intake の回答からプロダクトの 1 行紹介に置き換える)

## docs 正本 pointer 集

| 内容 | 正本 |
| --- | --- |
| docs 全体マップ | `docs/README.md` |
| 要件（一覧 / 運用） | `docs/requirements/INDEX.md` / `docs/requirements/README.md` |
| ADR（運用 / 一覧） | `docs/adr/README.md` / `docs/adr/INDEX.md` |
| 内部設計 | `docs/product/ARCHITECTURE.md` |
| 技術スタック | `docs/product/TECH_STACK.md` |
| ドメイン用語集 | `docs/product/TERMS.md` |
| テスト戦略 | `docs/product/TEST_STRATEGY.md` |
| コーディング規約 | `docs/styles/coding_guide/INDEX.md` |
| チーム共有 rule | `docs/styles/team-feedback/INDEX.md` |
| リファクタ運用 | `docs/styles/refactoring_guide.md` |
| runbook | `docs/runbooks/INDEX.md` |
| 調査ノート | `docs/notes/README.md` |
| 監査レポート | `docs/audit/README.md` |
| Issue 成果物の運用 | `docs/issues/README.md` |
| 定期運用（routine / 定期 workflow 設計） | `docs/harness/scheduled-operations.md` |
| ハーネス文書の書き方規約 | `docs/harness/harness_authoring_guide.md` |

## ハーネス構成

正本と adapter の 2 層で管理する:

- **neutral 正本**: 手順・判断基準は tool-neutral に `docs/harness/` へ置く。skill 手順は `docs/harness/skills/<name>.md`、sync 系の共通契約は `docs/harness/skills/shared/`。
- **thin adapter**: `AGENTS.md` / `CLAUDE.md` / `.claude/skills/<name>/SKILL.md` は正本への参照だけを持つ薄い入口とし、詳細手順を二重管理しない。

`.claude/` 配下:

- `skills/` — slash コマンドの薄い adapter。プロジェクト固有値は各 `references/` の profile に分離
- `agents/` — 委譲先サブエージェント（gc-agent / adr-compactor / architecture-sync / refactorer / refactor-guide-sync）
- `hooks/` — トリガーベース自動化（commit 前フォーマット / push 前の秘密検知 + CI 同等検査 / 編集後検査）。外部契約は `.claude/hooks/README.md`
- `rules/` — 常時ロード 1 本（`team-policy.md`）+ paths スコープ 3 本（harness / product / infra）
- `bin/` — hooks 共通ユーティリティ
- `settings.json` — hook 配線の正本

## エージェントフロー

Skill 間の接続のみを示す。各 skill の内部フローは `docs/harness/skills/<name>.md` を正本とする。

```
[Issue 群] → /multi-issue または メインエージェント判断 → open PR → 人間レビュー・マージ（merge で Issue 自動 close）
```

### Issue 番号の直接指示時のトリアージ

`#<issue> 対応して` のように Issue 番号で直接指示された場合（`/multi-issue` の明示呼び出しでない場合）、即座に skill を起動せず次の順で判断する:

1. `gh issue view <number> --json title,body,labels` で Issue を読む（照会規約 → `docs/harness/skills/shared/gh-query-fail-closed.md`）
2. **実装 Issue（新規機能・仕様変更・ハーネス整備・環境整備）は `/multi-issue`** へ振り分ける
3. **バグ修正・リファクタ・小規模変更はメインエージェント判断**（Todo 管理 + TDD）で skill を使わず自律実装する
4. どちらの場合も、着手前に `docs/issues/<number>_<scope>/task-note.md` を作成する（テンプレート → `docs/issues/templates/task-note.md`。運用 → `docs/issues/README.md`）

ユーザーが `/multi-issue` を明示的に呼んだ場合は本トリアージを経ず当該 skill に従う。テストを追加・変更したら PR 前に `/simplify` 相当の簡素化パスを 1 回入れる（→ `docs/styles/team-feedback/refactor-before-pr.md`）。

## skill コマンド一覧

各コマンドの手順正本は `docs/harness/skills/<name>.md`。skill を追加・削除したら本表を同一 PR で更新する。

### core

| コマンド | 用途 |
| --- | --- |
| `/multi-issue #N ...` | 複数 issue を Planner–Worker で並列実装し issue ごとに PR を作成（単一 issue でも可） |
| `/static-check` | 検証ゲート（format:check / lint / typecheck / test / build）を一括実行し表形式で報告 |
| `/create-adr` | 設計判断を ADR として構造的に記録 |
| `/create-issue` | GitHub Issue を作成（読み戻し検証付き。Label・Project 等を自動設定） |
| `/handle-review` | PR レビューコメントを批判的に評価し、自律的に修正・push |
| `/review-cycle` | PR が LGTM になるまで自律ポーリングし、完了を通知 |
| `/promote-memory <name>` | 個人 memory の feedback を team 共有 rule（`docs/styles/team-feedback/`）へ昇格 |
| `/readme-sync` | 各 README を実コードと突合し、乖離を修正する PR を作成 |
| `/docs-sync` | docs「現状層」の鮮度ドリフトと「現状の事実のみ」原則違反を検査し PR を作成 |
| `/code-sync` | ソースコメントを 3 原則・内部参照排除の 2 検査にかけ、修正 PR を作成 |
| `/refactor-guide-sync` | コーディング規約正本とリファクタガイドの検出基準を突合し PR を作成 |
| `/gc-scan` | ハーネス全体のサイズ超過・重複・孤児・デッド参照を検出し、修正を PR で提案 |
| `/adr-compress` | ADR コーパスの肥大化を INDEX 再構築・スタブ化・要約で圧縮する PR を作成 |
| `/security-audit [scope]` | 多次元セキュリティ監査（発見 → 反証検証 → レポート統合 → PR / Issue） |
| `/deploy-verify [env]` | deploy → migrate → smoke の一気通貫検証（手順は bootstrap 時に具体化） |

### opt-in

| コマンド | グループ | 用途 |
| --- | --- | --- |
| `/renovate-sync` | opt-in:renovate | 依存 pin 箇所と Renovate 設定の突合 PR |
| `/public-arch-sync` | opt-in:public-site | 内部設計正本から公開射影ドキュメントへの追従 PR |
| `/customer-doc-review` | opt-in:public-site | 対外ドキュメントの多視点レビュー |

定期実行に載せる skill と頻度は `docs/harness/scheduled-operations.md` の routine カタログを正本とする。

## 承認モデル

> 既定は自律実行とする。エージェントは明示的な指示がない限り、変更の実装から open PR の提出までを自律的に行う。PR のマージは人間の操作だが、明示的に指示された場合はマージまで行ってよい。
> 人間の明示承認が必須なのは次の 2 つのみ: (1) 課金が発生する操作（有償リソースの作成・プラン変更・外部サービス契約） (2) 秘密値の挿入・変更（credential / API key / token を設定へ投入する操作）。
> ブランチモデルは main = dev 環境 / release = prod 環境。main は壊れても復旧可能な開発環境であり、開発過程ではセキュリティより柔軟性を優先する。
> prod リリースのみ手順を踏む: main の安全性確認 → release への反映手順の確認。

## 言語ポリシー

本リポジトリの project language は **{{PROJECT_LANGUAGE}}** とする。skill 正本・agent 定義がレポート言語に言及するときは、本節を正本として参照する（各所に言語名をハードコードしない）。

- ユーザとの会話、docs、Issue / PR 本文、ADR、レビューコメント、sync レポート、runbook は project language を既定とする。
- 次は原文または canonical spelling のまま保持する: コード識別子、API 名、package 名、ファイルパス、JSON キー、commit type、ラベル名、標準エラー、外部仕様名。
- 公式文書の引用タイトル・リンクタイトルは原文を保持し、要約のみ project language で書く。
- ユーザが明示的に別言語を指定した成果物のみ、その言語で書く。

## ブランチ・commit 規約

### ブランチ

- `main` = dev 環境 / `release` = prod 環境（上記承認モデル参照）
- 作業ブランチは常に最新の `origin/main` を起点に切り、変更は Pull Request として提出する
- エージェントの定期実行・sync 系の作業ブランチは `agent/<skill-name>-YYYY-MM-DD`（同日重複は末尾 `-2`）。共通フロー → `docs/harness/skills/shared/sync-pr-flow.md`
- PR body には `Closes #<番号>` 等の closing keyword を記載する（→ `docs/styles/team-feedback/pr-closing-keyword.md`、共通手順 → `docs/harness/skills/shared/pr-creation.md`）

### commit（Conventional Commits）

```
<type>: <subject>

<body>

<footer>
```

| Type | 用途 |
| --- | --- |
| `feat` | 新機能 |
| `fix` | バグ修正 |
| `docs` | ドキュメント変更 |
| `style` | コードの意味に影響しない変更（空白、フォーマット等） |
| `refactor` | リファクタリング（機能追加でもバグ修正でもない） |
| `test` | テストコード追加・修正 |
| `chore` | ビルドプロセスやツール変更 |

ルール:

1. 件名と本文を空行で区切る
2. 件名は 50 文字以内、末尾にピリオドを付けず、命令形で書く
3. 本文は 72 文字で改行
4. 関連 Issue があれば footer に `関連: #<番号>` を記載する
