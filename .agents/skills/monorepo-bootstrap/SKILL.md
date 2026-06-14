---
name: monorepo-bootstrap
description: Codex/Claude両対応で任意のモノレポをbootstrapする。技術選定調査、人間承認、docs運用正本、ハーネス/環境/CI/CD整備、初期実装、deploy検証までを段階実行する
user_invocable: true
---

# Monorepo Bootstrap Skill (Codex / Claude)

任意のプロダクト概要から、実装可能なモノレポを立ち上げる上位オーケストレーション Skill。
特定 project、業務ドメイン、cloud provider、runtime、CSS framework に固定せず、技術選定、docs 正本、Codex/Claude 両対応ハーネス、環境整備、CI/CD、初期実装、deploy 検証までを人間承認 gate 付きで進める。

bootstrap 先では vendor/tool 固有の手順を入口ファイルへ閉じ込めない。
Codex は `AGENTS.md`、Claude は `CLAUDE.md` を薄い adapter にし、共通の運用正本は `docs/harness/` と `docs/product/` 配下に置く。

## 入力

| 項目 | 必須 | 説明 | 例 |
|------|------|------|----|
| Product overview | Yes | 誰のどんな課題を解くか、主要機能、想定ユーザ | `/monorepo-bootstrap B2B SaaS の請求照合プロダクト` |
| Constraints | No | 予算、cloud/provider 制約、既存技術、納期、規制、運用体制 | `組織標準 provider 優先、DB は PostgreSQL` |
| Existing repository | No | 空 repo か、既存コードを含む repo か | `既存 Next.js app あり` |
| Deploy goal | No | preview / staging / production のどこまで行うか | `staging まで` |
| Project language | No | Issue / PR / ADR / docs / review comment の既定言語 | `日本語`, `English` |

入力が足りない場合は、作業を止めずに仮定を明示して Discovery を始める。
ただし課金 resource 作成、本番 deploy、破壊的 migration、外部公開、remote GitHub mutation は、必ず人間の明確な承認を得る。

## 基本方針

### Provider / Runtime Neutrality

- template は特定 provider、runtime model、database、storage、queue/workflow、auth、observability、CI/CD provider を既定採用として書かない。
- user が provider や既存技術の制約を指定した場合だけ、その選択肢を優先候補として比較する。
- user が指定していない場合は、複数 provider / runtime option を比較し、Gate A で推奨案と代替案を提示する。
- provider 固有の CLI、binding、secret、deploy 手順は、template 本体へ直書きせず、target repo の `docs/runbooks/`、`docs/harness/skills/bootstrap-infra.md`、または provider-specific reference へ分離する。
- 最新仕様、価格、制限、deploy behavior、CLI option、CI/CD syntax に依存する判断は一次情報を確認し、URL と確認日を `research.md` に残す。

### Codex / Claude 対応

| 領域 | Codex | Claude | 共通化方針 |
|------|-------|--------|------------|
| 常時入口 | `AGENTS.md` | `CLAUDE.md` | どちらも短い pointer にし、詳細は `docs/` に置く |
| Workflow 実行 | Skill 名または明示プロンプト | slash command / Skill | 手順名は tool-neutral にする |
| 作業計画 | plan / Todo / diff | Todo / subagent / diff | 成果物ファイルで引き継ぐ |
| 実装者/評価者分離 | 別セッション、別 reviewer、明示 review pass | subagent / evaluator | 「作る役」と「評価する役」を概念として分ける |
| ローカル規約 | repo の `AGENTS.md` 優先 | repo の `CLAUDE.md` 優先 | 両方ある場合は矛盾しない thin adapter にする |

### Language Policy

template 側で言語を固定しない。
Intake で project language を確認し、`product-brief.md`、`docs/harness/LANGUAGE_POLICY.md`、Issue / PR / ADR / review comment / docs / sync report の既定言語へ反映する。

言語に関係なく、次は原文または canonical spelling を保持する。

- code identifiers
- API 名
- package 名
- JSON keys
- commit type
- 標準エラー
- 外部仕様名
- 公式 docs の引用タイトルやリンクタイトル

## 成果物

bootstrap の成果物は、継続運用に入ったら `docs/product/issues/000-bootstrap/` を "Issue 0" として扱う。
一時調査を `docs/bootstrap/<project-slug>/` に置いた場合でも、Gate B までに `docs/product/issues/000-bootstrap/` へ統合し、`docs/bootstrap/` を恒久的な正本として残し続けない。
既存 repo の規約がある場合は、その規約を優先し、配置理由を `bootstrap-plan.md` に残す。

| 成果物 | 既定配置 | 内容 |
|--------|----------|------|
| `product-brief.md` | `docs/product/issues/000-bootstrap/` | product overview、user、core flows、non-goals、language policy、constraints |
| `research.md` | `docs/product/issues/000-bootstrap/` and/or `docs/notes/research/` | 技術調査、一次情報 URL、比較観点、未確定事項 |
| `decision-matrix.md` | `docs/product/issues/000-bootstrap/` | 技術選定候補、採否、理由、運用リスク、cost/limits、local dev 影響 |
| `harness-catalog.md` | `docs/product/issues/000-bootstrap/` | docs 運用、workflow、Issue/Project 運用、adapter 方針 |
| `bootstrap-plan.md` | `docs/product/issues/000-bootstrap/` | 実装計画、docs/ハーネス/環境/CI/CD/deploy/初期機能の Task |
| `implementation-report.md` | `docs/product/issues/000-bootstrap/` | 実装結果、検証、deploy URL、残タスク |

必要に応じて以下を読む。
Skill 本体は orchestration に限定し、詳細 checklist と template は references を正本にする。

| 参照 | 使う場面 |
|------|----------|
| `references/bootstrap-artifacts.md` | 成果物テンプレートが必要なとき |
| `references/technology-selection.md` | Gate A の比較範囲、infrastructure service selection、app topology、CSS/UI stack 選定を作るとき |
| `references/docs-operating-model.md` | docs 配下の層分離、Issue 0、adapter 配置、公開射影を生成するとき |
| `references/issue-lifecycle.md` | issue taxonomy、issue-local docs、ADR 要否、draft PR approval gate を作るとき |
| `references/generated-workflows.md` | `*-sync` 系、`create-issue`、milestone / Project 管理を生成するとき |
| `references/ci-cd-runner-deploy.md` | CI/CD、self-hosted runner、deploy strategy、runbook を設計するとき |
| `references/reference-harness-patterns.md` | この repo 由来のハーネス責務分離を target repo に写像するとき |

## フロー図

```text
monorepo-bootstrap <product overview>
  +-- 1. Intake と repo 観察
  +-- 2. 技術調査と候補比較
  +-- Gate A: 技術選定、人間承認
  +-- 3. harness-catalog.md と bootstrap-plan.md 作成
  +-- Gate B: 実装計画、人間承認
  +-- 4. モノレポ基盤作成
  +-- 5. docs 運用正本、ハーネス、issue lifecycle 整備
  +-- 6. 環境、secret、deploy 下準備
  +-- 7. CI/CD と runner 運用整備
  +-- 8. 初期実装と品質 gate
  +-- 9. preview/staging deploy と smoke test
  +-- 10. 完了処理と PR
```

## Step 1: Intake と repo 観察

### 1.1 Product overview の構造化

ユーザ入力から以下を抽出し、`product-brief.md` の draft を作る。

| 観点 | 抽出する内容 |
|------|--------------|
| Problem | 解く課題、現状の代替手段、成功条件 |
| Users | 管理者、エンドユーザ、外部連携先、運用者 |
| Core flows | 最初に動くべき 1-3 個の主要 workflow |
| Data | 中心 entity、保持期間、機密性、監査要件 |
| Interfaces | Web, API, mobile, batch, webhook, SDK, external agent |
| Operations | deploy 頻度、監視、障害対応、権限管理 |
| Constraints | 既存技術、provider 制約、予算、規制、納期 |
| Language | project language、英語/日本語などの例外条件 |

### 1.2 Repo 観察

既存 repo なら、README、package/config、CI、infra、docs、既存 app/package を読む。
空 repo なら、GitHub 設定、remote、利用可能な secrets、deploy 先の前提だけ確認する。

観察結果は `research.md` の "Repository observations" に記録する。

## Step 2: 技術調査と候補比較

`references/technology-selection.md` を読み、`research.md` と `decision-matrix.md` を作る。
最新仕様に依存する判断は、必ず一次情報を確認する。
公式 docs、公式 examples、SDK/CLI reference、価格/制限ページ、信頼できる migration guide を優先する。

Gate A までに、少なくとも以下を比較する。

| 領域 | 必須確認 |
|------|----------|
| App framework / language / monorepo tool | framework、language/runtime、package manager、task runner、workspace 境界 |
| Deploy / hosting provider | provider 候補、preview/staging/prod support、region、cost、limits、rollback |
| Runtime model | server、serverless、edge、container、hybrid の適合性 |
| Database | data model、migration、backup、local dev、connection/runtime 制約 |
| Object/file storage | upload/download、signed URL、retention、local mock |
| Cache | consistency、TTL、invalidation、runtime locality |
| Queue / workflow / job orchestration | retry、DLQ、schedule、durability、visibility |
| Long-running task handling | timeout、checkpoint、resume、human approval、cancel/retry |
| External agent / worker runtime boundary | trust boundary、permissions、network/file access、audit |
| Auth / identity | session boundary、OAuth/OIDC、RBAC、tenant/workspace |
| Observability | logs、metrics、traces、error tracking、audit trail |
| CI/CD provider and deployment strategy | CI provider、branch deploy、environment promotion、required checks |
| CSS / UI styling strategy | UI がある場合。CSS Modules、Tailwind、Panda CSS、vanilla-extract、framework-native styling 等 |

各領域で、`decision-matrix.md` に「採用案」「代替案」「棄却理由」「運用リスク」「cost/limits」「local dev 影響」を残す。
UI がある project では CSS / styling strategy の採用判断を ADR 化する。

### App Topology Selection

`apps/web`, `apps/api`, `apps/workers`, `apps/jobs`, `apps/workflows` などの分割を機械的に決めない。
次を比較し、`decision-matrix.md` または ADR に残す。

- UI と server-side route の結合度
- deploy 単位
- scaling 単位
- auth/session 境界
- external API と internal route の違い
- tenant/workspace ごとの domain route の自然さ
- long-running / async 処理の責務分離

## Gate A: 技術選定の人間承認

`decision-matrix.md` を作成したら、依存追加、scaffold、infra 作成の前にユーザへ提示する。

```text
技術選定案を作成しました。

Path: <bootstrap-dir>/decision-matrix.md
- 推奨 stack:
- Infrastructure service selection:
- App topology:
- CSS/UI strategy:
- 代替案:
- 主なリスク:
- 先に決める必要がある事項:

承認 / 修正指示 / 追加調査 のどれで進めるか確認してください。
```

Gate A は、infrastructure service selection と app topology selection を必ず含む。
user が provider を指定していない場合は、複数 provider / runtime option を比較した上で推奨案を提示する。
承認なしに依存追加、テンプレート生成、infra 作成へ進まない。
修正指示または追加調査があれば Step 2 に戻り、`research.md` と `decision-matrix.md` を更新する。

## Step 3: harness-catalog.md と bootstrap-plan.md 作成

承認された技術選定をもとに、`harness-catalog.md` と `bootstrap-plan.md` を作る。

参照順:

1. `references/bootstrap-artifacts.md`
2. `references/docs-operating-model.md`
3. `references/issue-lifecycle.md`
4. `references/generated-workflows.md`
5. `references/ci-cd-runner-deploy.md`
6. `references/reference-harness-patterns.md`

`harness-catalog.md` には以下を必ず含める。

| セクション | 内容 |
|------------|------|
| Docs operating model | `docs/harness/` と `docs/product/` の層分離、INDEX、README、公開射影、Issue 0 |
| Workflow inventory | `implement-feature`, `bootstrap-infra`, `static-check`, `create-issue`, `*-sync` 系の採否 |
| Sync scope | README/docs/code/API/public docs/dependency/env/security など、鮮度維持対象 |
| Issue taxonomy | infra, web/ui, core/domain, integration, async/job/workflow, ci/cd, security, docs |
| Issue lifecycle | inception / plan / construction / verification / review notes の置き場所と承認 gate |
| Milestones | product roadmap から導いた milestone 一覧と対象範囲 |
| Project model | Project board、fields、status、date field、owner field、magic value の保管先 |
| Tool adapters | Codex と Claude から各 workflow をどう呼ぶか |
| Language policy | Project language と surface ごとの例外 |

`bootstrap-plan.md` には以下を必ず含める。

| セクション | 内容 |
|------------|------|
| Scope | bootstrap で作るもの、作らないもの |
| Architecture | apps/packages/infra/docs の構成、境界、依存方向 |
| Infrastructure | deploy/provider/runtime/DB/storage/cache/queue/workflow/observability の採用案 |
| App topology | web/api/jobs/workflows/workers の分割理由、deploy/scaling/auth/session 境界 |
| Docs | docs 正本、Issue 0、4 層モデル、INDEX 更新、公開 docs gate |
| Harness | AGENTS/CLAUDE、workflow、role、rules、hooks、sync 系、issue 管理 |
| Environment | Node/package manager、env files、secret 管理、local dev |
| CI/CD | YAML parse、diff check、lint/typecheck/test/build/docs/secret scan/deploy/smoke |
| Runner operations | self-hosted runner を使う場合の service manager、user、credentials、logs、restart |
| Implementation | 最初の vertical slice、API/UI/DB/worker 等の単位 |
| Deploy | branch deploy、preview/staging/production、承認 gate、rollback、smoke |
| Risks | 技術/運用/セキュリティ/cost/limits のリスクと緩和 |
| Tasks | 1 session で完了可能な issue 粒度、検証コマンド、完了条件 |

## Gate B: 実装計画の人間承認

`harness-catalog.md` と `bootstrap-plan.md` を提示し、承認を得る。

```text
bootstrap-plan.md を生成しました。

Path: <bootstrap-dir>/bootstrap-plan.md
- 作成予定:
- docs 運用正本:
- issue lifecycle:
- 生成する汎用 workflow:
- CI/CD と runner 運用:
- deploy strategy:
- 実装順序:

この計画で実装に進んでよいですか？
```

承認後は plan を固定する。
実装中の進捗は Todo と PR checklist で管理し、計画変更が必要な場合だけ plan を更新して再承認を取る。

## Step 4: モノレポ基盤作成

承認済み plan の Task 順に実装する。

基本方針:

- package manager、workspace、task runner、TypeScript/config、formatter/linter を先に固定する
- `apps/`, `packages/`, `infra/`, `docs/`, `scripts/` の境界を app topology decision に沿って明確にする
- 最初から full-stack を広げすぎず、deploy 可能な vertical slice を 1 本作る
- 共有設定は `packages/config` などに集約し、各 app/package の差分を小さくする
- generated code と handwritten code の境界を README または docs に明記する

## Step 5: docs 運用正本、ハーネス、issue lifecycle 整備

`references/docs-operating-model.md`、`references/issue-lifecycle.md`、`references/reference-harness-patterns.md` を読み、先に docs の置き場所・鮮度維持ルールを作り、その上に Codex/Claude adapter と workflow を載せる。

### 5.1 Docs 正本を作る

- agent が直接読むものだけ `.agents/` または `.claude/` に置く。
- project 運用 docs、issue lifecycle、workflow 手順、harness docs は原則 `docs/harness/` または `docs/product/` に置く。
- bootstrap 成果物は `docs/product/issues/000-bootstrap/` を Issue 0 として扱う。
- `docs/bootstrap/` は一時作業場所に限定し、継続運用の正本として残し続けない。
- `AGENTS.md` と `CLAUDE.md` は thin adapter とし、詳細手順を二重管理しない。

### 5.2 Docs 鮮度維持 workflow を作る

product brief と `harness-catalog.md` に従い、必要な `*-sync` だけを生成する。
各 sync は source of truth、比較対象、auto-edit 範囲、report/PR 方針を明示する。

### 5.3 Issue lifecycle を作る

issue ごとの inception / plan / construction / verification / review notes は `docs/product/issues/<number>-<slug>/` 配下に Markdown として置く。
issue 作成時点で実装方針が十分に厳密なら、issue-local approval gate を省略できる。
実装方針が未確定なら、inception 完了時に draft PR を出し、実装前に人間承認 gate を置く。

### 5.4 Codex / Claude adapter を作る

| ファイル/領域 | 目的 |
|---------------|------|
| `AGENTS.md` | Codex 用 thin adapter。docs 正本、主要 workflow、ブランチ/PR 運用への pointer |
| `CLAUDE.md` | Claude 用 thin adapter。`AGENTS.md` と同じ共通正本への pointer |
| `docs/harness/OPERATING_MODEL.md` | Codex / Claude 共通の作業フロー、承認 gate、品質基準 |
| `docs/harness/LANGUAGE_POLICY.md` | project language と例外規則 |
| `docs/harness/skills/*.md` | tool-neutral な workflow 手順 |
| `docs/harness/roles/*.md` | generator/evaluator/mapper/sync などの role 定義 |
| `docs/harness/rules/` | security、comments、dependency direction、docs freshness |
| `docs/harness/project-management.md` | milestone、Project、fields、status、date、relationship の運用正本 |
| `docs/harness/references/project-fields.md` | GitHub Project ID / field ID など推論不能な magic value |

## Step 6: 環境、secret、deploy 下準備

`.env.example`、local dev、seed、migration、secret 登録手順を整える。
secret 値そのものは repo に書かない。
provider bindings、environment variables、rollback、smoke test は `docs/runbooks/` に残す。

deploy は段階を分ける。

| 段階 | 条件 |
|------|------|
| preview | CI と build が通り、公開してもよい dummy data だけを使う |
| staging | secrets と外部サービスが設定済みで、smoke test が自動実行できる |
| production | ユーザの明示承認、rollback 手順、監視、alert がある |

production deploy、課金 resource 作成、破壊的 migration、外部公開は明示承認 gate 必須にする。

## Step 7: CI/CD と runner 運用整備

`references/ci-cd-runner-deploy.md` を読み、CI/CD provider、deployment strategy、runner 運用を設計する。

CI workflow には project に応じて以下を含める。

- YAML parse / workflow lint
- base branch diff check
- format / lint / typecheck
- unit / integration / e2e / contract / migration test
- build
- docs gate
- secret scan
- preview/staging deploy
- smoke test

GitHub Actions 等を使う場合は repo setting checklist も plan に含める。

- default merge strategy
- squash merge policy
- auto-delete merged branches
- branch protection
- required checks

self-hosted runner を使う場合は、foreground の `run.sh` 常用ではなく service manager 経由の常駐を推奨し、runner user、CLI login/keychain/credentials、CLI version 確認、fetch strategy、logs/status/restart 手順を runbook に残す。
`actionlint` などの check が未導入なら、未実行理由を報告する。

## Step 8: 初期実装と品質 gate

最初の vertical slice を実装する。
例: 認証なし health endpoint、最小 DB migration、1 画面、1 API、1 async job、1 deploy smoke など。

実装の完了条件:

- local で `format:check`, `lint`, `typecheck`, `test`, `build` 相当が通る
- docs gate と secret scan が CI に入っている、または未導入理由が issue 化されている
- CI が同じ品質 gate を実行する
- smoke test が deploy 先で通る
- README または docs に local dev と deploy 手順がある
- ハーネスが次の issue 実装を自律実行できる入力/出力を持つ

## Step 9: deploy と smoke test

承認済み deploy 目標に従い、preview または staging へ deploy する。
branch-based deploy を採用する場合、main/dev/release/prod 等の branch と environment の対応を docs と issue に残す。
deploy URL、commit SHA、environment、smoke 結果を `implementation-report.md` に記録する。

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
remote GitHub mutation、GitHub Project / Milestone / Label / Issue 作成は、人間承認後に行う。
product completion までの task は、1 session で完了可能な issue 粒度に分ける。
技術判断変更が既存 issue に影響する場合、関連 issue に comment する。

## 制約

- 技術選定と実装計画は、それぞれ人間承認を得てから次段階へ進む
- 最新仕様、価格、制限、deploy 手順、CLI option は推測しない。一次情報を確認する
- secrets、tokens、本番データ、個人情報を repo に書かない
- production deploy、課金 resource 作成、破壊的 migration、外部公開は明示承認なしに実行しない
- GitHub Project / Milestone / Label / Issue 作成は明示承認なしに実行しない
- ハーネスは過剰に作らない。最初の 1-2 個の反復で使う workflow/role から始める
- target repo の既存規約がある場合は、この Skill より repo 規約を優先する

## Self-check

- [ ] `product-brief.md` にユーザ、core flows、制約、非目標、project language がある
- [ ] `research.md` に一次情報 URL、確認日、repo 観察がある
- [ ] `decision-matrix.md` に採用案、代替案、棄却理由、運用リスク、cost/limits、local dev 影響がある
- [ ] Gate A に infrastructure service selection と app topology selection がある
- [ ] UI がある場合、CSS / UI styling strategy の比較と ADR がある
- [ ] `harness-catalog.md` に docs 層分離、Issue 0、issue taxonomy、issue lifecycle、sync 系、Project 管理の採否がある
- [ ] Gate A/B の承認ログがある
- [ ] `bootstrap-plan.md` が docs、環境、CI/CD、runner、deploy、ハーネス、初期実装を含む
- [ ] `AGENTS.md` / `CLAUDE.md` は thin adapter で、詳細手順を二重管理していない
- [ ] local 品質 gate と CI が同じ主要 check を実行する
- [ ] self-hosted runner を使う場合、service manager、user/credentials、CLI version、logs/status/restart runbook がある
- [ ] deploy URL と smoke test 結果が `implementation-report.md` にある
- [ ] PR body に artifacts、検証結果、残リスクがある
