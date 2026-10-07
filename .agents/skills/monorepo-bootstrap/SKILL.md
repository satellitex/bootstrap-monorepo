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

既存のスタック・コード・CI を維持したまま運用ハーネスだけを導入する場合は、本 Skill ではなく `harness-adopt` Skill（`../harness-adopt/SKILL.md`）を使う。
本 Skill は、新規 repo または技術選定・基盤構築からやり直す repo を対象とする。

## 入力

| 項目 | 必須 | 説明 | 例 |
|------|------|------|----|
| Product overview | Yes | 誰のどんな課題を解くか、主要機能、想定ユーザ | `/monorepo-bootstrap B2B SaaS の請求照合プロダクト` |
| Constraints | No | 予算、cloud/provider 制約、既存技術、納期、規制、運用体制 | `組織標準 provider 優先、DB は PostgreSQL` |
| Existing repository | No | 空 repo か、既存コードを含む repo か | `既存 Next.js app あり` |
| Deploy goal | No | preview / staging / production のどこまで行うか | `staging まで` |
| Project language | No | Issue / PR / ADR / docs / review comment の既定言語。assets の運用文書は日本語で収録されており、翻訳は明示された場合のみ（Language Policy 参照） | `日本語`, `English` |

入力が足りない場合は、作業を止めずに仮定を明示して Discovery を始める。
既定は自律実行とし、変更の実装から open PR の提出までを自律的に行う。PR のマージは人間の操作だが、明示的に指示された場合はマージまで行ってよい。
人間の明示承認が必須なのは次の 2 つのみ: (1) 課金が発生する操作（有償リソースの作成・プラン変更・外部サービス契約）、(2) 秘密値の挿入・変更（credential / API key / token を設定へ投入する操作）。

## 基本方針

### Provider / Runtime Neutrality

- template は特定 provider、runtime model、database、storage、queue/workflow、auth、observability、CI/CD provider を既定採用として書かない。
- user が provider や既存技術の制約を指定した場合だけ、その選択肢を優先候補として比較する。
- user が指定していない場合は、複数 provider / runtime option を比較し、Gate A で推奨案と代替案を提示する。
- provider 固有の CLI、binding、secret、deploy 手順は、template 本体へ直書きせず、target repo の `docs/runbooks/` または provider-specific reference へ分離する。
- 最新仕様、価格、制限、deploy behavior、CLI option、CI/CD syntax に依存する判断は一次情報を確認し、URL と確認日を調査ノート（`docs/notes/research/<topic>.md`）に残す。

### Codex / Claude 対応

| 領域 | Codex | Claude | 共通化方針 |
|------|-------|--------|------------|
| 常時入口 | `AGENTS.md` | `CLAUDE.md` | どちらも短い pointer にし、詳細は `docs/` に置く |
| Workflow 実行 | Skill 名または明示プロンプト | slash command / Skill | 手順名は tool-neutral にする |
| 作業計画 | plan / Todo / diff | Todo / subagent / diff | PR 本文・commit・ADR で引き継ぐ |
| 実装者/評価者分離 | 別セッション、別 reviewer、明示 review pass | subagent / evaluator | 「作る役」と「評価する役」を概念として分ける |
| ローカル規約 | repo の `AGENTS.md` 優先 | repo の `CLAUDE.md` 優先 | 両方ある場合は矛盾しない thin adapter にする |

### Language Policy

assets の運用文書（docs、skill 正本、agent 定義、rules、hooks のメッセージ）は日本語で収録されている。
bootstrap 先でも収録言語のまま導入し、翻訳は Intake で明示された場合のみ行う。翻訳は資産の更新を再び取り込むときの差分管理を重くするため、既定にしない。

Intake で project language を確認し、次へ反映する。

- `docs/harness/OPERATING_MODEL.md` の言語ポリシー節（`{{PROJECT_LANGUAGE}}` の唯一の記入箇所）
- Issue / PR / ADR / review comment / sync report の既定言語

project language が日本語以外で、運用文書を翻訳しない場合は、「運用文書は収録言語、成果物は project language」という決定を PR 本文に記録し、言語ポリシー節にも同じ区別を書く。
翻訳する場合は、識別子・パス・コマンド・TODO 記法・表構造・見出しアンカー・token を保持し、翻訳後に MANIFEST の Self-check を再実施する。言語名が言語ポリシー節以外へ混入していないことも確認する。

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

bootstrap の成果物は、専用のディレクトリやファイルとして作らない。
作業中の成果は PR 本文の節に書き、確定した内容を既存の層（調査・決定・現状・運用）の文書へ移す。
Gate A / Gate B の途中成果は、PR 本文の「Intake（確定前）」「Gate A 技術選定（確定前）」「Gate B 実装計画（確定前）」節に書き、確定時に各層へ移して、節には移管先への参照だけを残す。
課金・秘密値の承認ログは PR 本文の「承認ログ（課金・秘密値）」節に残す。
既存 repo に ADR・調査ノート・計画の置き場の規約がある場合は、その規約を優先し、配置理由を PR 本文の「移管先の文書」節に残す。

| 作業中の成果 | 移管先 |
|--------------|--------|
| Intake の整理（product overview、user、core flows、non-goals、constraints、language policy） | `docs/product/ARCHITECTURE.md` の High-Level Overview 冒頭（目的・主な利用者・提供する価値を 3〜5 行）と `docs/product/TERMS.md`、`docs/harness/OPERATING_MODEL.md` のプロダクト 1 行。Intake の原文は PR 本文の「背景」 |
| 技術調査（一次情報 URL、比較観点、未確定事項、repo 観察） | `docs/notes/research/<topic>.md` |
| 技術選定（採用案、代替案、棄却理由、運用リスク、cost/limits、local dev 影響） | 採用した選定は `docs/adr/`（1 領域 1 ADR。代替案と棄却理由を含む）。現在の採用状態は `docs/product/TECH_STACK.md` |
| ハーネス構成（docs 運用、workflow、Issue/Project 運用、adapter 方針、opt-in 採否） | opt-in の採否とその理由は ADR 1 本。workflow 一覧と言語ポリシーは `docs/harness/OPERATING_MODEL.md`。Project / ラベルの実値は `.claude/skills/create-issue/references/project-fields.md` |
| 実装計画（docs/ハーネス/環境/CI/CD/deploy/初期機能の Task） | PR 本文の標準節（背景 / 方針と却下案 / スコープ外 / 検証結果 / リスク）。残タスクは GitHub Issue |
| 実装結果（検証、deploy URL、残タスク） | PR 本文（検証結果・リスク）。残タスクは GitHub Issue |

PR 本文の節構成と、移管先の文書のテンプレートは `references/bootstrap-artifacts.md` にある。標準節と 2 つの追加節（承認ログ / 移管先の文書）の定義は `assets/docs/harness/skills/shared/pr-creation.md` が正本である。

必要に応じて以下を読む。
Skill 本体は orchestration に限定し、詳細 checklist と template は references を正本にする。

| 参照 | 使う場面 |
|------|----------|
| `assets/MANIFEST.md` | ハーネス/docs/CI 資産を copy・置換・削除するとき（資産台帳の正本） |
| `references/bootstrap-artifacts.md` | PR 本文の節構成と、各層へ移す文書のテンプレートが必要なとき |
| `references/technology-selection.md` | Gate A の比較範囲、infrastructure service selection、app topology、CSS/UI stack 選定を作るとき |
| `references/docs-operating-model.md` | docs 配下の層分離、adapter 配置、公開射影を設計するとき |
| `references/issue-lifecycle.md` | issue taxonomy、計画・判断・検証結果の置き場、ADR 要否、承認要否の判定を作るとき |
| `references/generated-workflows.md` | `*-sync` 系、`create-issue`、milestone / Project 管理を PJ 固有化するとき。実行系 routine のレシピ（§8） |
| `references/ci-cd-runner-deploy.md` | CI/CD、self-hosted runner、deploy strategy、runbook を設計するとき |
| `references/reference-harness-patterns.md` | assets/ 収録資産の設計根拠と縮約判断が必要なとき |

## フロー図

```text
monorepo-bootstrap <product overview>
  +-- 1. Intake と repo 観察（PR 本文の Intake 節）
  +-- 2. 技術調査と候補比較（調査ノートと Gate A 節）
  +-- Gate A: 技術選定の確定（領域ごとの ADR と TECH_STACK。課金・秘密値が絡む項目のみ人間承認）
  +-- 3. ハーネス構成と実装計画（Gate B 節）
  +-- Gate B: 実装計画の確定（PR 本文の標準節と残タスクの Issue。課金・秘密値が絡む項目のみ人間承認）
  +-- 4. モノレポ基盤作成
  +-- 5. docs 運用正本とハーネス整備（assets からの copy + 置換）
  +-- 6. 環境、secret、deploy 下準備
  +-- 7. CI/CD と runner 運用整備
  +-- 8. 初期実装と品質 gate
  +-- 9. preview/staging deploy と smoke test
  +-- 10. 完了処理と PR
```

## Step 1: Intake と repo 観察

### 1.1 Product overview の構造化

ユーザ入力から以下を抽出し、PR 本文の「Intake（確定前）」節に書く。

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

観察結果は調査ノート（`docs/notes/research/repo-observations.md`）の "Repository observations" に記録する。

## Step 2: 技術調査と候補比較

`references/technology-selection.md` を読み、調査ノート（`docs/notes/research/<topic>.md`）と PR 本文の「Gate A 技術選定（確定前）」節を作る。
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

各領域で、Gate A 節に「採用案」「代替案」「棄却理由」「運用リスク」「cost/limits」「local dev 影響」を残す。
UI がある project では CSS / styling strategy の採用判断も 1 領域として ADR 化する。

### App Topology Selection

`apps/web`, `apps/api`, `apps/workers`, `apps/jobs`, `apps/workflows` などの分割を機械的に決めない。
次を比較し、Gate A 節（確定後は ADR）に残す。

- UI と server-side route の結合度
- deploy 単位
- scaling 単位
- auth/session 境界
- external API と internal route の違い
- tenant/workspace ごとの domain route の自然さ
- long-running / async 処理の責務分離

## Gate A: 技術選定の確定

PR 本文の「Gate A 技術選定（確定前）」節を作成したら、依存追加、scaffold、infra 作成の前に選定を確定する。
Gate A は「人間を待つ関門」ではなく「判断材料を成果物として固定する関門」とする。

- 課金が発生する選定（有償リソースの作成、有償プラン、外部サービス契約）、または秘密値の投入を伴う選定が含まれる場合は、その項目だけ人間の明示承認を得る。承認が得られるまで当該項目に依存する作業へ進まない。
- それ以外の選定は承認を待たず、自律続行する。判断材料は ADR と調査ノートに残し、最終的に PR で提示する。

確定した選定は、次のとおり各層へ移す。

- 領域ごとに 1 本の ADR を作る（`docs/adr/`。Status は `Proposed`。代替案と棄却理由を含む。テンプレートは `references/bootstrap-artifacts.md`）。
- `docs/product/TECH_STACK.md` の確定スタック一覧に行を足し、ADR 列から参照する。
- Gate A 節には移管先への参照だけを残す。

Gate A 節には最低限、次を含める。

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
user が provider を指定していない場合は、複数 provider / runtime option を比較した上で推奨案と代替案を残す。
ユーザから修正指示または追加調査の指示があった場合は Step 2 に戻り、調査ノートと Gate A 節（確定済みの選定は ADR）を更新する。

## Step 3: ハーネス構成と実装計画

Gate A で確定した技術選定をもとに、PR 本文の「Gate B 実装計画（確定前）」節にハーネス構成と実装計画を書く。

参照順:

1. `references/bootstrap-artifacts.md`
2. `references/docs-operating-model.md`
3. `references/issue-lifecycle.md`
4. `references/generated-workflows.md`
5. `references/ci-cd-runner-deploy.md`
6. `references/reference-harness-patterns.md`

ハーネス構成には以下を必ず含める。

| セクション | 内容 |
|------------|------|
| Docs operating model | `docs/harness/` と `docs/product/` の層分離、INDEX、README、公開射影 |
| Workflow inventory | `assets/MANIFEST.md` の core 資産一覧と opt-in グループ（一覧は MANIFEST）の採否 |
| Sync scope | README/docs/code/public docs/dependency など、鮮度維持対象 |
| Issue taxonomy | infra, web/ui, core/domain, integration, async/job/workflow, ci/cd, security, docs |
| Issue lifecycle | 計画は PR 本文、判断は ADR、残タスクは Issue。承認要否（必須は課金・秘密値のみ） |
| Milestones | product roadmap から導いた milestone 一覧と対象範囲 |
| Project model | Project board、fields、status、date field、owner field、magic value の保管先 |
| Tool adapters | Codex と Claude から各 workflow をどう呼ぶか |
| Language policy | Project language と surface ごとの例外、運用文書の言語の扱い（収録言語のまま導入するか、翻訳するか） |

実装計画には以下を必ず含める。

| セクション | 内容 |
|------------|------|
| Scope | bootstrap で作るもの、作らないもの |
| Architecture | apps/packages/infra/docs の構成、境界、依存方向 |
| Infrastructure | deploy/provider/runtime/DB/storage/cache/queue/workflow/observability の採用案 |
| App topology | web/api/jobs/workflows/workers の分割理由、deploy/scaling/auth/session 境界 |
| Docs | docs 正本、4 層モデル、INDEX 更新、公開 docs gate |
| Harness | AGENTS/CLAUDE、workflow、role、rules、hooks、sync 系、issue 管理 |
| Environment | `mise` による tool/runtime version 管理、Node/package manager、env files、secret 管理、local dev |
| CI/CD | 既定は基礎 CI 1 本（format:check / test / build、hooks テストとハーネス機械検査込み）。拡張候補の採否と理由 |
| Runner operations | self-hosted runner を使う場合の service manager、user、credentials、logs、restart |
| Implementation | 最初の vertical slice、API/UI/DB/worker 等の単位 |
| Deploy | branch deploy（main=dev / release=prod）、prod リリース手順、rollback、smoke |
| Risks | 技術/運用/セキュリティ/cost/limits のリスクと緩和 |
| Tasks | 1 session で完了可能な issue 粒度、検証コマンド、完了条件 |

## Gate B: 実装計画の確定

ハーネス構成と実装計画を確定する。

- 計画に課金が発生する操作、または秘密値の挿入・変更が含まれる場合は、その項目だけ人間の明示承認を得る。承認前に当該操作を実行しない。
- それ以外は承認を待たず、計画を固定して実装へ自律続行する。計画の全体像（作成予定 / docs 運用正本 / 採用 workflow / CI/CD と runner 運用 / deploy strategy / 実装順序）は PR 本文で提示する。

確定した内容は、次のとおり各層へ移す。

- 計画は PR 本文の標準節（背景 / 方針と却下案 / スコープ外 / 検証結果 / リスク）へ。退けた案は 1 案ごとに 1 行で「方針と却下案」に書く。
- opt-in グループの採否とその理由は ADR 1 本へ。workflow 一覧と言語ポリシーは `docs/harness/OPERATING_MODEL.md` へ。
- 残タスクは GitHub Issue へ。
- Gate B 節には移管先への参照だけを残す。

実装中の進捗は Todo と PR checklist で管理し、計画変更が必要な場合だけ PR 本文を更新して差分を明示する。課金・秘密値に関わる変更が新たに生じた場合のみ、その時点で承認を取る。

## Step 4: モノレポ基盤作成

確定した実装計画の Task 順に実装する。

基本方針:

- package manager、workspace、task runner、TypeScript/config、formatter/linter を先に固定する
- tool/runtime version 管理は `mise` を既定にし、runtime、package manager、主要 CLI version、local dev task を repository-local な `.mise.toml` などへ記録する。node の既定 pin は、bootstrap 時に公式のリリース一覧で最新の LTS を確認し、`.mise.toml` と `package.json`（`packageManager` / `engines`）を揃える
- `pnpm-workspace.yaml` は assets の内容（`apps/*` と `packages/*` の列挙）が hooks の外部契約になる。scaffold が別の内容を生成した場合は assets に合わせ、再生成で上書きしない
- `apps/`, `packages/`, `infra/`, `docs/`, `scripts/` の境界を app topology decision に沿って明確にする
- 最初から full-stack を広げすぎず、deploy 可能な vertical slice を 1 本作る
- 共有設定は `packages/config` などに集約し、各 app/package の差分を小さくする
- generated code と handwritten code の境界を README または docs に明記する

## Step 5: docs 運用正本とハーネス整備

ハーネス・docs・CI の実体はスクラッチ生成しない。
`assets/MANIFEST.md` を台帳として、次の手順で展開する。

1. core 資産を bootstrap 先へ同一相対パスで copy する。
2. opt-in グループ（一覧は MANIFEST）は Intake / 計画の採否判断に従い、採用グループのみ copy する。不採用グループの資産は copy しない。core 側に残る参照は、MANIFEST の「グループ除去チェックリスト」で処理する。`docs/README.md` のディレクトリマップは、opt-in と付記した行のうち不採用グループの行を削除し、表の直前の HTML コメントも削除する（所属グループは MANIFEST のグループ節で確認する）。
3. 明示 token `{{PRODUCT_NAME}}` `{{GITHUB_ORG}}` `{{REPO_NAME}}` `{{PROJECT_LANGUAGE}}` を一括置換する。
4. TODO は 2 種類ある（正本表は MANIFEST の「TODO 記法」）。`TODO(取得方法: ...)` は環境から取得する値で、実環境で検証した値のみ埋め、未検証のまま実値を書かない。`TODO(記入方法: ...)` はチームが決める内容で、判断基準に沿って PJ の内容を書く。
5. product docs の骨格（ARCHITECTURE / TECH_STACK / TERMS / TEST_STRATEGY）と各 skill の profile 類を PJ 固有の内容で充填する。Intake の整理と確定した選定は、「成果物」の移管先の表に従って移す。
6. 言語方針（収録言語のまま導入するか、翻訳するか）を PR 本文に記録し、`docs/harness/OPERATING_MODEL.md` の言語ポリシー節に反映する。

設計判断の背景が必要な場合のみ `references/docs-operating-model.md`、`references/issue-lifecycle.md`、`references/reference-harness-patterns.md` を読む。

### 5.1 Docs 正本の配置規約

- agent が直接読むものだけ `.agents/` または `.claude/` に置く。
- ハーネス運用の neutral 正本は `docs/harness/OPERATING_MODEL.md`、skill 手順の正本は `docs/harness/skills/<name>.md`、skill 横断の共通契約は `docs/harness/skills/shared/`（sync 専用は `sync-` 接頭辞）に置く。
- ADR は `docs/adr/` の 1 箇所のみ。技術選定の調査は `docs/notes/research/`、計画と検証結果は PR 本文に置く。Issue ごとの成果物ファイルは作らない。
- INDEX（ADR・調査ノート・runbook など）の更新主体は `docs/harness/skills/shared/index-writer-policy.md` の割当表に従う。更新する routine の登録は完了報告の TODO に含め、登録前の経過措置では、bootstrap の PR が同一 PR で INDEX の行を追加してよい。
- `AGENTS.md` と `CLAUDE.md` は thin adapter とし、詳細手順を二重管理しない。

### 5.2 Docs 鮮度維持 workflow

sync 系 skill（readme-sync / docs-sync / code-sync など）は `assets/MANIFEST.md` の core に含まれており、copy で導入される。
product 固有の鮮度維持対象を追加する場合のみ、`references/generated-workflows.md` §2 の 10 項目契約に従って新しい sync doc を設計する。実装キュー・棚卸し・観測点検のような実行系 routine は資産に収録しておらず、需要が出た時点で同 §8 のレシピに従って追加する。

### 5.3 Issue lifecycle

issue ごとの計画は PR 本文の標準節（背景 / 方針と却下案 / スコープ外 / 検証結果 / リスク）、設計判断は ADR、残タスクは GitHub Issue に置く。Issue ごとの計画ファイルは作らない。
issue-local の人間承認は既定では置かない。実装方針が未確定でも、未確定点は 1 案に確定して「方針と却下案」に書き、open PR まで自律続行する。
PR は通常 PR で open する（draft にしない。経路ごとの指定は `assets/docs/harness/skills/shared/pr-creation.md` の「draft にしない」）。

### 5.4 Codex / Claude adapter

copy 済み資産のうち、adapter と magic value の位置は次のとおり。

| ファイル/領域 | 目的 |
|---------------|------|
| `AGENTS.md` | Codex 用 thin adapter。`docs/harness/OPERATING_MODEL.md` への pointer |
| `CLAUDE.md` | Claude 用 thin adapter。`AGENTS.md` と同じ共通正本への pointer |
| `docs/harness/OPERATING_MODEL.md` | Codex / Claude 共通の作業フロー、承認モデル、言語ポリシー、品質基準 |
| `docs/harness/skills/*.md` | tool-neutral な workflow 手順の正本 |
| `docs/harness/skills/shared/` | skill 横断の共通契約（無人 run・INDEX の更新主体・PR 作成・検証ゲートなど。sync 専用は `sync-` 接頭辞） |
| `.claude/skills/<name>/SKILL.md` | 各正本への薄い adapter（1:1 対応） |
| `.claude/rules/*.md` | 常時ロード / paths スコープの rule 層 |
| `tests/harness/` | ハーネス文書・設定の機械検査（`pnpm harness:test`）。サイズ上限・skill の 1:1・参照パスの実在・未置換 token などを CI が検査する |
| `.claude/skills/create-issue/references/project-fields.md` | GitHub Project ID / field ID など推論不能な magic value（TODO 形式） |

## Step 6: 環境、secret、deploy 下準備

`.env.example`（assets の雛形に、キー名と読み手を足す。値は書かない）、local dev、seed、migration、secret 登録手順を整える。
secret 値そのものは repo に書かない。
provider bindings、environment variables、rollback、smoke test は `docs/runbooks/` に残す。

tool/runtime version 管理と local dev command は `mise` を既定にする。
runtime、package manager、主要 CLI は `.mise.toml` など repository-local な設定に固定し、setup 手順は `mise install` から始める。
反復的な local dev / check / seed / migration command は、project の package scripts と矛盾しない範囲で `mise run <task>` から呼べるようにする。
既存 repo に別の標準がある場合は、移行するか併存するかを PR 本文の「方針と却下案」に明記する。

ブランチモデルの既定は main = dev 環境 / release = prod 環境とする。
main は壊れても復旧可能な開発環境であり、開発過程ではセキュリティより柔軟性を優先する。

| 環境 | 条件 |
|------|------|
| dev (main) | CI と build が通る。壊れても復旧可能な前提で自律 deploy してよい |
| prod (release) | prod リリース手順を踏む: main の安全性確認 → release への反映手順の確認（具体は `docs/harness/skills/deploy-verify.md` の「release 反映（prod）」。merge commit 限定、承認は release 宛て PR のマージ 1 か所） |

秘密値の挿入・変更（secret 登録、credential 投入）と課金が発生する操作（有償リソース作成、プラン変更、外部サービス契約）は人間の明示承認を得てから行う。

## Step 7: CI/CD と runner 運用整備

`references/ci-cd-runner-deploy.md` を読み、CI/CD provider、deployment strategy、runner 運用を設計する。

CI の既定は基礎 CI 1 本（`assets/.github/workflows/ci.yml` を copy）とする。

- format:check / test / build（`gate:ci`）
- test job 内で `.claude/hooks/tests/run-all.sh`（hooks の bash テスト）と `pnpm harness:test`（ハーネスの機械検査）を実行。job は増やさず、step を足すだけにする

これを超える check（workflow lint、diff check、e2e、docs gate、deploy、smoke など）は拡張候補であり、`references/ci-cd-runner-deploy.md` の拡張候補リストから必要なものだけ選び、採否と理由を PR 本文の「方針と却下案」に残す。
秘密検知は CI ではなく pre-push hook（`.claude/hooks/pre-push-ci-check.sh`）が既定の担い手になる。
定期実行 workflow は既定では収録しない。追加する場合は bootstrap 先の `docs/harness/scheduled-operations.md` の設計ガイドに従う。

GitHub Actions 等を使う場合は repo setting checklist も実装計画に含める。

- default merge strategy
- squash merge policy
- auto-delete merged branches
- branch protection
- required checks

self-hosted runner を使う場合は、foreground の `run.sh` 常用ではなく service manager 経由の常駐を推奨し、runner user、CLI login/keychain/credentials、CLI version 確認、fetch strategy、logs/status/restart 手順を runbook に残す。
`actionlint` などの check が未導入なら、未実行理由を PR 本文の「リスク」に書く。

## Step 8: 初期実装と品質 gate

最初の vertical slice を実装する。
例: 認証なし health endpoint、最小 DB migration、1 画面、1 API、1 async job、1 deploy smoke など。

実装の完了条件:

- `gate:commit` が通る（組合せの定義は `assets/docs/harness/skills/shared/verification-gates.md`）。assets の md は整形済みで、`.prettierignore` は生成物だけを除外するため、追加した文書も `format:check` の対象になる
- 秘密検知が pre-push hook に入っており、`.claude/hooks/tests/run-all.sh` が green
- `pnpm harness:test`（`pnpm install` の前なら `node tests/harness/run.mjs`）が green。失敗は、置換漏れ、opt-in グループ除去後のデッド参照、skill の 1:1 欠落、起動経路のない agent などを示す。検査は Node 22 以上の `node:test` だけで動き、追加の依存はない
- 基礎 CI（`gate:ci` に hooks テストとハーネスの機械検査を加えたもの）が通る
- smoke test が deploy 先で通る
- README または docs に local dev と deploy 手順がある
- ハーネスが次の issue 実装を自律実行できる入力/出力を持つ

## Step 9: deploy と smoke test

Intake で確認した deploy 目標に従い、dev 環境（main）へ deploy する。
branch と environment の対応は既定で main = dev / release = prod とし、変更する場合は対応表を docs と issue に残す。
prod（release）への反映は、main の安全性確認 → release への反映手順の確認を経てから行う。
`docs/harness/skills/deploy-verify.md` のステップ表は、deploy の runbook と同時に具体化する（骨格の `TODO` を残したまま完了にしない）。
deploy URL、commit SHA、environment、smoke 結果を PR 本文の「検証結果」に記録する。

失敗時は原因を分類する。

| 分類 | 対応 |
|------|------|
| code | 修正して local/CI を再実行 |
| config | secret/env/binding を修正し、値は記録しない |
| provider | 公式 status/docs を確認し、retry か代替案を提示 |
| scope | bootstrap 外なら残タスクに切り出す |

## Step 10: 完了処理と PR

完了時に以下を実行する。

1. PR 本文を確定する。途中成果の節（Intake / Gate A / Gate B）は移管先への参照だけにし、標準 5 節と「承認ログ（課金・秘密値）」「移管先の文書」を埋める（`references/bootstrap-artifacts.md`）。残 TODO（`TODO(` の一覧）と routine 登録は「リスク」に書く
2. 変更ファイルと検証結果を要約
3. Conventional Commits 形式で commit
4. branch を push し、open PR を作成する（既定の完了形）。作成手順は `assets/docs/harness/skills/shared/pr-creation.md` に従い、base は既定ブランチ、通常 PR（draft にしない）で作る
5. マージは人間の操作とする。ただし明示的に指示された場合はマージまで行ってよい

既存 repo に PR 作成規約があればそれに従う。
GitHub Project / Milestone / Label / Issue の作成・更新・comment は自律実行してよい。人間承認が必要なのは課金が発生する操作と秘密値の挿入・変更のみ。
product completion までの task は、1 session で完了可能な issue 粒度に分け、GitHub Issue として起票する。
技術判断変更が既存 issue に影響する場合、関連 issue に comment する。

## 制約

- 既定は自律実行。変更の実装から open PR の提出までを自律的に行い、マージは明示指示があった場合のみ行う
- 人間の明示承認が必須なのは、課金が発生する操作と秘密値の挿入・変更の 2 つのみ
- 技術選定は ADR、実装計画は PR 本文の標準節に残し、PR で提示する。Issue ごとの計画ファイルや bootstrap 専用の成果物ディレクトリは作らない
- 最新仕様、価格、制限、deploy 手順、CLI option は推測しない。一次情報を確認する
- secrets、tokens、本番データ、個人情報を repo に書かない
- prod リリースは main の安全性確認 → release への反映手順の確認を経てから行う
- ハーネスは `assets/MANIFEST.md` の core を基準にし、不要な opt-in グループを持ち込まない
- target repo の既存規約がある場合は、この Skill より repo 規約を優先する

## Self-check

- [ ] PR 本文の「背景」に Intake（ユーザ、core flows、制約、非目標、project language）があり、概要が `docs/product/ARCHITECTURE.md` と `docs/product/TERMS.md`、`docs/harness/OPERATING_MODEL.md` のプロダクト 1 行へ移っている
- [ ] 調査ノート（`docs/notes/research/`）に一次情報 URL、確認日、repo 観察がある
- [ ] 採用した選定が領域ごとに 1 本の ADR（採用案、代替案、棄却理由、運用リスク、cost/limits、local dev 影響）と `docs/product/TECH_STACK.md` の ADR 列にある
- [ ] 選定に infrastructure service selection と app topology selection がある
- [ ] UI がある場合、CSS / UI styling strategy の比較と ADR がある
- [ ] opt-in グループの採否とその理由が ADR 1 本にあり、workflow 一覧と言語ポリシーが `docs/harness/OPERATING_MODEL.md` にある
- [ ] 課金・秘密値が絡む項目の承認ログが PR 本文の「承認ログ（課金・秘密値）」にある（該当なしの場合はその旨を明記）
- [ ] PR 本文が標準 5 節と「承認ログ」「移管先の文書」を持ち、途中成果の節（Intake / Gate A / Gate B）は移管先への参照だけになっている。残タスクは GitHub Issue にある
- [ ] 言語方針（収録言語のまま導入するか、翻訳するか）が PR 本文に記録され、言語ポリシー節に反映されている。言語名が言語ポリシー節以外に混入していない
- [ ] `assets/MANIFEST.md` の Self-check を全項目実施した
- [ ] `pnpm harness:test` が green
- [ ] tool/runtime version 管理と local dev command が `mise` を入口にしている
- [ ] `AGENTS.md` / `CLAUDE.md` は thin adapter で、詳細手順を二重管理していない
- [ ] local と CI の検査の差が、`docs/harness/skills/shared/verification-gates.md` の名前付き組合せ（`gate:push` / `gate:ci`）の表で説明できる
- [ ] self-hosted runner を使う場合、service manager、user/credentials、CLI version、logs/status/restart runbook がある
- [ ] deploy URL と smoke test 結果が PR 本文の「検証結果」にあり、`docs/harness/skills/deploy-verify.md` の `TODO` が 0（または不採用として除去済み）
- [ ] 残っている `TODO(` を一覧にして、PR 本文の「リスク」に転記した
