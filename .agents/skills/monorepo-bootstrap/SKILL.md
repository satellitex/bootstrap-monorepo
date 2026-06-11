---
name: monorepo-bootstrap
description: Codex/Claude両対応で任意のモノレポをbootstrapする。技術選定調査、人間承認、docs運用正本、ハーネス/環境/CI/CD整備、初期実装、deploy検証までを段階実行する
user_invocable: true
---

# Monorepo Bootstrap Skill (Codex / Claude)

任意のプロダクト概要から、実装可能なモノレポを立ち上げる上位オーケストレーション Skill。
この repo の運用を参考に、技術選定、docs 正本、Codex/Claude 両対応ハーネス、環境整備、CI/CD、初期実装、deploy 検証までを人間承認ゲート付きで進める。

bootstrap 先では特定ベンダーの形式に固定しない。
Codex は `AGENTS.md`、Claude は `CLAUDE.md` を薄い入口にし、共通の正本は `docs/` 配下に置く。

## 入力

| 項目 | 必須 | 説明 | 例 |
|------|------|------|----|
| プロダクト概要 | Yes | 誰のどんな課題を解くか、主要機能、想定ユーザ | `/monorepo-bootstrap B2B SaaS の請求照合プロダクト` |
| 制約 | No | 予算、クラウド、既存技術、納期、規制、運用体制 | `Cloudflare 優先、DB は PostgreSQL` |
| 既存リポジトリ | No | 空 repo か、既存コードを含む repo か | `既存 Next.js app あり` |
| deploy 目標 | No | preview / staging / production のどこまで行うか | `staging まで` |

入力が足りない場合は、作業を止めずに仮定を明示して Discovery を始める。
ただし課金・本番 deploy・破壊的 migration・外部公開・GitHub Project 変更を伴う判断は、必ず人間の明確な承認を得る。

## 基本方針

### Codex / Claude 対応

| 領域 | Codex | Claude | 共通化方針 |
|------|-------|--------|------------|
| 常時入口 | `AGENTS.md` | `CLAUDE.md` | どちらも短い pointer にし、詳細は `docs/` に置く |
| Workflow 実行 | Skill 名または明示プロンプト | slash command / Skill | 手順名は tool-neutral にする |
| 作業計画 | plan / Todo / diff | Todo / subagent / diff | 成果物ファイルで引き継ぐ |
| 実装者/評価者分離 | 別セッション、別 reviewer、明示 review pass | subagent / evaluator | 「作る役」と「評価する役」を概念として分ける |
| ローカル規約 | repo の `AGENTS.md` 優先 | repo の `CLAUDE.md` 優先 | 両方ある場合は矛盾しない thin adapter にする |

### 言語ポリシー

この Skill で作成する monorepo は、原則として日本語でやりとりする。
`AGENTS.md` / `CLAUDE.md` / docs 運用正本に「ユーザとの会話、Issue、PR、ADR、review コメント、sync レポート、運用 docs は日本語を既定とする」と明記する。

例外:

- コード識別子、API 名、package 名、commit type、標準エラー、外部仕様名は原文または英語のまま保持する
- public docs、SDK docs、顧客提出物などで英語が明示要求された場合は、その成果物だけ英語にする
- 外部公式 docs の引用・リンクタイトルは原文を保持し、要約は日本語にする

## 成果物

標準では `$BOOTSTRAP_DIR=docs/bootstrap/<project-slug>/` を作り、以下を保存する。
既存 repo の規約がある場合は、その規約に合わせて場所を調整する。

| 成果物 | 内容 |
|--------|------|
| `product-brief.md` | プロダクト概要、ユーザ、ユースケース、非目標、言語方針、制約 |
| `research.md` | 技術調査、一次情報 URL、比較観点、未確定事項 |
| `decision-matrix.md` | 技術選定候補、採否、理由、リスク |
| `harness-catalog.md` | docs 運用、汎用 workflow、sync 系、Issue/Project 運用 |
| `bootstrap-plan.md` | 実装計画、docs/ハーネス/環境/CI/CD/初期機能の Task |
| `implementation-report.md` | 実装結果、検証、deploy URL、残タスク |

必要に応じて以下を読む:

| 参照 | 使う場面 |
|------|----------|
| `references/bootstrap-artifacts.md` | 成果物テンプレートが必要なとき |
| `references/docs-operating-model.md` | docs 配下の層分離・現状層ルール・公開射影を生成するとき |
| `references/generated-workflows.md` | `*-sync` 系、`create-issue`、milestone / Project 管理を生成するとき |
| `references/reference-harness-patterns.md` | この repo 由来のハーネス責務分離を target repo に写像するとき |

## フロー図

```
monorepo-bootstrap <product overview>
  +-- 1. Intake と repo 観察
  +-- 2. 技術調査と候補比較
  +-- Gate A: 技術選定の人間承認
  +-- 3. harness-catalog.md と bootstrap-plan.md 作成
  +-- Gate B: 実装計画の人間承認
  +-- 4. モノレポ基盤作成
  +-- 5. docs 運用正本 + ハーネス整備
  +-- 6. 環境/secret/deploy 下準備
  +-- 7. CI/CD 整備
  +-- 8. 初期実装と品質ゲート
  +-- 9. preview/staging deploy と smoke test
  +-- 10. 完了処理と PR
```

## Step 1: Intake と repo 観察

### 1.1 プロダクト概要の構造化

ユーザ入力から以下を抽出し、`product-brief.md` の draft を作る。

| 観点 | 抽出する内容 |
|------|--------------|
| Problem | 解く課題、現状の代替手段、成功条件 |
| Users | 管理者、エンドユーザ、外部連携先、運用者 |
| Core flows | 最初に動くべき 1-3 個の主要ワークフロー |
| Data | 中心エンティティ、保持期間、機密性、監査要件 |
| Interfaces | Web, API, mobile, batch, webhook, SDK |
| Operations | deploy 頻度、監視、障害対応、権限管理 |
| Constraints | 既存技術、クラウド、予算、規制、納期 |
| Language | 基本は日本語。英語が必要な成果物と例外条件 |

### 1.2 repo 観察

既存 repo なら、README、package/config、CI、infra、docs、既存 app/package を読む。
空 repo なら、GitHub 設定、リモート、利用可能な secrets、deploy 先の前提だけ確認する。

観察結果は `research.md` の「Repository observations」に記録する。

## Step 2: 技術調査と候補比較

最新仕様に依存する判断は、必ず一次情報を確認する。
公式 docs、公式 examples、SDK/CLI reference、価格/制限ページ、信頼できる migration guide を優先する。

比較対象はプロダクト概要から決めるが、最低限以下を検討する。

| 領域 | 比較例 |
|------|--------|
| Monorepo | pnpm/Turborepo, Nx, npm workspaces |
| Runtime | Node.js, Cloudflare Workers, Bun, serverless container |
| Web/API | Next.js, Hono, Fastify, Remix, tRPC, OpenAPI |
| Data | PostgreSQL, SQLite/libSQL, DynamoDB, object storage, queue |
| Auth | managed auth, OAuth/OIDC, API key, internal RBAC |
| Testing | unit, integration, e2e, contract, seed/migration tests |
| CI/CD | GitHub Actions, preview deploy, environment promotion |
| Observability | logs, metrics, traces, error tracking, audit trail |

比較は「一番流行っている」ではなく、制約、運用者のスキル、deploy 先、将来の変更容易性で評価する。
`decision-matrix.md` には採用案だけでなく、棄却案と棄却理由も残す。

## Gate A: 技術選定の人間承認

`decision-matrix.md` を作成したら、実装前にユーザへ以下を提示する。

```
技術選定案を作成しました。

Path: $BOOTSTRAP_DIR/decision-matrix.md
- 推奨スタック: ...
- 代替案: ...
- 主なリスク: ...
- 先に決める必要がある事項: ...

承認 / 修正指示 / 追加調査 のどれで進めるか確認してください。
```

承認なしに依存追加、テンプレート生成、infra 作成へ進まない。
修正指示または追加調査があれば Step 2 に戻り、`research.md` と `decision-matrix.md` を更新する。

## Step 3: harness-catalog.md と bootstrap-plan.md 作成

承認された技術選定をもとに、`harness-catalog.md` と `bootstrap-plan.md` を作る。
テンプレート構造は `references/bootstrap-artifacts.md` を読む。
docs 運用は `references/docs-operating-model.md`、workflow 生成は `references/generated-workflows.md` を参照する。

`harness-catalog.md` には以下を必ず含める:

| セクション | 内容 |
|------------|------|
| Docs operating model | docs 配下の層分離、INDEX、README、公開射影、顧客原本/要約の扱い |
| Workflow inventory | `implement-feature`, `bootstrap-infra`, `static-check`, `create-issue`, `*-sync` 系の採否 |
| Sync scope | README/docs/code/API/public docs/dependency/env/security など、鮮度維持対象 |
| Issue taxonomy | labels, components, priorities, issue types, harness labels |
| Milestones | product roadmap から導いた milestone 一覧と対象範囲 |
| Project model | Project board、fields、status、date field、owner field、magic value の保管先 |
| Tool adapters | Codex と Claude から各 workflow をどう呼ぶか |
| Language policy | 日本語既定、英語例外、Issue/PR/docs の表記方針 |

`bootstrap-plan.md` には以下を必ず含める:

| セクション | 内容 |
|------------|------|
| Scope | bootstrap で作るもの、作らないもの |
| Architecture | apps/packages/infra/docs の構成、境界、依存方向 |
| Docs | docs 正本、4 層モデル、INDEX 更新、公開 docs gate |
| Harness | AGENTS/CLAUDE、workflow、role、rules、hooks、sync 系、issue 管理 |
| Environment | Node/package manager、env files、secret 管理、local dev |
| CI/CD | lint/test/typecheck/build/secret scan/docs gate/deploy/smoke の順序 |
| Implementation | 最初の vertical slice、API/UI/DB/worker 等の単位 |
| Deploy | preview/staging/production の対象、承認、rollback |
| Risks | 技術/運用/セキュリティ/コストのリスクと緩和 |
| Tasks | 順序付き Task、検証コマンド、完了条件 |

## Gate B: 実装計画の人間承認

`harness-catalog.md` と `bootstrap-plan.md` を提示し、承認を得る。

```
bootstrap-plan.md を生成しました。

Path: $BOOTSTRAP_DIR/bootstrap-plan.md
- 作成予定: ...
- docs 運用正本: ...
- 生成する汎用 workflow: ...
- Issue / Project 管理: ...
- CI/CD: ...
- deploy 対象: ...
- 実装順序: ...

この計画で実装に進んでよいですか？
```

承認後は plan を固定する。
実装中の進捗は Todo と PR checklist で管理し、計画変更が必要な場合だけ plan を更新して再承認を取る。

## Step 4: モノレポ基盤作成

承認済み plan の Task 順に実装する。

基本方針:

- package manager、workspace、task runner、TypeScript/config、formatter/linter を先に固定する
- `apps/`, `packages/`, `infra/`, `docs/`, `scripts/` の境界を明確にする
- 最初から full-stack を広げすぎず、deploy 可能な vertical slice を 1 本作る
- 共有設定は `packages/config` などに集約し、各 app/package の差分を小さくする
- generated code と手書き code の境界を README または docs に明記する

## Step 5: docs 運用正本 + ハーネス整備

`references/docs-operating-model.md` と `references/reference-harness-patterns.md` を読み、先に docs の置き場所・鮮度維持ルールを作り、その上に Codex/Claude adapter と workflow を載せる。

### 5.1 docs 正本を作る

target repo の `docs/` は、この repo と同じ責務分離を保つ。

| 領域 | 目的 |
|------|------|
| `docs/README.md` | docs ナレッジハブ。置き場所と INDEX 更新ルール |
| `docs/product/` | 現状層。ARCHITECTURE / TECH_STACK / INFRA / TERMS / API_FLOWS 等 |
| `docs/product/adr/` | 決定層。技術選定理由、代替案、撤回・置換履歴 |
| `docs/notes/research/` | 調査層。候補比較、外部規格、一次情報サマリ |
| `docs/product/issues/` | 実装計画層。Issue ごとの inception / construction / plan |
| `docs/requirements/` | 要件正本。人間承認で管理し、AI 自動編集対象外 |
| `docs/customer/` | 顧客原本と要約。originals と summaries を分離 |
| `docs/runbooks/` | 運用手順、secret、deploy、incident 対応 |
| `docs/styles/` | コーディング、docs、security、testing、harness authoring 規約 |
| `docs/operations/` | docs site や運用データの永続正本 |

現状層には「今こうなっている」事実だけを書く。
技術選定理由は ADR、候補比較は research、Issue 固有計画は `docs/product/issues/`、README は `/readme-sync` 相当の責務に分ける。

### 5.2 docs 鮮度維持 workflow を作る

product brief と `harness-catalog.md` に従い、必要な `*-sync` を生成する。

| Workflow | 責務 |
|----------|------|
| `readme-sync` | 各 README と近傍コードの整合 |
| `docs-sync` | 現状層 docs と実コード・設定・要件の鮮度、No-Time / No-Ticket / No-Counterfactual |
| `code-sync` | ソースコメントの現状層原則と公開 doc-style コメントの内部参照排除 |
| `public-docs-sync` | 内部正本から顧客/外部公開版への射影、内部名・内部 ID リーク検出 |
| `dependency-sync` | Renovate/Dependabot の pin 漏れ、cross-manager drift、未管理 pin |
| `env-sync` | `.env.example`、secret docs、deploy bindings、provider config の整合 |
| `api-schema-sync` | OpenAPI/GraphQL/protobuf 等と SDK/docs/test の整合 |
| `security-sync` | secret scan、authz docs、audit controls、依存 alert の運用整合 |

`*-sync` は全て作らない。該当 surface があるものだけ作る。
各 sync は source of truth、比較対象、auto-edit 範囲、report/PR 方針を明示する。

### 5.3 Codex / Claude adapter を作る

| ファイル/領域 | 目的 |
|---------------|------|
| `AGENTS.md` | Codex 用 thin adapter。docs 正本、主要 workflow、ブランチ/PR 運用への pointer |
| `CLAUDE.md` | Claude 用 thin adapter。`AGENTS.md` と同じ共通正本への pointer |
| `docs/harness/OPERATING_MODEL.md` | Codex / Claude 共通の作業フロー、承認ゲート、品質基準 |
| `docs/harness/LANGUAGE_POLICY.md` | 日本語既定の会話・Issue・PR・ADR・sync レポート運用 |
| `docs/harness/skills/*.md` | tool-neutral な workflow 手順 |
| `docs/harness/roles/*.md` | generator/evaluator/mapper/sync などの role 定義 |
| `docs/harness/rules/` | セキュリティ、コメント、依存方向、docs 鮮度 |
| `docs/harness/project-management.md` | milestone、Project、fields、status、date、relationship の運用正本 |
| `docs/harness/references/project-fields.md` | GitHub Project ID / field ID など推論不能な magic value |

`AGENTS.md` と `CLAUDE.md` に同じ詳細手順を二重管理しない。
Claude slash command や subagent 定義を作る場合でも、共通正本を複製せず adapter 側から参照する。
Codex では同じ手順を Skill 名、明示プロンプト、または `AGENTS.md` の運用フローとして呼び出せるようにする。

### 5.4 Issue / Project 管理を作る

`create-issue` は product taxonomy から生成する。
GitHub Project / milestone を実作成または更新する場合は、`harness-catalog.md` の taxonomy を提示して人間承認を得てから実行する。
Project ID / field ID は推測せず、作成後または既存 Project 確認後に `docs/harness/references/project-fields.md` へ記録する。

## Step 6: 環境/secret/deploy 下準備

`.env.example`、local dev、seed、migration、secret 登録手順を整える。
secret 値そのものは repo に書かない。

deploy は段階を分ける。

| 段階 | 条件 |
|------|------|
| preview | CI と build が通り、公開してもよいダミーデータだけを使う |
| staging | secrets と外部サービスが設定済みで、smoke test が自動実行できる |
| production | ユーザの明示承認、rollback 手順、監視、アラートがある |

production deploy は bootstrap の既定スコープ外にする。
ユーザが明示した場合のみ、リスクと rollback を提示して承認を取る。

## Step 7: CI/CD 整備

CI は最初から PR gate として使える状態にする。

推奨順序:

1. install/cache
2. format:check
3. lint
4. typecheck
5. unit/integration test
6. build
7. migration/contract/schema check
8. docs gate
9. secret scan
10. preview deploy
11. smoke test

monorepo の差分実行を入れる場合も、main branch では全体検証を残す。
CI が失敗する既知理由を許容する場合は、issue と期限を残す。

## Step 8: 初期実装と品質ゲート

最初の vertical slice を実装する。
例: 認証なし health endpoint、最小 DB migration、1 画面、1 API、1 deploy smoke など。

実装の完了条件:

- local で `format:check`, `lint`, `typecheck`, `test`, `build` が通る
- docs gate と secret scan が CI に入っている
- CI が同じ品質ゲートを実行する
- smoke test が deploy 先で通る
- README または docs に local dev と deploy 手順がある
- ハーネスが次の Issue 実装を自律実行できる入力/出力を持つ

## Step 9: deploy と smoke test

承認済み deploy 目標に従い、preview または staging へ deploy する。
deploy URL、commit SHA、環境名、smoke 結果を `implementation-report.md` に記録する。

失敗時は原因を分類する。

| 分類 | 対応 |
|------|------|
| code | 修正して local/CI を再実行 |
| config | secret/env/binding を修正し、値は記録しない |
| provider | 公式 status/docs を確認し、retry か代替案を提示 |
| scope | bootstrap 外なら残タスクに切り出す |

## Step 10: 完了処理と PR

完了時に以下を実行する。

1. `implementation-report.md` を更新
2. 変更ファイルと検証結果を要約
3. Conventional Commits 形式で commit
4. ユーザまたは repo 規約が要求する場合のみ branch を push
5. push 済みなら PR を作成し、bootstrap artifacts、検証、deploy URL、残リスクを body に記載

既存 repo に PR 作成規約があればそれに従う。
この repo では `.claude/skills/shared-references/references/pr-creation.md` を読む。

## 制約

- 技術選定と実装計画は、それぞれ人間承認を得てから次段階へ進む
- 最新仕様、価格、制限、deploy 手順は推測しない。一次情報を確認する
- secrets、tokens、本番データ、個人情報を repo に書かない
- production deploy、課金リソース作成、破壊的 migration は明示承認なしに実行しない
- GitHub Project / milestone / labels / issue 作成は明示承認なしに実行しない
- ハーネスは過剰に作らない。最初の 1-2 個の反復で使う workflow/role から始める
- target repo の既存規約がある場合は、この Skill より repo 規約を優先する

## Self-check

- [ ] `product-brief.md` にユーザ、core flows、制約、非目標がある
- [ ] `product-brief.md` と docs 運用正本に日本語既定の言語ポリシーがある
- [ ] `research.md` に一次情報 URL と repo 観察がある
- [ ] `decision-matrix.md` に採用/棄却理由とリスクがある
- [ ] `harness-catalog.md` に docs 層分離、sync 系、create-issue、milestone / Project 管理の採否がある
- [ ] Gate A/B の承認ログがある
- [ ] `bootstrap-plan.md` が docs、環境、CI/CD、deploy、ハーネス、初期実装を含む
- [ ] local 品質ゲートと CI が同じ主要チェックを実行する
- [ ] deploy URL と smoke test 結果が `implementation-report.md` にある
- [ ] PR body に artifacts、検証結果、残リスクがある
