# Bootstrap Artifacts

`monorepo-bootstrap` が生成する成果物の標準構造。
target repo に既存テンプレートがある場合は、そちらを優先し、この構造を不足確認に使う。

## product-brief.md

```markdown
# Product Brief: <project name>

## Summary

- Problem:
- Users:
- Core value:
- First deploy target:
- Default language: 日本語

## Language Policy

- Default communication language: 日本語
- Applies to: user chat, Issues, PRs, ADRs, review comments, sync reports, runbooks, and internal docs
- Exceptions: code identifiers, API/package names, external specification names, quoted source titles, and deliverables explicitly requested in another language

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
- External integrations:

## Constraints

- Technical:
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

| Topic | Source | Why it matters |
|-------|--------|----------------|

## Findings

| Area | Finding | Confidence | Follow-up |
|------|---------|------------|-----------|

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
```

Rules:

- Use primary sources for current product docs, pricing, API limits, deploy behavior, and CI/CD syntax.
- Record URLs and access dates when the result may change.
- Separate observation from recommendation.

## decision-matrix.md

```markdown
# Technology Decision Matrix

## Recommended Stack

| Area | Choice | Why | Risk | Mitigation |
|------|--------|-----|------|------------|

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

## harness-catalog.md

```markdown
# Harness Catalog

## Docs Operating Model

| Area | Path | Responsibility | Sync owner |
|------|------|----------------|------------|
| Knowledge hub | `docs/README.md` | Placement rules and INDEX discipline | docs-sync |
| State-of-now | `docs/product/`, `docs/styles/`, `docs/schedule/` | Current facts only | docs-sync |
| Decisions | `docs/product/adr/` | Why, alternatives, supersession history | create-adr |
| Research | `docs/notes/research/` | Investigation and comparisons | research workflow |
| Issue plans | `docs/product/issues/` | Issue-specific plans | implement-feature/bootstrap-infra |
| Requirements | `docs/requirements/` | Human-approved requirements | manual approval |
| Customer docs | `docs/customer/` | Originals and summaries | customer-docs workflow |
| Runbooks | `docs/runbooks/` | Operations procedures | env-sync / infra workflow |
| Public projection | `docs/product/PUBLIC_*.md` | External/customer-safe docs | public-docs-sync |

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

## Issue Taxonomy

| Category | Values | Derivation from product brief | Notes |
|----------|--------|-------------------------------|-------|
| Type labels | | | |
| Component labels | | | |
| Priority labels | | | |
| Harness labels | | | |

## Language Policy

| Surface | Default language | Exceptions |
|---------|------------------|------------|
| User-facing agent replies | 日本語 | User explicitly requests another language |
| GitHub Issues / PRs | 日本語 | Code identifiers, labels, commit types |
| ADR / planning docs | 日本語 | External standard names, quoted source titles |
| Public docs / SDK docs | 日本語 by default | English if product brief or customer requires it |
| Sync reports | 日本語 | File paths, symbols, command output |

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

- Generate taxonomy from the product brief and roadmap, not from this repository's BWB-specific labels.
- Do not invent GitHub Project IDs, field IDs, option IDs, or milestone node IDs.
- If the Project or fields do not exist yet, write placeholders and a creation task in `bootstrap-plan.md`.
- Keep Codex and Claude invocation columns thin; workflow details live in shared docs.

## bootstrap-plan.md

```markdown
# Bootstrap Plan

## 0. Metadata

- Project:
- Branch:
- Bootstrap directory:
- Approved stack:
- Deploy target:

## 1. Scope

### In Scope

- ...

### Out Of Scope

- ...

## 2. Architecture

| Layer | Path | Responsibility | Depends on |
|-------|------|----------------|------------|

## 3. Docs Operating Model

| Docs artifact | Path | Purpose | Required before first implementation |
|---------------|------|---------|--------------------------------------|

## 4. Harness

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

## 5. Environment

| Item | Path/Provider | Notes |
|------|---------------|-------|

## 6. CI/CD

| Check | Command/Workflow | Required before merge |
|-------|------------------|-----------------------|

## 7. Deploy

| Environment | Provider | Trigger | Smoke check | Rollback |
|-------------|----------|---------|-------------|----------|

## 8. Implementation Tasks

| Task | Why | What | Verification | Depends on |
|------|-----|------|--------------|------------|

## 9. Risks And Mitigations

| Risk | Impact | Mitigation | Owner |
|------|--------|------------|-------|

## 10. Gate B Approval

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

## Remaining Work

| Item | Reason | Suggested owner |
|------|--------|-----------------|

## PR Notes

- Artifacts:
- Risks:
- Follow-up issues:
```
