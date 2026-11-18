# bootstrap-monorepo

Codex と Claude Code で使えるモノレポ運用テンプレートです。新規プロジェクトの立ち上げと、既存リポジトリへの開発ルールや CI の導入に使えます。

## assets の構成

2 つのスキルは、導入先に合わせて同じ `assets/` から必要なファイルを選びます。[テンプレート資産の一覧](.agents/skills/monorepo-bootstrap/assets/MANIFEST.md#資産一覧)

| 場所 | 用途 |
| --- | --- |
| ルート | `AGENTS.md` を共通の入口にし、mise・pnpm・Turborepo の設定で開発環境を整える |
| `docs/` | 要件、設計判断（ADR）、運用手順を記録する。`docs/harness/skills/` には両エージェントが使う手順を収録 |
| `.claude/` | Claude Code のスキル呼び出し口、エージェント、開発ルール、コミット前や push 前のフック |
| `.github/workflows/` · `tests/harness/` | GitHub Actions でテストとビルドを実行し、文書の参照先やスキルの構成も検査する |
| `scripts/` | 任意で導入できるチャット受付や PR 自動マージのスクリプト |

## インストール

認証済みの GitHub CLI（`gh`）を用意し、2 つのスキルを一緒にインストールします。

```sh
npx skills add satellitex/bootstrap-monorepo -g --skill '*' -a claude-code codex
```

`-g` を付けると、どのプロジェクトからでも使えます。Claude Code は v2.1.277 以降が必要です。[ほかのインストール方法と更新手順](docs/installation.md) · [Claude Code の読み込み条件](.agents/skills/monorepo-bootstrap/references/docs-operating-model.md#claude-code-の読み込み条件)

## 使い方

作業先のディレクトリで Codex または Claude Code を起動し、チャットに入力します。

| やりたいこと | Codex | Claude Code |
| --- | --- | --- |
| 技術選定からモノレポを立ち上げ、デプロイを検証する | `$monorepo-bootstrap 社内の備品予約アプリを作りたい` | `/monorepo-bootstrap 社内の備品予約アプリを作りたい` |
| 既存の技術構成を保ちながら開発ルールや CI を導入する | `$harness-adopt` | `/harness-adopt` |

どちらも変更を検証して Pull Request を作成します。課金や秘密値の設定には承認が必要です。[新規プロジェクトの手順](.agents/skills/monorepo-bootstrap/SKILL.md) · [既存リポジトリへの導入手順](.agents/skills/harness-adopt/SKILL.md)

## オプション

導入時に必要な機能を選べます。[テンプレート資産とオプションの一覧](.agents/skills/monorepo-bootstrap/assets/MANIFEST.md#opt-in-グループ)

- Slack や Discord の投稿を、担当者の承認後に GitHub Issue にする。[チャットからの受付](.agents/skills/monorepo-bootstrap/assets/.claude/skills/feedback-triage/references/chat-profile.md)
- `auto-implement` ラベル付きの Issue を定期的に実装し、PR を作る。[Issue の定期実装](.agents/skills/monorepo-bootstrap/assets/docs/harness/skills/daily-implement.md)
- 指定した条件を満たす PR を開発ブランチへ自動マージする。[PR の自動マージ](.agents/skills/monorepo-bootstrap/assets/docs/harness/skills/pr-auto-merge.md)

## テンプレートの整合検査

このリポジトリの文書・スキル・資産を変更したら、ルートで次のコマンドを実行します。Bash と Node.js が必要です。

```sh
bash .agents/skills/monorepo-bootstrap/scripts/check-assets.sh
```

固有語も検査する場合は、リポジトリ外のパターンファイルを環境変数 `TEMPLATE_DENYLIST_FILE` に指定します。[検査項目とファイル形式](.agents/skills/monorepo-bootstrap/scripts/check-assets.sh)
