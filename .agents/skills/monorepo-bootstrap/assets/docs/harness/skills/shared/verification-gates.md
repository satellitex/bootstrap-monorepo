# 検証ゲートコマンド定義（一元管理）

この文書は本リポジトリの検証ゲートコマンド 6 本と、名前付きの組合せ（`gate:commit` / `gate:push` / `gate:ci` / `gate:docs`）、hook と CI の分担を一元定義する正本である。各コマンドの実装（lint ツールの選定・設定）は書かない（root `package.json` の scripts と各ツール設定ファイルが正本）。hook の fail-open / fail-closed の設計は `.claude/hooks/README.md` が担当する。

skill 文書・agent 定義・hook のコメントが検証コマンドを必要とするときは、コマンド列を書かず、組合せの名前（`gate:commit` 等）で本ファイルを参照する。コマンド名（`pnpm run <name>`）を直接書いてよい箇所は、本書、`.claude/hooks/`、`.github/workflows/ci.yml`、root `package.json` に限る。

## コマンド定義

root `package.json` の scripts として以下の名前で提供する。実装（背後のツール）は自由だが、
**名前はこの 6 本を契約として保つ**。

| コマンド                | 役割                                                                                                                                                         |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `pnpm run format`       | フォーマットの適用（書き換える）。作業者が commit 前の整形に使う（pre-format-check hook はこの script を呼ばず、staged ファイルに formatter を直接実行する） |
| `pnpm run format:check` | フォーマット差分の検査（書き換えない）                                                                                                                       |
| `pnpm run lint`         | 静的解析（lint）                                                                                                                                             |
| `pnpm run typecheck`    | 型検査                                                                                                                                                       |
| `pnpm run test`         | テスト実行                                                                                                                                                   |
| `pnpm run build`        | ビルド                                                                                                                                                       |

## 名前付き組合せ

| 名前          | 実行するゲート                                                                | 実行主体と契機                                                            |
| ------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `gate:commit` | `format:check` + `lint` + `typecheck` + `test` + `build`（全部）              | 作業者。実装完了の検収（PR 作成前・実装系 skill の最終検証）              |
| `gate:push`   | `format:check` + `lint` + `typecheck` + `build`（`test` は `gate:ci` が実行） | pre-push hook（`.claude/hooks/pre-push-ci-check.sh`）が push 時に自動実行 |
| `gate:ci`     | `format:check` + `test` + `build`                                             | CI（`.github/workflows/ci.yml`）が PR と `main` への push で実行          |
| `gate:docs`   | `format:check` のみ                                                           | 作業者。`*.md` の編集だけの変更に対する `gate:commit` の縮約              |

### ゲートごとの実行先

| ゲート         | `gate:commit` | `gate:push` | `gate:ci` |
| -------------- | :-----------: | :---------: | :-------: |
| `format:check` |       ○       |      ○      |     ○     |
| `lint`         |       ○       |      ○      |     —     |
| `typecheck`    |       ○       |      ○      |     —     |
| `test`         |       ○       |      —      |     ○     |
| `build`        |       ○       |      ○      |     ○     |

- `gate:push` と `gate:ci` の和集合は `gate:commit` に一致する。どのゲートも、hook と CI のどちらかが実行する。
- CI の test job は `gate:ci` の `test` に加えて、hooks のテストとハーネス機械検査（`pnpm harness:test`）を実行する。ハーネス文書・設定・workflow を変更する作業者は、`gate:commit` に加えて `harness:test` を実行する。`harness:test` は 6 本の契約に含めない補助 script である。
- hook は Claude Code 経由の操作にだけ効き、Claude Code 外の端末からの push や、hook の `if` に一致しない形（`git -c ...` など）の操作は素通りする。CI は PR と `main` への push の全経路に効く。したがって `lint` / `typecheck` と、pre-push hook が実行する秘密検知（CI では実行しない）は、hook にだけ置かれ、hook の効かない経路では担保されない。CI にも課す場合は `gate:ci` に足し、`ci.yml` と本書を同一 PR で更新する。
- docs と設定が混在する変更など、`*.md` 以外のファイルを 1 つでも含む変更は `gate:docs` ではなく `gate:commit` を使う。`gate:docs` は検査の対象が `*.md` だけのときの縮約であり、設定や実装の変更を検査から外すためのものではない。
- いずれの組合せでも、hook が失敗したら原因を直して再実行する。hook を迂回すると、`format:check` / `build` の失敗は CI で初めて赤くなって修正の往復が増え、`lint` / `typecheck` / 秘密検知の失敗は CI がこれらを実行しないため検出されないまま残り得る。

## 変更時の注意

**コマンド名を変える場合は、本ファイルと hooks（`.claude/hooks/pre-push-ci-check.sh` /
`.claude/hooks/pre-format-check.sh`）と CI（`.github/workflows/ci.yml`）を同一 PR で同時更新する。**
片方だけ変えると、hook / CI が存在しない script を呼んで無言に fail するか、検査がスキップされる。

名前付き組合せの構成を変える場合（例: `gate:ci` に `lint` を足す）も、表の更新、対応する hook の step、`ci.yml` の job を同一 PR で揃える。スタック固有の拡張ゲート（型付き言語のビルドチェック等）を足すときは、どの組合せに含めるかを本書の表で決めてから、hook と CI に配線する。
