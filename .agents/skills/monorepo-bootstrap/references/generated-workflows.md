# Generated Workflows

この文書は、bootstrap 先の workflow（`*-sync` 系、`create-issue`、milestone / Project 管理）を PJ 固有化・追加設計するときの参照である。
収録済み workflow 資産の一覧はここに書かない（正本台帳は `../assets/MANIFEST.md`）。

## 1. Workflow Inventory

収録済み workflow の一覧と core / opt-in 区分は `../assets/MANIFEST.md` が正本である。

- core 区分の skill doc は既定で bootstrap 先へ copy する。
- opt-in グループ（一覧は MANIFEST）は Intake の整理と制約から採否を判断し、採用グループのみ copy する。
- MANIFEST にない鮮度境界（env examples、API schema、security policy、async runbook、runner 運用など）が product に必要な場合のみ、新しい sync workflow を §2 の契約に従って `docs/harness/skills/<name>.md` として追加設計する。

不要な workflow を先回りで作らない。追加は「対応する surface が product に実在する」ことを条件にする。実行系の routine（実装キュー・棚卸し・観測点検）は資産に収録せず、§8 のレシピとして持つ。

## 2. Generic `*-sync` Shape

Every generated sync workflow should follow the same contract:

| Section | Required content |
|---------|------------------|
| Purpose | What freshness boundary this workflow owns |
| Source of truth | The canonical files or generated artifacts |
| Compared against | Code, config, schema, deploy provider, docs, dependency metadata, or runner state |
| Scope | Include / exclude paths and generated-file exclusions |
| Detection | Drift categories and severity. A contradiction between a description and the implementation is classified (「記述修正 / 実装疑い / 判定不能」) before anything is edited; only 記述修正 is edited, the rest is recorded in the PR body (`docs/harness/skills/shared/implementation-consistency.md`) |
| Auto-edit policy | What may be changed automatically and what must be reported only |
| Branch / PR policy | Whether to push automatically or only when user/repo policy asks |
| Validation | Commands and CI checks |
| Report shape | PR body or local report sections |
| Language | Reports, PR bodies, and review notes use the project language from intake |

生成先はすべて `docs/harness/skills/<name>.md` とする。収録済みの例:

```text
docs/harness/skills/readme-sync.md
docs/harness/skills/docs-sync.md
docs/harness/skills/code-sync.md
docs/harness/skills/refactor-guide-sync.md
docs/harness/skills/gc-scan.md
docs/harness/skills/adr-compress.md
docs/harness/skills/renovate-sync.md      (opt-in:renovate)
docs/harness/skills/public-arch-sync.md   (opt-in:public-site)
```

共通後段（origin/main 基準、0 件終了、open PR ガード、fail-closed 照会、1 スキャン 1 PR、識別ラベルの付与）と、ノイズ除外・実装整合・INDEX の更新主体・通知の共通契約は `docs/harness/skills/shared/`（sync 専用は `sync-` 接頭辞）を参照し、各 skill doc 本文に複製しない。

Each workflow should be tool-neutral.
Claude 側は `.claude/skills/<name>/SKILL.md` を薄い adapter とし、正本の手順を複製しない。

## 3. `create-issue` Specialization

`create-issue` の手順正本は copy 済みの `docs/harness/skills/create-issue.md` である。
product brief、roadmap、`references/issue-lifecycle.md` に従い、taxonomy・milestone・Project の対応を PJ 固有化する。

Required behavior:

- Build an issue body in the project language with summary, motivation, acceptance criteria, dependencies, and references.
- Infer labels from the product-specific taxonomy.
- Infer milestone from the roadmap phase.
- Infer Project board from issue category, if Projects are used.
- Set default status to Todo or the target repo's equivalent.
- Set a target/expired date only if the team uses date fields.
- Support blocked-by and parent/sub-issue relationships as separate inputs and separate mutations when GitHub supports them in the target org.
- Keep labels, milestones, and trailing machine-readable markers that the caller specified; read them back to verify.
- Issue の作成・更新は自律実行してよい。作成後は読み戻して検証する。人間承認が必要なのは課金が発生する操作と秘密値の挿入・変更のみ。

PJ 固有値の置き場所:

```text
docs/harness/skills/create-issue.md
.claude/skills/create-issue/references/project-fields.md
```

`project-fields.md` must contain magic values only after they are verified from GitHub.
Until verified, keep them in `TODO(取得方法: ...)` form:

```markdown
| Project | ID | Source |
|---------|----|--------|
| Product | TODO(取得方法: gh / GraphQL で作成または照会) | create or verify with gh / GraphQL |
| Platform / Harness | TODO(取得方法: gh / GraphQL で作成または照会) | create or verify with gh / GraphQL |
```

Never invent Project IDs, field IDs, option IDs, milestone node IDs, or label IDs.
Issue titles and bodies use the project language by default.
Keep label names, code identifiers, package names, API names, and GitHub field names in their canonical spelling.

## 4. Product-Derived Taxonomy

Start from this neutral taxonomy and specialize it from the product brief.

### Required Issue Types

| Type | Use when |
|------|----------|
| `infra` | provider config, environments, secrets, deploy, migrations, storage, queue, observability |
| `web/ui` | UI screens, interaction, styling, design system, accessibility |
| `core/domain` | domain model, business rules, data validation, core workflows |
| `integration` | external API, webhook, SDK, import/export, third-party service |
| `async/job/workflow` | queue, job, workflow, scheduler, long-running task, retry/DLQ |
| `ci/cd` | CI workflow, required checks, release, branch deploy, runner operations |
| `security` | auth, authorization, secrets, privacy, audit, dependency/security policy |
| `docs` | docs, ADRs, runbooks, harness docs, public docs projection |

### Optional Cross-Cutting Labels

Use only when useful for the target repo.

- `kind:feature`
- `kind:bug`
- `kind:research`
- `kind:refactor`
- `harness:feature-flow`
- `harness:infra`
- `harness:harness`
- `harness:docs-only`
- `harness:research`

### Priority

| Priority | Meaning |
|----------|---------|
| `priority:critical` | launch blocker, security incident, data loss, production outage |
| `priority:high` | default for near-term roadmap work |
| `priority:medium` | useful but not on the immediate critical path |
| `priority:low` | cleanup, nice-to-have, low blast radius |

### Components

Derive component labels from product architecture:

| Architecture surface | Example labels |
|----------------------|----------------|
| Web app | `component:web`, `component:admin` |
| API | `component:api` |
| Database | `component:db` |
| Worker/job/queue | `component:jobs`, `component:worker` |
| Workflow | `component:workflow` |
| SDK/client | `component:sdk` |
| Infra/deploy | `component:infra` |
| Docs | `component:docs` |
| Cross-cutting | `component:shared` |

Do not copy this repository's domain-specific labels unless the target product actually has the same architecture.

## 5. Milestone Model

Generate milestones from the product roadmap captured at Intake (the background section of the PR body).
Use neutral phases unless the user provides named phases.

| Milestone | Typical scope |
|-----------|---------------|
| `P0: Bootstrap` | repo, harness, local dev, CI, first deploy path |
| `P1: Foundation` | auth, data model, infra, observability, shared packages |
| `P2: Core Workflow` | first end-to-end user value path |
| `P3: Admin / Operations` | admin tools, support, audit, internal ops |
| `P4: Hardening` | test depth, security, performance, reliability, docs |
| `P5: Launch` | staging/production readiness, rollout, rollback, monitoring |

If the product has regulatory or customer milestones, replace these with the user's names and preserve the same entry/exit criteria structure.

## 6. Project Model

Project board の作成・変更は自律実行してよい（人間承認が必要なのは課金が発生する操作と秘密値の挿入・変更のみ）。
作成・変更後は実値を読み戻して検証し、magic value を profile に記録する。

Default boards:

| Project | Purpose | Typical issues |
|---------|---------|----------------|
| Product | Product behavior and user-facing implementation | features, bugs, docs, SDK |
| Platform / Harness | CI, deploy, environment, agent harness, dependency automation | infra, harness, sync workflows |
| Security / Compliance | Optional board for regulated products | security, audit, privacy, incident follow-up |

Default fields:

| Field | Type | Required |
|-------|------|----------|
| Status | single-select: Todo / In Progress / In Review / Done | Yes |
| Priority | single-select or label mirror | Recommended |
| Target date or Expired date | date | Recommended if team plans by dates |
| Milestone | native GitHub milestone | Recommended |
| Component | label or single-select | Recommended |
| Owner | assignee or person field | Optional |

Record the final IDs in `.claude/skills/create-issue/references/project-fields.md`.

## 7. Approval Model

既定は自律実行とする。remote GitHub mutation のうち次は承認なしに実行してよい:

- label / milestone / Project board / Project fields・options の作成・編集
- issue / PR の作成、issue の Project への追加
- dates / status / relationships の設定
- 技術判断変更に伴う既存 issue への comment

人間の明示承認が必須なのは次の 2 つのみ:

- 課金が発生する操作（有償リソースの作成、プラン変更、外部サービス契約）
- 秘密値の挿入・変更（credential / API key / token を設定へ投入する操作）

自律実行した mutation は判断材料を成果物に残す:

- 採用した labels / milestones / Projects / fields とその理由（PR 本文）
- 実行した commands / API operations と読み戻し検証の結果
- sample generated issue

成果物とレポートは project language で書く（ユーザが明示的に別言語を指定した場合を除く）。
実行できなかった remote setup は、GitHub Issue の残タスクとして起票する。

## 8. 実行系 routine のレシピ（資産として収録しないもの）

次の 3 つは、routine として定期に実行する実行系の skill のレシピである。資産としては収録しない。
対応する surface（Issue を実装キューに使うか、監視基盤を持つか、棚卸しが要る規模か）が導入先ごとに異なり、profile 駆動の骨格だけを収録しても、profile が埋まるまで何も実行されないためである。
需要が出た導入先が、§2 の 10 項目契約と §8.1 の共通前提に従い、`docs/harness/skills/<name>.md` として追加設計する。追加時は、正本と adapter の 1:1、MANIFEST と OPERATING_MODEL の skill 一覧を同一 PR で更新する。

### 8.1 共通前提

- 無人 run の契約: 起動プロンプトの冒頭 1 行で `docs/harness/skills/shared/unattended-contract.md` を読ませる。人間へ渡すのは、承認必須 2 種（課金・秘密値）と、`docs/harness/OPERATING_MODEL.md` の「人間引き渡し境界」に定めた区分に限る。
- routine の登録: `docs/harness/scheduled-operations.md` の起動プロンプトの正準形と登録チェックリストに従う。
- routine ラベル: 作った PR / Issue に `routine:<skill-name>` を、起動経路を問わず付ける（付与の手順は `docs/harness/skills/shared/sync-pr-flow.md`、ラベルの一覧は `.claude/skills/create-issue/references/project-fields.md`）。
- 照会: `docs/harness/skills/shared/gh-query-fail-closed.md` に従う。0 件を「対象なし」と取り違えないよう、疎通 canary を通してから候補を数える。
- 1 run の上限: 人間のレビュー負荷から決める。上限を超える候補は次回に回す。
- 判断: 解決策は 1 案に確定し、受入条件は確定事項で書く（`docs/styles/team-feedback/single-solution.md`）。

起票系のレシピ（8.3 と 8.4）は、重複起票を防ぐために次の最小機構を持つ。

| 項目 | 規約 |
|------|------|
| 候補 ID | 日付・行番号・run 固有の値を含まない決定的な文字列。対象の識別子から作り、日をまたいで同じ対象には同じ ID になる |
| マーカー | 起票する Issue 本文の末尾に機械可読ブロックとして候補 ID を置く（例 `<!-- <skill-name>:candidate-ids: <id>, ... -->`）。`create-issue` は呼び出し元が指定した末尾マーカーを改変せず、読み戻しで保持を確認する |
| 突合 | 起票の前に open Issue を全件取得し、ローカルでマーカーを突合する。既存なら起票しない。取得に失敗したら起票しない（fail-closed） |
| 検証 | 起票の後に Issue を読み戻し、マーカーが保持されていることを確認する |

### 8.2 実装キュー

open Issue を優先順に選び、`/multi-issue` に渡して Issue ごとに PR を作る。
前提は、GitHub Issues を issue tracker とすること、`/multi-issue` が無人 run で待たずに PR の open まで進んで返ること（`/review-cycle` を run の中で起動しない。待機が run を止めるため）である。

| 段 | 内容 |
|----|------|
| 候補収集 | open Issue を全件取得し（canary 付き）、ローカルで絞り込む |
| 除外 | 除外ラベル（既定は `question` / `wontfix` / `duplicate` / `invalid` / `refactor:proposal`。導入先が追加する）、open PR に紐づく Issue（PR 本文の closing keyword・`関連:`・出所マーカー・作業ブランチ名の 4 経路で判定）、試行マーカーの除外期間内の Issue |
| 優先順位 | 層（既定は `bug` ラベルのみ。優先 milestone は導入先が任意に定義する）→ `priority:*` ラベル → 作成日の古い順 |
| 一次判定 | 受入条件が origin/main ですべて満たされている Issue は、受入条件ごとの根拠（commit / PR / ファイルと行）を書いて close する。条件は、受入条件ごとの根拠がある、reopen 履歴がない、照会に成功している、の 3 つ。前提の Issue が open なら deferred にして着手しない |
| 着手状態の記録 | Issue コメントの先頭行に機械可読マーカーを書き、状態を持つ（下表）。claim を書いた直後に読み直し、先着（comment id が最小）でなければ自分の claim を deferred に書き換えて引く。同じ状態・理由ならコメントを重ねず書き換える |
| 実行 | 選定した Issue を `/multi-issue` に渡す。PR 本文の先頭に出所マーカーを置く |
| 上限 | `/multi-issue` の in-flight 上限（既定 3）を参照し、二重管理しない |
| 報告 | 選定と除外の理由、close した Issue と根拠、deferred / failed / needs-human の Issue を完了報告に残す |

| 状態 | 意味 | 除外期間 |
|------|------|----------|
| claimed | 着手中 | 導入先が決める（初期値の例は 1 日） |
| pr | PR 作成済み | PR が open の間 |
| deferred | 待ち相手が open の間は着手しない | 待ち相手が close するまで（上限は導入先が決める） |
| failed | 着手して失敗した | 導入先が決める（初期値の例は 1 週間） |
| needs-human | 受入条件の残りが課金操作または秘密値の投入を必須とし、実装・script・CI で代替できない | 人間が解消するまで |

状態は Issue コメントに持つ。無人 run は state ファイルを持てず、GitHub 上に永続化できるのがコメントだけだからである。
最小構成から始める。claimed と pr の 2 状態、除外は open PR との紐づきのみで運用を開始し、deferred・failed・needs-human と一次判定は、必要になってから足す。複数の routine や複数のアカウントが同じ Issue を選び得る運用でなければ、claim の排他は要らない。

### 8.3 コードと docs の棚卸し

参照が 0 件になったコードと文書を検出し、確定した処置つきの Issue として起票する。編集はしない。1 run で起票するのは最大 1 件である。
`/refactor-sync`（参照は残るコードの課題）、`/gc-scan`（ハーネス文書）、`/docs-sync`（行レベルの鮮度）と対象が重ならないよう、責務分界表を skill 正本に置く。

| 項目 | 内容 |
|------|------|
| スコープ | 候補にするパス（既定は `apps/**`・`packages/**`・`docs/**`）と、参照元を探す範囲（常にリポジトリ全体）を分けて持つ。候補から除外するもの: 生成物、migration 履歴、submodule・vendor、依存とビルド成果物、ハーネス文書（`/gc-scan` の担当） |
| コードの検出 | 未参照ファイル、未使用 export、静的に到達不能な分岐。エントリポイント（package scripts・CI workflow・hooks・IaC などが起動するハンドラや script）は毎回 origin/main から導出し、そこから参照グラフを辿る |
| docs の検出 | どこからもリンクされない文書、主題の実体が消えた文書、廃止を表明した文書、同じ読者向けに重複する手順書、実装と乖離した手順書 |
| 反証パス | 全候補を誤検知レジストリと突合し、反証に残った高確度の候補だけを起票する。判定が割れる候補は見送り、次回に再評価する |
| 候補 ID | 種別（dead-file / dead-export / dead-branch / dead-doc / dup-doc / stale-doc）とパスの slug から作る。dead-branch は行番号ではなく囲むシンボル名を使う |
| 受入条件 | 確定した処置で書く。実装側が反証検証を再実行し、削除・統合・書き直し・許容表明のいずれかを根拠付きで確定する |

誤検知レジストリの初期値（導入先が profile に追記し、エントリポイント・外部公開面・許容リストは TODO 記法で記入する）:

| パターン | 扱い |
|----------|------|
| 動的 import・reflection | 実参照とみなす |
| 設定・CI・scripts からの参照 | 実参照とみなす |
| 外部公開面（package exports の閉包、公開 API、外部から呼ばれる関数、生成型） | 除去の対象外 |
| テスト専用の helper | 参照元のテストが存在する間は対象外 |
| 実行時の分岐に依存する参照 | 静的に判定できないため対象外 |
| 追加直後のコード・文書 | 猶予期間（導入先が日数を決める）の間は対象外 |
| 許容表明（対象に付ける明示マーカー） | 対象外 |
| 型だけの export、値の型導出の正本 | 対象外 |
| source 本文を文字列として解析するテスト・script | 実参照とみなす |

言語に依存する検出（import 構文など）は、採用する言語の import / require 相当に読み替える。小規模な導入先では、言語固有の専用ツールを使う判断も妥当である。

### 8.4 日次観測点検

監視基盤から事実を取り、新規の問題だけを、受入条件が確定した Issue にする。
前提は、監視基盤を採用していること、routine の実行環境から読み取りツールが使えること、の 2 つである。provider は profile で駆動し、本文には観点の定義と不変条件だけを書く。profile が TODO のままなら「点検できなかった」と報告して終了し、「異常なし」とは報告しない。

| # | 観点 | 備考 |
|---|------|------|
| 1 | 発火中のアラート定義 | 通知の有無に頼らず、発火の一覧を直接引く |
| 2 | セキュリティ検知 | 検知基盤がある場合のみ。profile で有効化する |
| 3 | エラー追跡の新規・急増 | |
| 4 | ログのエラー傾向 | 目安は直近 24 時間が 7 日平均の 2 倍超。profile の既定値として置く |
| 5 | 主要メトリクスの閾値接近 | 目安は閾値の 80% 超を 1 時間以上持続。閾値の正本は監視定義側にあり、本文へ写さない |
| 6 | 基盤の異常検知機能 | 提供される場合のみ |
| 7 | 沈黙 | 取り込み経路ごとに最低 1 本の欠落検知を置き、途絶えていないか確認する |

不変条件:

- 前提検査（読み取りツールの疎通と権限）に失敗したら fail-closed とする。観点ごとに取得できなかったものは「点検できなかった」と報告し、「異常なし」を作らない。
- 通知が無いことは正常を意味しない。配信先を持たない環境があり得るため、通知経路の実態を profile に記入させ、発火の一覧を直接引く。
- 候補 ID は `obs:<env>:<観点>:<key>` の形にし、日付を含めない。起票は §8.1 の重複起票防止に従う。
- 所見 1 件につき Issue 1 件とする。後段の実装 routine が Issue 単位で PR にするため。
- 意図の確認を受入条件にしない。run が持つ手段で根拠を集めて結論を書き、集まらなければ、次回に機械判別できる記録の実装を受入条件にする。

profile（TODO 記法）に記入させる項目: 監視 provider の読み取りツール名と観点ごとのクエリ、環境の一覧、閾値の正本の場所、heartbeat の一覧、通知経路の実態、label と milestone の対応。
発火を起点とする一次対応の skill を別に持つ場合は、候補 ID の名前空間を共有して二重起票を防ぐ。
