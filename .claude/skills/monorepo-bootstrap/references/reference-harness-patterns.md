# Reference Harness Patterns

この repo のハーネスを、任意の新規モノレポへ移植するときの参照パターン。
そのままコピーせず、Codex / Claude の両方から読める portable harness として、target repo の規模、チーム、deploy 先、規制要件に合わせて縮約する。

## 1. Repository Knowledge Map

この repo では `.claude/CLAUDE.md` が Claude 側の入口になり、Codex 側では repo root の `AGENTS.md` が入口になる。
bootstrap 先では、両入口に同じ詳細を複製せず、`docs/harness/` に共通正本を置いて参照させる。

移植時の最小構成:

| Target file | Role |
|-------------|------|
| `AGENTS.md` | Codex 用入口。repo の目的、正本 docs、主要コマンド、ブランチ/PR 運用への pointer |
| `CLAUDE.md` | Claude 用入口。`AGENTS.md` と同じ共通正本への pointer |
| `docs/harness/OPERATING_MODEL.md` | Codex / Claude 共通の作業フロー、承認ゲート、品質基準 |
| `docs/harness/LANGUAGE_POLICY.md` | 日本語既定の会話・Issue・PR・ADR・sync レポート運用 |
| `docs/product/TECH_STACK.md` | 採用技術と理由 |
| `docs/product/ARCHITECTURE.md` | システム境界、データフロー、依存方向 |
| `docs/product/adr/` | 重要判断の履歴 |
| `docs/styles/coding_guide/` | 言語、テスト、セキュリティ、コメント規約 |
| `docs/notes/research/` | 技術調査、比較、外部資料 |

常時読むファイルは短くし、更新頻度が低い詳細は docs へ逃がす。
`AGENTS.md` と `CLAUDE.md` の文言は、片方だけに重要ルールが入らないように同期する。
両ファイルには、日本語を既定のコミュニケーション言語にすることと、詳細は `docs/harness/LANGUAGE_POLICY.md` を参照することを記載する。

## 2. Workflow / Skill Layers

この repo は実装種別ごとに Skill を分けている。
bootstrap 先では、Claude の slash command と Codex の Skill/明示プロンプトのどちらでも呼べるよう、workflow 名を tool-neutral にする。

| Source pattern | Responsibility | Generic target equivalent |
|----------------|----------------|---------------------------|
| `/pge` | 要件から実装、TDD、Evaluator、PR | `implement-feature` |
| `/hge` | Skill/Agent/AGENTS/CLAUDE などハーネス変更 | `update-harness` |
| `/ipe` | CI、infra、環境、依存追加 | `bootstrap-infra` or `operate-infra` |
| `/static-check` | test/lint/typecheck/format 統合 | `static-check` |
| `/create-issue` | Issue、label、milestone、Project、date、relationship 設定 | `create-issue` |
| `/create-adr` | 設計判断の永続化 | `create-adr` |
| `/handle-review` | PR review 対応 | `handle-review` |
| `*-sync` | README/docs/code/public docs/dependency/env などの鮮度維持 | product-specific sync workflows |

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
| `docs/harness/LANGUAGE_POLICY.md` | 日本語既定の運用を参照 | 日本語既定の運用を参照 |

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

小規模 repo では `traceability-mapper` と `architecture-sync` は後回しにできる。

## 4. Human Gates

この repo の重要な設計は、実装前に人間承認を挟む。

bootstrap で必須にする gate:

| Gate | Before | Approval target |
|------|--------|-----------------|
| Gate A | dependency install / scaffold | 技術選定と主要 trade-off |
| Gate B | file creation / CI / infra | bootstrap-plan.md |
| Gate C | staging/production deploy | deploy target, cost, rollback |

承認ログは成果物に残す。
チャットだけに閉じると、後続 agent や別ツールが判断経緯を読めない。

## 5. CI/CD Baseline

この repo は GitHub Actions で CI、docs check、secret scan、deploy/smoke 系 workflow を分離している。

generic baseline:

| Workflow | Required early | Notes |
|----------|----------------|-------|
| CI | Yes | install, format, lint, typecheck, test, build |
| PR title/body check | Optional | チーム運用がある場合 |
| Secret scan | Yes | public/private を問わず早期に入れる |
| Docs check | Optional | public docs や SDK がある場合 |
| Preview deploy | If web/API | PR ごとの確認 URL |
| Staging smoke | If external services | deploy 後に health/API/UI を検証 |

CI は「agent が merge 可能性を判断できる」粒度まで機械化する。
Codex / Claude のどちらで実装しても同じ gate に当たるよう、CI を tool 非依存の最終判定にする。

## 6. Environment And Secrets

bootstrap 時に作るもの:

- `.env.example`
- secret naming convention
- local dev setup command
- seed/migration command
- provider binding docs
- deploy environment mapping

作らないもの:

- 実 secret 値
- production credentials
- 本番データ dump
- irreversible migration without approval

## 7. Documentation Freshness

この repo は README/docs と実装の drift を検知する Skill を持つ。
新規 repo では、最初から重い drift detector を作る必要はない。

代わりに bootstrap 直後は以下を PR checklist に入れる。

- app/package を追加したら nearest README を更新
- env/secret を追加したら `.env.example` と setup docs を更新
- public API を変えたら OpenAPI/SDK/docs を更新
- deploy workflow を変えたら smoke test と rollback docs を更新

## 8. PR Contract

PR body に最低限入れる情報:

- Summary
- Related issue or bootstrap request
- Test plan
- Deploy URL or reason no deploy was run
- Bootstrap artifacts path
- Remaining risks and follow-up issues

Issue auto-close が必要な repo では、closing keyword を body に入れる。
title だけに issue number を書いても auto-close されない。

## 9. Avoid Tool Lock-in

避けること:

- workflow 正本を `.claude/` だけ、または `AGENTS.md` だけに閉じる
- slash command 名を唯一の呼び出し方法として書く
- Claude subagent の存在を前提にし、Codex で代替できる role separation を書かない
- Codex/Claude の片方だけに secret/deploy/PR ルールを書く

推奨:

- 共通正本は `docs/harness/` に置く
- `AGENTS.md` と `CLAUDE.md` は thin adapter にする
- workflow 名は `implement-feature` のように tool-neutral にする
- tool 固有の実装詳細は adapter 側に閉じ込める
