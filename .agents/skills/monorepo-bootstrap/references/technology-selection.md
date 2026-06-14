# Technology Selection Reference

Use this reference when `monorepo-bootstrap` creates `research.md`, `decision-matrix.md`, Gate A notes, and ADR candidates.
The selection must stay provider-neutral unless the user explicitly supplies a provider, runtime, database, or organizational constraint.

## 1. Required Comparison Domains

Gate A must compare more than app framework, language, and monorepo tooling.
For each domain, record the recommended choice, alternatives considered, rejected reasons, operational risks, cost/limit considerations, and local development impact.

| Domain | Required questions |
|--------|--------------------|
| Product architecture | Which core flows must work first, and what technical boundaries do they imply? |
| App framework / language | Which framework and language/runtime fit UI, API, SSR, worker, and team constraints? |
| Monorepo tool | Which package manager, workspace model, and task runner minimize repo complexity? |
| Deploy / hosting provider | Which providers can run the selected topology with preview/staging/prod, rollback, cost visibility, and required regions? |
| Runtime model | Is the fit server, serverless, edge, container, hybrid, or another model? |
| Database | Which database fits the data model, migrations, backup, transactions, connection limits, latency, and local dev? |
| Object/file storage | Are object storage, file uploads, retention, signed URLs, antivirus, or lifecycle policies needed? |
| Cache | What data needs caching, what consistency is acceptable, and where is invalidation handled? |
| Queue / workflow / job orchestration | Are retry, DLQ, schedule, durable workflow, idempotency, visibility, or fan-out needed? |
| Long-running task handling | How are timeout, checkpoint, resume, cancellation, human approval, and progress reporting handled? |
| External agent / worker runtime boundary | What code runs outside the main app, what permissions it has, and how it is audited? |
| Auth / identity | Which identity provider/session model/RBAC/tenant boundary fits the product and deploy model? |
| Observability | Which logs, metrics, traces, errors, audit events, and alert routes are required from day one? |
| CI/CD provider and deployment strategy | Which CI provider, preview strategy, promotion model, and required checks are used? |
| CSS / UI styling strategy | If UI exists, which styling strategy fits design system, tokens, runtime cost, and team familiarity? |

## 2. Decision Matrix Shape

Use this table for every major domain.

```markdown
| Domain | Recommended | Alternatives | Rejected reasons | Operational risks | Cost / limits | Local dev impact | Sources |
|--------|-------------|--------------|------------------|-------------------|---------------|------------------|---------|
```

Rules:

- A recommendation without alternatives is incomplete.
- "Popular" is not a sufficient reason.
- If a limit, price, CLI option, deploy behavior, or support matrix can change, verify a primary source and record the access date.
- If the user supplied a provider constraint, compare that provider first but still record material trade-offs.
- If the user supplied no provider constraint, compare at least two viable provider/runtime options before Gate A.
- Do not write provider-specific implementation recipes into the template; put them in target repo runbooks or optional provider references.

## 3. Provider And Runtime Comparison

Compare provider/runtime as a combined decision, not as separate defaults.

| Axis | What to record |
|------|----------------|
| Runtime support | server, serverless function, edge runtime, container, worker, scheduled jobs, long-running jobs |
| Deploy model | preview, staging, production, branch deploy, environment promotion, rollback |
| Service availability | database, object storage, cache, queue/workflow, cron/scheduler, secrets, observability |
| Limits | request timeout, CPU/memory, payload size, connection limits, job duration, cold start, region limits |
| Local dev | emulator, local container, local DB, mock services, seed/migration path |
| Operations | logs, metrics, traces, audit, alerting, incident and rollback flow |
| Cost | free tier traps, per-request cost, egress, storage, build minutes, runner cost |
| Lock-in | migration cost, API portability, data export, IaC availability |

## 4. Infrastructure Service Selection

At Gate A, explicitly propose the following service selections or state why the product does not need them yet.

| Service area | Decision output |
|--------------|-----------------|
| Deploy / hosting | provider, environment model, rollback strategy |
| Runtime model | server/serverless/edge/container/hybrid, timeout assumptions |
| Database | engine, migration tool, backup, local dev mode |
| Object/file storage | provider-neutral capability needs, local mock/test strategy |
| Cache | storage location, invalidation, TTL, failure behavior |
| Queue/workflow/job orchestration | queue/workflow engine, retry/DLQ/idempotency, visibility |
| Long-running tasks | runtime boundary, timeout mitigation, checkpoint/resume/cancel |
| External agent/worker runtime | trust boundary, credential scope, audit/logging |
| Auth/identity | provider or protocol, session/RBAC/tenant boundary |
| Observability | logs/metrics/traces/errors/audit, alert route |
| CI/CD | provider, required checks, deploy trigger, environment protection |

## 5. App Topology Selection

Do not mechanically create `apps/web`, `apps/api`, `apps/workers`, `apps/jobs`, or `apps/workflows`.
Choose the topology from product and operations constraints.

Record the comparison in `decision-matrix.md` or an ADR.

| Axis | Compare |
|------|---------|
| UI and server-side route coupling | Is colocating server routes with UI simpler, or do APIs need independent lifecycle? |
| Deploy unit | Which parts must deploy independently? |
| Scaling unit | Which traffic or job types scale differently? |
| Auth/session boundary | Where sessions are created, verified, refreshed, and invalidated |
| External API vs internal route | Which routes are public contracts, and which are UI-private implementation details? |
| Tenant/workspace domain route | Whether domain routes naturally map to app, API, worker, or edge boundaries |
| Async responsibility | Where queues, workflows, scheduled tasks, and long-running work live |
| Shared packages | What belongs in `packages/` versus app-local code |

Suggested output:

```markdown
## App Topology

| Option | Shape | Pros | Cons | Decision |
|--------|-------|------|------|----------|
| A | `apps/web` only with server routes | | | |
| B | `apps/web` + `apps/api` | | | |
| C | `apps/web` + `apps/api` + `apps/jobs` | | | |

Decision:
Rationale:
Risks:
ADR needed: Yes / No
```

## 6. CSS / UI Styling Strategy

If the project has UI, CSS/styling is a Gate A decision.
Compare choices against the actual product needs instead of defaulting to a familiar framework.

Potential options:

- Tailwind
- CSS Modules
- Panda CSS
- vanilla-extract
- framework-native styling
- component library theming system
- existing organization design system

Comparison axes:

| Axis | Questions |
|------|-----------|
| Design system fit | Are tokens, variants, themes, and component APIs first-class? |
| Typed tokens | Can color/space/typography tokens be type-checked or centrally generated? |
| Component package | Will shared UI live in a package, and can styles compose across apps? |
| Runtime cost | Is styling build-time, runtime, CSS-in-JS, atomic CSS, or framework-specific? |
| Team familiarity | Can the team maintain it without creating a custom DSL? |
| Migration cost | What happens if the stack changes or a design system is introduced later? |
| SSR/RSC/edge compatibility | Does styling work with the chosen rendering/runtime model? |
| Theming/accessibility | Are dark mode, density, motion preferences, and accessibility states manageable? |

Adopted CSS/UI strategy should become an ADR when UI is in scope.

## 7. ADR Triggers

Create an ADR when a decision is hard to reverse, cross-cutting, expensive, or likely to affect multiple issues.

Examples:

- deploy / hosting provider
- runtime model
- database and migration strategy
- object storage or file retention model
- queue/workflow/job orchestration
- long-running task architecture
- auth/session/tenant boundary
- observability platform
- CI/CD provider and branch deploy strategy
- app topology
- CSS / UI styling strategy
- public API schema style
- package boundary or shared component system

Small local implementation choices can stay in issue docs if they do not change cross-cutting architecture.
