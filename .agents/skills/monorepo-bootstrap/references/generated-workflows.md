# Generated Workflows

この文書は、bootstrap 先の workflow（`*-sync` 系、`create-issue`、milestone / Project 管理）を PJ 固有化・追加設計するときの参照である。
収録済み workflow 資産の一覧はここに書かない（正本台帳は `../assets/MANIFEST.md`）。

## 1. Workflow Inventory

収録済み workflow の一覧と core / opt-in 区分は `../assets/MANIFEST.md` が正本である。

- core 区分の skill doc は既定で bootstrap 先へ copy する。
- opt-in グループ（`opt-in:renovate` / `opt-in:public-site` / `opt-in:submodule` / `opt-in:traceability`）は product brief と制約から採否を判断し、採用グループのみ copy する。
- MANIFEST にない鮮度境界（env examples、API schema、security policy、async runbook、runner 運用など）が product に必要な場合のみ、新しい sync workflow を §2 の契約に従って `docs/harness/skills/<name>.md` として追加設計する。

不要な workflow を先回りで作らない。追加は「対応する surface が product に実在する」ことを条件にする。

## 2. Generic `*-sync` Shape

Every generated sync workflow should follow the same contract:

| Section | Required content |
|---------|------------------|
| Purpose | What freshness boundary this workflow owns |
| Source of truth | The canonical files or generated artifacts |
| Compared against | Code, config, schema, deploy provider, docs, dependency metadata, or runner state |
| Scope | Include / exclude paths and generated-file exclusions |
| Detection | Drift categories and severity |
| Auto-edit policy | What may be changed automatically and what must be reported only |
| Branch / PR policy | Whether to push automatically or only when user/repo policy asks |
| Validation | Commands and CI checks |
| Report shape | PR body or local report sections |
| Language | Reports, PR bodies, and review notes use the project language from intake |

生成先はすべて `docs/harness/skills/<name>.md` とする。収録済みの例:

```text
docs/harness/skills/readme-sync.md
docs/harness/skills/docs-sync.md
docs/harness/skills/code-sync.md
docs/harness/skills/refactor-guide-sync.md
docs/harness/skills/gc-scan.md
docs/harness/skills/adr-compress.md
docs/harness/skills/renovate-sync.md      (opt-in:renovate)
docs/harness/skills/public-arch-sync.md   (opt-in:public-site)
```

共通後段（origin/main 基準、0 件終了、open PR ガード、fail-closed 照会、1 スキャン 1 PR）は `docs/harness/skills/shared/` の共通契約を参照し、各 skill doc 本文に複製しない。

Each workflow should be tool-neutral.
Claude 側は `.claude/skills/<name>/SKILL.md` を薄い adapter とし、正本の手順を複製しない。

## 3. `create-issue` Specialization

`create-issue` の手順正本は copy 済みの `docs/harness/skills/create-issue.md` である。
product brief、roadmap、`references/issue-lifecycle.md` に従い、taxonomy・milestone・Project の対応を PJ 固有化する。

Required behavior:

- Build an issue body in the project language with summary, motivation, acceptance criteria, dependencies, and references.
- Infer labels from the product-specific taxonomy.
- Infer milestone from the roadmap phase.
- Infer Project board from issue category, if Projects are used.
- Set default status to Todo or the target repo's equivalent.
- Set a target/expired date only if the team uses date fields.
- Support parent/sub-issue or blocked-by relationships when GitHub supports them in the target org.
- Create or reference the issue-local docs directory `docs/issues/<number>_<scope>/`.
- Issue の作成・更新は自律実行してよい。作成後は読み戻して検証する。人間承認が必要なのは課金が発生する操作と秘密値の挿入・変更のみ。

PJ 固有値の置き場所:

```text
docs/harness/skills/create-issue.md
.claude/skills/create-issue/references/project-fields.md
docs/issues/README.md
```

`project-fields.md` must contain magic values only after they are verified from GitHub.
Until verified, keep them in `TODO(取得方法: ...)` form:

```markdown
| Project | ID | Source |
|---------|----|--------|
| Product | TODO(取得方法: gh / GraphQL で作成または照会) | create or verify with gh / GraphQL |
| Platform / Harness | TODO(取得方法: gh / GraphQL で作成または照会) | create or verify with gh / GraphQL |
```

Never invent Project IDs, field IDs, option IDs, milestone node IDs, or label IDs.
Issue titles and bodies use the project language by default.
Keep label names, code identifiers, package names, API names, and GitHub field names in their canonical spelling.

## 4. Product-Derived Taxonomy

Start from this neutral taxonomy and specialize it from the product brief.

### Required Issue Types

| Type | Use when |
|------|----------|
| `infra` | provider config, environments, secrets, deploy, migrations, storage, queue, observability |
| `web/ui` | UI screens, interaction, styling, design system, accessibility |
| `core/domain` | domain model, business rules, data validation, core workflows |
| `integration` | external API, webhook, SDK, import/export, third-party service |
| `async/job/workflow` | queue, job, workflow, scheduler, long-running task, retry/DLQ |
| `ci/cd` | CI workflow, required checks, release, branch deploy, runner operations |
| `security` | auth, authorization, secrets, privacy, audit, dependency/security policy |
| `docs` | docs, ADRs, runbooks, harness docs, public docs projection |

### Optional Cross-Cutting Labels

Use only when useful for the target repo.

- `kind:feature`
- `kind:bug`
- `kind:research`
- `kind:refactor`
- `harness:feature-flow`
- `harness:infra`
- `harness:harness`
- `harness:docs-only`
- `harness:research`

### Priority

| Priority | Meaning |
|----------|---------|
| `priority:critical` | launch blocker, security incident, data loss, production outage |
| `priority:high` | default for near-term roadmap work |
| `priority:medium` | useful but not on the immediate critical path |
| `priority:low` | cleanup, nice-to-have, low blast radius |

### Components

Derive component labels from product architecture:

| Architecture surface | Example labels |
|----------------------|----------------|
| Web app | `component:web`, `component:admin` |
| API | `component:api` |
| Database | `component:db` |
| Worker/job/queue | `component:jobs`, `component:worker` |
| Workflow | `component:workflow` |
| SDK/client | `component:sdk` |
| Infra/deploy | `component:infra` |
| Docs | `component:docs` |
| Cross-cutting | `component:shared` |

Do not copy this repository's domain-specific labels unless the target product actually has the same architecture.

## 5. Milestone Model

Generate milestones from the product roadmap in `product-brief.md`.
Use neutral phases unless the user provides named phases.

| Milestone | Typical scope |
|-----------|---------------|
| `P0: Bootstrap` | repo, harness, local dev, CI, first deploy path |
| `P1: Foundation` | auth, data model, infra, observability, shared packages |
| `P2: Core Workflow` | first end-to-end user value path |
| `P3: Admin / Operations` | admin tools, support, audit, internal ops |
| `P4: Hardening` | test depth, security, performance, reliability, docs |
| `P5: Launch` | staging/production readiness, rollout, rollback, monitoring |

If the product has regulatory or customer milestones, replace these with the user's names and preserve the same entry/exit criteria structure.

## 6. Project Model

Project board の作成・変更は自律実行してよい（人間承認が必要なのは課金が発生する操作と秘密値の挿入・変更のみ）。
作成・変更後は実値を読み戻して検証し、magic value を profile に記録する。

Default boards:

| Project | Purpose | Typical issues |
|---------|---------|----------------|
| Product | Product behavior and user-facing implementation | features, bugs, docs, SDK |
| Platform / Harness | CI, deploy, environment, agent harness, dependency automation | infra, harness, sync workflows |
| Security / Compliance | Optional board for regulated products | security, audit, privacy, incident follow-up |

Default fields:

| Field | Type | Required |
|-------|------|----------|
| Status | single-select: Todo / In Progress / In Review / Done | Yes |
| Priority | single-select or label mirror | Recommended |
| Target date or Expired date | date | Recommended if team plans by dates |
| Milestone | native GitHub milestone | Recommended |
| Component | label or single-select | Recommended |
| Owner | assignee or person field | Optional |

Record the final IDs in `.claude/skills/create-issue/references/project-fields.md`.

## 7. Approval Model

既定は自律実行とする。remote GitHub mutation のうち次は承認なしに実行してよい:

- label / milestone / Project board / Project fields・options の作成・編集
- issue / PR の作成、issue の Project への追加
- dates / status / relationships の設定
- 技術判断変更に伴う既存 issue への comment

人間の明示承認が必須なのは次の 2 つのみ:

- 課金が発生する操作（有償リソースの作成、プラン変更、外部サービス契約）
- 秘密値の挿入・変更（credential / API key / token を設定へ投入する操作）

自律実行した mutation は判断材料を成果物に残す:

- 採用した labels / milestones / Projects / fields とその理由（`harness-catalog.md` または issue-local docs）
- 実行した commands / API operations と読み戻し検証の結果
- sample generated issue

成果物とレポートは project language で書く（ユーザが明示的に別言語を指定した場合を除く）。
実行できなかった remote setup は `bootstrap-plan.md` に残タスクとして残す。
