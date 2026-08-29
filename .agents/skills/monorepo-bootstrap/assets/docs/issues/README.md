# Issue Artifacts

> この文書は `docs/issues/` 配下の Issue 単位成果物の運用規約（ディレクトリ規約・task-note 運用・アーカイブポリシー）の正本である。
> task-note の記入項目自体は [`templates/task-note.md`](./templates/task-note.md) に委譲し、ここには書かない。

**Issue 番号を持つ対応は、どのフローで着手しても本ディレクトリに成果物を残す**
（`/multi-issue` に加え、Skill を経由しないメインエージェント判断も対象）。
Issue ごとにディレクトリを作成し、全成果物を集約する。

## ディレクトリ構成

```
docs/issues/
  ├── README.md                          # 本ファイル
  ├── templates/
  │     ├── task-note.md                 # 計画・記録テンプレート
  │     └── traceability.md              # カバレッジレポートテンプレート（opt-in:traceability）
  └── <number>_<scope>/                  # Issue 単位のディレクトリ（$ISSUE_DIR）
        ├── task-note.md                 # 計画・記録（全フロー共通で実体化する）
        ├── traceability-matrix.yaml     # AC ↔ テスト対応 matrix（opt-in:traceability・テスト追加時）
        └── traceability.md              # カバレッジレポート（opt-in:traceability・テスト追加時）
```

例: `docs/issues/42_api-key-rotation/`

## ワークフロー

### /multi-issue（実装 Issue）

```
Planner（計画・wave 分割） → worker（worktree 隔離で TDD 実装） → 簡素化パス → コードレビュー → PR → レビュー対応
```

worker が issue ごとに `$ISSUE_DIR/task-note.md` を実体化する。詳細 → `docs/harness/skills/multi-issue.md`

### メインエージェント判断（バグ修正・リファクタ・小規模変更）

```
task-note.md 作成 → 実装 → task-note.md の検証結果を確定 → PR
```

実装 Issue に該当しない対応は、`$ISSUE_DIR/task-note.md` 1 本に背景・原因・方針・スコープ・検証を集約する。

- **着手時**: §0〜§4 / §5.1 / §6 / §7 を記入
- **完了時**: §5.2〜§5.4（検証結果 / traceability 成果物 / リファクタパス）と §8（PR / ADR リンク）を確定

検証コマンドの定義は `docs/harness/skills/shared/verification-gates.md` が正本。
PR を出す前の簡素化パスは `docs/styles/team-feedback/refactor-before-pr.md`、
スコープ外の指摘の扱いは `docs/styles/team-feedback/scope-boundary.md` が正本。

`#<issue> 対応して` の直接指示など Skill を経由しない対応でも task-note の実体化を省略しない。

### traceability 成果物（opt-in:traceability 採用時のみ）

テストを追加・変更した場合は同一 PR で `$ISSUE_DIR/traceability-matrix.yaml` と `traceability.md` も更新する。
opt-in:traceability を採用しない場合、この節は適用しない（テスト方針・結果は task-note §5 に記録する）。

## テンプレート

- Task Note: [`templates/task-note.md`](./templates/task-note.md)
- Traceability: [`templates/traceability.md`](./templates/traceability.md)（opt-in:traceability）

## アーカイブポリシー（in-place スタブ化／要約圧縮）

完了 Issue の成果物は容量・grep ノイズ削減のため **ファイルを移動せず同一パスのまま**圧縮する。

- **退避トリガ**: 起票元 Issue が close 済み **かつ** 当該成果物への issues/ 外からの durable 参照（特に `§` アンカー付き）が無い、の AND 条件。時間ベースの自動退避はしない。
- **レイヤ**:
  - **保全（不可侵）**: durable 参照に指される `task-note.md` は本文・見出しを保持する。
  - **要約圧縮（lossy）**: durable 参照の無い大型 `task-note.md` は US/AC 一覧・設計判断（D-ID）・Related を保持し、コード断片・実装概要図解・作業ラウンド履歴・自己検証ログを除去する。
  - **in-place スタブ化（lossless）**: 中間レポート等のプロセス成果物は H1・メタ・概要・主要 Related を残し、本文を git 履歴へ退避する。
  - **保留（不可侵）**: `traceability.md` / `traceability-matrix.yaml`（opt-in:traceability 採用時）は網羅測定の入力データであるため、測定運用が確立するまでスタブ化しない。
- **リンク保全**: ファイルパスは不変。要約時も durable 参照のアンカー先見出しは削除しない。
- **ロールバック**: ファイル移動が無いため、適用 PR の revert または `git show <rev>:<path> > <path>` で原状復帰する。圧縮前の本文は git 履歴が正本。

## 参照

- multi-issue オーケストレーション: `docs/harness/skills/multi-issue.md`
- 検証ゲート定義: `docs/harness/skills/shared/verification-gates.md`
- 要件 INDEX: `docs/requirements/INDEX.md`
