# multi-issue — Planner–Worker 並列実装

この文書は `/multi-issue` の tool-neutral な正本手順である。検証ゲートのコマンド定義（`docs/harness/skills/shared/verification-gates.md`）と PR 作成規約（`docs/harness/skills/shared/pr-creation.md`）はここに複製しない。

## 目的

複数の GitHub Issue を受け取り、Planner–Worker 分離のエージェントスウォームで並列実装し、**issue ごとに 1 本の PR** を作成するオーケストレーションフロー。

> 設計原則: 高能力モデルは分解・設計判断・検収のみに使い、実装は安価なモデルへ委譲する。Planner は実装に潜らないため、コンテキストを計画・競合裁定・検収に最後まで温存できる。

## 承認モデル（要旨）

既定は自律実行とする。計画の提示は報告のみで承認を待たず、実装から open PR の提出までを自律的に行う。PR のマージは人間の操作だが、明示的に指示された場合はマージまで行ってよい。人間の明示承認が必須なのは課金が発生する操作と秘密値の挿入・変更のみ（`docs/styles/team-feedback/autonomous-flow.md`）。

## 役割分担

| 役割 | 担当 | モデル |
|------|------|--------|
| Planner: issue 読解・スコープ検査・wave 分割・実装計画・検収・仕上げ・PR 作成 | オーケストレーター（本セッション） | **上位モデル**（Step 0 で確認） |
| Sub-planner: Planner が複雑と判断した issue の詳細計画 | subagent | 上位モデル |
| Worker: 実装（worktree 隔離・TDD） | subagent | **実装モデル**（安価なモデル） |
| マージ | 人間（merge が完了シグナル） | — |

## PJ 固有の追加検証ゲート（placeholder）

通常の検証ゲート（`docs/harness/skills/shared/verification-gates.md`）で検証が完結しない領域を持つ PJ は、bootstrap 時にここへ profile 的に追加ゲートを定義する。例:

- `<special-area-path>/**` を変更した worker には `<additional-language-check>` の全 PASS を追加で課す
- dev 環境が必要な実走検証は本フローでは実行せず、委譲先の運用フロー（`/deploy-verify` 等）を PR body の Test plan に明記する

Planner は issue ごとに**任意の凍結パス**を計画で指定できる（触るべきでない隣接領域の保護）。指定した場合、worker へのプロンプト明示に加え、検収（3.3）で `git diff --name-only` により機械検証する。

## フロー

```
/multi-issue #A #B [#C ...]
  ├── Step 0: セットアップ（モデル確認 / fetch / タスクリスト）
  ├── Step 1: Planner — issue 読解・着手可否検査・wave 分割・実装計画
  │           （複雑 issue は sub-planner へ委譲）
  ├── Step 2: 方針確定・提示（承認ゲートなし・待たずに続行）
  ├── Step 3: 実装ループ（wave 単位: worktree → worker → 検収）
  ├── Step 4: 仕上げ（issue ごと: /simplify → /code-review → Architecture Sync → PR 作成）
  └── Step 5: /review-cycle（open PR 群へ round-robin）→ 完了報告
```

## Step 0: セットアップ

1. **モデル確認**: 現在のセッションモデルが上位モデル（Planner 適格クラス）でない場合は警告し、モデル変更後の再実行を提案する（根拠は冒頭の設計原則）。ユーザーが続行を選んだ場合のみ進む。
2. `git fetch origin main` し、セッションブランチを `agent/multi-issue-YYYY-MM-DD` に整える（同日重複は `-2`。オーケストレーター自身はコードを変更しない。成果物はすべて各 issue の worktree 側に置く）。
3. タスク管理ツール（TodoWrite 等）で issue 単位のタスクリストを作成する。

## Step 1: Planner（計画）

1. 各 issue を `gh issue view <N> --json title,body,labels` で読む（相互に独立なので並列に読んでよい。`--repo` に owner を直書きしない → `docs/harness/skills/shared/gh-query-fail-closed.md`）。
2. **着手可否の検査**: 外部依存待ち・前提 issue 未解決等で着手不能な issue を対象外候補にする。
3. **競合分析と wave 分割**: 相互に独立な issue は同一 wave で並列。同一ファイル群に触れる issue は直列とし、**後続は前 issue のブランチ起点で worktree を積み上げる**のを既定とする（PR base を前 PR ブランチにし、前 PR のマージ後に main へ retarget）。前 PR がレビューで大きく変わる見込みのときのみマージ待ちにする（マージは人間操作でレイテンシが大きく、in-flight 枠を空転させるため）。in-flight（実装中 + レビュー待ち PR）上限は既定 3（Step 2 で確定）。
4. **issue ごとの実装計画**を作成する: 対象ファイル・受入条件の分解・テスト方針・検証ゲート・issue 固有の凍結パス。`docs/issues/templates/task-note.md` の構造に沿って書き、worker prompt に埋め込む。worker が `docs/issues/<N>_<scope>/task-note.md` として実体化・コミットする。
5. **Sub-planner への委譲**: 設計判断（ADR 級）・大型構造変更・影響範囲を読み切れない issue は、上位モデルの subagent（バックグラウンド実行）に詳細計画の作成を委譲する。複数 issue を委譲する場合は並列に起動し、返り次第レビューして統合する。Planner は返ってきた計画を受入条件と突き合わせて採否を判断し、コードの実装詳細には潜らない。

## Step 2: 方針の確定と提示（承認ゲートなし）

Planner は以下を確定してユーザーへ**報告のみ**行い、入力を待たずに Step 3 へ進む:

- 対象 issue 一覧と wave 分割・直列化（積み上げ or マージ待ち）の根拠
- 対象外とする issue（外部依存待ち等）とその根拠
- in-flight 上限（既定 3。人間レビュー負荷に直結）

以降も自律実行し、停止してよいのは人間の merge 待ちと、承認モデルで人間承認必須と定めた操作（課金・秘密値）のみ。実行中にユーザーから訂正が入った場合は方針へ反映して継続する。

## Step 3: 実装ループ（wave 単位）

### 3.1 worktree 準備

subagent 実行環境の worktree 自動作成が不調な場合に備え、自前で worktree を作成しパスを worker のプロンプトで明示する:

```bash
git -C <main-repo> worktree add -b agent/issue-<N>-<slug> .claude/worktrees/issue-<N>-<slug> origin/main
```

直列 issue の積み上げ時は起点を前 issue のブランチにする。worker の初動を実装に使わせるため、wave 内の全 worktree で依存導入（`mise trust && pnpm install`）を並列に済ませてから worker を起動する。

### 3.2 worker 起動

下記「worker プロンプト骨格」に issue 固有情報と Step 1 の実装計画を埋め、実装モデルの subagent（バックグラウンド実行）として起動する。同時実行は Step 2 で確定した in-flight 上限まで。

**途中停止への対応**（完了通知の result が途中経過文・タイムアウト・権限エラーのとき）:

1. worktree の `git status` / `git log origin/main..HEAD` で進捗を確認する
2. プロンプト骨格を流用し、冒頭に「前任の進捗 + 残作業 + 前任の学び（エラー回避策）」を追加した再開プロンプトで新 worker を起動する（worktree は同じものを使う）
3. `.claude/` 配下への新規 Write が権限拒否される場合は worker に「ファイルパスと完全な内容を報告して停止」させ、Planner が代行する

### 3.3 検収（Planner）

worker の報告は鵜呑みにしない。worktree で以下を自ら検証する:

1. `git diff origin/main...HEAD` を読み、受入条件と突合する
2. 検証ゲート（`docs/harness/skills/shared/verification-gates.md` の全コマンド）の再実行または結果の裏取り。PJ 固有の追加ゲートを定義した issue はそれも裏取りする
3. 計画で凍結パスを指定した場合: `git diff --name-only` に当該パスが含まれないこと
4. `docs/issues/<N>_<scope>/task-note.md` と、トレーサビリティ運用を採用している PJ ではテスト追加時のカバレッジ成果物（`docs/issues/templates/traceability.md`）が揃っていること

不合格なら差し戻し内容を明記した再実装プロンプトで worker を再起動する。

## Step 4: 仕上げ（issue ごと・検収 PASS 後）

後続 wave の worker 実行とは独立なので、worker をバックグラウンドで走らせたまま並行して進めてよい。

1. **`/simplify`**: 当該 worktree の diff を対象にリファクタパスを 1 回入れる（振る舞い不変を確認して `refactor:` コミット。`docs/styles/team-feedback/refactor-before-pr.md` の充足）。実行環境に相当 skill が無い場合は `docs/styles/refactoring_guide.md` の検出観点による自己見直しで代替する
2. **`/code-review`**（最高エフォート）: 当該 worktree の diff をレビューし、CONFIRMED の指摘を修正する。issue scope 外の指摘は修正せず `/create-issue` で起票する（`docs/styles/team-feedback/scope-boundary.md`）。実行環境に相当 skill が無い場合は通常のセルフレビューで代替する
3. **Architecture Sync**: subagent として architecture-sync（`.claude/agents/architecture-sync.md`）を起動する。プロンプトに以下を必ず含める:
   - **当該 issue の worktree 絶対パス**と「全操作をそのパス配下で行う」指示。オーケストレーター自身のブランチには差分が無いため、パスを渡さないと同 Agent の `git diff origin/main...HEAD` が空になり、恒久的に no-op になる（worker 起動時と同じ落とし穴）
   - Handoff Summary（**対象ファイル・禁止事項・正本パスの 3 点のみ**）。task-note.md を丸ごと渡さない（同 Agent は計画成果物の全文 Read を既定で行わない設計）
   同 Agent は `.claude/` 配下を同期対象外にするため、ハーネスのみの diff では実質 no-op になり、毎回必ず README が変わるわけではない。公開射影区画（opt-in:public-site）を採用している PJ で同 Agent が `docs/product/ARCHITECTURE.md` を更新した場合は、`docs/harness/skills/public-arch-sync.md` の射影を同一 PR に含める。
4. push → `gh pr create`。PR body は `docs/harness/skills/shared/pr-creation.md` に従い **`Closes #<N>`** を注入する。dev 環境が必要な実走検証を残した issue は Test plan に委譲先（`/deploy-verify` 等）を明記する

## Step 5: /review-cycle と完了処理

1. PR は作成され次第 `/review-cycle`（`docs/harness/skills/review-cycle.md`）の対象に加える。open PR が複数ある間は 1 PR の LGTM まで直列で回さず、各イテレーション（CI 待機 → 未解決コメント確認 → `/handle-review`）を **open PR 群へ round-robin で適用する**（1 PR の CI・レビュー待ちの間に他 PR を先へ進める）
2. 完了報告: issue → PR 対応表 / 対象外とした issue と理由 / 起票した派生 issue / worker・sub-planner の起動回数と差し戻し回数
3. マージ済み issue の worktree を `git worktree remove` で後片付けする（未マージ分は残す）

## worker プロンプト骨格

worker へ渡すプロンプトは以下の骨格で組む。**太字の固定文言は事故防止の経験則なので削らない**:

```
あなたは本リポジトリの実装エージェント（worker）です。
GitHub Issue #<N> を Planner の実装計画に従って TDD で実装してください。

## 作業環境（最重要）
- 作業ディレクトリ: <worktree 絶対パス>。**全操作をこのパス配下で行うこと**
- 依存は導入済み。コマンドが依存不足で失敗する場合のみ再導入する

## Issue #<N>: <タイトル>
<issue 本文の引用（概要・受入条件）>

## 実装計画（Planner 作成）
<実装計画: 対象ファイル・受入条件の分解・テスト方針・検証ゲート>
- 受入条件と計画が矛盾する場合は issue 本文が正
- 計画の前提が実態と乖離している場合は、実態を計測してから着手し乖離を報告すること

## 凍結領域（計画で指定された場合のみ。無ければ本セクションを削る)
- <凍結パス>
- 変更が必要と判明したら、**変更せずに停止して理由を最終報告に書くこと**

## 実装手順（TDD）
1. docs/issues/<N>_<scope>/ を作成し、実装計画を docs/issues/templates/task-note.md の
   構造で task-note.md として実体化・コミットする
2. ユーザーストーリーを設計し、それに対応するテストのみを先に書いて Red を確認し
   `test:` コミット → 実装で Green にする（下記「テスト規約」）
3. テストを追加・変更したら、トレーサビリティ運用がある場合は同一ブランチで
   カバレッジ成果物を更新する

## 検証（必須ゲート）
- docs/harness/skills/shared/verification-gates.md の全コマンドを PASS させる
- <PJ 固有の追加ゲート（定義されている場合）>
- 凍結領域の指定がある場合: git diff --name-only origin/main...HEAD に当該パスが含まれないこと

## リポジトリ規約
- **push・PR 作成・issue 操作・外部通知は行わない**（オーケストレーターの役割）
- --no-verify 禁止

## 最終報告に必ず含める
- 変更ファイル一覧と定量サマリ / 受入条件ごとの充足状況（満たせなかったものは理由）
- 検証ゲートの実行結果（コマンドと結果）/ 計画からの逸脱・見送りと理由
- 未検証の範囲（無ければ「なし」）/ 判断に迷った点
```

## テスト規約（必須）

テストは「ユーザーストーリーの設計」→「それに対応するテストのみを作成」の順で書く。ユーザーストーリーに対応しない冗長なテスト、数合わせのテスト、実装詳細に密結合してすぐ形骸化するテストは書かない（SSOT: `docs/styles/coding_guide/testing_principles.md`）。この順序は worker の TDD 手順で必須とする。

## 制約・原則

- **1 issue = 1 PR = `Closes #<N>`**。複数 issue を 1 PR に束ねない
- **worker は push・PR 作成・issue 操作をしない**: `/simplify` → `/code-review`（実行環境に相当 skill が無い場合は `docs/styles/refactoring_guide.md` の検出観点による自己見直し / 通常のセルフレビュー）が PR 前に入る規約のため、PR 作成は仕上げ完了後に Planner が行う
- **Planner は実装しない**: 修正が必要なら worker への差し戻しが原則。例外は Step 4 の仕上げ（/simplify・/code-review の指摘修正・Architecture Sync による構造マップ同期）のみ
- 受入条件が実装時に不可能・陳腐化と判明した場合は、無理に満たさず根拠を issue にコメント記録して人間判断（merge）に委ねる
