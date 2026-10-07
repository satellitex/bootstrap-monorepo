# {{PRODUCT_NAME}}

TODO(記入方法: Intake の回答から、プロダクトの目的と主な利用者を 1 行で書く。`docs/harness/OPERATING_MODEL.md` の「プロダクト」節と同じ文にする)

この README は人間向けの入口である。運用の規約・手順は複製せず、各正本への pointer で示す。

## 構成

実在するディレクトリだけを載せる。

| パス             | 役割                                                                                                 |
| ---------------- | ---------------------------------------------------------------------------------------------------- |
| `apps/`          | アプリケーション。TODO(記入方法: 各 workspace の名前と役割を 1 行ずつ書く。まだ無ければ行を削除する) |
| `packages/`      | 共有ライブラリ。TODO(記入方法: 各 workspace の名前と役割を 1 行ずつ書く。まだ無ければ行を削除する)   |
| `docs/`          | 正本ドキュメント。置き場所の判断は `docs/README.md` のディレクトリマップに従う                       |
| `.claude/`       | ハーネス（skill・agent・hook・rules）の Claude Code 向け実装                                         |
| `tests/harness/` | ハーネス文書・設定の機械検査                                                                         |

## セットアップ

必要なツールと版数は `.mise.toml` の pin を正本とし、この README には複製しない。hooks とスクリプトは bash を前提とするため、Windows では WSL2 などの bash 環境での作業を推奨する。

1. [mise](https://mise.jdx.dev/) を導入する（手順は公式 docs に従う）
2. リポジトリを取得する: `git clone https://github.com/{{GITHUB_ORG}}/{{REPO_NAME}}.git`
3. ツールを導入する: `mise install`
4. 依存を導入する: `pnpm install --frozen-lockfile`

## 開発コマンド

- 検証ゲート（build / test / lint / typecheck / format / format:check）の定義と、用途別の組合せ（`gate:commit` など）は `docs/harness/skills/shared/verification-gates.md` が正本である
- TODO(取得方法: スタック確定後に、開発サーバの起動と単一 package の実行コマンドを確認して追記する。コマンドの型は `.claude/rules/product-development.md` の「コマンド」節に従う)

## 開発スタイル

AI エージェントが実装の主力で、人間はレビュー・方向付け・要件定義に集中する。人間向けの使い方は `DEVELOPMENT.md`、エージェント向けの運用正本は `docs/harness/OPERATING_MODEL.md` を参照する。hooks は Claude Code 経由の操作にだけ効くローカルガードで、全経路に効く最終ゲートは CI である（→ `.claude/hooks/README.md`）。

セットアップや運用の手順書は `docs/runbooks/INDEX.md` から辿る。
