# 開発スタイルガイド（人間向け）

この文書は人間の開発者向けに、AI エージェント主体の開発をどう回すかを説明する手順書である。エージェント向けの規約・手順の正本は `docs/harness/OPERATING_MODEL.md` と `docs/harness/skills/` に置き、ここには人間から見た使い方だけを書く。

## 前提

- **AI エージェントが実装の主力**であり、人間はレビュー・方向付け・要件定義に集中する
- 要件定義・設計判断の最終権限は人間にある
- エージェントは既定で自律実行し、open PR の提出までを人間の承認なしで進める

## 承認が必要な操作

承認が必要な操作の範囲と、branch ごとの扱いは `docs/harness/OPERATING_MODEL.md`「承認モデル」が定める。人間の通常の関与は、PR のレビューとマージである。

## 実装フロー

```
人間: Issue 起票・指示 ───────────────→ PR レビュー → マージ
  AI: Issue 取得 → TDD（テスト → 実装）→ 検証ゲート → open PR（標準節で計画・判断・検証結果を記録）→ レビュー対応
```

1. **Issue 起点** — `/create-issue` で起票するか、既存 Issue の番号をエージェントに伝える。実装フローの振り分けと標準手順は `docs/styles/team-feedback/implementation-flow-switch.md` に従う
2. **TDD** — テストはユーザーストーリーの設計から書く（→ `docs/styles/coding_guide/testing_principles.md`「第一原則: ユーザーストーリー起点」。テストレベルと網羅基準 → `docs/product/TEST_STRATEGY.md`）
3. **open PR** — 検証ゲート（`gate:commit`。定義 → `docs/harness/skills/shared/verification-gates.md`）を通し、PR 前に簡素化パスを 1 回入れてから提出する。計画・判断・検証結果は PR 本文の標準節と commit に残し、設計判断は `/create-adr` で ADR に残す（標準節と PR の作り方 → `docs/harness/skills/shared/pr-creation.md`「PR 本文の標準節」）
4. **レビュー対応** — レビューコメントが付いたら `/handle-review`（批判的評価と自律修正）、LGTM まで見届けさせるなら `/review-cycle`
5. **マージ** — 人間が diff を確認してマージする（PR body の `Closes #N` で Issue が自動 close）

PR 本文は、レビュー時に判断の経緯を確認する唯一の置き場になる。標準節に方針と却下案、検証結果、残るリスクが書かれているかを見る。

## よく使う slash コマンド

| コマンド                 | 用途                                                         |
| ------------------------ | ------------------------------------------------------------ |
| `/multi-issue #N ...`    | 実装 Issue を並列実装し issue ごとに PR を作成               |
| `/create-issue`          | GitHub Issue を作成（Label・Project 等を自動設定）           |
| `/create-adr`            | 設計判断を ADR として記録                                    |
| `/handle-review`         | PR レビューコメントを批判的に評価し自律対応                  |
| `/review-cycle`          | LGTM まで自律対応（レビュー・conflict・CI 修正）し完了を通知 |
| `/refactor-sync`         | リファクタ観点を検出し、提案 Issue を起票                    |
| `/runbook-alignment`     | 手順書の未確定事項を実装と照合し、差異評価表を PR 本文に出す |
| `/deploy-verify`         | デプロイ一気通貫検証と release 反映                          |
| `/promote-memory <name>` | 個人 memory の feedback を team 共有 rule へ昇格             |

sync 系（`/readme-sync` / `/docs-sync` / `/code-sync` 等）を含む全コマンドの一覧と正本は `docs/harness/OPERATING_MODEL.md` の skill コマンド一覧を参照。定期実行の頻度は `docs/harness/scheduled-operations.md` を参照。

## ディレクトリ構成（ハーネス）

| パス                                                                          | 内容                                                                                                      |
| ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `docs/harness/`                                                               | 運用正本（`OPERATING_MODEL.md` / `harness_authoring_guide.md` / `scheduled-operations.md`）               |
| `docs/harness/skills/`                                                        | skill 手順の正本。skill 固有の詳細は同名ディレクトリに置く                                                |
| `docs/harness/skills/shared/`                                                 | skill 横断の共通契約（PR 作成・検証ゲート・無人 run・INDEX の更新主体など）                               |
| `.claude/skills/`                                                             | slash コマンドの薄い adapter（正本は `docs/harness/skills/`）                                             |
| `.claude/agents/`                                                             | 委譲先サブエージェント（gc-agent / adr-compactor / architecture-sync / refactorer / refactor-guide-sync） |
| `.claude/hooks/`                                                              | トリガーベース自動化（commit 前フォーマット / push 前の秘密検知 + CI 同等検査 / 編集後検査）              |
| `.claude/rules/`                                                              | 常時ロード 1 本 + paths スコープ 3 本                                                                     |
| `.claude/bin/`                                                                | hooks 共通ユーティリティ                                                                                  |
| `.claude/settings.json`                                                       | hook 配線の正本                                                                                           |
| `tests/harness/`                                                              | ハーネス文書・設定の機械検査（`pnpm harness:test`）                                                       |
| `.gitleaks.toml` / `.env.example` / `.prettierignore` / `pnpm-workspace.yaml` | 秘密検知・環境変数のキー名・整形の除外・workspace 定義の root 設定                                        |

この表は、列挙したものの実在だけを検査する。skill の一覧の正本は `docs/harness/OPERATING_MODEL.md` の skill コマンド一覧である。

## Tips

- **レビューでは遠慮なく修正指示を出す** — AI は再生成するだけなのでコストは低い。設計段階で方向修正するほうが手戻りが少ない
- **設計判断は ADR に残す** — `/create-adr` で「なぜこの設計にしたか」を記録すると後から振り返れる
- **複数タスクは worktree で並行** — 各 worktree は独立した作業コピーで、互いに干渉しない
- **INDEX は更新主体に任せる** — 実装 PR は既存の `INDEX.md` を編集しない（正本 → `docs/styles/team-feedback/shared-aggregate-single-writer.md`）
