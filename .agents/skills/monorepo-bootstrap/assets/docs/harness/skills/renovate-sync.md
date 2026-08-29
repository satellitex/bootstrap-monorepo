# renovate-sync（依存 pin ↔ Renovate 設定の突合）

> **opt-in:renovate** — 本 skill は Renovate を導入済みのリポジトリでのみ採用する。前提:
> `renovate.json`（または同等の設定ファイル）が存在し、`LGTM` ラベルが repo に作成済みであること。

この文書は `/renovate-sync` の手順正本である。`renovate.json` と `origin/main` 上の依存 pin 箇所を突き合わせて 3 検査を実施し、違反があれば `renovate.json` の修正 PR を作り、open Renovate PR の `LGTM` ラベルを検査結果に同期する。依存の実際の update（Renovate 本体の仕事）・依存定義ファイル自体の編集は扱わない。

## Purpose

Renovate が依存 pin 箇所を漏れなく検知できているか、複数 manager にまたがる同一依存の pin
（cross-manager dual-pin）が同一 PR に束ねられているかを検証し、検知漏れによる version drift を防ぐ。

## Source of truth

`origin/main` 上の依存 pin の実態（下記インベントリ）。`renovate.json` は実態に追従する側。

## Compared against

- `renovate.json`（または `.github/renovate.json` / `.renovaterc.json` / `.renovaterc`）の
  `packageRules` / `enabledManagers` / `includePaths` / `customManagers`
- open Renovate PR の changed files

## Scope

依存 pin インベントリの走査対象（既定。プロジェクトで使う manager に合わせて調整する）:

| Manager | 走査対象 | 抽出キー |
|---|---|---|
| `mise` | `.mise.toml`, `.tool-versions` | `[tools]` 配下の各エントリ |
| `npm` (packageManager) | root `package.json` の `"packageManager"` | `pnpm@X.Y.Z` 形式から dep 名と version |
| `npm` (deps) | `**/package.json` の `dependencies` / `devDependencies` / `peerDependencies` | キーと version |
| `dockerfile` | `**/Dockerfile*` | `FROM` 行の image:tag |
| `docker-compose` | `**/docker-compose*.{yml,yaml}` | `image:` 値 |
| `github-actions` | `.github/workflows/**/*.{yml,yaml}` | `uses:` の `owner/repo@ref`（SHA pin は隣接コメントの `# vN`） |
| その他 | シェルスクリプト内の `tool_X.Y.Z` / `tool@X.Y.Z` 等のリテラル pin を grep | 「未管理 pin 候補」として記録 |

除外: `node_modules/`、ビルド成果物、`.git/`、`.claude/worktrees/`、lock ファイル
（version 以外の hash 行）。

## Detection

```
/renovate-sync
  +-- 1. 共通 prelude（origin/main fetch）
  +-- 2. renovate.json と pin 箇所インベントリ収集 + open Renovate PR 収集
  +-- 3. 3 検査を実行（open PR スコープ / cross-manager / 未管理 pin）
  +-- 4. open Renovate PR の LGTM ラベルを検査結果に同期
  +-- 5. 違反あり: renovate.json 更新 → validator → commit → PR（sync-pr-flow）
  +-- 6. renovate.json で吸収不能な違反: 人間へエスカレーション（PR は作らない）
```

- **Step 1**: `docs/harness/skills/shared/sync-prelude.md` を Read し、その手順に従う。
- **Step 2**: 現行 `renovate.json` を Read し、`origin/main` から上掲の走査で
  `{ dep_name, file, manager, version_spec }` の集合を構築する。open PR は
  **LGTM 有無に関わらず全件**取得し、`renovate` ラベルで**ローカル絞り込み**する。照会は
  `docs/harness/skills/shared/gh-query-fail-closed.md` の規約に従う（`--label` は search 経路で
  空を無言で返すと Step 4 の LGTM 同期が全 PR について no-op 化し、本 skill が防ぐと明言している
  stale 承認がそのまま残るため、疎通 canary + plain list + `--limit` 打ち切り検知で行う）。
  `LGTM` は前回実行時点の結果に過ぎないため、収集の除外条件に使わない。
- **Step 3** の 3 検査:

### 検査 1: open PR スコープ検証（per-PR）

PR が更新しようとしている依存名を pin する**全ファイル**が、その PR の changed files に
含まれているか確認する。漏れがあると、当該依存を別経路で読む側（CI のツールランナー /
ローカルの corepack 等）が古い version のまま残る。

1. PR title / diff から更新対象の依存名集合を抽出する
2. インベントリから、その依存名が pin されている全ファイルを引く
3. PR の changed files との差集合を「スコープ漏れ」として記録する

判定の注意: major-only 指定や caret range（`^X.Y.Z`）は新しい patch / minor を取り込む側なので
漏れ扱いしない。スクリプト中の完全 pin（`tool_1.2.3` 等）は漏れ対象。

### 検査 2: Cross-manager dual-pin 検出

同名依存が複数 manager で pin され、別グループに割り当てられていると、片方のみ merge /
異なる cadence で version が乖離する。

1. インベントリを依存名でグループ化し、manager のユニーク数が 2 以上のものを抽出する
2. 現行 `packageRules` に全 manager をカバーする `groupName` 割り当て
   （`matchPackageNames` / `matchDepNames` での指定）が無ければ「未対策」として記録する

代表例: `pnpm` は `.mise.toml`（mise manager）と root `package.json` の `packageManager`
（npm manager）の双方で pin される。`matchDepNames` に `["pnpm"]` を入れて同一 PR に束ねる。
`package.json` の `engines.node` は constraint であり manager 扱いが Renovate のバージョンに
依存するため、判定保留にして PR body で言及する。

### 検査 3: 未管理 pin 検出

Renovate が現状見ていない pin 箇所（manager 無効・対象 path 範囲外・スクリプト内リテラル等）を
炙り出す。インベントリの「未管理 pin 候補」、`enabledManagers` / `ignorePaths` で除外されている
manager / path、標準 manager で拾えないリテラルが対象。

## Auto-edit policy

- 編集対象は **`renovate.json` のみ**。実コード・依存定義ファイル（`package.json`・`.mise.toml`・
  workflow 等）は編集しない。
- 検査 1〜3 の問題はすべて `renovate.json` の編集で吸収する:
  - 検査 1: 漏れの原因別に吸収（`ignorePaths` 解除 / 検査 2 のグルーピングへ統合 / 検査 3 の
    `customManagers` へ統合）
  - 検査 2: 該当依存ごとに `packageRules` エントリ（`matchDepNames` + `groupName`）を追加する。
    既存 rule とのコンフリクトを避けるため、より具体的な rule として配列末尾に置く
    （Renovate は配列順に評価し、後勝ち）
  - 検査 3: ファイル種・pin 形式ごとに `customManagers`（regex manager）エントリを追加する。
    追加後は検査 2 のグルーピング対象として再評価する
- **LGTM ラベル同期（Step 4）**: 各 open Renovate PR について、検査 1〜3 すべてクリアなら
  `gh pr edit <num> --add-label "LGTM"`（冪等）、いずれか該当なら `--remove-label "LGTM"` で剥がす。
  `LGTM` は「現在の origin/main / PR head で全検査クリア」を示す状態ラベルであり、毎回全件を
  再評価して stale 承認を防ぐ。判定は per-PR で他 PR の違反に影響されない。ラベル定義自体の
  作成・削除は行わない。このステップは Step 5 の PR 作成有無・open PR ガード発火の有無に
  関わらず実行する（Step 2 の疎通 canary が通ったうえで open Renovate PR が 0 件なら何もしない）。

## Branch & PR policy

全検査で違反 0 件なら何も作らず終了する（sync-prelude の規約）。違反ありの場合は
`docs/harness/skills/shared/sync-pr-flow.md` を Read してその手順に従う。本 skill の差分:

| 項目 | 値 |
|------|-----|
| 変更なしメッセージ | `[renovate-sync] 変更なし。依存 pin 箇所は Renovate の検知範囲と整合しています。` |
| ブランチ | `agent/renovate-sync-{YYYY-MM-DD}` |
| git add | `renovate.json` のみ |
| commit | `chore(renovate): renovate.json sync (YYYY-MM-DD)`（body に検査結果サマリ） |
| PR title | `chore(renovate): renovate.json sync (YYYY-MM-DD)` |
| PR body | 下記 Report shape |

PR は必ず `renovate.json` の実変更を含む（報告のみの PR は作らない）。

### 吸収不能な違反の人間エスカレーション（Step 6）

`renovate.json` の編集で吸収できない違反（例: 依存名が推論不能・datasource 不明）を検出した場合のみ
実行する。console 出力だけだと自動実行時に取りこぼされるため、チーム通知チャネルへ投稿して人間判断を
仰ぎ、skill は**失敗扱い**で終了する（PR は作成しない）。

- 通知先: `TODO(取得方法: チーム通知チャネル〔chat の webhook 等〕を用意し、URL を環境変数
  PROJ_RENOVATE_SYNC_ESCALATION_WEBHOOK で注入する。実値はコミットしない)`。未設定の場合は
  通知をスキップし、その旨を明示して失敗扱いで終了する。
- メッセージには検査 1〜3 の件数、吸収不能な違反の一覧（依存名 / 理由）、推奨する次の人間判断
  ステップを含める。
- このステップは **open PR ガードが発火して PR 作成が見送られた場合も実行する**（ガードが止めるのは
  PR 作成までで、エスカレーションは止めない）。

## Validation

編集後、必ず `npx --yes --package=renovate -- renovate-config-validator renovate.json` で検証する。
`Config validated successfully` が出ない限り commit しない。加えて設定ファイルのみの変更のため
`pnpm run format:check`（`docs/harness/skills/shared/verification-gates.md`）。

## Report shape

PR body の構成:

1. **Summary**: 問題件数と修正概要
2. **検査 1〜3 の各結果**: 該当箇所と加えた変更
3. **Validation**: validator の実行結果
4. **Test plan**: 次回 Renovate dashboard 更新時の検証項目

## Language

報告・PR body・Issue 本文は project language に従う（正本: `docs/harness/OPERATING_MODEL.md` の言語ポリシー節）。依存名・manager 名・`renovate.json` のキーは原文のまま保持する。

## Self-check

- [ ] open Renovate PR を LGTM 有無に関わらず全件検査した
- [ ] 各 PR の `LGTM` を検査結果に同期した（クリア → 付与 / stale → 剥がし）
- [ ] 吸収可能な違反はすべて `renovate.json` の変更に反映し、validator が成功した
- [ ] 吸収不能な違反があった場合は人間へエスカレーションし PR を作成していない
