# Docs Operating Model

Use this reference when `monorepo-bootstrap` generates the target monorepo's docs structure and freshness rules.
The goal is to preserve this repository's docs discipline: clear placement, layered responsibility, current-state hygiene, public projection, and sync ownership.

## 1. Required Docs Map

Generate a docs knowledge hub first.

| Path | Role | Notes |
|------|------|-------|
| `docs/README.md` | Docs knowledge hub | Placement map, naming, INDEX update rules |
| `docs/product/` | Product definition | Current-state docs such as ARCHITECTURE, TECH_STACK, INFRA, TERMS, API_FLOWS |
| `docs/product/adr/` | Decision layer | Why, alternatives, supersession, deprecation |
| `docs/product/issues/` | Implementation planning layer | Issue-specific inception, construction, infra plan, traceability |
| `docs/product/templates/` | Planning templates | Inception, construction, infra-plan, traceability templates |
| `docs/requirements/` | Requirements canonical source | Human-approved; AI auto-edit is out of scope |
| `docs/customer/originals/` | Customer originals | Original files only |
| `docs/customer/summaries/` | Customer source summaries | Safe summaries of originals |
| `docs/notes/research/` | Research layer | Comparisons, external standards, investigations |
| `docs/notes/mtgs/` | Meeting logs | Time-sequenced meeting records |
| `docs/runbooks/` | Operations procedures | Setup, secrets, deploy, incident, rollback |
| `docs/styles/` | Engineering rules | Coding, docs, security, testing, harness authoring |
| `docs/operations/` | Operations data | Docs site metadata, changelog data, persistent generated ops data |

Every directory that holds many docs should have an `INDEX.md` or README-like index if the target repo expects agents to navigate it.
Adding, renaming, or deleting docs must update the relevant index in the same change.

## 2. Four-Layer Model

Docs are separated by responsibility.

| Layer | Typical path | Allowed | Not allowed |
|-------|--------------|---------|-------------|
| State-of-Now | `docs/product/**/*.md`, `docs/styles/**`, `docs/schedule/**`, root adapters/rules | Current system facts, current stack, current terms, global rules | History, migration story, rejected alternatives, future plans |
| Decision | `docs/product/adr/` | Why, alternatives, trade-offs, superseded/deprecated decisions | Detailed implementation plans |
| Research | `docs/notes/research/` | Candidate comparison, investigation, external standard summaries | Declaring final adoption without ADR |
| Implementation Plan | `docs/product/issues/<id>/` | Issue-specific inception, construction, plan, traceability | Cross-cutting current facts that belong in State-of-Now |

Generated target repos should include this model in `docs/styles/coding_guide/docs.md` or equivalent.

## 3. State-of-Now Rules

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

## 4. README Responsibility

README files are not owned by docs-sync.
They are local maps for nearby code, setup, commands, and package/app-specific structure.

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

## 5. Customer And Public Docs

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

## 6. Sync Ownership

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

Each sync workflow must define source of truth, compared-against target, include/exclude paths, auto-edit scope, validation commands, and report format.

## 7. Templates To Generate

Recommended docs/harness and docs/style files:

```text
docs/README.md
docs/styles/coding_guide/docs.md
docs/styles/coding_guide/code-comments.md
docs/styles/harness_authoring_guide.md
docs/product/adr/README.md
docs/product/adr/INDEX.md
docs/product/adr/template.md
docs/product/templates/inception.md
docs/product/templates/construction.md
docs/product/templates/infra-plan.md
docs/harness/OPERATING_MODEL.md
docs/harness/LANGUAGE_POLICY.md
```

Scale this list to the target repo. Do not generate customer/public docs scaffolding unless the product needs it.

## 8. Validation Gates

Docs-related CI should include the subset relevant to the product:

- markdown format/lint if present
- broken internal link check
- docs current-state policy check
- source comment public-doc check
- customer/public docs internal-reference check
- docs site build
- OpenAPI/SDK docs generation check

Record these in `bootstrap-plan.md` and CI.
