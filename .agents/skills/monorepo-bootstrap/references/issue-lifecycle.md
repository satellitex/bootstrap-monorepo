# Issue Lifecycle Reference

この文書は、`monorepo-bootstrap` が issue 単位の粒度・taxonomy・lifecycle・承認要否を bootstrap 先に設計するときの参照である。
Issue ごとの成果物ファイルは持たない。計画と検証結果は PR 本文の標準節、設計判断は ADR、残タスクは GitHub Issue に置く。
標準節の定義は `../assets/docs/harness/skills/shared/pr-creation.md`、資産の台帳は `../assets/MANIFEST.md` が正本であり、ここには複製しない。
目標は、すべての issue を 1 回の実装 session で完了できる大きさに保ちつつ、判断の履歴と承認モデルを維持することである。

## 1. Where Things Live

| 内容 | 置き場 | 備考 |
|------|--------|------|
| 問題・scope・受入条件・依存 | GitHub Issue 本文 | 受入条件はリポジトリ内で満たせる確定事項で書く。「A か B かを選ぶ」を受入条件にしない（`docs/styles/team-feedback/single-solution.md`） |
| 実装計画 | 実装を担う worker のプロンプトと PR 本文の「方針と却下案」 | Issue 専用の計画ファイルは作らない |
| 方針と却下案・スコープ外・リスク | PR 本文の標準節 | 標準節の定義は `../assets/docs/harness/skills/shared/pr-creation.md`「PR 本文の標準節」 |
| 検証結果 | PR 本文の「検証結果」 | 実行した検証ゲートの名前と結果、未検証の範囲 |
| 設計判断 | ADR（`docs/adr/`） | 起票基準は §5。PR 本文から ADR へリンクする |
| 残タスク・スコープ外の追跡 | GitHub Issue | PR 本文の「スコープ外」に Issue 番号を書く |
| レビュー指摘への対応 | PR コメントの返信 | 設計方針が変わる指摘だけ ADR にする |

Issue の大きさによって置き場は変わらない。大きすぎる Issue は、置き場を増やさずに Issue を分ける（§7）。

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

ラベル名は導入先の規約に合わせてよい。
canonical な製品用語、package 名、API 名、GitHub の field 名は原文のまま書く。

## 3. Lifecycle

| Phase | 出力 | Gate |
|-------|------|------|
| Inception | Issue 本文（問題・scope・受入条件・制約・依存） | Issue 本文が既に具体的なら不要 |
| Plan | worker プロンプトの計画と PR 本文の「方針と却下案」 | 既定で人間 gate なし。未確定点は 1 案に確定して書く |
| Construction | コード・docs の diff と commit。計画からの逸脱は PR 本文へ追記 | scope を増やす場合は Issue を分ける |
| Verification | PR 本文の「検証結果」（検証ゲート、CI、deploy / smoke、未検証の範囲） | レビュー依頼の前に必須 |
| Review | PR コメントへの対応。設計方針が変わるものは ADR | 非自明な変更で必須 |

実装方針が未確定でも作業を止めない。
既存 docs、一次情報、保守的な既定の順に調べて 1 案に確定し、却下した案と理由を PR 本文の「方針と却下案」に残して、open PR まで自律続行する。
PR は通常 PR で open する。draft にしない規則と、経路ごとの指定は `docs/harness/skills/shared/pr-creation.md` の「draft にしない」が正本である。

## 4. Approval Rules

承認モデル（既定の自律実行、人間の明示承認が必須な操作、ブランチモデル）は `../assets/docs/harness/OPERATING_MODEL.md`「承認モデル」が正本であり、ここには複製しない。導入先が人間へ引き渡す範疇を持つ場合は、同書の「人間引き渡し境界」に記入する。

次の条件に当たる issue は承認の対象ではないが、判断材料を PR 本文（設計判断は ADR）に残して提示する:

- technology choice is unsettled
- provider/runtime/database/storage/queue/auth/observability selection may change
- security, privacy, auth, or tenant boundary changes
- app topology or package boundaries change
- implementation spans multiple deploy/scaling units
- long-running or async workflow durability is not yet designed
- issue has unclear acceptance criteria

## 5. ADR Triggers

起票基準の正本は `../assets/docs/adr/README.md` の「いつ書くか」である（複数の選択肢を比較して決定したとき、既存の方針を撤回・置換するとき、レビュー指摘への対応で設計方針が変わったとき）。
次の領域の決定は、複数案の比較を伴う場合に ADR になる。技術選定は 1 領域 1 ADR とし、代替案と棄却理由を含める。

- cross-cutting across apps/packages/services
- hard to reverse
- likely to affect future issue planning
- tied to provider/runtime/database/storage/queue/auth/observability
- tied to CSS/UI styling strategy or design system
- tied to CI/CD provider, branch deploy, or runner operations
- tied to public API contracts, data retention, compliance, or security boundaries

1 つの issue に閉じ、元に戻しやすい局所的な実装判断は ADR にせず、PR 本文の「方針と却下案」に書く。

## 6. Remote GitHub Mutation

GitHub labels / milestones / Projects / fields / issues / issue relationships の作成・変更は自律実行してよい（§4）。

自律実行した mutation は、判断材料と結果を PR 本文に残す:

- adopted labels and descriptions
- milestones with entry/exit criteria
- Projects and fields
- sample issue body
- 実行した commands / API operations と読み戻し検証の結果

実行できなかった remote setup は、GitHub Issue として残タスクに起票する。

## 7. Issue Size

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

技術判断の変更が既存 issue に影響する場合は、影響を受ける GitHub issue へ自律的に comment または更新する。
