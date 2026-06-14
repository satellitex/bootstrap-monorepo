# Docs Operating Model

Use this reference when `monorepo-bootstrap` generates the target monorepo's docs structure and freshness rules.
The goal is to keep agent entrypoints thin, place durable project operations under `docs/`, and preserve clear responsibility boundaries.

## 1. Placement Principles

| Principle | Rule |
|-----------|------|
| Agent-only files | Put only files that agents directly load or execute under `.agents/` or `.claude/`. |
| Thin adapters | Keep `AGENTS.md` and `CLAUDE.md` short pointers to shared docs and commands. Do not duplicate detailed procedures. |
| Durable project docs | Put operating model, issue lifecycle, workflow procedures, runbooks, ADRs, and product docs under `docs/`. |
| Bootstrap Issue 0 | Treat completed bootstrap artifacts as `docs/product/issues/000-bootstrap/`. |
| No permanent `docs/bootstrap/` | Use `docs/bootstrap/` only as temporary scratch if needed; migrate durable content before completion. |
| Index discipline | Directories that agents navigate should have `README.md` or `INDEX.md`, updated in the same change. |

## 2. Required Docs Map

Generate a docs knowledge hub first.

| Path | Role | Notes |
|------|------|-------|
| `docs/README.md` | Docs knowledge hub | Placement map, naming, INDEX update rules |
| `docs/harness/` | Agent/tool operating model | Tool-neutral workflow docs, roles, rules, project management, language policy |
| `docs/harness/OPERATING_MODEL.md` | Shared operating model | Gates, quality standards, Codex/Claude handoff |
| `docs/harness/LANGUAGE_POLICY.md` | Project language policy | Derived from intake, not fixed by template |
| `docs/product/` | Product definition | Current-state docs such as ARCHITECTURE, TECH_STACK, INFRA, TERMS, API_FLOWS |
| `docs/product/adr/` | Decision layer | Why, alternatives, supersession, deprecation |
| `docs/product/issues/000-bootstrap/` | Bootstrap Issue 0 | Bootstrap artifacts, Gate A/B approvals, implementation report |
| `docs/product/issues/<number>-<slug>/` | Issue planning layer | inception, plan, construction, verification, review notes |
| `docs/product/templates/` | Planning templates | Inception, plan, construction, verification, traceability templates |
| `docs/requirements/` | Requirements canonical source | Human-approved; AI auto-edit is out of scope unless explicitly allowed |
| `docs/customer/originals/` | Customer originals | Original files only |
| `docs/customer/summaries/` | Customer source summaries | Safe summaries of originals |
| `docs/notes/research/` | Research layer | Comparisons, external standards, investigations |
| `docs/notes/mtgs/` | Meeting logs | Time-sequenced meeting records |
| `docs/runbooks/` | Operations procedures | Setup, secrets, deploy, rollback, incident, runner operations |
| `docs/styles/` | Engineering rules | Coding, docs, security, testing, harness authoring |
| `docs/operations/` | Operations data | Docs site metadata, changelog data, persistent generated ops data |

Scale this list to the target repo.
Do not generate customer/public docs scaffolding unless the product needs it.

## 3. Four-Layer Model

Docs are separated by responsibility.

| Layer | Typical path | Allowed | Not allowed |
|-------|--------------|---------|-------------|
| State-of-Now | `docs/product/**/*.md`, `docs/styles/**`, root adapters/rules | Current system facts, current stack, current terms, global rules | History, migration story, rejected alternatives, future plans |
| Decision | `docs/product/adr/` | Why, alternatives, trade-offs, superseded/deprecated decisions | Detailed implementation plans |
| Research | `docs/notes/research/` | Candidate comparison, investigation, external standard summaries | Declaring final adoption without ADR |
| Implementation Plan | `docs/product/issues/<id>/` | Issue-specific inception, plan, construction, verification, traceability | Cross-cutting current facts that belong in State-of-Now |
| Operations | `docs/runbooks/`, `docs/harness/` | Current operational procedures, workflow contracts, approvals | Product decision rationale that belongs in ADR |

Generated target repos should include this model in `docs/styles/coding_guide/docs.md` or equivalent.

## 4. State-of-Now Rules

State-of-Now docs must contain only "how the system is now".

Required principles:

| Principle | Rule |
|-----------|------|
| No-Time | Do not write past/future/migration prose in current-state docs |
| No-Ticket-In-Prose | Do not embed Issue/PR numbers in prose; use related resources sections |
| No-Counterfactual | Do not write rejected alternatives or "X instead of Y"; put that in ADR/research |

Allowed exceptions:

- Current version numbers
- ADR/research/requirements links in footnotes, references, or related resources
- Requirement IDs where the term table or requirement mapping needs them
- Architectural invariants such as "the system does not store user private keys"
- Code examples where the text is part of code

## 5. README Responsibility

README files are local maps for nearby code, setup, commands, and package/app-specific structure.

Use `readme-sync` for:

- app/package directory maps
- local setup and commands
- generated/handwritten boundaries
- near-code architecture notes

Use `docs-sync` for:

- `docs/product/ARCHITECTURE.md`
- `docs/product/INFRA.md`
- `docs/product/TECH_STACK.md`
- `docs/product/TERMS.md`
- `docs/styles/**`
- global rules/adapters that describe current operation

## 6. Customer And Public Docs

If the product has customer-facing docs, separate internal canonical docs from public projection.

Recommended pattern:

| Internal source | Public projection | Sync owner |
|-----------------|-------------------|------------|
| `docs/product/ARCHITECTURE.md` | `docs/product/PUBLIC_ARCHITECTURE.md` or equivalent | `public-docs-sync` |
| OpenAPI schema | `/api` docs site or generated reference | `api-schema-sync` |
| Source doc comments | SDK / code reference | `code-sync` |
| Customer originals | `docs/customer/summaries/` | customer source workflow |

Public/customer docs gate should detect:

- internal doc paths
- ADR IDs, requirement IDs, issue/PR references
- internal service/provider names that must be abstracted
- unsafe source paths

If no public docs exist, leave `public-docs-sync` out and record why in `harness-catalog.md`.

## 7. Sync Ownership

Use separate sync workflows so each owns one freshness boundary.

| Workflow | Owns | Does not own |
|----------|------|--------------|
| `readme-sync` | README vs nearby code | Product current-state docs |
| `docs-sync` | Current-state docs vs code/config/requirements | README, ADR/research creation |
| `code-sync` | Source comments and public doc comments | README or product docs |
| `public-docs-sync` | Public projection from internal docs | Internal canonical docs |
| `dependency-sync` | Dependency automation coverage | Product code behavior |
| `env-sync` | env examples, secret docs, bindings | Secret values |
| `api-schema-sync` | schema/generated client/docs/test alignment | Business implementation |
| `security-sync` | secret scan policy, authz docs, audit controls, dependency alerts | Feature implementation |

Each sync workflow must define source of truth, compared-against target, include/exclude paths, auto-edit scope, validation commands, and report format.

## 8. Templates To Generate

Recommended docs/harness and docs/style files:

```text
docs/README.md
docs/harness/OPERATING_MODEL.md
docs/harness/LANGUAGE_POLICY.md
docs/harness/issue-lifecycle.md
docs/harness/project-management.md
docs/harness/references/project-fields.md
docs/harness/skills/static-check.md
docs/harness/skills/implement-feature.md
docs/harness/skills/bootstrap-infra.md
docs/harness/skills/create-issue.md
docs/harness/roles/README.md
docs/harness/rules/README.md
docs/styles/coding_guide/docs.md
docs/styles/coding_guide/code-comments.md
docs/styles/harness_authoring_guide.md
docs/product/adr/README.md
docs/product/adr/INDEX.md
docs/product/adr/template.md
docs/product/templates/inception.md
docs/product/templates/plan.md
docs/product/templates/construction.md
docs/product/templates/verification.md
docs/product/templates/review-notes.md
docs/product/issues/000-bootstrap/product-brief.md
docs/product/issues/000-bootstrap/research.md
docs/product/issues/000-bootstrap/decision-matrix.md
docs/product/issues/000-bootstrap/harness-catalog.md
docs/product/issues/000-bootstrap/bootstrap-plan.md
docs/product/issues/000-bootstrap/implementation-report.md
docs/runbooks/deploy.md
```

Generate only what the target repo needs for the first 1-2 iterations.

## 9. Adapter Rules

`AGENTS.md` and `CLAUDE.md` should include:

- short repo purpose
- pointer to `docs/harness/OPERATING_MODEL.md`
- pointer to project language policy
- local commands or pointer to command docs
- approval gate reminders
- secret and destructive-operation constraints

They should not include:

- full issue lifecycle procedure
- full CI/CD runbook
- provider-specific deploy instructions
- duplicated workflow bodies
- product-specific research summaries

Claude slash commands or subagents may exist, but they should point to shared docs instead of becoming the only source of truth.

## 10. Validation Gates

Docs-related CI should include the subset relevant to the product:

- markdown format/lint if present
- broken internal link check
- docs current-state policy check
- source comment public-doc check
- customer/public docs internal-reference check
- docs site build
- OpenAPI/SDK docs generation check

Record these in `bootstrap-plan.md` and CI.
