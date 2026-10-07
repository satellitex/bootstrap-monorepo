# 実装フローの切替

> この文書は team-shared rule の 1 つ。Issue の実装フローを選ぶ判定と、メインエージェント判断フローの標準手順のみを定める。各フローの手順本文は `docs/harness/skills/multi-issue.md` と `docs/harness/skills/shared/` に書く。

Issue の実装フローは 2 つに集約する。実装 Issue（新規機能・仕様変更・ハーネス整備・環境整備など、複数ファイルにまたがる変更）は `/multi-issue`、それ以外（バグ修正・リファクタ・小規模変更）は skill を経由せず、メインエージェントが自律的に実装する。

## 判定

`#<issue> 対応して` のように Issue 番号で直接指示された場合も、本順序で判定する（直接指示時のトリアージの正本）。即座に skill を起動せず、Issue を読んでから振り分ける（照会規約 → `docs/harness/skills/shared/gh-query-fail-closed.md`）。ユーザーが `/multi-issue` を明示的に呼んだ場合は、判定を経ずに当該 skill に従う。

上から評価し、最初に当てはまったものを採用する。

| 順  | Issue の性質                                                 | フロー                                                                           |
| --- | ------------------------------------------------------------ | -------------------------------------------------------------------------------- |
| 1   | 実装 Issue（新規機能・仕様変更・ハーネス整備・環境整備など） | `/multi-issue`（単一 Issue でも可。複数 Issue はまとめて渡すと並列で実装される） |
| 2   | 上記以外（バグ修正・リファクタ・小規模変更・緊急修正）       | メインエージェント判断                                                           |

- 判定の単位は Issue 全体の性質である。実装 Issue に軽微な修正が混在していても、Issue 全体が実装系なら `/multi-issue` に渡す
- 緊急修正も専用フローを持たず、バグ修正と同じくメインエージェント判断で扱う
- ラベルは補助情報であり、判定は Issue の性質で行う。導入先の label 体系との対応表を持つ場合は `.claude/skills/create-issue/references/project-fields.md` に追記する
- `refactor:approved` の Issue（着手指示済み）の実装はメインエージェント判断で行う。[refactoring_guide](../refactoring_guide.md) の承認済み観点を読み、既存テストの全 PASS を維持しながら、全対象箇所へ順次適用する

## メインエージェント判断の標準手順

1. **計画を立てる** — 調査で把握した方針と変更対象から手順を導出し、タスク管理ツールで列挙して、進行に従い更新する
2. **TDD を可能な範囲で適用する** — バグ修正は再現テストを先に書く。リファクタは既存テストがすべて通ることの確認から始める
3. **コーディング規約に従う** — [coding_guide/INDEX.md](../coding_guide/INDEX.md)
4. **テストの追加・変更に合わせて対応表を更新する** — opt-in:traceability 採用時のみ
5. **設計判断が出たら ADR に記録する** — `/create-adr`
6. **PR 前に簡素化パスを 1 回入れる** — [refactor-before-pr](./refactor-before-pr.md)
7. **PR を作成する** — `docs/harness/skills/shared/pr-creation.md`。計画・判断根拠・検証結果は PR 本文の標準節と commit メッセージに残す
8. **検証ゲートがすべて通ったことを確認してから push する** — `docs/harness/skills/shared/verification-gates.md`

手順の本文は各リンク先が正本であり、本書には再記述しない。

## Why

- `/multi-issue`: Planner–Worker のエージェントスウォームが worktree 隔離で TDD 実装し、簡素化・レビュー・PR 作成までを内包する。実装 Issue をこの 1 フローに集約すると、フロー選択の認知負荷と、複数フローの保守コストを抑えられる
- メインエージェント判断: バグ修正・リファクタ・小規模変更は、既存コードを読んで原因と影響を直接把握する方が速い。skill 化したフローを通すと、認知負荷とセッション時間が増える

判断根拠は PR 本文・commit メッセージ・（設計判断が生じた場合の）ADR に残す。

## 関連

- `docs/harness/skills/multi-issue.md` — 実装 Issue のフロー正本
- [refactor-before-pr](./refactor-before-pr.md) — PR 前の簡素化パス（標準手順 6）
- [single-solution](./single-solution.md) — 判断は 1 案に確定して書く
- `docs/harness/skills/shared/pr-creation.md` — PR 作成共通手順
- `docs/harness/skills/shared/verification-gates.md` — 検証ゲート定義
