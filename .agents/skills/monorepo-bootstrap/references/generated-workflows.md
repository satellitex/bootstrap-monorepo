# Generated Workflows

Use this reference when `monorepo-bootstrap` needs to generate reusable workflows from a product brief: generic `*-sync` workflows, `create-issue`, and milestone / Project management.

## 1. Product Brief To Workflow Inventory

Derive workflows from product surfaces and operational needs.

| Product signal | Generate workflow | Purpose |
|----------------|-------------------|---------|
| Any repo with code | `static-check` | One command for format, lint, typecheck, test, build |
| Any planned feature work | `implement-feature` | Issue/requirements to implementation, verification, PR |
| CI, deploy, secrets, infra, migrations | `bootstrap-infra` or `operate-infra` | Plan-first environment and operations changes |
| Multiple README files or package/app boundaries | `readme-sync` | README freshness against current code |
| Product/architecture docs as current-state docs | `docs-sync` | Keep docs aligned with code and prevent stale prose |
| Public API comments, SDK docs, generated docs | `code-sync` | Keep source comments publishable and current |
| Public/customer/shared docs derived from internal docs | `public-docs-sync` | Project internal docs into a safe external version |
| Dependency automation via Renovate/Dependabot | `dependency-sync` | Detect untracked pins and cross-manager version drift |
| Environment bindings, `.env.example`, secrets, deploy targets | `env-sync` | Keep env examples, secret docs, and deploy bindings aligned |
| OpenAPI/GraphQL/protobuf/schema-driven SDK | `api-schema-sync` | Keep schema, generated client, docs, and tests aligned |
| Security/compliance-sensitive product | `security-sync` | Secret scan policy, authz docs, audit controls, dependency alerts |
| Long-running tasks, queues, workflows, schedulers | `async-ops-sync` or product-specific workflow | Keep async runbooks, retries, DLQ, and visibility aligned |
| Self-hosted runner | `runner-sync` or runner runbook check | Keep runner service, credentials, logs, and CLI versions documented |

Do not generate every workflow by default.
Generate `static-check`, `implement-feature`, `bootstrap-infra`, and `create-issue` unless the user opts out.
Add `*-sync` workflows only when the product has the corresponding surface.

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

Recommended generated files:

```text
docs/harness/skills/readme-sync.md
docs/harness/skills/docs-sync.md
docs/harness/skills/code-sync.md
docs/harness/skills/public-docs-sync.md
docs/harness/skills/dependency-sync.md
docs/harness/skills/env-sync.md
docs/harness/skills/api-schema-sync.md
docs/harness/skills/security-sync.md
```

Each workflow should be tool-neutral.
If Claude slash commands or Codex Skills are installed later, they should point to these shared docs instead of duplicating the procedure.

## 3. `create-issue` Generation

Generate `docs/harness/skills/create-issue.md` from the product brief, roadmap, and `references/issue-lifecycle.md`.

Required behavior:

- Build an issue body in the project language with summary, motivation, acceptance criteria, dependencies, and references.
- Infer labels from the product-specific taxonomy.
- Infer milestone from the roadmap phase.
- Infer Project board from issue category, if Projects are used.
- Set default status to Todo or the target repo's equivalent.
- Set a target/expired date only if the team uses date fields.
- Support parent/sub-issue or blocked-by relationships when GitHub supports them in the target org.
- Create or reference the issue-local docs directory `docs/product/issues/<number>-<slug>/`.
- Ask for human confirmation before creating or mutating remote GitHub state.

Required generated references:

```text
docs/harness/project-management.md
docs/harness/references/project-fields.md
docs/harness/issue-lifecycle.md
```

`project-fields.md` must contain magic values only after they are verified from GitHub.
Use placeholders until then:

```markdown
| Project | ID | Source |
|---------|----|--------|
| Product | TODO | create or verify with gh / GraphQL |
| Platform / Harness | TODO | create or verify with gh / GraphQL |
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

Create a Project model only after human approval.

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

Record the final IDs in `docs/harness/references/project-fields.md`.

## 7. Approval Gates

Remote GitHub mutation requires approval:

- Creating labels
- Creating milestones
- Creating or editing Project boards
- Creating Project fields/options
- Creating issues
- Adding issues to Projects
- Setting dates/status/relationships
- Commenting on existing issues because a technical decision changed their scope

Before mutation, present:

- proposed labels and descriptions
- proposed milestones with entry/exit criteria
- proposed Projects and fields
- sample generated issue
- commands or API operations to run

Present the approval summary in the project language unless the user explicitly requests another language.

If approval is not granted, generate local docs and leave remote setup as tasks in `bootstrap-plan.md`.
