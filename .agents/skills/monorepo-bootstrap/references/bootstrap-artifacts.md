# Bootstrap Artifacts

`monorepo-bootstrap` が生成する成果物の標準構造。
target repo に既存テンプレートがある場合は、そちらを優先し、この構造を不足確認に使う。

Durable bootstrap artifacts belong under:

```text
docs/issues/000_bootstrap/
```

Do not keep `docs/bootstrap/` as the long-lived source of truth.
If temporary scratch files are created there, migrate durable content into Issue 0, `docs/notes/research/`, `docs/adr/`, `docs/harness/`, or `docs/runbooks/` before completion.

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

## Billing / Secret Approvals

課金または秘密値に該当する項目とその承認状態のみを記録する。該当なしの場合は「該当なし」と明記する。

| Item | Category (billing / secret) | Status (Pending / Approved) | Approved by | Date |
|------|-----------------------------|-----------------------------|-------------|------|

> 承認者・日付欄は、課金 / 秘密値に該当する項目がある場合のみ記入する。それ以外の選定は承認を待たず自律続行する。
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
| Bootstrap Issue 0 | `docs/issues/000_bootstrap/` | Bootstrap artifacts and approval history | bootstrap workflow |
| Decisions | `docs/adr/` | Why, alternatives, supersession history | create-adr |
| Research | `docs/notes/research/` | Investigation and comparisons | research workflow |
| Issue plans | `docs/issues/<number>_<scope>/` | Issue-specific lifecycle docs | multi-issue / メインエージェント判断 |
| Requirements | `docs/requirements/` | Human-approved requirements | manual approval |
| Customer docs | `docs/customer/` | Originals and summaries | customer-doc-review (opt-in:public-site) |
| Runbooks | `docs/runbooks/` | Operations procedures | infra workflow |
| Public projection | `docs/product/PUBLIC_*.md` or equivalent | External/customer-safe docs | public-arch-sync (opt-in:public-site) |

## Product-Derived Workflow Inventory

収録 skill と採否は `assets/MANIFEST.md` を正本とする（本節に一覧を複製せず、MANIFEST にない workflow を追加した場合のみその理由をここに書く）。

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

| Phase | File | Notes |
|-------|------|-------|
| Inception | `docs/issues/<number>_<scope>/inception.md` | Write when the issue body is not precise |
| Plan | `docs/issues/<number>_<scope>/plan.md` | Write when the approach is unsettled/high impact |
| Construction | `docs/issues/<number>_<scope>/construction.md` | Record deviations |
| Verification | `docs/issues/<number>_<scope>/verification.md` | Required before review |
| Review notes | `docs/issues/<number>_<scope>/review-notes.md` | Required for non-trivial changes |

小さな issue は `docs/issues/<number>_<scope>/task-note.md` 1 枚に収めてよい（運用の正本は `docs/issues/README.md`）。

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

Path: `.claude/skills/create-issue/references/project-fields.md`

| Constant | Value | How it was obtained | Last verified |
|----------|-------|---------------------|---------------|

## Billing / Secret Approvals

課金または秘密値に該当する項目とその承認状態のみを記録する（taxonomy / Project / milestone の作成は自律実行のため記入対象外）。該当なしの場合は「該当なし」と明記する。

| Item | Category (billing / secret) | Status (Pending / Approved) | Approved by | Date |
|------|-----------------------------|-----------------------------|-------------|------|

> 承認者・日付欄は、課金 / 秘密値に該当する項目がある場合のみ記入する。
```

Rules:

- Generate taxonomy from the product brief and roadmap, not from this repository's domain labels.
- Do not invent GitHub Project IDs, field IDs, option IDs, or milestone node IDs.
- If the Project or fields do not exist yet, write placeholders and a creation task in `bootstrap-plan.md`.
- Keep the Codex / Claude invocation notes thin; workflow details live in shared docs.
- issue / PR / ラベル / milestone / Project 等の GitHub mutation は自律実行してよい（人間の明示承認が必須なのは課金が発生する操作と秘密値の挿入・変更のみ）。

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
| project field constants | `.claude/skills/create-issue/references/project-fields.md` | |
| issue 成果物の運用 | `docs/issues/README.md` | |

## 7. Environment

| Item | Path/Provider | Notes |
|------|---------------|-------|
| tool/runtime version management | `.mise.toml` or repo-local mise config | Pin runtime, package manager, and major CLI versions; setup starts with `mise install` |
| local dev task entrypoints | `mise run <task>` and package scripts | Keep repeated dev/check/seed/migration commands callable through mise without hiding package-native scripts |
| env examples | `.env.example` and docs/runbooks | Document required names and safe sample values only |
| secrets | provider / secret manager | Document registration steps and naming convention, never secret values |

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

## 13. Billing / Secret Approvals

課金または秘密値に該当する項目とその承認状態のみを記録する。該当なしの場合は「該当なし」と明記する。

| Item | Category (billing / secret) | Status (Pending / Approved) | Approved by | Date |
|------|-----------------------------|-----------------------------|-------------|------|

> 承認者・日付欄は、課金 / 秘密値に該当する項目がある場合のみ記入する。それ以外の計画項目は承認を待たず実装へ自律続行する。
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
