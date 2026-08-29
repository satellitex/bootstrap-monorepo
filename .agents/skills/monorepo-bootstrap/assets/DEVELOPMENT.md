# 開発スタイルガイド（人間向け）

この文書は人間の開発者向けに、AI エージェント主体の開発をどう回すかを説明する手順書である。エージェント向けの規約・手順の正本は `docs/harness/OPERATING_MODEL.md` と `docs/harness/skills/` に置き、ここには人間から見た使い方だけを書く。

## 前提

- **AI エージェントが実装の主力**であり、人間はレビュー・方向付け・要件定義に集中する
- 要件定義・設計判断の最終権限は人間にある
- エージェントは既定で自律実行し、open PR の提出までを人間の承認なしで進める

## 承認が必要な操作

既定は自律実行で、エージェントは明示的な指示がない限り、変更の実装から open PR の提出までを自律的に行う。PR のマージは人間の操作だが、明示的に指示すればマージまで任せられる。

人間の明示承認が必須なのは次の 2 つのみ:

1. **課金が発生する操作** — 有償リソースの作成・プラン変更・外部サービス契約
2. **秘密値の挿入・変更** — credential / API key / token を設定へ投入する操作

ブランチモデルは main = dev 環境 / release = prod 環境。main は壊れても復旧可能な開発環境であり、開発過程ではセキュリティより柔軟性を優先する。**prod リリースのみ手順を踏む**: main の安全性確認 → release への反映手順の確認。

## 実装フロー

```
人間: Issue 起票・指示 ───────────────→ PR レビュー → マージ
  AI: Issue 取得 → task-note → TDD（テスト → 実装）→ 検証ゲート → open PR → レビュー対応
```

1. **Issue 起点** — `/create-issue` で起票するか、既存 Issue の番号をエージェントに伝える。実装 Issue（新規機能・仕様変更・ハーネス・環境整備）は `/multi-issue`、バグ修正・リファクタ・小規模変更はメインエージェント判断で進む（トリアージの正本 → `docs/harness/OPERATING_MODEL.md`）
2. **task-note** — 着手前に `docs/issues/<番号>_<scope>/task-note.md` へ計画を残す（テンプレート → `docs/issues/templates/task-note.md`）
3. **TDD** — テストは「ユーザーストーリーの設計」→「それに対応するテストのみを作成」の順で書く。ユーザーストーリーに対応しない冗長なテスト、数合わせのテスト、実装詳細に密結合してすぐ形骸化するテストは書かない（正本 → `docs/product/TEST_STRATEGY.md` / `docs/styles/coding_guide/testing_principles.md`）
4. **open PR** — 検証ゲート（`docs/harness/skills/shared/verification-gates.md` の format:check / lint / typecheck / test / build）を通し、PR 前に簡素化パスを 1 回入れてから提出する
5. **レビュー対応** — レビューコメントが付いたら `/handle-review`（批判的評価と自律修正）、LGTM まで見届けさせるなら `/review-cycle`
6. **マージ** — 人間が diff を確認してマージする（PR body の `Closes #N` で Issue が自動 close）

## よく使う slash コマンド

| コマンド | 用途 |
| --- | --- |
| `/multi-issue #N ...` | 実装 Issue を並列実装し issue ごとに PR を作成 |
| `/create-issue` | GitHub Issue を作成（Label・Project 等を自動設定） |
| `/create-adr` | 設計判断を ADR として記録 |
| `/static-check` | 検証ゲートを一括実行し表形式で報告 |
| `/handle-review` | PR レビューコメントを批判的に評価し自律対応 |
| `/review-cycle` | LGTM まで自律ポーリングし完了を通知 |
| `/security-audit` | 多次元セキュリティ監査 |
| `/deploy-verify` | デプロイ一気通貫検証 |
| `/promote-memory <name>` | 個人 memory の feedback を team 共有 rule へ昇格 |

sync 系（`/readme-sync` / `/docs-sync` / `/code-sync` 等）を含む全コマンドの一覧と正本は `docs/harness/OPERATING_MODEL.md` の skill コマンド一覧を参照。定期実行の頻度は `docs/harness/scheduled-operations.md` を参照。

## ディレクトリ構成（ハーネス）

```
docs/harness/              運用正本（OPERATING_MODEL.md / harness_authoring_guide.md /
                           scheduled-operations.md / skills/<name>.md / skills/shared/）
.claude/
├── skills/                slash コマンドの薄い adapter（正本は docs/harness/skills/）
├── agents/                委譲先サブエージェント（gc-agent / adr-compactor /
│                          architecture-sync / refactorer / refactor-guide-sync）
├── hooks/                 トリガーベース自動化（commit 前フォーマット /
│                          push 前の秘密検知 + CI 同等検査 / 編集後検査）
├── rules/                 常時ロード 1 本 + paths スコープ 3 本
├── bin/                   hooks 共通ユーティリティ
└── settings.json          hook 配線の正本
```

## Tips

- **レビューでは遠慮なく修正指示を出す** — AI は再生成するだけなのでコストは低い。設計段階で方向修正するほうが手戻りが少ない
- **設計判断は ADR に残す** — `/create-adr` で「なぜこの設計にしたか」を記録すると後から振り返れる
- **複数タスクは worktree で並行** — 各 worktree は独立した作業コピーで、互いに干渉しない
