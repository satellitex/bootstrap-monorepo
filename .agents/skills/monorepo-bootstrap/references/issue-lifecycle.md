# Issue Lifecycle Reference

この文書は、`monorepo-bootstrap` が issue 単位の計画・記録・承認要否の運用を bootstrap 先に設計するときの参照である。
issue 資産の実体（README・テンプレート）は書かない（正本台帳は `../assets/MANIFEST.md`）。
The goal is to make every issue small enough for one focused implementation session while preserving decision history and the approval model.

## 1. Issue Docs Location

Each implementation issue owns a directory:

```text
docs/issues/<number>_<scope>/
```

起点テンプレートは copy 済みの `docs/issues/templates/task-note.md` を使う。
小さな issue は task-note 1 枚に計画から検証まで収めてよい。大きな issue は次のように分割する。

| File | Purpose |
|------|---------|
| `inception.md` | Problem framing, scope, constraints, acceptance criteria, open questions |
| `plan.md` | Chosen implementation approach, files/modules, test strategy, docs impact |
| `construction.md` | Execution notes, commands run, deviations from plan |
| `verification.md` | Local/CI/deploy checks, evidence, residual risk |
| `review-notes.md` | Review feedback, evaluator notes, follow-up tasks |
| `traceability.md` | Acceptance criteria to tests/docs/implementation mapping (opt-in:traceability) |

Bootstrap itself is Issue 0:

```text
docs/issues/000_bootstrap/
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
| Plan | `plan.md` with approach, topology impact, tests, docs, rollout | 既定で人間 gate なし。未確定点は open questions として記録し PR で提示 |
| Construction | Code/docs diff and `construction.md` notes for deviations | No new scope without updating plan |
| Verification | `verification.md` with commands, CI, deploy/smoke, skipped checks | Required before review |
| Review notes | `review-notes.md` or PR review summary | Required for non-trivial changes |

実装方針が未確定でも作業を止めない。inception を先に仕上げ、未確定点を明記した上で open PR まで自律続行する。
実装前の人間確認（draft PR gate）を置くのは、人間から明示的に指示があった場合のみとする。

## 4. Approval Rules

既定は自律実行とする。エージェントは明示的な指示がない限り、変更の実装から open PR の提出までを自律的に行う。
PR のマージは人間の操作だが、明示的に指示された場合はマージまで行ってよい。

人間の明示承認が必須なのは次の 2 つのみ:

- 課金が発生する操作（有償リソースの作成、プラン変更、外部サービス契約）
- 秘密値の挿入・変更（credential / API key / token を設定へ投入する操作）

次の条件に当たる issue は承認の対象ではないが、判断材料を issue-local docs（または ADR）に残し、PR で提示する:

- technology choice is unsettled
- provider/runtime/database/storage/queue/auth/observability selection may change
- security, privacy, auth, or tenant boundary changes
- app topology or package boundaries change
- implementation spans multiple deploy/scaling units
- long-running or async workflow durability is not yet designed
- issue has unclear acceptance criteria

ブランチモデルは main = dev 環境 / release = prod 環境。main は壊れても復旧可能な開発環境であり、開発過程ではセキュリティより柔軟性を優先する。
prod（release）への反映のみ手順を踏む: main の安全性確認 → release への反映手順の確認。

## 5. Draft PR Gate（明示指示があった場合のみ）

draft PR を実装前の承認 gate として使うのは、人間から明示的に指示があった場合のみとする。
既定では inception / plan を issue-local docs に残し、実装へ自律続行する。

指示があった場合の手順:

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

GitHub labels / milestones / Projects / fields / issues / issue relationships の作成・変更は自律実行してよい。
人間承認が必要なのは、課金が発生する操作と秘密値の挿入・変更のみ。

自律実行した mutation は、判断材料と結果を成果物に残す:

- adopted labels and descriptions
- milestones with entry/exit criteria
- Projects and fields
- sample issue body
- 実行した commands / API operations と読み戻し検証の結果

実行できなかった remote setup は `bootstrap-plan.md` に残タスクとして残す。

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
- prod（release）への反映手順、課金操作、または秘密値の投入が独立の確認を必要とする
- a changed technical decision invalidates existing issue plans

When a technical decision changes existing issues, comment on or update the affected issue docs and GitHub issues autonomously.
