# Bootstrap Artifacts

この文書は、`monorepo-bootstrap` と `harness-adopt` の成果物を、PR 本文の節構成と、各層の文書へ移すときのテンプレートとして定める。
成果物専用のディレクトリやファイルは作らない。作業中の成果は PR 本文の節に書き、確定した内容を既存の層（調査・決定・現状・運用）の文書へ移す。
どの成果をどの文書へ移すかの対応表は `../SKILL.md` の「成果物」を正本とし、ここには複製しない。
target repo に既存のテンプレート（PR テンプレート、ADR テンプレート等）がある場合はそちらを優先し、この構造は不足確認に使う。

## 1. PR 本文の節構成

PR 本文の標準節と、bootstrap / adopt の PR に加える 2 節（承認ログ / 移管先の文書）の定義は、`../assets/docs/harness/skills/shared/pr-creation.md`「PR 本文の標準節」「bootstrap / adopt の PR に加える節」が正本である。
ここでは bootstrap で各節に何を書くかと、確定前の途中成果を載せる節を定める。

```markdown
<linkage 行（起票元 Issue がある場合のみ）>

## 背景
## 方針と却下案
## スコープ外
## 検証結果
## リスク
## 承認ログ（課金・秘密値）
## 移管先の文書

## Intake（確定前）
## Gate A 技術選定（確定前）
## Gate B 実装計画（確定前）
```

| 節 | bootstrap で書くこと |
|----|----------------------|
| 背景 | プロダクト概要、project language、deploy 目標、制約。Intake の原文を引用し、入力が足りずに置いた仮定を明示する |
| 方針と却下案 | 採用した stack と app topology の要約（詳細は技術選定の ADR を参照）、opt-in グループの採否、既存 repo の規約を優先した判断、CI の拡張候補の採否と理由。退けた案は 1 案ごとに 1 行 |
| スコープ外 | bootstrap で作らないものと、その追跡先の GitHub Issue |
| 検証結果 | 実行した検証ゲート（`gate:commit` 等）と基礎 CI の結果、`pnpm harness:test` と hooks テストの結果、deploy 先の smoke 結果、deploy URL・commit SHA・environment。未検証の範囲 |
| リスク | 技術・運用・セキュリティ・cost / limits のリスクと緩和、残っている `TODO(` の一覧、routine 登録など人間への引き継ぎ |
| 承認ログ（課金・秘密値） | 承認必須 2 種に該当する項目と状態。該当なしの場合は「該当なし」と書く |
| 移管先の文書 | 成果を移した文書のパスと、各文書へ移した内容の 1 行要約 |

途中成果の節（Intake / Gate A / Gate B）の扱い:

- 作業中は、これらの節に確定前の内容を書く。PR 本文は commit しない作業用ファイルに書き、最後に `gh pr create --body-file` へ渡す。作業が複数 session にまたがる場合は、作業ブランチを push した後に通常 PR（draft にしない）を open し、同じ節構成で本文を更新し続けてよい。
- 内容を確定したら、§2 のテンプレートに従って移管先の文書へ移し、途中成果の節には移管先への参照だけを残す。確定前の内容を節に残したまま PR を提出しない。
- 課金・秘密値の承認ログは、承認を得た時点で「承認ログ（課金・秘密値）」節に追記する。チャットだけに閉じると、後続の agent や別ツールが判断経緯を読めない。

### Intake（確定前）

```markdown
## Intake（確定前）

- Problem:
- Users:
- Core flows（最初に動くべき 1-3 個）:
- Data and trust（中心 entity、機密性、保持期間、監査要件）:
- Interfaces（Web / API / batch / webhook / SDK / external agent）:
- Constraints（技術 / provider / 組織 / cost / compliance / timeline）:
- Non-goals:
- Project language と、運用文書の言語の扱い（収録言語のまま導入するか、翻訳するか）:
- Open questions（仮定として確定した内容と根拠）:
```

### Gate A 技術選定（確定前）

領域の一覧は `technology-selection.md` §1 に従う。

```markdown
## Gate A 技術選定（確定前）

| 領域 | 採用案 | 代替案 | 棄却理由 | 運用リスク | cost / limits | local dev 影響 | 調査ノート |
|------|--------|--------|----------|------------|---------------|----------------|------------|

### App topology

| Option | Shape | Pros | Cons | Decision |
|--------|-------|------|------|----------|

### CSS / UI styling strategy（UI がある場合のみ）

| Option | Design system fit | Typed tokens | Runtime cost | Team familiarity | Migration cost | Decision |
|--------|-------------------|--------------|--------------|------------------|----------------|----------|

### 人間承認が必要な項目（課金 / 秘密値）

| Item | Category (billing / secret) | Status (Pending / Approved) |
|------|-----------------------------|-----------------------------|
```

選定の判断基準:

- Fit to product flows and operational capacity
- Long-term maintainability
- Local development speed
- CI reliability and cost
- Deploy target maturity
- Security and compliance requirements
- Lock-in and migration cost
- Provider/runtime limits and pricing
- App topology and deployment/scaling boundaries

### Gate B 実装計画（確定前）

```markdown
## Gate B 実装計画（確定前）

### Scope
（In Scope / Out Of Scope）

### Architecture
| Layer | Path | Responsibility | Depends on |
|-------|------|----------------|------------|

### Infrastructure
| Service | Selected approach | Required setup | Verification | Runbook |
|---------|-------------------|----------------|--------------|---------|

### App topology
| Unit | Path | Deploy unit | Scaling unit | Auth/session boundary | Async responsibility |
|------|------|-------------|--------------|-----------------------|----------------------|

### Docs と Harness
| Item | Path | Purpose | Required before first implementation |
|------|------|---------|--------------------------------------|

### Environment
| Item | Path/Provider | Notes |
|------|---------------|-------|

### CI/CD（拡張候補の採否と理由）
| Check | Command/Workflow | Required before merge | Notes |
|-------|------------------|-----------------------|-------|

### Runner operations（self-hosted runner を使う場合）
| Topic | Decision | Runbook path |
|-------|----------|--------------|

### Implementation（最初の vertical slice）
| Slice | 単位（API / UI / DB / worker など） | Verification |
|-------|-------------------------------------|--------------|

### Deploy
| Environment | Provider | Trigger | Smoke check | Rollback | Approval required |
|-------------|----------|---------|-------------|----------|-------------------|

### Tasks（1 session で完了できる粒度）
| Task | Issue type | Why | What | Verification | Depends on |
|------|------------|-----|------|--------------|------------|

### Risks
| Risk | Impact | Mitigation | Owner |
|------|--------|------------|-------|
```

「Docs と Harness」には、次の項目を立てる。

- docs 運用の層分離、INDEX、公開射影
- workflow 一覧と opt-in の採否
- sync 範囲（README / docs / code / public docs / dependency など、鮮度維持の対象）
- Issue taxonomy と lifecycle
- milestone
- Project model（board、field、status、date field、owner field、magic value の保管先）
- tool adapter（Codex と Claude から各 workflow をどう呼ぶか）
- 言語方針（Project language と surface ごとの例外、運用文書の言語の扱い）

確定時の移管先:

| 計画の項目 | 移管先 |
|------------|--------|
| Scope | PR 本文の「背景」と「スコープ外」 |
| Architecture / App topology | `docs/product/ARCHITECTURE.md`（現在の構成のみ。判断理由は ADR） |
| Infrastructure | 採用した選定の ADR と `docs/product/TECH_STACK.md`。手順は `docs/runbooks/` |
| Docs と Harness | `docs/harness/OPERATING_MODEL.md`（workflow 一覧と言語ポリシー）。opt-in の採否とその理由は ADR 1 本 |
| Implementation | PR 本文の「方針と却下案」（vertical slice の選定）と「検証結果」 |
| Environment / Runner operations / Deploy | `docs/runbooks/`。deploy の具体手順は `docs/harness/skills/deploy-verify.md` |
| CI/CD | PR 本文の「方針と却下案」（拡張候補の採否と理由） |
| Tasks | GitHub Issue |
| Risks | PR 本文の「リスク」 |

## 2. 各層へ移す文書のテンプレート

### 2.1 調査ノート（`docs/notes/research/<topic>.md`）

1 トピック 1 ファイルで置く。冒頭の見出しとリード文（調査の目的と範囲）は `docs/harness/skills/shared/index-writer-policy.md`「leaf 文書の要件」に従う。`INDEX.md` の行は更新主体が起こす。
調査ノートは調査した時点の記録であり、採用の宣言は書かない。採用した選定は ADR と `docs/product/TECH_STACK.md` に置く。

```markdown
# <topic> の調査

<調査の目的と範囲を 1〜3 行で書く>

## Repository observations

| Area | Observation | Evidence |
|------|-------------|----------|

## External sources

| Topic | Source | Access date | Why it matters |
|-------|--------|-------------|----------------|

## Findings

| Area | Finding | Confidence | Follow-up |
|------|---------|------------|-----------|

## Provider / Runtime notes

| Option | Source | Limits checked | Cost checked | Local dev notes |
|--------|--------|----------------|--------------|-----------------|

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
```

規則:

- 現行の製品 docs、価格、API limits、deploy の挙動、CLI option、CI/CD の構文、migration の挙動は一次情報で確認する。
- 結果が変わりうる場合は URL と確認日を記録する。
- 観察と推奨を分ける。
- 判断が provider の limits に依存するとき、limits を記憶から推定しない。

### 2.2 技術選定の ADR（1 領域 1 ADR）

ファイル名は `docs/adr/README.md`「書き方」の命名規則に従う。書式は `docs/adr/template.md` に従い、Status は `Proposed` にする（bootstrap PR のマージ後に `/adr-compress` が `Accepted` へ追従させる）。
代替案と棄却理由を Decision に含める。調査の過程と一次情報は調査ノートに置き、ADR から参照する。

```markdown
# ADR-{date}_{branch-slug}_{topic-slug}: <領域> の選定

| 項目 | 値 |
|------|-----|
| Status | Proposed |
| Date | YYYY-MM-DD |
| Author | <著者> |

## Context

<この領域で満たす要件と、選定を制約する条件（既存技術、provider 制約、予算、規制、納期）>

## Decision

<採用する技術と、その理由>

### 検討した代替案

| 代替案 | 棄却理由 |
|--------|----------|

## Consequences

### Positive

- <期待されるメリット（local dev 影響を含む）>

### Negative

- <運用リスク、cost / limits、lock-in と移行コスト>

## Related Issues

- 調査ノート: `docs/notes/research/<topic>.md`
```

選定の対象領域（app framework / deploy / runtime model / database / storage / cache / queue / long-running task / external agent boundary / auth / observability / CI/CD / CSS・UI strategy / app topology）は `technology-selection.md` §1・§5・§6 に従う。複数の領域を 1 本の ADR にまとめない。

### 2.3 opt-in 採否の ADR（1 本）

opt-in グループ（一覧は `../assets/MANIFEST.md`）と、実態次第で不採用にする core 資産（deploy 手順が確立していない場合の `deploy-verify`、IaC を採用しない場合の infra 向け rule など）の採否を、複数の選択肢を比較して決めた判断として 1 本の ADR に記録する。形式は §2.2 と同じ。

```markdown
## Decision

| 対象（MANIFEST のグループ名または資産） | 採否 | 理由（対応する surface が product に実在するか） |
|------------------------------------------|------|--------------------------------------------------|

### 検討した代替案

| 代替案 | 棄却理由 |
|--------|----------|
```

workflow 一覧と project language の扱いは、ADR ではなく `docs/harness/OPERATING_MODEL.md` に書く（現状の事実を 1 箇所に置くため）。

### 2.4 `docs/product/TECH_STACK.md` の記入

確定した選定ごとに、確定スタック一覧へ 1 行を足す。決定日と ADR 列を埋める。選定理由は 1 行にとどめ、詳細は ADR に委ねる。

```markdown
| # | 領域 | 技術 | 選定理由 | 決定日 | ADR |
|---|------|------|---------|--------|-----|
| 1 | <領域> | <技術とバージョン> | <1 行> | YYYY-MM-DD | `ADR-{id}` |
```

### 2.5 プロダクト概要の記入

- `docs/product/ARCHITECTURE.md` の High-Level Overview の冒頭に、プロダクトの目的・主な利用者・提供する価値を 3〜5 行で書く。現在形で書き、変更の経緯や将来計画は書かない。
- `docs/product/TERMS.md` に、Intake で確定した主要な用語を足す。対応する要件が無い用語は「初出」列を `—` にする。
- `docs/harness/OPERATING_MODEL.md` のプロダクト 1 行を、Intake の回答から書く。
- Intake の原文は PR 本文の「背景」に残す。

### 2.6 Project / ラベルの実値（`.claude/skills/create-issue/references/project-fields.md`）

GitHub から検証した値だけを書く。検証前の値は TODO 記法（`TODO(取得方法: ...)`）のまま残す。

| Constant | Value | How it was obtained | Last verified |
|----------|-------|---------------------|---------------|

規則:

- taxonomy は、この repository のドメイン固有のラベルではなく、product の目的と roadmap から導く。
- GitHub Project ID・field ID・option ID・milestone node ID・label ID を推測で書かない。
- Project や field がまだ無い場合は placeholder を書き、作成を GitHub Issue の残タスクに起こす。
- Codex / Claude の呼び出し方の注記は薄く保ち、workflow の詳細は shared docs に置く。
- issue / PR / ラベル / milestone / Project 等の GitHub mutation は自律実行してよい（承認の定義 → `../assets/docs/harness/OPERATING_MODEL.md`「承認モデル」）。
