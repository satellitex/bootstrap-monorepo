# Reference Harness Patterns

この文書は、`../assets/` に収録したハーネス資産の**設計根拠**と、target repo の規模・team・deploy 先・規制要件・project language に合わせた**縮約判断**の指針である。
資産ファイルの一覧・区分（core / opt-in）はここに書かない。正本台帳は `../assets/MANIFEST.md`。
copy と置換の手順も書かない（手順は SKILL.md Step 5 と MANIFEST の「使い方」）。

## 1. Repository Knowledge Map

`assets/` は「bootstrap 先のディレクトリ構造をミラーしたコピー元」であり、入口を薄く、正本を `docs/` に置く構造を前提にしている。
両入口（`AGENTS.md` / `CLAUDE.md`）に同じ詳細を複製せず、docs 正本へ参照させる。

| 収録資産（assets 内の相対パス） | 設計上の役割 |
|-------------------------------|--------------|
| `AGENTS.md` | Codex 用入口。repo の目的と正本 docs への pointer だけを持つ thin adapter |
| `CLAUDE.md` | Claude 用入口。`AGENTS.md` と同じ共通正本を指す。rules の読み込まれ方だけが固有 |
| `DEVELOPMENT.md` | 人間向けの開発スタイル。承認ポイントとフローを人間の言葉で書く |
| `docs/README.md` | docs ナレッジハブ。置き場所、INDEX 同時更新ルール |
| `docs/harness/OPERATING_MODEL.md` | Codex / Claude 共通の作業フロー、承認モデル、言語ポリシー、品質基準。両 adapter の参照先 |
| `docs/harness/harness_authoring_guide.md` | ハーネス文書の書き方（サイズ上限、分離原則） |
| `docs/harness/scheduled-operations.md` | routine 登録カタログと、定期 workflow を足すときの設計ガイド |
| `docs/harness/skills/<name>.md` | workflow 手順の tool-neutral 正本 |
| `docs/harness/skills/shared/` | sync 系の共通契約（前段・後段・fail-closed・PR 作成・検証ゲート） |
| `docs/adr/` | 重要判断の履歴。ADR の置き場は 1 箇所のみ |
| `docs/issues/000_bootstrap/` | bootstrap 成果物（Issue 0） |
| `docs/product/TECH_STACK.md` | 採用技術と provider/runtime/service selection の現在状態 |
| `docs/product/ARCHITECTURE.md` | system boundary、data flow、dependency direction |
| `docs/product/TERMS.md` / `TEST_STRATEGY.md` | ドメイン用語とテスト戦略の現在状態 |
| `docs/requirements/` | 要件正本。AI の自動編集対象外 |
| `docs/notes/research/` | 技術調査、比較、外部資料 |
| `docs/runbooks/` | deploy、rollback、secrets、runner operations |
| `docs/styles/coding_guide/docs.md` | docs 層分離と現状層 3 原則 |
| `docs/styles/team-feedback/` | 横断判断 rule の本文。`.claude/rules/team-policy.md` は pointer に徹する |
| `.claude/rules/*.md` | 常時ロード rule と paths スコープ rule |
| `.claude/hooks/` / `.claude/bin/` | 機械強制される検査（format / 秘密検知 / 編集後検査）とその hermetic テスト |
| `.claude/agents/*.md` | 単機能 subagent。skill 本文から呼ばれる |

言語ポリシー、issue lifecycle、Project 運用は独立ファイルにせず、次に畳み込んでいる。分割を増やすと入口が太り、pointer の維持コストだけが増えるため。

| 畳み込み先 | 畳み込んだ内容 |
|------------|----------------|
| `docs/harness/OPERATING_MODEL.md` | project language と例外規則、承認モデル、Codex/Claude handoff |
| `docs/issues/README.md` | issue-local docs の置き場所とアーカイブポリシー |
| `docs/harness/skills/create-issue.md` + `.claude/skills/create-issue/references/project-fields.md` | labels、milestones、Projects、field の magic value |

常時読むファイルは短くし、更新頻度が低い詳細は docs へ逃がす。
`AGENTS.md` と `CLAUDE.md` の文言は、片方だけに重要ルールが入らないように同期する。

## 2. Workflow / Skill Layers

skill は責務レイヤごとに分けている。名前は tool-neutral にし、Claude の slash command と Codex の Skill/明示プロンプトのどちらからも同じ手順を呼べるようにする。

| 層 | 収録 skill（MANIFEST の名称） | 責務 |
|----|------------------------------|------|
| 実装フロー | `multi-issue` | 複数 issue を Planner–Worker で並列実装し、issue ごとに PR を作る |
| 検証 | `static-check` | 検証ゲートの一括実行と表形式報告 |
| レビュー | `handle-review` / `review-cycle` | レビューコメントの批判的評価と、LGTM までの自律ポーリング |
| 記録 | `create-issue` / `create-adr` | Issue と ADR の構造的記録 |
| 鮮度維持（`*-sync`） | `readme-sync` / `docs-sync` / `code-sync` / `refactor-guide-sync` | README・現状層 docs・ソースコメント・規約ガイドの drift 検知 |
| ハーネス保守 | `gc-scan` / `adr-compress` / `promote-memory` | ハーネス文書の GC、ADR コーパス圧縮、memory → team rule 昇格 |
| 運用 | `deploy-verify` / `security-audit` | deploy 一気通貫と多次元セキュリティ監査 |
| 公開区画（opt-in:public-site） | `public-arch-sync` / `customer-doc-review` | 内部正本 → 公開射影の追従と、対外 docs のレビュー |
| 依存自動化（opt-in:renovate） | `renovate-sync` | 依存 pin ↔ 依存更新設定の突合 |

縮約の判断基準は「対応する surface が product に実在するか」の一点にする。

- core 区分は既定で全部入れる。相互参照（shared 契約、rules、hooks）が成立しているのは core 一式が揃っている前提のため、部分採用は参照切れを生む。
- opt-in グループは surface が無いなら**グループ単位で丸ごと落とす**。個別ファイルだけ残すと adapter と正本の 1:1 が崩れる。
- MANIFEST にない鮮度境界（env examples、API schema、security policy など）は、必要になってから `generated-workflows.md` §2 の 10 項目契約で追加する。

skill は 2 層構成にする。正本を片方のツールに閉じないための構造。

| 層 | 実体 | 制約 |
|----|------|------|
| 正本 | `docs/harness/skills/<name>.md` | tool-neutral。手順・判定条件・fail 方向はここだけに書く |
| adapter | `.claude/skills/<name>/SKILL.md` | 正本を読んで実行するだけ。手順を複製しない |
| profile | `.claude/skills/<name>/references/*.md` | 推論不能な PJ 固有値のみ。未検証の値は `TODO(取得方法: ...)` のまま置く |

## 3. Role Separation

自分で作った変更を自分で評価しない。Codex に subagent 機構がない場合でも、同じセッション内の明示的な review pass、別スレッド、または人間レビューで責務分離を維持する。

| Role | 収録資産 | Input | Output | 制約 |
|------|----------|-------|--------|------|
| generator | `multi-issue` の worker | 受入条件、対象ファイル | code/docs diff | scope 外の変更をしない |
| evaluator | `multi-issue` の後段レビューパス | diff、受入条件、coding guide | 修正提案 | 実装と同一の役で完結させない |
| `architecture-sync` | `.claude/agents/architecture-sync.md` | 実装差分、README/docs | docs 更新案 | 現状事実だけを書く |
| `refactorer` | `.claude/agents/refactorer.md` | 変更近傍のコード、規約正本 | 観点の検出結果 | 実装せず Issue 提案に留める |
| `gc-agent` | `.claude/agents/gc-agent.md` | ハーネス文書全体 | サイズ超過・重複・孤児の削除案 | 削除はすべて PR で提案し、単独で消さない |
| `adr-compactor` | `.claude/agents/adr-compactor.md` | ADR コーパス | 圧縮案と INDEX 再構築 | 判断内容を改変しない |
| `refactor-guide-sync` | `.claude/agents/refactor-guide-sync.md` | 規約正本、リファクタガイド | 観点の追加・削除・根拠パス修正 | 規約内容そのものを決めない |
| traceability-mapper | `docs/issues/templates/traceability.md`（opt-in:traceability） | 受入条件と test diff | AC-test matrix | 実装判断をしない |

小規模 repo では traceability と `architecture-sync` を後回しにできる。GC と ADR 圧縮は文書量が閾値に達してから routine 登録すればよい。

## 4. 承認が必要な操作

既定は自律実行とする。エージェントは明示的な指示がない限り、変更の実装から open PR の提出までを自律的に行う。PR のマージは人間の操作だが、明示的に指示された場合はマージまで行ってよい。

人間の明示承認が必須なのは次の 2 つのみ。

| 対象 | 具体例 |
|------|--------|
| 課金が発生する操作 | 有償リソースの作成、有償プランへの変更、外部サービス契約 |
| 秘密値の挿入・変更 | credential / API key / token を設定へ投入する操作 |

これ以外は承認を待たずに実行してよい。ただし判断材料は成果物に残し、PR で提示する。

| 操作 | 承認 | 残すもの |
|------|------|----------|
| 技術選定の確定 | 不要 | `decision-matrix.md`（採用案・代替案・棄却理由・リスク） |
| 実装計画の確定 | 不要 | `bootstrap-plan.md` |
| label / milestone / Project / field の作成・変更 | 不要 | 実行した operation と読み戻し検証の結果 |
| issue / PR の作成、issue への comment | 不要 | PR body と issue-local docs |
| dev 環境（main）への deploy | 不要 | deploy URL、commit SHA、smoke 結果 |
| repo settings の変更 | 不要 | 変更前後の設定と理由 |

ブランチモデルは main = dev 環境 / release = prod 環境。main は壊れても復旧可能な開発環境であり、開発過程ではセキュリティより柔軟性を優先する。
prod リリースのみ手順を踏む: main の安全性確認 → release への反映手順の確認。

承認を得た場合、そのログは成果物に残す。チャットだけに閉じると、後続 agent や別ツールが判断経緯を読めない。

## 5. CI/CD Baseline

CI の既定は基礎 CI 1 本のみ（`assets/.github/workflows/ci.yml`）。

- format:check / test / build
- test job 内で hooks の bash テストを実行する

これを超える check は拡張候補であり、product に必要なものだけ選ぶ。候補一覧・採否の記録先・base branch diff の注意点は `ci-cd-runner-deploy.md` を参照する。
秘密検知は CI ではなく pre-push hook が既定の担い手になる。CI job を増やす前に hook で止められないかを先に検討する。

CI は「agent が merge 可能性を判断できる」粒度まで機械化する。
Codex / Claude のどちらで実装しても同じ gate に当たるよう、CI を tool 非依存の最終判定にする。

定期実行 workflow は既定では収録しない。追加する場合は `docs/harness/scheduled-operations.md` の設計ガイドに従う。

## 6. Runner Operations

self-hosted runner を使う場合のみ、`docs/runbooks/` に runner 運用手順を作る。必須項目は `ci-cd-runner-deploy.md` を参照する。

設計上の要点だけ再掲する。

- foreground の常駐スクリプト常用ではなく service manager 経由の常駐を推奨する
- runner user と、必要な CLI login / keychain / credentials を持つ user を一致させる
- runner 上の実 CLI version で `--help` を確認してから workflow option を使う
- base branch diff 用の fetch は prune で remote ref を消さない形にする

runner の実環境は interactive shell と違う。workflow は service user の non-interactive environment で検証する。

## 7. Environment And Secrets

bootstrap 時に作るもの。

- tool/runtime version の pin（収録資産の `.mise.toml`）と `mise install` から始まる setup 手順
- 反復的な local dev / check / seed / migration command の入口
- `.env.example`
- secret naming convention
- seed / migration command
- provider binding docs
- deploy environment mapping
- rollback と smoke-test の runbook

作らないもの。

- 実 secret 値
- production credentials
- 本番データ dump
- 承認なしの不可逆 migration

## 8. Documentation Freshness

drift の検知は skill ごとに責務境界を分ける。境界が重なると、同じ指摘が複数 PR に出て収束しない。
どの skill がどの境界を持つかは `docs-operating-model.md` の Sync Ownership 表を参照する。

bootstrap 直後の PR checklist:

- app/package を追加したら nearest README を更新
- env/secret を追加したら `.env.example` と setup docs を更新
- public API を変えたら schema / SDK / docs を更新
- 公開区画を採用している場合は公開射影と内部参照 gate を更新
- deploy workflow を変えたら smoke test と rollback docs を更新
- runner workflow を変えたら runner runbook と CLI version の前提を更新
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
- 課金操作・秘密値投入を行った場合はその承認ログへの参照

Issue auto-close が必要な repo では closing keyword を body に入れる。title だけに issue number を書いても auto-close されない。
運用 rule の本文は `docs/styles/team-feedback/pr-closing-keyword.md` を正本にする。

## 10. Avoid Tool / Provider Lock-in

避けること:

- workflow 正本を `.claude/` だけ、または `AGENTS.md` だけに閉じる
- thin adapter を実体化し、正本と手順を二重管理する
- slash command 名を唯一の呼び出し方法として書く
- Claude subagent の存在を前提にし、Codex で代替できる role separation を書かない
- Codex/Claude の片方だけに secret/deploy/PR/docs ルールを書く
- specific provider、database、queue、storage、CSS framework を template の既定として固定する

推奨:

- docs 正本は `docs/` に置く
- `AGENTS.md` と `CLAUDE.md` は thin adapter にする
- workflow 名は tool-neutral にする
- tool 固有の実装詳細は adapter 側に閉じ込める
- provider 固有の CLI や binding は target repo の runbook に閉じ込める
