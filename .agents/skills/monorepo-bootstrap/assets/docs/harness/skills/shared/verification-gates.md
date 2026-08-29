# 検証ゲートコマンド定義（一元管理）

この文書は本リポジトリの検証ゲートコマンド 6 本と、用途別の組合せを一元定義する。各コマンドの実装（lint ツールの選定・設定）は書かない（root `package.json` の scripts と各ツール設定ファイルが正本）。

skill 文書・agent 定義・hook が検証コマンドを必要とするときは、本ファイルを参照する（各所に
コマンド列を複製しない）。

## コマンド定義

root `package.json` の scripts として以下の名前で提供する。実装（背後のツール）は自由だが、
**名前はこの 6 本を契約として保つ**。

| コマンド | 役割 |
|---|---|
| `pnpm run format` | フォーマットの適用（書き換える）。hook（pre-format-check）が staged ファイルに対して使う |
| `pnpm run format:check` | フォーマット差分の検査（書き換えない） |
| `pnpm run lint` | 静的解析（lint） |
| `pnpm run typecheck` | 型検査 |
| `pnpm run test` | テスト実行 |
| `pnpm run build` | ビルド |

## 用途別の組合せ

| 用途 | 実行するゲート |
|---|---|
| pre-push（`.claude/hooks/pre-push-ci-check.sh`） | `format:check` + `lint` + `typecheck` + `build`（`test` は CI が実行） |
| 実装完了の検収（PR 作成前・実装系 skill の最終検証） | `format:check` + `lint` + `typecheck` + `test` + `build`（全部） |
| docs のみ変更（*.md の編集だけの PR。`/static-check --docs` はこの組合せを実行する） | `format:check` のみ |

- 判定に迷う場合（docs と設定の混在等）は広い側（実装完了の検収）に倒す。
- いずれの用途でも `--no-verify` による hook 回避は禁止。

## 変更時の注意

**コマンド名を変える場合は、本ファイルと hooks（`.claude/hooks/pre-push-ci-check.sh` /
`.claude/hooks/pre-format-check.sh`）と CI（`.github/workflows/ci.yml`）を同一 PR で同時更新する。**
片方だけ変えると、hook / CI が存在しない script を呼んで無言に fail するか、検査がスキップされる。
