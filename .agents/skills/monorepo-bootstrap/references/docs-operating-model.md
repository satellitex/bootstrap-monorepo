# Docs Operating Model

この文書は、`monorepo-bootstrap` が bootstrap 先の docs 構造・層分離・鮮度維持ルールを設計するときの参照（設計根拠）である。
資産ファイルの実体一覧は書かない。copy すべきファイルの正本台帳は `../assets/MANIFEST.md` にある。
The goal is to keep agent entrypoints thin, place durable project operations under `docs/`, and preserve clear responsibility boundaries.

## 1. Placement Principles

| Principle | Rule |
|-----------|------|
| Agent-only files | Put only files that agents directly load or execute under `.agents/` or `.claude/`. |
| Thin adapters | Keep `AGENTS.md` and `CLAUDE.md` short pointers to shared docs and commands. Do not duplicate detailed procedures. |
| Durable project docs | Put operating model, issue lifecycle, workflow procedures, runbooks, ADRs, and product docs under `docs/`. |
| Bootstrap Issue 0 | Treat completed bootstrap artifacts as `docs/issues/000_bootstrap/`. |
| No permanent `docs/bootstrap/` | Use `docs/bootstrap/` only as temporary scratch if needed; migrate durable content before completion. |
| Index discipline | Directories that agents navigate should have `README.md` or `INDEX.md`, updated in the same change. |

## 2. Required Docs Map

Generate a docs knowledge hub first.

| Path | Role | Notes |
|------|------|-------|
| `docs/README.md` | Docs knowledge hub | Placement map, naming, INDEX update rules |
| `docs/harness/` | Agent/tool operating model | Neutral operating model, authoring guide, scheduled operations |
| `docs/harness/OPERATING_MODEL.md` | Shared operating model | Approval model, language policy, quality standards, Codex/Claude handoff |
| `docs/harness/skills/` | Workflow procedure canon | Tool-neutral skill docs; thin adapters live in `.claude/skills/` |
| `docs/harness/skills/shared/` | Shared sync contracts | Common prelude/PR flow/verification gates for sync workflows |
| `docs/product/` | Product definition | Current-state docs such as ARCHITECTURE, TECH_STACK, TERMS, TEST_STRATEGY |
| `docs/adr/` | Decision layer | Why, alternatives, supersession, deprecation. The only ADR location |
| `docs/issues/000_bootstrap/` | Bootstrap Issue 0 | Bootstrap artifacts, decision records, implementation report |
| `docs/issues/<number>_<scope>/` | Issue planning layer | Issue-local plans, notes, verification records |
| `docs/issues/templates/` | Planning templates | Task note and optional traceability templates |
| `docs/requirements/` | Requirements canonical source | Human-approved; AI auto-edit is out of scope unless explicitly allowed |
| `docs/customer/` | Customer docs (opt-in:public-site) | Originals, safe summaries, customer runbooks |
| `docs/notes/research/` | Research layer | Comparisons, external standards, investigations |
| `docs/notes/mtgs/` | Meeting logs | Optional. Time-sequenced meeting records |
| `docs/runbooks/` | Operations procedures | Setup, secrets, deploy, rollback, incident, runner operations |
| `docs/styles/` | Engineering rules | Coding, docs, testing, team-feedback rules |
| `docs/audit/` | Audit reports | Security audit outputs and naming rules |

このうちテンプレート資産として収録済みのものは `../assets/MANIFEST.md` が正本であり、この表を台帳として使わない。
Scale this list to the target repo.
Do not generate customer/public docs scaffolding unless the product needs it (`opt-in:public-site`).

## 3. Four-Layer Model

Docs are separated by responsibility.

| Layer | Typical path | Allowed | Not allowed |
|-------|--------------|---------|-------------|
| State-of-Now | `docs/product/**/*.md`, `docs/styles/**`, root adapters/rules | Current system facts, current stack, current terms, global rules | History, migration story, rejected alternatives, future plans |
| Decision | `docs/adr/` | Why, alternatives, trade-offs, superseded/deprecated decisions | Detailed implementation plans |
| Research | `docs/notes/research/` | Candidate comparison, investigation, external standard summaries | Declaring final adoption without ADR |
| Implementation Plan | `docs/issues/<id>/` | Issue-specific plans, notes, verification, traceability | Cross-cutting current facts that belong in State-of-Now |
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
- `docs/product/TECH_STACK.md`
- `docs/product/TERMS.md`
- `docs/styles/**`
- global rules/adapters that describe current operation

## 6. Customer And Public Docs

公開射影と customer 区画はまとめて `opt-in:public-site` グループであり、product が対外 docs を必要とする場合のみ copy する。

If the product has customer-facing docs, separate internal canonical docs from public projection.

Recommended pattern:

| Internal source | Public projection | Sync owner |
|-----------------|-------------------|------------|
| `docs/product/ARCHITECTURE.md` | `docs/product/PUBLIC_ARCHITECTURE.md` | `public-arch-sync` (opt-in:public-site) |
| Source doc comments | SDK / code reference | `code-sync` |
| Customer originals | `docs/customer/summaries/` | `customer-doc-review` (opt-in:public-site) |

Public/customer docs gate should detect:

- internal doc paths
- ADR IDs, requirement IDs, issue/PR references
- internal service/provider names that must be abstracted
- unsafe source paths

If no public docs exist, leave the `opt-in:public-site` group out and record why in `harness-catalog.md`.

## 7. Sync Ownership

Use separate sync workflows so each owns one freshness boundary.

| Workflow | Owns | Does not own |
|----------|------|--------------|
| `readme-sync` (core) | README vs nearby code | Product current-state docs |
| `docs-sync` (core) | Current-state docs vs code/config/requirements | README, ADR/research creation |
| `code-sync` (core) | Source comments and public doc comments | README or product docs |
| `refactor-guide-sync` (core) | Coding guide vs refactoring guide alignment | Coding guide content decisions |
| `gc-scan` (core) | Harness size limits, duplication, orphans (all proposed via PR) | Product docs freshness |
| `adr-compress` (core) | ADR corpus size and INDEX consistency | ADR content decisions |
| `public-arch-sync` (opt-in:public-site) | Public projection from internal docs | Internal canonical docs |
| `customer-doc-review` (opt-in:public-site) | Customer-facing doc quality and leakage review | Internal canonical docs |
| `renovate-sync` (opt-in:renovate) | Dependency automation coverage | Product code behavior |

収録済み sync の正本は `docs/harness/skills/<name>.md` として copy される（台帳: `../assets/MANIFEST.md`）。
env examples / API schema / security policy など、この表にない鮮度境界が product に必要な場合は、`generated-workflows.md` §2 の 10 項目契約に従って追加設計する。
Each sync workflow must define source of truth, compared-against target, include/exclude paths, auto-edit scope, validation commands, and report format.

## 8. Templates To Copy

docs / harness / styles / CI のテンプレート資産一覧は `../assets/MANIFEST.md` が正本であり、この文書では一覧を重複管理しない。
bootstrap 時は MANIFEST の「使い方」に従い、core 資産の copy → 明示 token 置換 → `TODO(取得方法: ...)` の充填 → 不要な opt-in グループの除外 → PJ 固有化、の順で適用する。

MANIFEST に含まれない bootstrap 固有の成果物（`docs/issues/000_bootstrap/` 配下の product-brief / research / decision-matrix / harness-catalog / bootstrap-plan / implementation-report）は `references/bootstrap-artifacts.md` のテンプレートから作る。

## 9. Adapter Rules

`AGENTS.md` and `CLAUDE.md` should include:

- short repo purpose
- pointer to `docs/harness/OPERATING_MODEL.md`
- pointer to project language policy
- local commands or pointer to command docs
- approval model summary（人間承認が必須なのは課金と秘密値のみ。既定は open PR までの自律実行）
- secret constraints（secret 値を commit しない）

They should not include:

- full issue lifecycle procedure
- full CI/CD runbook
- provider-specific deploy instructions
- duplicated workflow bodies
- product-specific research summaries

Claude slash commands or subagents may exist, but they should point to shared docs instead of becoming the only source of truth.

## 10. Validation Gates

CI の既定は基礎 CI 1 本（format:check / test / build）であり、docs 系の機械検査は既定では sync 系 skill と hooks が担う。
CI に docs 検査を追加するのは拡張であり、product に応じて次の候補から選ぶ。

- markdown format/lint if present
- broken internal link check
- docs current-state policy check
- source comment public-doc check
- customer/public docs internal-reference check (opt-in:public-site)
- docs site build (opt-in:public-site)

Record adopted checks and reasons in `bootstrap-plan.md`.
