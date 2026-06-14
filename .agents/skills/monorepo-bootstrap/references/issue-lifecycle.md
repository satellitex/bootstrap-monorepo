# Issue Lifecycle Reference

Use this reference when `monorepo-bootstrap` creates `harness-catalog.md`, `bootstrap-plan.md`, `docs/harness/skills/create-issue.md`, and issue-local planning templates.
The goal is to make every issue small enough for one focused implementation session while preserving decision history and approval gates.

## 1. Issue Docs Location

Each implementation issue owns a directory:

```text
docs/product/issues/<number>-<slug>/
```

Recommended files:

| File | Purpose |
|------|---------|
| `inception.md` | Problem framing, scope, constraints, acceptance criteria, open questions |
| `plan.md` | Chosen implementation approach, files/modules, test strategy, docs impact |
| `construction.md` | Execution notes, commands run, deviations from plan |
| `verification.md` | Local/CI/deploy checks, evidence, residual risk |
| `review-notes.md` | Review feedback, evaluator notes, follow-up tasks |
| `traceability.md` | Acceptance criteria to tests/docs/implementation mapping, if needed |

Bootstrap itself is Issue 0:

```text
docs/product/issues/000-bootstrap/
```

Do not keep long-lived bootstrap artifacts in `docs/bootstrap/`.
If `docs/bootstrap/` is used as a temporary scratch area, migrate durable artifacts into Issue 0 or the normal docs tree before completion.

## 2. Issue Taxonomy

Use this neutral taxonomy as the starting point.
Specialize only when the product architecture requires more precise categories.

| Type | Scope |
|------|-------|
| `infra` | provider config, environments, secrets, deploy, migrations, storage, queue, observability |
| `web/ui` | UI screens, interaction, styling, design system, accessibility |
| `core/domain` | domain model, business rules, data validation, core workflows |
| `integration` | external API, webhook, SDK, import/export, third-party service |
| `async/job/workflow` | queue, job, workflow, scheduler, long-running task, retry/DLQ |
| `ci/cd` | CI workflow, required checks, release, branch deploy, runner operations |
| `security` | auth, authorization, secrets, privacy, audit, dependency/security policy |
| `docs` | docs, runbooks, ADRs, harness docs, public docs projection |

Labels may mirror these values, but label names can follow the target repo's conventions.
Keep canonical product terms, package names, API names, and GitHub field names in their original spelling.

## 3. Lifecycle

| Phase | Required output | Gate |
|-------|-----------------|------|
| Inception | `inception.md` with problem, scope, AC, constraints, dependencies | Optional if issue body is already precise |
| Plan | `plan.md` with approach, topology impact, tests, docs, rollout | Human approval required when approach is uncertain or high-impact |
| Construction | Code/docs diff and `construction.md` notes for deviations | No new scope without updating plan |
| Verification | `verification.md` with commands, CI, deploy/smoke, skipped checks | Required before review |
| Review notes | `review-notes.md` or PR review summary | Required for non-trivial changes |

Issue creation-time implementation detail may be strict enough to skip the inception approval gate.
If the plan is not strict, finish inception first, open or update a draft PR, and ask for human confirmation before implementation.

## 4. Approval Gate Rules

An issue-local approval gate is required when any of these are true:

- technology choice is unsettled
- provider/runtime/database/storage/queue/auth/observability selection may change
- production deploy, paid resource, destructive migration, or external publication is involved
- security, privacy, auth, or tenant boundary changes
- app topology or package boundaries change
- implementation spans multiple deploy/scaling units
- long-running or async workflow durability is not yet designed
- issue has unclear acceptance criteria

Approval gate may be skipped when all are true:

- issue body already contains precise acceptance criteria
- implementation approach and affected modules are clear
- no cross-cutting architecture decision is being made
- no remote mutation, billing, production deploy, destructive migration, or external publication occurs
- verification commands and docs impact are known

## 5. Draft PR Gate

When the plan needs confirmation before implementation:

1. Create `inception.md` and `plan.md`.
2. Open a draft PR or update an existing draft PR with links to the issue docs.
3. Include proposed files, test plan, docs impact, risks, and explicit open questions.
4. Wait for human approval before construction.

The draft PR should be used for plan review, not as a substitute for the issue-local docs.

## 6. ADR Triggers

Create an ADR when the issue makes or changes a decision that is:

- cross-cutting across apps/packages/services
- hard to reverse
- likely to affect future issue planning
- tied to provider/runtime/database/storage/queue/auth/observability
- tied to CSS/UI styling strategy or design system
- tied to CI/CD provider, branch deploy, or runner operations
- tied to public API contracts, data retention, compliance, or security boundaries

ADR is not required for narrow implementation details that are fully local to one issue and easy to reverse.

## 7. Remote GitHub Mutation

Creating or mutating GitHub labels, milestones, Projects, fields, issues, or issue relationships is remote mutation.
Do it only after human approval.

Before mutation, present:

- proposed labels and descriptions
- proposed milestones with entry/exit criteria
- proposed Projects and fields
- sample issue body
- commands/API operations to run

If approval is not granted, write local docs and leave remote setup as tasks in `bootstrap-plan.md`.

## 8. Issue Size

Break product completion into issues that a single agent session can complete.
Good issues usually have:

- one primary user or operator outcome
- one deploy/scaling boundary
- clear acceptance criteria
- a bounded test plan
- explicit docs impact

Split issues when:

- infrastructure choice and feature implementation are both unsettled
- UI, API, DB, and async workflow all need independent verification
- production deploy or remote migration approval is required
- a changed technical decision invalidates existing issue plans

When a technical decision changes existing issues, comment on or update the affected issue docs and GitHub issues after approval.
