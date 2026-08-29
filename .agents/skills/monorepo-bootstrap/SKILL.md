---
name: monorepo-bootstrap
description: Codex/Claude両対応で任意のモノレポをbootstrapする。技術選定調査、docs運用正本、ハーネス/環境/CI/CD整備、初期実装、deploy検証までを自律実行する。人間承認が必須なのは課金と秘密値のみ
user_invocable: true
---

# Monorepo Bootstrap Skill (Codex / Claude)

任意のプロダクト概要から、実装可能なモノレポを立ち上げる上位オーケストレーション Skill。
特定 project、業務ドメイン、cloud provider、runtime、CSS framework に固定せず、技術選定、docs 正本、Codex/Claude 両対応ハーネス、環境整備、CI/CD、初期実装、deploy 検証までを自律実行で進める。
人間の明示承認が必須なのは、課金が発生する操作と秘密値の挿入・変更の 2 つのみとする。
ハーネス・docs・CI の実体はスクラッチ生成せず、`assets/`（台帳: `assets/MANIFEST.md`）からの copy + placeholder 置換で展開する。

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
既定は自律実行とし、変更の実装から open PR の提出までを自律的に行う。PR のマージは人間の操作だが、明示的に指示された場合はマージまで行ってよい。
人間の明示承認が必須なのは次の 2 つのみ: (1) 課金が発生する操作（有償リソースの作成・プラン変更・外部サービス契約）、(2) 秘密値の挿入・変更（credential / API key / token を設定へ投入する操作）。

## 基本方針

### Provider / Runtime Neutrality

- template は特定 provider、runtime model、database、storage、queue/workflow、auth、observability、CI/CD provider を既定採用として書かない。
- user が provider や既存技術の制約を指定した場合だけ、その選択肢を優先候補として比較する。
- user が指定していない場合は、複数 provider / runtime option を比較し、Gate A で推奨案と代替案を提示する。
- provider 固有の CLI、binding、secret、deploy 手順は、template 本体へ直書きせず、target repo の `docs/runbooks/` または provider-specific reference へ分離する。
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
Intake で project language を確認し、`product-brief.md` と `docs/harness/OPERATING_MODEL.md` の言語ポリシー節、Issue / PR / ADR / review comment / docs / sync report の既定言語へ反映する。

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

bootstrap の成果物は、継続運用に入ったら `docs/issues/000_bootstrap/` を "Issue 0" として扱う。
一時調査を `docs/bootstrap/<project-slug>/` に置いた場合でも、Gate B までに `docs/issues/000_bootstrap/` へ統合し、`docs/bootstrap/` を恒久的な正本として残し続けない。
既存 repo の規約がある場合は、その規約を優先し、配置理由を `bootstrap-plan.md` に残す。

| 成果物 | 既定配置 | 内容 |
|--------|----------|------|
| `product-brief.md` | `docs/issues/000_bootstrap/` | product overview、user、core flows、non-goals、language policy、constraints |
| `research.md` | `docs/issues/000_bootstrap/` and/or `docs/notes/research/` | 技術調査、一次情報 URL、比較観点、未確定事項 |
| `decision-matrix.md` | `docs/issues/000_bootstrap/` | 技術選定候補、採否、理由、運用リスク、cost/limits、local dev 影響 |
| `harness-catalog.md` | `docs/issues/000_bootstrap/` | docs 運用、workflow、Issue/Project 運用、adapter 方針 |
| `bootstrap-plan.md` | `docs/issues/000_bootstrap/` | 実装計画、docs/ハーネス/環境/CI/CD/deploy/初期機能の Task |
| `implementation-report.md` | `docs/issues/000_bootstrap/` | 実装結果、検証、deploy URL、残タスク |

必要に応じて以下を読む。
Skill 本体は orchestration に限定し、詳細 checklist と template は references を正本にする。

| 参照 | 使う場面 |
|------|----------|
| `assets/MANIFEST.md` | ハーネス/docs/CI 資産を copy・置換・削除するとき（資産台帳の正本） |
| `references/bootstrap-artifacts.md` | 成果物テンプレートが必要なとき |
| `references/technology-selection.md` | Gate A の比較範囲、infrastructure service selection、app topology、CSS/UI stack 選定を作るとき |
| `references/docs-operating-model.md` | docs 配下の層分離、Issue 0、adapter 配置、公開射影を設計するとき |
| `references/issue-lifecycle.md` | issue taxonomy、issue-local docs、ADR 要否、承認要否の判定を作るとき |
| `references/generated-workflows.md` | `*-sync` 系、`create-issue`、milestone / Project 管理を PJ 固有化するとき |
| `references/ci-cd-runner-deploy.md` | CI/CD、self-hosted runner、deploy strategy、runbook を設計するとき |
| `references/reference-harness-patterns.md` | assets/ 収録資産の設計根拠と縮約判断が必要なとき |

## フロー図

```text
monorepo-bootstrap <product overview>
  +-- 1. Intake と repo 観察
  +-- 2. 技術調査と候補比較
  +-- Gate A: 技術選定の確定（decision-matrix.md。課金・秘密値が絡む項目のみ人間承認）
  +-- 3. harness-catalog.md と bootstrap-plan.md 作成
  +-- Gate B: 実装計画の確定（bootstrap-plan.md。課金・秘密値が絡む項目のみ人間承認）
  +-- 4. モノレポ基盤作成
  +-- 5. docs 運用正本、ハーネス、issue lifecycle 整備（assets からの copy + 置換）
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

## Gate A: 技術選定の確定

`decision-matrix.md` を作成したら、依存追加、scaffold、infra 作成の前に選定を確定する。
Gate A は「人間を待つ関門」ではなく「判断材料を成果物として固定する関門」とする。

- 課金が発生する選定（有償リソースの作成、有償プラン、外部サービス契約）、または秘密値の投入を伴う選定が含まれる場合は、その項目だけ人間の明示承認を得る。承認が得られるまで当該項目に依存する作業へ進まない。
- それ以外の選定は承認を待たず、自律続行する。判断材料は `decision-matrix.md` に残し、最終的に PR で提示する。

`decision-matrix.md` には最低限、次を含める。

```text
- 推奨 stack:
- Infrastructure service selection:
- App topology:
- CSS/UI strategy:
- 代替案:
- 主なリスク:
- 人間承認が必要な項目（課金 / 秘密値）とその状態:
```

Gate A は、infrastructure service selection と app topology selection を必ず含む。
user が provider を指定していない場合は、複数 provider / runtime option を比較した上で推奨案と代替案を `decision-matrix.md` に残す。
ユーザから修正指示または追加調査の指示があった場合は Step 2 に戻り、`research.md` と `decision-matrix.md` を更新する。

## Step 3: harness-catalog.md と bootstrap-plan.md 作成

Gate A で確定した技術選定をもとに、`harness-catalog.md` と `bootstrap-plan.md` を作る。

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
| Workflow inventory | `assets/MANIFEST.md` の core 資産一覧と opt-in グループ（`opt-in:renovate` / `opt-in:public-site` / `opt-in:submodule` / `opt-in:traceability`）の採否 |
| Sync scope | README/docs/code/public docs/dependency など、鮮度維持対象 |
| Issue taxonomy | infra, web/ui, core/domain, integration, async/job/workflow, ci/cd, security, docs |
| Issue lifecycle | issue-local docs の置き場所と承認要否（必須は課金・秘密値のみ） |
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
| Environment | `mise` による tool/runtime version 管理、Node/package manager、env files、secret 管理、local dev |
| CI/CD | 既定は基礎 CI 1 本（format:check / test / build、hooks テスト込み）。拡張候補の採否と理由 |
| Runner operations | self-hosted runner を使う場合の service manager、user、credentials、logs、restart |
| Implementation | 最初の vertical slice、API/UI/DB/worker 等の単位 |
| Deploy | branch deploy（main=dev / release=prod）、prod リリース手順、rollback、smoke |
| Risks | 技術/運用/セキュリティ/cost/limits のリスクと緩和 |
| Tasks | 1 session で完了可能な issue 粒度、検証コマンド、完了条件 |

## Gate B: 実装計画の確定

`harness-catalog.md` と `bootstrap-plan.md` を成果物として確定する。

- 計画に課金が発生する操作、または秘密値の挿入・変更が含まれる場合は、その項目だけ人間の明示承認を得る。承認前に当該操作を実行しない。
- それ以外は承認を待たず、plan を固定して実装へ自律続行する。計画の全体像（作成予定 / docs 運用正本 / issue lifecycle / 採用 workflow / CI/CD と runner 運用 / deploy strategy / 実装順序）は `bootstrap-plan.md` に残し、PR で提示する。

実装中の進捗は Todo と PR checklist で管理し、計画変更が必要な場合だけ plan を更新して差分を PR に明示する。課金・秘密値に関わる変更が新たに生じた場合のみ、その時点で承認を取る。

## Step 4: モノレポ基盤作成

確定済み plan の Task 順に実装する。

基本方針:

- package manager、workspace、task runner、TypeScript/config、formatter/linter を先に固定する
- tool/runtime version 管理は `mise` を既定にし、runtime、package manager、主要 CLI version、local dev task を repository-local な `.mise.toml` などへ記録する
- `apps/`, `packages/`, `infra/`, `docs/`, `scripts/` の境界を app topology decision に沿って明確にする
- 最初から full-stack を広げすぎず、deploy 可能な vertical slice を 1 本作る
- 共有設定は `packages/config` などに集約し、各 app/package の差分を小さくする
- generated code と handwritten code の境界を README または docs に明記する

## Step 5: docs 運用正本、ハーネス、issue lifecycle 整備

ハーネス・docs・CI の実体はスクラッチ生成しない。
`assets/MANIFEST.md` を台帳として、次の手順で展開する。

1. core 資産を bootstrap 先へ同一相対パスで copy する。
2. opt-in グループ（`opt-in:renovate` / `opt-in:public-site` / `opt-in:submodule` / `opt-in:traceability`）は Intake / 計画の採否判断に従い、採用グループのみ copy する。不採用グループの資産は copy しない。
3. 明示 token `{{PRODUCT_NAME}}` `{{GITHUB_ORG}}` `{{REPO_NAME}}` `{{PROJECT_LANGUAGE}}` を一括置換する。
4. `TODO(取得方法: ...)` 形式の値は、実環境で検証した値のみ埋める。未検証のまま実値を書かない。
5. product docs の骨格（ARCHITECTURE / TECH_STACK / TERMS / TEST_STRATEGY）と各 skill の profile 類を PJ 固有の内容で充填する。

設計判断の背景が必要な場合のみ `references/docs-operating-model.md`、`references/issue-lifecycle.md`、`references/reference-harness-patterns.md` を読む。

### 5.1 Docs 正本の配置規約

- agent が直接読むものだけ `.agents/` または `.claude/` に置く。
- ハーネス運用の neutral 正本は `docs/harness/OPERATING_MODEL.md`、skill 手順の正本は `docs/harness/skills/<name>.md`、sync 系共通契約は `docs/harness/skills/shared/` に置く。
- ADR は `docs/adr/` の 1 箇所のみ。Issue 成果物は `docs/issues/<number>_<scope>/` に置く。
- bootstrap 成果物は `docs/issues/000_bootstrap/` を Issue 0 として扱う。
- `docs/bootstrap/` は一時作業場所に限定し、継続運用の正本として残し続けない。
- `AGENTS.md` と `CLAUDE.md` は thin adapter とし、詳細手順を二重管理しない。

### 5.2 Docs 鮮度維持 workflow

sync 系 skill（readme-sync / docs-sync / code-sync など）は `assets/MANIFEST.md` の core に含まれており、copy で導入される。
product 固有の鮮度維持対象を追加する場合のみ、`references/generated-workflows.md` §2 の 10 項目契約に従って新しい sync doc を設計する。

### 5.3 Issue lifecycle

issue ごとの計画・記録は `docs/issues/<number>_<scope>/` 配下に Markdown として置く（テンプレートは `docs/issues/templates/`）。
issue-local の人間承認は既定では置かない。実装方針が未確定でも、open questions を成果物に残して open PR まで自律続行する。
draft PR を承認 gate として使うのは、人間から明示的に指示があった場合のみとする。

### 5.4 Codex / Claude adapter

copy 済み資産のうち、adapter と magic value の位置は次のとおり。

| ファイル/領域 | 目的 |
|---------------|------|
| `AGENTS.md` | Codex 用 thin adapter。`docs/harness/OPERATING_MODEL.md` への pointer |
| `CLAUDE.md` | Claude 用 thin adapter。`AGENTS.md` と同じ共通正本への pointer |
| `docs/harness/OPERATING_MODEL.md` | Codex / Claude 共通の作業フロー、承認モデル、言語ポリシー、品質基準 |
| `docs/harness/skills/*.md` | tool-neutral な workflow 手順の正本 |
| `.claude/skills/<name>/SKILL.md` | 各正本への薄い adapter（1:1 対応） |
| `.claude/rules/*.md` | 常時ロード / paths スコープの rule 層 |
| `.claude/skills/create-issue/references/project-fields.md` | GitHub Project ID / field ID など推論不能な magic value（TODO 形式） |

## Step 6: 環境、secret、deploy 下準備

`.env.example`、local dev、seed、migration、secret 登録手順を整える。
secret 値そのものは repo に書かない。
provider bindings、environment variables、rollback、smoke test は `docs/runbooks/` に残す。

tool/runtime version 管理と local dev command は `mise` を既定にする。
runtime、package manager、主要 CLI は `.mise.toml` など repository-local な設定に固定し、setup 手順は `mise install` から始める。
反復的な local dev / check / seed / migration command は、project の package scripts と矛盾しない範囲で `mise run <task>` から呼べるようにする。
既存 repo に別の標準がある場合は、移行するか併存するかを `bootstrap-plan.md` に明記する。

ブランチモデルの既定は main = dev 環境 / release = prod 環境とする。
main は壊れても復旧可能な開発環境であり、開発過程ではセキュリティより柔軟性を優先する。

| 環境 | 条件 |
|------|------|
| dev (main) | CI と build が通る。壊れても復旧可能な前提で自律 deploy してよい |
| prod (release) | prod リリース手順を踏む: main の安全性確認 → release への反映手順の確認 |

秘密値の挿入・変更（secret 登録、credential 投入）と課金が発生する操作（有償リソース作成、プラン変更、外部サービス契約）は人間の明示承認を得てから行う。

## Step 7: CI/CD と runner 運用整備

`references/ci-cd-runner-deploy.md` を読み、CI/CD provider、deployment strategy、runner 運用を設計する。

CI の既定は基礎 CI 1 本（`assets/.github/workflows/ci.yml` を copy）とする。

- format:check / test / build
- test job 内で `.claude/hooks/tests/run-all.sh`（hooks の bash テスト）を実行

これを超える check（workflow lint、diff check、e2e、docs gate、deploy、smoke など）は拡張候補であり、`references/ci-cd-runner-deploy.md` の拡張候補リストから必要なものだけ選び、採否と理由を `bootstrap-plan.md` に残す。
秘密検知は CI ではなく pre-push hook（`.claude/hooks/pre-push-ci-check.sh`）が既定の担い手になる。
定期実行 workflow は既定では収録しない。追加する場合は bootstrap 先の `docs/harness/scheduled-operations.md` の設計ガイドに従う。

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
- 秘密検知が pre-push hook に入っており、`.claude/hooks/tests/run-all.sh` が green
- 基礎 CI（format:check / test / build、hooks テスト込み）が通る
- smoke test が deploy 先で通る
- README または docs に local dev と deploy 手順がある
- ハーネスが次の issue 実装を自律実行できる入力/出力を持つ

## Step 9: deploy と smoke test

Intake で確認した deploy 目標に従い、dev 環境（main）へ deploy する。
branch と environment の対応は既定で main = dev / release = prod とし、変更する場合は対応表を docs と issue に残す。
prod（release）への反映は、main の安全性確認 → release への反映手順の確認を経てから行う。
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
4. branch を push し、open PR を作成する（既定の完了形）。PR body に bootstrap artifacts、検証、deploy URL、残リスクを記載
5. マージは人間の操作とする。ただし明示的に指示された場合はマージまで行ってよい

既存 repo に PR 作成規約があればそれに従う。
GitHub Project / Milestone / Label / Issue の作成・更新・comment は自律実行してよい。人間承認が必要なのは課金が発生する操作と秘密値の挿入・変更のみ。
product completion までの task は、1 session で完了可能な issue 粒度に分ける。
技術判断変更が既存 issue に影響する場合、関連 issue に comment する。

## 制約

- 既定は自律実行。変更の実装から open PR の提出までを自律的に行い、マージは明示指示があった場合のみ行う
- 人間の明示承認が必須なのは、課金が発生する操作と秘密値の挿入・変更の 2 つのみ
- 技術選定と実装計画は成果物（`decision-matrix.md` / `bootstrap-plan.md`）に残し、PR で提示する
- 最新仕様、価格、制限、deploy 手順、CLI option は推測しない。一次情報を確認する
- secrets、tokens、本番データ、個人情報を repo に書かない
- prod リリースは main の安全性確認 → release への反映手順の確認を経てから行う
- ハーネスは `assets/MANIFEST.md` の core を基準にし、不要な opt-in グループを持ち込まない
- target repo の既存規約がある場合は、この Skill より repo 規約を優先する

## Self-check

- [ ] `product-brief.md` にユーザ、core flows、制約、非目標、project language がある
- [ ] `research.md` に一次情報 URL、確認日、repo 観察がある
- [ ] `decision-matrix.md` に採用案、代替案、棄却理由、運用リスク、cost/limits、local dev 影響がある
- [ ] Gate A に infrastructure service selection と app topology selection がある
- [ ] UI がある場合、CSS / UI styling strategy の比較と ADR がある
- [ ] `harness-catalog.md` に docs 層分離、Issue 0、issue taxonomy、issue lifecycle、opt-in グループの採否がある
- [ ] 課金・秘密値が絡む項目の人間承認ログが成果物にある（該当なしの場合はその旨を明記）
- [ ] `bootstrap-plan.md` が docs、環境、CI/CD、runner、deploy、ハーネス、初期実装を含む
- [ ] `assets/MANIFEST.md` の Self-check（token 置換、opt-in 採否、skill 1:1 対応、hooks 外部契約、hooks テスト green、routine 登録 TODO）を実施した
- [ ] tool/runtime version 管理と local dev command が `mise` を入口にしている
- [ ] `AGENTS.md` / `CLAUDE.md` は thin adapter で、詳細手順を二重管理していない
- [ ] local 品質 gate と基礎 CI（format:check / test / build）が同じ主要 check を実行する
- [ ] self-hosted runner を使う場合、service manager、user/credentials、CLI version、logs/status/restart runbook がある
- [ ] deploy URL と smoke test 結果が `implementation-report.md` にある
- [ ] PR body に artifacts、検証結果、残リスクがある
