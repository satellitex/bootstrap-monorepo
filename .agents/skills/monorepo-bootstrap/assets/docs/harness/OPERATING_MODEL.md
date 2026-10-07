# 運用モデル（neutral 正本）

この文書はリポジトリ運用の tool-neutral な正本であり、`AGENTS.md` / `CLAUDE.md` 両 adapter から参照される。docs の正本 pointer・ハーネス構成・領域別 rule の読み場面・ツール固有手段の読み替え・エージェントフロー・skill コマンド一覧・承認モデル・言語ポリシー・ブランチ / commit / ラベル規約を定める。個別 skill の手順本文は `docs/harness/skills/` に置き、ここには書かない。

## プロダクト

{{PRODUCT_NAME}} — TODO(記入方法: 導入時の依頼内容から、プロダクトの目的と主な利用者を 1 行で書く)

## docs 正本 pointer 集

| 内容                                     | 正本                                                         |
| ---------------------------------------- | ------------------------------------------------------------ |
| docs 全体マップ                          | `docs/README.md`                                             |
| 要件（一覧 / 運用）                      | `docs/requirements/INDEX.md` / `docs/requirements/README.md` |
| ADR（運用 / 一覧）                       | `docs/adr/README.md` / `docs/adr/INDEX.md`                   |
| 内部設計                                 | `docs/product/ARCHITECTURE.md`                               |
| 技術スタック                             | `docs/product/TECH_STACK.md`                                 |
| ドメイン用語集                           | `docs/product/TERMS.md`                                      |
| テスト戦略                               | `docs/product/TEST_STRATEGY.md`                              |
| API 契約バージョニング（opt-in）         | `docs/product/API_VERSIONING.md`                             |
| traceability matrix（opt-in）            | `docs/product/tests/README.md`                               |
| コーディング規約                         | `docs/styles/coding_guide/INDEX.md`                          |
| チーム共有 rule                          | `docs/styles/team-feedback/INDEX.md`                         |
| リファクタ運用                           | `docs/styles/refactoring_guide.md`                           |
| runbook（一覧 / 書き方）                 | `docs/runbooks/INDEX.md` / `docs/runbooks/README.md`         |
| 調査ノート                               | `docs/notes/README.md`                                       |
| 外部監査レポート                         | `docs/audit/README.md`                                       |
| インシデント記録（opt-in）               | `docs/postmortems/README.md`（様式は `docs/templates/`）     |
| INDEX の更新主体                         | `docs/harness/skills/shared/index-writer-policy.md`          |
| 定期運用（routine / 定期 workflow 設計） | `docs/harness/scheduled-operations.md`                       |
| ハーネス文書の書き方規約                 | `docs/harness/harness_authoring_guide.md`                    |

opt-in の行は、採用したグループの分だけを置く。

## ハーネス構成

正本と adapter の 2 層で管理する:

- **neutral 正本**: 手順・判断基準は tool-neutral に `docs/harness/` へ置く。skill 手順は `docs/harness/skills/<name>.md`、skill 固有の詳細（圧縮規則・出力形式など）は同名ディレクトリの `docs/harness/skills/<name>/<topic>.md`、skill 横断の共通契約は `docs/harness/skills/shared/<topic>.md`（sync 系専用は `sync-` 接頭辞。一覧は同ディレクトリ）。
- **thin adapter**: `AGENTS.md` / `CLAUDE.md` / `.claude/skills/<name>/SKILL.md` は正本への参照だけを持つ薄い入口とし、詳細手順を二重管理しない。

`.claude/` 配下:

- `skills/` — slash コマンドの薄い adapter。プロジェクト固有値は各 `references/` の profile に分離
- `agents/` — 委譲先サブエージェント（gc-agent / adr-compactor / architecture-sync / refactorer / refactor-guide-sync）
- `hooks/` — トリガーベース自動化（commit 前フォーマット / push 前の秘密検知 + CI 同等検査 / 編集後検査）。外部契約は `.claude/hooks/README.md`
- `rules/` — 常時ロード 1 本（`team-policy.md`）+ paths スコープ 3 本（harness / product / infra）
- `bin/` — hooks 共通ユーティリティ
- `settings.json` — hook 配線の正本

機械検査は `tests/harness/` に置く。`pnpm harness:test` で実行し、CI が全 PR に対して実行する（検査の範囲と追加手順 → `tests/harness/README.md`「検査一覧」）。

## 領域別 rule の読み場面

rule 本文は `.claude/rules/` に置く。Claude Code は `paths:` を持つ rule を該当ファイルの編集時に、持たない rule を全セッションでロードする。自動ロードを持たない実行環境では、作業の場面に応じて次の表の rule を読む。

| rule                                   | スコープ                             | 読む場面                                                      |
| -------------------------------------- | ------------------------------------ | ------------------------------------------------------------- |
| `.claude/rules/team-policy.md`         | 全領域                               | 常時。作業を始める前に読む（横断判断 rule の pointer 層）     |
| `.claude/rules/harness-development.md` | `.claude/**/*` / `docs/harness/**/*` | ハーネス（skill・agent・hook・rules・運用正本）を編集するとき |
| `.claude/rules/product-development.md` | `apps/**/*` / `packages/**/*`        | プロダクトコードを編集するとき                                |
| `.claude/rules/infra-development.md`   | `infra/**/*`                         | インフラコードを編集するとき（IaC を採用した導入先のみ）      |

rule を追加・削除したら、本表を同一 PR で更新する。

## ツール固有手段の読み替え

手順正本は tool-neutral に書く。Claude Code 固有の手段が出てくる箇所は、次のとおり読み替える。

| 手段                           | Claude Code                                                                                                                              | それ以外のエージェント                                                                                                                                                          |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| slash コマンド・skill 起動     | `/<name>` で `.claude/skills/<name>/SKILL.md` が起動する                                                                                 | `docs/harness/skills/<name>.md` を手順書として読み、同じ成果物規定に従う。固有値は `.claude/skills/<name>/references/` の profile                                               |
| タスク管理（TodoWrite など）   | 組み込みのタスク管理 tool                                                                                                                | 利用できる計画機能で、同等の進捗管理を行う                                                                                                                                      |
| 対話での確認（質問 tool など） | 質問 tool で確認できる。無人 run では、質問 tool や許可リストにない tool の呼び出しで run が止まる場合があるため、呼ばずに代替経路へ進む | 既定が自律実行のため待たない。保守的な既定で進め、判断を PR 本文に記録する（承認必須は課金・秘密値のみ）。無人 run の扱いは `docs/harness/skills/shared/unattended-contract.md` |
| subagent の起動                | Agent tool の `subagent_type` に agent 名を指定して起動する（指定は各 skill の adapter の注記に置く）                                    | 同一セッション内の独立した pass、別スレッド、逐次実行のいずれかで、作る役と評価する役を分ける                                                                                   |
| hooks（`.claude/hooks/`）      | commit 前の整形・push 前の秘密検知と `gate:push`・編集後検査が自動で走る                                                                 | 発火しない。commit / push の前に `gate:commit` と秘密検知（`.claude/hooks/pre-push-ci-check.sh` が実行する gitleaks の検査）を手動で実行する。全経路に効く最終ゲートは CI       |
| MCP tool                       | 登録済みの tool を使う                                                                                                                   | 使えなければ `gh` CLI など同等の手段で代替する（経路の切替 → `docs/harness/skills/shared/gh-query-fail-closed.md`）                                                             |

skill を経由しない作業でも、次の規定は変わらない: commit 前の format（→ `docs/styles/team-feedback/format-check.md`）、PR 前の簡素化パス（→ `docs/styles/team-feedback/refactor-before-pr.md`）、検証ゲート通過後の push（→ `docs/harness/skills/shared/verification-gates.md`）。

## エージェントフロー

Skill 間の接続のみを示す。各 skill の内部フローは `docs/harness/skills/<name>.md` を正本とする。

```
[Issue 群] → /multi-issue または メインエージェント判断 → open PR → 人間レビュー・マージ（merge で Issue 自動 close）
```

### Issue 番号の直接指示時のトリアージ

`#<issue> 対応して` のように Issue 番号で直接指示された場合は、Issue を読んでから実装フローを振り分ける（→ `docs/styles/team-feedback/implementation-flow-switch.md`「判定」）。

### 実装 PR の作法

- 計画・判断・検証結果は、PR 本文の標準節、commit メッセージ、設計判断の ADR に残す。Issue 単位の別成果物は作らない（標準節 → `docs/harness/skills/shared/pr-creation.md`「PR 本文の標準節」）
- 解決策は 1 案に確定して書く（→ `docs/styles/team-feedback/single-solution.md`）
- 既存の `INDEX.md` は実装 PR で編集しない。更新主体は割当表に従う（→ `docs/harness/skills/shared/index-writer-policy.md`）

## skill コマンド一覧

各コマンドの手順正本は `docs/harness/skills/<name>.md`。skill を追加・削除したら本表を同一 PR で更新する。

### core

| コマンド                      | 用途                                                                                                                           |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `/multi-issue #N ...`         | 複数 issue を Planner–Worker で並列実装し issue ごとに PR を作成（単一 issue でも可）                                          |
| `/create-adr`                 | 設計判断を ADR として構造的に記録（既存 ADR の置換・廃止を含む）                                                               |
| `/create-issue`               | GitHub Issue を作成（読み戻し検証付き。Label・Project 等を自動設定）                                                           |
| `/handle-review`              | PR レビューコメントを批判的に評価し、自律的に修正・push                                                                        |
| `/review-cycle`               | PR が LGTM になるまで、レビュー対応・conflict 解消・CI 修正を自律で繰り返し、終了を通知                                        |
| `/promote-memory <name>`      | 個人 memory の feedback を team 共有 rule（`docs/styles/team-feedback/`）へ昇格                                                |
| `/readme-sync`                | 各 README を実コードと突合し、乖離を修正する PR を作成                                                                         |
| `/docs-sync`                  | docs「現状層」の鮮度ドリフト・実装との内容矛盾・「現状の事実のみ」原則違反を検査し、INDEX の行を実ファイルに合わせる PR を作成 |
| `/code-sync`                  | ソースコメントを 3 原則・内部参照排除・実装整合の 3 検査にかけ、コメントのみの修正 PR を作成                                   |
| `/refactor-guide-sync`        | コーディング規約正本とリファクタガイドの検出基準を突合し PR を作成                                                             |
| `/refactor-sync`              | リファクタ観点を検出し、観点ごとの提案 Issue を最大 3 件起票（コードは変更しない）                                             |
| `/gc-scan`                    | ハーネス全体の重複・孤児・デッド参照を検出し、修正を PR で提案（機械検査で判定できる項目は対象外）                             |
| `/adr-compress`               | ADR の Status 追従・INDEX 再構築・stub 化・要約を 1 PR にまとめる                                                              |
| `/runbook-alignment [手順書]` | 手順書の未確定事項を実装と照合し、差異評価表を PR 本文に出して本文を修正                                                       |
| `/deploy-verify [env]`        | デプロイ一気通貫と release 反映（prod は release 反映 PR の作成からマージ後の確認まで）。手順は bootstrap 時に具体化           |

### opt-in

| コマンド               | グループ           | 用途                                            |
| ---------------------- | ------------------ | ----------------------------------------------- |
| `/renovate-sync`       | opt-in:renovate    | 依存 pin 箇所と Renovate 設定の突合 PR          |
| `/public-arch-sync`    | opt-in:public-site | 内部設計正本から公開射影ドキュメントへの追従 PR |
| `/customer-doc-review` | opt-in:public-site | 対外ドキュメントの多視点レビュー                |

opt-in の行は、採用したグループの分だけを置く。定期実行に載せる skill と頻度は `docs/harness/scheduled-operations.md` の routine カタログを正本とする。

## 承認モデル

> 既定は自律実行とする。エージェントは明示的な指示がない限り、変更の実装から open PR の提出までを自律的に行う。PR のマージは人間の操作だが、明示的に指示された場合はマージまで行ってよい。
> 人間の明示承認が必須なのは次の 2 つのみ: (1) 課金が発生する操作（有償リソースの作成・プラン変更・外部サービス契約） (2) 秘密値の挿入・変更（credential / API key / token を設定へ投入する操作）。
> ブランチモデルは main = dev 環境 / release = prod 環境。main は壊れても復旧可能な開発環境であり、開発過程ではセキュリティより柔軟性を優先する。
> prod リリースのみ手順を踏む: main の安全性確認 → release への反映手順の確認（→ `docs/harness/skills/deploy-verify.md`）。

### 人間引き渡し境界（既定: なし）

人間へ引き渡す範疇を導入先が定める小節である。既定は「なし」で、課金・秘密値以外の判断は、エージェントが 1 案に確定して進める（→ `docs/styles/team-feedback/single-solution.md`）。導入先が境界を設けるときは、下表に記入する。選んだ案が下表の区分に当たる場合に限り、案と根拠を記録して人間へ引き渡す（扱いは実行モードによる → `docs/harness/skills/shared/unattended-contract.md`）。課金・秘密値の承認は本小節とは別に、常に人間が行う。

| 区分     | 内容                                                                                                                                                              |
| -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| （なし） | TODO(記入方法: 公開契約の非互換・個人情報の取扱いの変更など、PR のレビューだけでは覆しにくい判断を、導入先の事情に合わせて列挙する。不要なら「なし」のままにする) |

## 言語ポリシー

本リポジトリの project language は **{{PROJECT_LANGUAGE}}** とする。skill 正本・agent 定義がレポート言語に言及するときは、本節を正本として参照する（各所に言語名をハードコードしない）。

- ユーザとの会話、導入後に書く docs、Issue / PR 本文、ADR、レビューコメント、sync レポート、runbook は project language を既定とする。
- 導入した運用文書（`docs/harness/` や `docs/styles/` など、テンプレート由来の文書）は収録言語（日本語）のまま使う。翻訳するのは、導入の依頼で翻訳が明示された場合だけである。翻訳しても、識別子・パス・コマンド・TODO 記法・表構造・見出し・token は保持し、翻訳しない決定は PR 本文に記録する。
- 次は原文または canonical spelling のまま保持する: コード識別子、API 名、package 名、ファイルパス、JSON キー、commit type、ラベル名、標準エラー、外部仕様名。
- 公式文書の引用タイトル・リンクタイトルは原文を保持し、要約のみ project language で書く。
- ユーザが明示的に別言語を指定した成果物のみ、その言語で書く。

## ブランチ・commit・ラベル規約

### ブランチ

- `main` = dev 環境 / `release` = prod 環境（上記承認モデル参照）
- 作業ブランチは常に最新の `origin/main` を起点に切り、変更は Pull Request として提出する。PR の base は常に既定ブランチで、draft にしない（→ `docs/harness/skills/shared/pr-creation.md`）
- エージェントの定期実行・sync 系の作業ブランチは `agent/<skill-name>-YYYY-MM-DD`（同日重複は末尾 `-2`）。共通フロー → `docs/harness/skills/shared/sync-pr-flow.md`
- PR body には `Closes #<番号>` 等の closing keyword を記載する（→ `docs/styles/team-feedback/pr-closing-keyword.md`）

### commit（Conventional Commits）

```
<type>(<scope>): <subject>

<body>

<footer>
```

type は `feat`（新機能）/ `fix`（バグ修正）/ `docs`（ドキュメント変更）/ `style`（意味に影響しない変更）/ `refactor`（機能追加でもバグ修正でもない）/ `test`（テストの追加・修正）/ `ci`（CI 設定の変更）/ `build`（ビルド・依存の変更）/ `chore`（ビルドプロセスやツール変更）のいずれか。`(<scope>)` は任意で、変更の対象領域（例: `docs(harness)`）を示す。

1. 件名と本文を空行で区切る
2. 件名は 50 文字以内、末尾にピリオドを付けず、命令形で書く
3. 本文は 72 文字で改行
4. 関連 Issue があれば footer に `関連: #<番号>` を記載する

### ラベル

- sync 系 skill が作る PR・Issue には、routine 起点を示すラベル `routine:<skill-name>` を付ける。起動が routine でも人間の直接起動でも付け、人間が手で起票した Issue には付けない。一覧は `.claude/skills/create-issue/references/project-fields.md` を唯一の正本とする
- 存在しないラベルを指定すると `gh` が非ゼロ終了するため、ラベルは routine の登録より前に作成する。作成は人間または bootstrap 時に行い、skill は作らない（→ `docs/harness/scheduled-operations.md`）
- 付与は PR / Issue の作成後に別コマンドで行う（→ `docs/harness/skills/shared/sync-pr-flow.md`）
