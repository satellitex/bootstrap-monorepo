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
| `docs/README.md` | docs ナレッジハブ。置き場所、INDEX の更新主体、命名規約 |
| `docs/harness/OPERATING_MODEL.md` | Codex / Claude 共通の作業フロー、承認モデル、言語ポリシー、品質基準。両 adapter の参照先 |
| `docs/harness/harness_authoring_guide.md` | ハーネス文書の書き方（サイズ上限、分離原則、プロンプト記述） |
| `docs/harness/scheduled-operations.md` | routine 登録カタログ、起動プロンプトの正準形、定期 workflow を足すときの設計ガイド |
| `docs/harness/skills/<name>.md` | workflow 手順の tool-neutral 正本 |
| `docs/harness/skills/shared/` | skill 横断の共通契約（無人 run・INDEX の更新主体・実装整合・通知・PR 作成・検証ゲート・fail-closed 照会。sync 専用は `sync-` 接頭辞） |
| `docs/adr/` | 重要判断の履歴。ADR の置き場は 1 箇所のみ |
| `docs/product/TECH_STACK.md` | 採用技術と provider/runtime/service selection の現在状態（選定ごとの ADR を参照） |
| `docs/product/ARCHITECTURE.md` | system boundary、data flow、dependency direction。冒頭にプロダクト概要 |
| `docs/product/TERMS.md` / `TEST_STRATEGY.md` | ドメイン用語とテスト戦略の現在状態 |
| `docs/requirements/` | 要件正本。AI の自動編集対象外 |
| `docs/notes/research/` | 技術調査、技術選定の比較（一次情報の URL と確認日）、外部資料 |
| `docs/runbooks/` | deploy、rollback、secrets、runner operations。`README.md` が手順の必須要素を定める |
| `docs/styles/coding_guide/docs.md` | docs 層分離、現状層 3 原則、実装整合の原則 |
| `docs/styles/team-feedback/` | 横断判断 rule の本文。`.claude/rules/team-policy.md` は pointer に徹する |
| `.claude/rules/*.md` | 常時ロード rule と paths スコープ rule |
| `.claude/hooks/` / `.claude/bin/` | 機械強制される検査（format / 秘密検知 / 編集後検査）とその hermetic テスト。Claude Code 経由の操作にだけ効く |
| `tests/harness/` | ハーネス文書・設定の機械検査（依存ゼロの `node:test`。範囲 → `tests/harness/README.md`「検査一覧」）。CI の test job が実行する |
| `.claude/agents/*.md` | 単機能 subagent。skill 本文から呼ばれる |

言語ポリシー、issue lifecycle、Project 運用は独立ファイルにせず、次に畳み込んでいる。分割を増やすと入口が太り、pointer の維持コストだけが増えるため。

| 畳み込み先 | 畳み込んだ内容 |
|------------|----------------|
| `docs/harness/OPERATING_MODEL.md` | project language と例外規則、承認モデル、Codex/Claude handoff |
| `docs/harness/skills/shared/pr-creation.md` | 計画・判断の根拠・検証結果の置き場（PR 本文の標準節） |
| `docs/harness/skills/create-issue.md` + `.claude/skills/create-issue/references/project-fields.md` | labels、milestones、Projects、field の magic value |

常時読むファイルは短くし、更新頻度が低い詳細は docs へ逃がす。
`AGENTS.md` と `CLAUDE.md` の文言は、片方だけに重要ルールが入らないように同期する。

## 2. Workflow / Skill Layers

skill は責務レイヤごとに分けている。名前は tool-neutral にし、Claude の slash command と Codex の Skill/明示プロンプトのどちらからも同じ手順を呼べるようにする。

| 層 | 収録 skill（MANIFEST の名称） | 責務 |
|----|------------------------------|------|
| 実装フロー | `multi-issue` | 複数 issue を Planner–Worker で並列実装し、独立した review pass を経て issue ごとに PR を作る（PR の base は常に既定ブランチ） |
| 検証 | （skill ではなく共通契約 `shared/verification-gates.md`） | 検証ゲートの名前付き組合せ（`gate:commit` / `gate:push` / `gate:ci` / `gate:docs`）。skill・hook・CI が同じ名前で参照する |
| レビュー | `handle-review` / `review-cycle` | レビューコメントの批判的評価と、LGTM までの自律対応（conflict 解消・CI 失敗の修正を含む） |
| 記録 | `create-issue` / `create-adr` | Issue と ADR の構造的記録（ADR は置換・廃止の手順を含む） |
| 鮮度維持（`*-sync`） | `readme-sync` / `docs-sync` / `code-sync` / `refactor-guide-sync` | README・現状層 docs・ソースコメント・規約ガイドの drift 検知。記述と実装の矛盾は「記述修正 / 実装疑い / 判定不能」に分類してから直す |
| 照合・提案 | `runbook-alignment` / `refactor-sync` | 手順書の未確定事項と実装の照合（差異評価表を PR 本文へ）、コード課題の Issue 提案（refactorer agent を起動する入口） |
| ハーネス保守 | `gc-scan` / `adr-compress` / `promote-memory` | ハーネス文書の重複・孤児の GC、ADR コーパスの Status 追従・圧縮と INDEX 再構築、memory → team rule 昇格 |
| 運用 | `deploy-verify` | deploy 一気通貫と、prod の release 反映（merge commit 限定・前提ゲート・マージ後の step 単位確認） |
| 公開区画（opt-in:public-site） | `public-arch-sync` / `customer-doc-review` | 内部正本 → 公開射影の追従と、対外 docs のレビュー |
| 依存自動化（opt-in:renovate） | `renovate-sync` | 依存 pin ↔ 依存更新設定の突合 |

縮約の判断基準は「対応する surface が product に実在するか」の一点にする。

- core 区分は既定で全部入れる。相互参照（shared 契約、rules、hooks）が成立しているのは core 一式が揃っている前提のため、部分採用は参照切れを生む。
- opt-in グループは surface が無いなら**グループ単位で丸ごと落とす**。個別ファイルだけ残すと adapter と正本の 1:1 が崩れる。
- MANIFEST にない鮮度境界（env examples、API schema、security policy など）は、必要になってから `generated-workflows.md` §2 の 10 項目契約で追加する。
- 実行系の routine（実装キュー・コードと docs の棚卸し・日次観測点検）は資産として収録しない。需要が出た導入先が、`generated-workflows.md` §8 のレシピに従って skill 化する。

skill は 2 層構成にする。正本を片方のツールに閉じないための構造。

| 層 | 実体 | 制約 |
|----|------|------|
| 正本 | `docs/harness/skills/<name>.md` | tool-neutral。手順・判定条件・fail 方向はここだけに書く |
| adapter | `.claude/skills/<name>/SKILL.md` | 正本を読んで実行するだけ。手順を複製しない |
| profile | `.claude/skills/<name>/references/*.md` | 推論不能な PJ 固有値のみ。環境から取得する未検証の値は `TODO(取得方法: ...)`、チームが決める値は `TODO(記入方法: ...)` のまま置く |

## 3. Role Separation

自分で作った変更を自分で評価しない。subagent 機構を持たない実行環境でも、同じセッション内の明示的な review pass、別スレッド、または人間レビューで責務分離を維持する。

| Role | 収録資産 | Input | Output | 制約 |
|------|----------|-------|--------|------|
| generator | `multi-issue` の worker | 受入条件、対象ファイル | code/docs diff | scope 外の変更をしない |
| evaluator | `multi-issue` の独立 review pass（worktree の絶対パスを渡す） | diff、受入条件、coding guide | 修正提案 | 実装と同一の役で完結させない |
| `architecture-sync` | `.claude/agents/architecture-sync.md` | 実装差分、README/docs | docs 更新案 | 現状事実だけを書く |
| `refactorer` | `.claude/agents/refactorer.md`（入口は `/refactor-sync`） | 変更近傍のコード、規約正本 | 観点の検出結果 | 実装せず Issue 提案に留める |
| `gc-agent` | `.claude/agents/gc-agent.md` | ハーネス文書全体 | 重複・孤児の整理案（機械検査で判定できる項目は対象外） | 削除はすべて PR で提案し、単独で消さない |
| `adr-compactor` | `.claude/agents/adr-compactor.md` | ADR コーパス | Status 追従、圧縮案、INDEX 再構築 | 判断内容を改変しない |
| `refactor-guide-sync` | `.claude/agents/refactor-guide-sync.md` | 規約正本、リファクタガイド | 観点の追加・削除・根拠パス修正 | 規約内容そのものを決めない |

小規模 repo では、opt-in:traceability の matrix 運用を後回しにできる。`architecture-sync` は core で、`multi-issue` の仕上げが Issue ごとに起動するため後回しにしない（ハーネスのみの diff では実質 no-op になる）。GC と ADR 圧縮は文書量が閾値に達してから routine 登録すればよい。

## 4. 承認が必要な操作

承認モデル（既定の自律実行、承認が必須な操作、ブランチモデル）は `../assets/docs/harness/OPERATING_MODEL.md`「承認モデル」が正本であり、ここには複製しない。承認が必須でない操作は、判断材料を成果物に残し、PR で提示する。

| 操作 | 承認 | 残すもの |
|------|------|----------|
| 技術選定の確定 | 不要 | 領域ごとの ADR（採用案・代替案・棄却理由・リスク）と `docs/product/TECH_STACK.md` |
| 実装計画の確定 | 不要 | PR 本文の標準節（方針と却下案・スコープ外・リスク）と、残タスクの GitHub Issue |
| label / milestone / Project / field の作成・変更 | 不要 | 実行した operation と読み戻し検証の結果 |
| issue / PR の作成、issue への comment | 不要 | PR 本文 |
| dev 環境（main）への deploy | 不要 | deploy URL、commit SHA、smoke 結果 |
| repo settings の変更 | 不要 | 変更前後の設定と理由 |

prod リリースの手順の具体は `deploy-verify` の「release 反映（prod）」節（merge commit 限定、承認は release 宛て PR のマージ 1 か所）にある。release 用の別 skill は持たない。

承認を得た場合、そのログは PR 本文の「承認ログ（課金・秘密値）」節に残す。チャットだけに閉じると、後続 agent や別ツールが判断経緯を読めない。

## 5. CI/CD Baseline

CI の既定は基礎 CI 1 本のみ（`assets/.github/workflows/ci.yml`）。

- format:check / test / build（`gate:ci`）
- test job 内で hooks の bash テストとハーネスの機械検査（`pnpm harness:test`）を実行する。job は増やさず、step を足すだけにする

これを超える check は拡張候補であり、product に必要なものだけ選ぶ。候補一覧・採否の記録先・base branch diff の注意点は `ci-cd-runner-deploy.md` を参照する。
秘密検知は CI ではなく pre-push hook が既定の担い手になる。CI job を増やす前に hook で止められないかを先に検討する。
hook と CI の分担は `../assets/docs/harness/skills/shared/verification-gates.md`「ゲートごとの実行先」が正本であり、この差を同書の表で説明できる状態に保つ。

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

PR 本文は標準節を既定とする。定義と各節に書くことは `assets/docs/harness/skills/shared/pr-creation.md`「PR 本文の標準節」が正本である。
bootstrap / adopt の PR は、これに「承認ログ（課金・秘密値）」と「移管先の文書」の 2 節を加える。bootstrap の節構成のテンプレートは `bootstrap-artifacts.md` にあり、adopt の各節の内容は `../../harness-adopt/SKILL.md` の「成果物」の表が正本である。

PR 本文に最低限入れる情報と、その置き場:

| 情報 | 節 |
|------|----|
| Summary、関連 issue または bootstrap の依頼 | 背景 |
| 採用した方針、退けた案 | 方針と却下案 |
| Follow-up issue、この PR で扱わなかったこと | スコープ外 |
| Test plan、deploy URL（または deploy しなかった理由） | 検証結果 |
| 残るリスク、docs への影響の有無 | リスク |
| 課金操作・秘密値投入の承認ログ | 承認ログ（課金・秘密値） |
| 成果を移した文書 | 移管先の文書 |

PR の作成規約は `assets/docs/harness/skills/shared/pr-creation.md` が正本である。base は常に既定ブランチ、draft にしない、open 前に他の open PR との衝突を検査する。
closing keyword の規則は `docs/styles/team-feedback/pr-closing-keyword.md` を正本にする。

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
