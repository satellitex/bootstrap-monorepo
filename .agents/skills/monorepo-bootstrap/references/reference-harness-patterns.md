# Reference Harness Patterns

この repo のハーネスを、任意の新規モノレポへ移植するときの参照パターン。
そのままコピーせず、Codex / Claude の両方から読める portable harness として、target repo の規模、team、deploy 先、規制要件、project language に合わせて縮約する。

## 1. Repository Knowledge Map

この repo は Claude 側では `CLAUDE.md`、Codex 側では repo root の `AGENTS.md` が入口になる。
bootstrap 先では、両入口に同じ詳細を複製せず、docs 正本へ参照させる。

移植時の最小構成:

| Target file | Role |
|-------------|------|
| `AGENTS.md` | Codex 用入口。repo の目的、正本 docs、主要コマンド、ブランチ/PR 運用への pointer |
| `CLAUDE.md` | Claude 用入口。`AGENTS.md` と同じ共通正本への pointer |
| `docs/README.md` | docs ナレッジハブ。置き場所、INDEX 更新、原本/要約ルール |
| `docs/harness/OPERATING_MODEL.md` | Codex / Claude 共通の作業フロー、承認 gate、品質基準 |
| `docs/harness/LANGUAGE_POLICY.md` | intake で決めた project language と例外規則 |
| `docs/harness/issue-lifecycle.md` | issue-local docs、approval gate、ADR、draft PR gate |
| `docs/harness/project-management.md` | labels、milestones、Projects、remote mutation approval |
| `docs/styles/coding_guide/docs.md` | docs 層分離と現状層 3 原則 |
| `docs/product/issues/000-bootstrap/` | bootstrap Issue 0 の成果物 |
| `docs/product/TECH_STACK.md` | 採用技術と現在の stack |
| `docs/product/INFRA.md` | provider/runtime/service selection の現在状態 |
| `docs/product/ARCHITECTURE.md` | system boundary、data flow、dependency direction |
| `docs/product/adr/` | 重要判断の履歴 |
| `docs/notes/research/` | 技術調査、比較、外部資料 |
| `docs/runbooks/` | deploy、rollback、secrets、runner operations |

常時読むファイルは短くし、更新頻度が低い詳細は docs へ逃がす。
`AGENTS.md` と `CLAUDE.md` の文言は、片方だけに重要ルールが入らないように同期する。

## 2. Workflow / Skill Layers

この repo は実装種別ごとに Skill を分けている。
bootstrap 先では、Claude の slash command と Codex の Skill/明示プロンプトのどちらでも呼べるよう、workflow 名を tool-neutral にする。

| Source pattern | Responsibility | Generic target equivalent |
|----------------|----------------|---------------------------|
| feature implementation flow | 要件から実装、TDD、evaluation、PR | `implement-feature` |
| harness update flow | Skill/Agent/AGENTS/CLAUDE/docs harness 変更 | `update-harness` |
| infra/environment flow | CI、infra、環境、依存追加、deploy | `bootstrap-infra` or `operate-infra` |
| static check flow | test/lint/typecheck/format 統合 | `static-check` |
| issue creation flow | Issue、label、milestone、Project、date、relationship 設定 | `create-issue` |
| ADR creation flow | 設計判断の永続化 | `create-adr` |
| review handling flow | PR review 対応 | `handle-review` |
| `*-sync` | README/docs/code/public docs/dependency/env/security などの鮮度維持 | product-specific sync workflows |

bootstrap 直後に全部を作らない。
最初は `static-check`, `implement-feature`, `bootstrap-infra`, `create-issue` を共通最小セットにする。
`*-sync` 系は product brief から必要な鮮度維持対象を選び、該当 surface があるものだけ生成する。

配置例:

| Shared doc | Codex adapter | Claude adapter |
|------------|---------------|----------------|
| `docs/harness/skills/static-check.md` | `AGENTS.md` から参照 | slash command または `CLAUDE.md` から参照 |
| `docs/harness/skills/implement-feature.md` | Skill 名/明示プロンプトで呼ぶ | slash command/Skill で呼ぶ |
| `docs/harness/skills/bootstrap-infra.md` | Skill 名/明示プロンプトで呼ぶ | slash command/Skill で呼ぶ |
| `docs/harness/skills/create-issue.md` | Issue 作成依頼時に呼ぶ | slash command/Skill で呼ぶ |
| `docs/harness/skills/*-sync.md` | 定期/明示実行で呼ぶ | slash command/Skill で呼ぶ |
| `docs/harness/project-management.md` | Issue/Project 運用の正本 | Issue/Project 運用の正本 |
| `docs/harness/LANGUAGE_POLICY.md` | project language を参照 | project language を参照 |

## 3. Role Separation

この repo は Generator と Evaluator を分離し、自分で作った変更を自分で評価しない。
Codex で subagent 機構がない場合でも、同じセッション内の明示的な review pass、別スレッド、または人間レビューで責務分離を維持する。

移植時の推奨:

| Role | Input | Output | Constraint |
|------|-------|--------|------------|
| `generator` | 承認済み plan、受入条件、対象ファイル | code/docs diff | scope 外の変更をしない |
| `evaluator` | diff、受入条件、coding guide | PASS/REVISE/REJECT | 修正実装をしない |
| `traceability-mapper` | AC と test diff | AC-test matrix | 実装判断をしない |
| `architecture-sync` | 実装差分、README/docs | docs 更新案 | 現状事実だけを書く |
| `ops-reviewer` | CI/deploy/runner diff、runbook | operational risk notes | secret 値や production change を実行しない |

小規模 repo では `traceability-mapper` と `architecture-sync` は後回しにできる。

## 4. Human Gates

bootstrap で必須にする gate:

| Gate | Before | Approval target |
|------|--------|-----------------|
| Gate A | dependency install / scaffold / infra creation | 技術選定、infrastructure service selection、app topology、CSS/UI strategy if UI exists |
| Gate B | file creation / CI / infra | `harness-catalog.md` と `bootstrap-plan.md` |
| Gate C | staging/production deploy | deploy target, cost, rollback, smoke, external exposure |
| Gate D | GitHub Project/milestone mutation | labels, milestones, Project fields, sample issue |
| Issue-local gate | uncertain implementation | inception/plan and draft PR before construction |

承認ログは成果物に残す。
チャットだけに閉じると、後続 agent や別ツールが判断経緯を読めない。

Production deploy、課金 resource 作成、破壊的 migration、外部公開、remote GitHub mutation は明示承認なしに実行しない。

## 5. CI/CD Baseline

generic baseline:

| Workflow | Required early | Notes |
|----------|----------------|-------|
| CI | Yes | install, format, lint, typecheck, test, build |
| Workflow lint / YAML parse | Recommended | `actionlint` or provider equivalent if available |
| Diff check | Recommended | base branch fetch must not prune required refs |
| PR title/body check | Optional | チーム運用がある場合 |
| Secret scan | Yes | public/private を問わず早期に入れる |
| Docs check | Yes if docs/public docs exist | docs 層ルール、internal reference、customer gate |
| Preview deploy | If web/API | PR ごとの確認 URL |
| Staging smoke | If external services | deploy 後に health/API/UI を検証 |

CI は「agent が merge 可能性を判断できる」粒度まで機械化する。
Codex / Claude のどちらで実装しても同じ gate に当たるよう、CI を tool 非依存の最終判定にする。

## 6. Runner Operations

self-hosted runner を使う場合は `docs/runbooks/runner.md` または equivalent を作る。

必須項目:

- foreground の `run.sh` 常用ではなく service manager 経由の常駐を推奨する
- runner user と必要な CLI login / keychain / credentials の user を一致させる
- runner 上の実 CLI version で `--help` を確認してから workflow option を使う
- base branch diff 用 fetch は prune で remote ref を消さない形にする
- logs / status / restart / upgrade 手順を残す
- secret scope、network access、workspace cleanup を残す

runner の実環境は interactive shell と違う。
workflow は service user の non-interactive environment で検証する。

## 7. Environment And Secrets

bootstrap 時に作るもの:

- repository-local `mise` config for runtime, package manager, and major CLI versions
- `mise install` based setup path
- `mise run <task>` entrypoints for repeated local dev/check/seed/migration commands where practical
- `.env.example`
- secret naming convention
- local dev setup command
- seed/migration command
- provider binding docs
- deploy environment mapping
- rollback and smoke-test runbook

作らないもの:

- 実 secret 値
- production credentials
- 本番データ dump
- irreversible migration without approval

## 8. Documentation Freshness

この repo は README/docs/code/public docs/dependency/env の drift を Skill で分けて検知する。
新規 repo でも、責務境界だけは最初に作る。

bootstrap 直後の PR checklist:

- app/package を追加したら nearest README を更新
- env/secret を追加したら `.env.example` と setup docs を更新
- public API を変えたら OpenAPI/SDK/docs を更新
- public/customer docs がある場合は公開射影と内部参照 gate を更新
- deploy workflow を変えたら smoke test と rollback docs を更新
- runner workflow を変えたら runner runbook と CLI version assumptions を更新
- infrastructure service selection を変えたら ADR と関連 issue を更新

## 9. PR Contract

PR body に最低限入れる情報:

- Summary
- Related issue or bootstrap request
- Test plan
- Docs impact
- Deploy URL or reason no deploy was run
- Bootstrap artifacts path
- Remaining risks and follow-up issues
- Human approval references for remote mutation, production deploy, paid resources, destructive migration, or external publication

Issue auto-close が必要な repo では、closing keyword を body に入れる。
title だけに issue number を書いても auto-close されない。

## 10. Avoid Tool / Provider Lock-in

避けること:

- workflow 正本を `.claude/` だけ、または `AGENTS.md` だけに閉じる
- slash command 名を唯一の呼び出し方法として書く
- Claude subagent の存在を前提にし、Codex で代替できる role separation を書かない
- Codex/Claude の片方だけに secret/deploy/PR/docs ルールを書く
- specific provider、database、queue、storage、CSS framework を template の既定として固定する

推奨:

- docs 正本は `docs/` に置く
- `AGENTS.md` と `CLAUDE.md` は thin adapter にする
- workflow 名は `implement-feature` のように tool-neutral にする
- tool 固有の実装詳細は adapter 側に閉じ込める
- provider 固有の CLI や binding は target repo の runbook/provider reference に閉じ込める
