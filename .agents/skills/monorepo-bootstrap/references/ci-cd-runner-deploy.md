# CI/CD, Runner, And Deploy Reference

Use this reference when `monorepo-bootstrap` creates `bootstrap-plan.md`, CI workflows, deploy runbooks, runner runbooks, and repository settings checklists.
Keep provider-specific commands in the target repo runbooks or provider-specific references, not in the skill body.

## 1. CI/CD Design Scope

CI/CD is part of Gate A and Gate B, not an afterthought.
Compare CI provider and deployment strategy together with the runtime/provider selection.

| Area | Required decision |
|------|-------------------|
| CI provider | GitHub Actions, GitLab CI, Buildkite, provider-native CI, or other |
| Required checks | YAML parse, workflow lint, diff check, format, lint, typecheck, test, build, docs, secret scan |
| Deployment trigger | PR preview, branch deploy, manual promotion, release tag, environment approval |
| Environments | local, preview, staging, production, ephemeral review apps |
| Secrets | where secrets live, who can modify them, how `.env.example` stays current |
| Artifacts | build outputs, test reports, coverage, deploy URLs, smoke logs |
| Rollback | previous release, branch revert, provider rollback, migration rollback/forward |
| Runner model | hosted runner, self-hosted runner, larger runner, provider-native build worker |

## 2. CI Quality Gates

Use the subset that matches the project, but record omissions and reasons.

Recommended order:

1. YAML parse / workflow lint
2. install/cache
3. base branch diff check
4. format check
5. lint
6. typecheck
7. unit test
8. integration / contract / migration / schema test
9. build
10. docs gate
11. secret scan
12. preview or staging deploy
13. smoke test

Notes:

- If `actionlint` or equivalent workflow lint is not installed, report that it was not run and why.
- If monorepo diff execution is used, keep full validation on the main branch or scheduled CI.
- CI should run the same meaningful checks that agents use locally.
- Known tolerated failures need an issue, owner, and expiry condition.

## 3. Base Branch Diff

Diff-based checks must fetch the base branch without deleting the remote ref needed for comparison.

Guidelines:

- Fetch the exact base ref required by the workflow.
- Avoid prune operations that can remove the remote ref before diff calculation.
- Log the base SHA and head SHA.
- Fail clearly when the base ref cannot be found.
- Use the CI provider's pull request metadata when available.

## 4. Repository Settings Checklist

Include these in `bootstrap-plan.md` and, if GitHub is used, `docs/harness/project-management.md` or a repo settings runbook.
Changing remote repo settings requires human approval.

| Setting | Decision |
|---------|----------|
| default merge strategy | merge commit, squash, rebase, or restricted combination |
| squash merge policy | title/body source, commit message convention |
| auto-delete merged branches | enabled/disabled and exceptions |
| branch protection | protected branches, bypass rules, required reviews |
| required checks | exact check names and environments |
| environments | preview/staging/prod protections and reviewers |
| status checks for docs/security | docs gate, secret scan, dependency scan if applicable |

## 5. Self-Hosted Runner Operations

Use self-hosted runners only when project constraints justify them.
If self-hosted runners are used, runner operations are part of the bootstrap design.

Required runbook topics:

| Topic | Requirement |
|-------|-------------|
| Process management | Prefer service manager persistence over foreground `run.sh` as the normal operating mode |
| Runner user | The service user must match the user that owns required CLI login, keychain, credentials, caches, and workspace permissions |
| CLI versions | Check the actual runner machine's CLI versions and `--help` output before using workflow options |
| Credentials | Document login/credential setup without committing secret values |
| Workspace cleanup | Define cache/workspace cleanup and disk pressure policy |
| Base branch fetch | Ensure fetch strategy does not prune refs needed for diff checks |
| Logs | Document log path or service log command |
| Status | Document status check command and expected healthy state |
| Restart | Document restart and recovery procedure |
| Upgrades | Document runner binary and CLI upgrade procedure |
| Security | Scope tokens, network access, filesystem access, and secret exposure |

Do not assume interactive shell state exists for a service-runner.
Workflows must be valid in the runner's real non-interactive environment.

## 6. Deployment Strategy

Deployment strategy is a Gate A/B decision.
Record the selected approach in `decision-matrix.md`, `bootstrap-plan.md`, and deploy runbooks.

| Strategy | What to document |
|----------|------------------|
| PR preview | trigger, URL discovery, data isolation, auth, teardown |
| Branch-based deploy | mapping such as `main`/`dev`/`release`/`prod`, protections, promotion rules |
| Environment promotion | artifact promotion, approval, smoke tests, rollback |
| Release tag deploy | versioning, changelog, rollback, hotfix |
| Manual deploy | who can run it, command, approval, audit trail |

Production deploy, paid resource creation, destructive migration, and external publication always require explicit human approval.

## 7. Deploy Runbook Checklist

Create or update `docs/runbooks/deploy.md` or an equivalent file.

Required sections:

- environments and branch/tag mapping
- provider bindings and required capabilities
- environment variables and secret names, without values
- build and deploy commands
- smoke test command and expected output
- rollback procedure
- migration procedure and safety notes
- observability links and alert routing
- known limits and cost considerations
- approval requirements for production, billing, destructive migration, and external publication

## 8. Smoke Tests

Smoke tests should verify the deployed artifact, not just local build success.

Examples by surface:

| Surface | Smoke check |
|---------|-------------|
| Web UI | page loads, key route renders, critical asset and API call succeeds |
| API | health endpoint, auth boundary, one read/write contract if safe |
| Worker/job | enqueue/run a safe job, verify retry/log behavior |
| Workflow | start a short workflow, verify status and completion |
| DB migration | migration status and a read-only schema check |
| Public docs | docs site builds and exposed page has no internal references |

Record deploy URL, commit SHA, environment, timestamp, and result in `implementation-report.md`.

## 9. Provider-Specific References

Provider-specific knowledge can be added as optional references when the target repo needs it.
Keep those files narrow and clearly named, for example:

```text
docs/runbooks/providers/<provider>.md
docs/harness/references/providers/<provider>.md
```

Provider references may contain CLI commands and binding syntax, but they should not make the generic bootstrap template assume that provider by default.
