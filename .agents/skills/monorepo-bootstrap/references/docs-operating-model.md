# Docs Operating Model

この文書は、`monorepo-bootstrap` が bootstrap 先の docs 構造・層分離・鮮度維持ルールを設計するときの参照（設計根拠）である。
資産ファイルの実体一覧は書かない。copy すべきファイルの正本台帳は `../assets/MANIFEST.md` にある。
The goal is to keep agent entrypoints thin, place durable project operations under `docs/`, and preserve clear responsibility boundaries.

## 1. Placement Principles

| Principle | Rule |
|-----------|------|
| Agent-only files | Put only files that agents directly load or execute under `.agents/` or `.claude/`. |
| Thin adapters | Keep `AGENTS.md` and `CLAUDE.md` short pointers to shared docs and commands. Do not duplicate detailed procedures. |
| Durable project docs | Put operating model, workflow procedures, runbooks, ADRs, and product docs under `docs/`. |
| Execution records in the PR | Keep per-issue plans, rejected alternatives, and verification results in the PR body and commit messages. Do not create per-issue artifact files under `docs/`. |
| Bootstrap / adopt artifacts | Write in-progress results as PR body sections, then move confirmed content into the existing layers (research, ADR, product docs, OPERATING_MODEL). The destinations are listed in `../SKILL.md`. |
| Index discipline | Directories that agents navigate should have `README.md` or `INDEX.md`. Implementation PRs write a heading and lead paragraph in each new document; the updater defined in `docs/harness/skills/shared/index-writer-policy.md` writes the INDEX rows. |

## 2. Required Docs Map

Generate a docs knowledge hub first.

| Path | Role | Notes |
|------|------|-------|
| `docs/README.md` | Docs knowledge hub | Placement map, naming, INDEX update rules |
| `docs/harness/` | Agent/tool operating model | Neutral operating model, authoring guide, scheduled operations |
| `docs/harness/OPERATING_MODEL.md` | Shared operating model | Approval model, language policy, quality standards, Codex/Claude handoff |
| `docs/harness/skills/` | Workflow procedure canon | Tool-neutral skill docs; thin adapters live in `.claude/skills/` |
| `docs/harness/skills/shared/` | Cross-skill contracts | Unattended runs, INDEX updater policy, PR creation, verification gates, notifications; sync-only contracts use the `sync-` prefix |
| `docs/product/` | Product definition | Current-state docs such as ARCHITECTURE, TECH_STACK, TERMS, TEST_STRATEGY |
| `docs/product/API_VERSIONING.md` | API contract versioning policy (opt-in:versioning) | Judgement principles, classification table, numbering window, release record items |
| `docs/product/tests/` | Requirement-to-test matrix (opt-in:traceability) | Matrix files, schema, update rules |
| `docs/adr/` | Decision layer | Why, alternatives, supersession, deprecation. The only ADR location |
| `docs/requirements/` | Requirements canonical source | Human-approved; AI auto-edit is out of scope unless explicitly allowed |
| `docs/customer/` | Customer docs (opt-in:public-site) | Originals, safe summaries, customer runbooks |
| `docs/notes/research/` | Research layer | Comparisons (including technology selection), external standards, investigations |
| `docs/notes/mtgs/` | Meeting logs | Optional. Time-sequenced meeting records |
| `docs/runbooks/` | Operations procedures | Setup, secrets, deploy, rollback, runner operations. `README.md` defines the required elements of a procedure |
| `docs/postmortems/` | Incident records (opt-in:incident) | Work records and blameless reviews; no INDEX |
| `docs/templates/` | Record templates (opt-in:incident) | Incident timeline and postmortem templates |
| `docs/styles/` | Engineering rules | Coding, docs, testing, team-feedback rules |
| `docs/audit/` | External audit reports | Reports from audits or diagnostics by outside parties, and naming rules |

このうちテンプレート資産として収録済みのものは `../assets/MANIFEST.md` が正本であり、この表を台帳として使わない。
Scale this list to the target repo.
Do not generate customer/public docs scaffolding unless the product needs it (`opt-in:public-site`).

## 3. Four-Layer Model

Docs are separated by responsibility.

| Layer | Typical path | Allowed | Not allowed |
|-------|--------------|---------|-------------|
| State-of-Now | `docs/product/**/*.md`, `docs/styles/**`, `docs/runbooks/`, `docs/harness/`, root adapters/rules | Current system facts, current stack, current terms, global rules, current operational procedures, workflow contracts, approvals | History, migration story, rejected alternatives, future plans, product decision rationale that belongs in ADR |
| Decision | `docs/adr/` | Why, alternatives, trade-offs, superseded/deprecated decisions | Detailed implementation plans |
| Research | `docs/notes/research/` | Candidate comparison, technology-selection investigation (sources and access dates), external standard summaries | Declaring final adoption without ADR |
| Implementation Record | PR body, commit messages | Issue-specific plan, chosen approach and rejected alternatives, out-of-scope items, verification results, risks | Cross-cutting current facts that belong in State-of-Now; lasting design decisions that belong in ADR |

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

If no public docs exist, leave the `opt-in:public-site` group out and record why in the opt-in adoption ADR.

## 7. Sync Ownership

Use separate sync workflows so each owns one freshness boundary.

| Workflow | Owns | Does not own |
|----------|------|--------------|
| `readme-sync` (core) | README vs nearby code | Product current-state docs |
| `docs-sync` (core) | Current-state docs vs code/config/requirements (freshness, "current facts only" principles, claim-vs-implementation consistency), INDEX rows it is the updater for | README, ADR/research creation |
| `code-sync` (core) | Source comments and public doc comments (comment-only edits, verified) | README or product docs |
| `refactor-guide-sync` (core) | Coding guide vs refactoring guide alignment | Coding guide content decisions |
| `refactor-sync` (core) | Code issues against the coding rules (violations, ineffective / deprecated / redundant code), proposed as Issues by the refactorer agent | Code changes, guide alignment |
| `runbook-alignment` (core) | Unresolved items in runbooks vs implementation (resolves what the code settles, records the rest as undecided) | Implementation, requirements, general freshness of current-state docs |
| `gc-scan` (core) | Harness duplication and orphans (all proposed via PR) | Items the mechanical checks cover (`pnpm harness:test`); product docs freshness |
| `adr-compress` (core) | ADR Status follow-up, INDEX rebuild, stubbing, summarization; the only writer of the ADR INDEX | ADR content decisions |
| `public-arch-sync` (opt-in:public-site) | Public projection from internal docs | Internal canonical docs |
| `customer-doc-review` (opt-in:public-site) | Customer-facing doc quality and leakage review | Internal canonical docs |
| `renovate-sync` (opt-in:renovate) | Dependency automation coverage | Product code behavior |

収録済み sync の正本は `docs/harness/skills/<name>.md` として copy される（台帳: `../assets/MANIFEST.md`）。
env examples / API schema / security policy など、この表にない鮮度境界が product に必要な場合は、`generated-workflows.md` §2 の 10 項目契約に従って追加設計する。
Each sync workflow must define source of truth, compared-against target, include/exclude paths, auto-edit scope, validation commands, and report format.

## 8. Templates To Copy

docs / harness / styles / CI のテンプレート資産一覧は `../assets/MANIFEST.md` が正本であり、この文書では一覧を重複管理しない。
bootstrap 時は MANIFEST の「使い方」に従い、core 資産の copy → 明示 token 置換 → TODO の充填（MANIFEST「TODO 記法」に従う） → 不要な opt-in グループの除外 → PJ 固有化、の順で適用する。
`docs/README.md` のディレクトリマップは、opt-in と付記した行のうち不採用グループの行を削除し、表の直前の HTML コメントも削除する（所属グループは MANIFEST のグループ節で確認する）。

MANIFEST に含まれない bootstrap 固有の成果物は、専用ファイルとして作らない。PR 本文の節に書き、確定した内容を既存の層へ移す。節構成と移管先文書のテンプレートは `references/bootstrap-artifacts.md` にある。

## 9. Adapter Rules

`AGENTS.md` and `CLAUDE.md` should include:

- short repo purpose
- pointer to `docs/harness/OPERATING_MODEL.md`
- pointer to the table of area-specific rules in `docs/harness/OPERATING_MODEL.md` (which rule to read for which work; environments without path-scoped auto-loading reach the rules through it)
- pointer to project language policy
- local commands or pointer to command docs
- approval model summary（1 行の要旨と `docs/harness/OPERATING_MODEL.md`「承認モデル」への pointer）
- secret constraints（secret 値を commit しない）

They should not include:

- full issue lifecycle procedure
- full CI/CD runbook
- provider-specific deploy instructions
- duplicated workflow bodies
- product-specific research summaries

Claude の入口は 1 か所に置く。新規 bootstrap ではルートの `CLAUDE.md` を使う。既存 repo が `.claude/CLAUDE.md` を使っている場合は、そこへ pointer 節を追記し、ルートに重複して作らない（`harness-adopt` の入口の置き場の規則）。
正本（OPERATING_MODEL）と矛盾した場合に正本を優先する旨の 1 文は、新規に作成する adapter にだけ置く。既存の adapter を持つ導入先では、既存の記述を優先する。

Claude slash commands or subagents may exist, but they should point to shared docs instead of becoming the only source of truth.

## 10. Validation Gates

CI の既定は基礎 CI 1 本（format:check / test / build。`gate:ci`）であり、test job の中でハーネスの機械検査（`tests/harness/`、依存ゼロの `node:test`）と hooks の bash テストを実行する。
決定論的に判定できる規約はこの機械検査が担い（範囲 → `../assets/tests/harness/README.md`「検査一覧」）、意味判定が要る検査（重複・孤児・鮮度・実装整合）は sync 系 skill が担う。
CI に docs 検査を追加するのは拡張であり、product に応じて次の候補から選ぶ。

- markdown format/lint if present
- broken internal link check
- docs current-state policy check
- source comment public-doc check
- customer/public docs internal-reference check (opt-in:public-site)
- docs site build (opt-in:public-site)

採否と理由は PR 本文の「方針と却下案」に記録する。
