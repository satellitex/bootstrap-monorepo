# Bootstrap Artifacts

`monorepo-bootstrap` が生成する成果物の標準構造。
target repo に既存テンプレートがある場合は、そちらを優先し、この構造を不足確認に使う。

Durable bootstrap artifacts belong under:

```text
docs/product/issues/000-bootstrap/
```

Do not keep `docs/bootstrap/` as the long-lived source of truth.
If temporary scratch files are created there, migrate durable content into Issue 0, `docs/notes/research/`, `docs/product/adr/`, `docs/harness/`, or `docs/runbooks/` before completion.

## product-brief.md

```markdown
# Product Brief: <project name>

## Summary

- Problem:
- Users:
- Core value:
- First deploy target:
- Project language:

## Language Policy

- Default communication language:
- Applies to: user chat, Issues, PRs, ADRs, review comments, sync reports, runbooks, and internal docs
- Exceptions: code identifiers, API/package names, JSON keys, standard errors, external specification names, quoted source titles, and deliverables explicitly requested in another language

## Core Flows

| ID | Actor | Flow | Success signal |
|----|-------|------|----------------|
| CF-1 | | | |

## Data And Trust

| Data | Owner | Sensitivity | Retention | Audit need |
|------|-------|-------------|-----------|------------|

## Interfaces

- Web:
- API:
- Background jobs:
- Workflow/queue:
- External agents/workers:
- External integrations:

## Constraints

- Technical:
- Provider/runtime:
- Organization:
- Cost:
- Compliance:
- Timeline:

## Non-goals

- ...

## Open Questions

| ID | Question | Impact | Owner |
|----|----------|--------|-------|
```

## research.md

```markdown
# Bootstrap Research

## Repository Observations

| Area | Observation | Evidence |
|------|-------------|----------|

## External Sources

| Topic | Source | Access date | Why it matters |
|-------|--------|-------------|----------------|

## Findings

| Area | Finding | Confidence | Follow-up |
|------|---------|------------|-----------|

## Provider / Runtime Notes

| Option | Source | Limits checked | Cost checked | Local dev notes |
|--------|--------|----------------|--------------|-----------------|

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
```

Rules:

- Use primary sources for current product docs, pricing, API limits, deploy behavior, CLI options, CI/CD syntax, and migration behavior.
- Record URLs and access dates when the result may change.
- Separate observation from recommendation.
- Do not infer provider limits from memory when the decision depends on them.

## decision-matrix.md

```markdown
# Technology Decision Matrix

## Recommended Stack

| Area | Choice | Why | Operational risk | Cost / limits | Local dev impact | Source |
|------|--------|-----|------------------|---------------|------------------|--------|

## Required Domain Decisions

| Domain | Recommended | Alternatives | Rejected reasons | Operational risks | Cost / limits | Local dev impact | Sources |
|--------|-------------|--------------|------------------|-------------------|---------------|------------------|---------|
| App framework / language / monorepo tool | | | | | | | |
| Deploy / hosting provider | | | | | | | |
| Runtime model | | | | | | | |
| Database | | | | | | | |
| Object/file storage | | | | | | | |
| Cache | | | | | | | |
| Queue / workflow / job orchestration | | | | | | | |
| Long-running task handling | | | | | | | |
| External agent / worker runtime boundary | | | | | | | |
| Auth / identity | | | | | | | |
| Observability | | | | | | | |
| CI/CD provider and deployment strategy | | | | | | | |
| CSS / UI styling strategy | | | | | | | |

## Infrastructure Service Selection

| Service | Adopted approach | Alternative | Why | Gate / follow-up |
|---------|------------------|-------------|-----|------------------|
| Deploy / hosting | | | | |
| Runtime model | | | | |
| Database | | | | |
| Object/file storage | | | | |
| Cache | | | | |
| Queue / workflow / job orchestration | | | | |
| Long-running tasks | | | | |
| External agent / worker boundary | | | | |
| Auth / identity | | | | |
| Observability | | | | |
| CI/CD | | | | |

## App Topology

| Option | Shape | Pros | Cons | Decision |
|--------|-------|------|------|----------|

Decision:
Rationale:
ADR:

## CSS / UI Styling Strategy

Required only when UI exists.

| Option | Design system fit | Typed tokens | Runtime cost | Team familiarity | Migration cost | Decision |
|--------|-------------------|--------------|--------------|------------------|----------------|----------|

Decision:
ADR:

## Alternatives Considered

| Area | Option | Pros | Cons | Decision |
|------|--------|------|------|----------|

## Decisions To Confirm

| ID | Decision | Default | Needs human input because |
|----|----------|---------|---------------------------|

## Gate A Approval

- Status: Pending / Approved / Revision requested
- Approved by:
- Date:
- Notes:
```

Decision criteria:

- Fit to product flows and operational capacity
- Long-term maintainability
- Local development speed
- CI reliability and cost
- Deploy target maturity
- Security and compliance requirements
- Lock-in and migration cost
- Provider/runtime limits and pricing
- App topology and deployment/scaling boundaries

## harness-catalog.md

```markdown
# Harness Catalog

## Docs Operating Model

| Area | Path | Responsibility | Sync owner |
|------|------|----------------|------------|
| Knowledge hub | `docs/README.md` | Placement rules and INDEX discipline | docs-sync |
| Harness docs | `docs/harness/` | Tool-neutral workflows, roles, rules, adapters | docs-sync |
| State-of-now | `docs/product/`, `docs/styles/` | Current facts only | docs-sync |
| Bootstrap Issue 0 | `docs/product/issues/000-bootstrap/` | Bootstrap artifacts and approval history | bootstrap workflow |
| Decisions | `docs/product/adr/` | Why, alternatives, supersession history | create-adr |
| Research | `docs/notes/research/` | Investigation and comparisons | research workflow |
| Issue plans | `docs/product/issues/<number>-<slug>/` | Issue-specific lifecycle docs | implement-feature/bootstrap-infra |
| Requirements | `docs/requirements/` | Human-approved requirements | manual approval |
| Customer docs | `docs/customer/` | Originals and summaries | customer-docs workflow |
| Runbooks | `docs/runbooks/` | Operations procedures | env-sync / infra workflow |
| Public projection | `docs/product/PUBLIC_*.md` or equivalent | External/customer-safe docs | public-docs-sync |

## Product-Derived Workflow Inventory

| Workflow | Generate? | Why this product needs it | Output path | Codex invocation | Claude invocation |
|----------|-----------|---------------------------|-------------|------------------|-------------------|
| static-check | Yes | | `docs/harness/skills/static-check.md` | | |
| implement-feature | Yes | | `docs/harness/skills/implement-feature.md` | | |
| bootstrap-infra | Yes | | `docs/harness/skills/bootstrap-infra.md` | | |
| create-issue | Yes | | `docs/harness/skills/create-issue.md` | | |
| readme-sync | | | `docs/harness/skills/readme-sync.md` | | |
| docs-sync | | | `docs/harness/skills/docs-sync.md` | | |
| code-sync | | | `docs/harness/skills/code-sync.md` | | |
| public-docs-sync | | | `docs/harness/skills/public-docs-sync.md` | | |
| dependency-sync | | | `docs/harness/skills/dependency-sync.md` | | |
| env-sync | | | `docs/harness/skills/env-sync.md` | | |
| api-schema-sync | | | `docs/harness/skills/api-schema-sync.md` | | |
| security-sync | | | `docs/harness/skills/security-sync.md` | | |

## Issue Taxonomy

| Type | Use when | Default labels |
|------|----------|----------------|
| infra | deploy/provider/runtime/storage/DB/cache/queue/observability | |
| web/ui | screens, components, styling, design system, accessibility | |
| core/domain | business rules, data model, core workflow | |
| integration | external APIs, webhooks, SDK, import/export | |
| async/job/workflow | queue, jobs, workflows, scheduler, long-running tasks | |
| ci/cd | CI, release, branch deploy, runner operations | |
| security | auth, authorization, secrets, privacy, audit | |
| docs | docs, ADRs, runbooks, harness docs | |

## Issue Lifecycle

| Phase | File | Approval behavior |
|-------|------|-------------------|
| Inception | `docs/product/issues/<number>-<slug>/inception.md` | Required when issue body is not precise |
| Plan | `docs/product/issues/<number>-<slug>/plan.md` | Approval required when approach is unsettled/high impact |
| Construction | `docs/product/issues/<number>-<slug>/construction.md` | Record deviations |
| Verification | `docs/product/issues/<number>-<slug>/verification.md` | Required before review |
| Review notes | `docs/product/issues/<number>-<slug>/review-notes.md` | Required for non-trivial changes |

## Language Policy

| Surface | Default language | Exceptions |
|---------|------------------|------------|
| User-facing agent replies | <project language> | User explicitly requests another language |
| GitHub Issues / PRs | <project language> | Code identifiers, labels, commit types |
| ADR / planning docs | <project language> | External standard names, quoted source titles |
| Public docs / SDK docs | <project language> | Another language if product brief or customer requires it |
| Sync reports | <project language> | File paths, symbols, command output |

## Milestones

| Milestone | Product phase | Entry criteria | Exit criteria |
|-----------|---------------|----------------|---------------|

## Project Model

| Project | Purpose | Included issue types | Fields |
|---------|---------|----------------------|--------|

## Project Field Constants

Path: `docs/harness/references/project-fields.md`

| Constant | Value | How it was obtained | Last verified |
|----------|-------|---------------------|---------------|

## Human Approvals

- Taxonomy approved by:
- Project/milestone creation approved by:
- Date:
```

Rules:

- Generate taxonomy from the product brief and roadmap, not from this repository's domain labels.
- Do not invent GitHub Project IDs, field IDs, option IDs, or milestone node IDs.
- If the Project or fields do not exist yet, write placeholders and a creation task in `bootstrap-plan.md`.
- Keep Codex and Claude invocation columns thin; workflow details live in shared docs.
- Remote GitHub mutation requires human approval.

## bootstrap-plan.md

```markdown
# Bootstrap Plan

## 0. Metadata

- Project:
- Branch:
- Bootstrap artifacts:
- Approved stack:
- Deploy target:
- Project language:

## 1. Scope

### In Scope

- ...

### Out Of Scope

- ...

## 2. Architecture

| Layer | Path | Responsibility | Depends on |
|-------|------|----------------|------------|

## 3. Infrastructure Service Selection

| Service | Selected approach | Required setup | Verification | Runbook |
|---------|-------------------|----------------|--------------|---------|
| Deploy / hosting | | | | |
| Runtime model | | | | |
| Database | | | | |
| Object/file storage | | | | |
| Cache | | | | |
| Queue / workflow / job orchestration | | | | |
| Long-running tasks | | | | |
| External agent / worker boundary | | | | |
| Auth / identity | | | | |
| Observability | | | | |

## 4. App Topology

| Unit | Path | Deploy unit | Scaling unit | Auth/session boundary | Async responsibility |
|------|------|-------------|--------------|-----------------------|----------------------|

## 5. Docs Operating Model

| Docs artifact | Path | Purpose | Required before first implementation |
|---------------|------|---------|--------------------------------------|

## 6. Harness

| Harness item | Path | Purpose | Required for first iteration |
|--------------|------|---------|------------------------------|

### Codex / Claude Adapter

| Tool | Entry file | How it invokes the shared workflow | Tool-specific notes |
|------|------------|------------------------------------|---------------------|
| Codex | `AGENTS.md` | | |
| Claude | `CLAUDE.md` | | |

Shared source of truth:

- Docs operating model:
- Language policy:
- Skill/workflow docs:
- Role docs:
- Rules:

### Generated Sync Workflows

| Workflow | Freshness source | Compared against | Auto-edit scope | Creates PR? |
|----------|------------------|------------------|-----------------|-------------|

### Issue And Project Management

| Artifact | Path | Purpose |
|----------|------|---------|
| create-issue workflow | `docs/harness/skills/create-issue.md` | |
| project field constants | `docs/harness/references/project-fields.md` | |
| project management guide | `docs/harness/project-management.md` | |
| issue lifecycle guide | `docs/harness/issue-lifecycle.md` or equivalent | |

## 7. Environment

| Item | Path/Provider | Notes |
|------|---------------|-------|

## 8. CI/CD

| Check | Command/Workflow | Required before merge | Notes |
|-------|------------------|-----------------------|-------|
| YAML parse / workflow lint | | | |
| base branch diff check | | | |
| format/lint/typecheck/test/build | | | |
| docs gate | | | |
| secret scan | | | |
| deploy/smoke | | | |

## 9. Runner Operations

Required if self-hosted runner is used.

| Topic | Decision | Runbook path |
|-------|----------|--------------|
| service manager | | |
| runner user / credentials | | |
| CLI versions and `--help` checks | | |
| fetch strategy | | |
| logs/status/restart | | |

## 10. Deploy

| Environment | Provider | Trigger | Smoke check | Rollback | Approval required |
|-------------|----------|---------|-------------|----------|-------------------|

## 11. Implementation Tasks

| Task | Issue type | Why | What | Verification | Depends on |
|------|------------|-----|------|--------------|------------|

## 12. Risks And Mitigations

| Risk | Impact | Mitigation | Owner |
|------|--------|------------|-------|

## 13. Gate B Approval

- Status: Pending / Approved / Revision requested
- Approved by:
- Date:
- Notes:
```

## implementation-report.md

```markdown
# Implementation Report

## Summary

- Branch:
- Commit:
- Deploy URL:
- CI:

## Changed Files

| Path | Purpose |
|------|---------|

## Verification

| Check | Result | Notes |
|-------|--------|-------|

## Deploy

| Environment | URL | Smoke result | Notes |
|-------------|-----|--------------|-------|

## Remote Mutations

| System | Mutation | Approval reference |
|--------|----------|--------------------|

## Remaining Work

| Item | Reason | Suggested owner |
|------|--------|-----------------|

## PR Notes

- Artifacts:
- Risks:
- Follow-up issues:
```
