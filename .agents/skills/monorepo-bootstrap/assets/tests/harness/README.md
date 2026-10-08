# tests/harness 運用ガイド

この文書は `tests/harness/` 配下の機械検査（ハーネス文書・設定の整合を決定論的に判定する検査）の一覧、実行方法、追加手順を定める。判定ロジックの詳細は各 `*.test.mjs` の冒頭コメントに書き、ここには書かない。

LLM による定期検査（`/gc-scan` など）は意味判定が要るものに集中させ、サイズ上限・1:1 対応・参照の実在・未置換 token のように機械で判定できる規約は、この検査で CI が全 PR に対して強制する。

## 実行方法

```bash
pnpm harness:test                                  # 全検査（ci.yml の test job が実行する）
node tests/harness/run.mjs                         # 同上
node --test tests/harness/check-workflows.test.mjs # 1 検査だけ
HARNESS_ROOT=/path/to/repo pnpm harness:test       # 検査対象のルートを差し替える
```

- 依存は Node 標準（`node:test` / `node:fs` ほか）だけで、Node 22 以上で動く。turbo と workspace package は経由しない。repo 外のファイルを読む検査を task のキャッシュや path filter の裏に置くと、検査したい変更に限って実行されなくなる。path filter を足す場合は、`tests/harness/**`、`docs/**`、`.claude/**`、`.github/**`、`scripts/**`、ルート直下の `*.md`・`package.json`・`.mise.toml`・`.gitignore` を含める。あわせて、参照の実在を確かめる接頭辞（`support/markdown.mjs` の `PATH_PREFIXES`）の各ディレクトリも含める。
- `run.mjs` を経由するのは、Node 21 以降は `node --test <ディレクトリ>` が失敗することと、検査ファイルまたは実行されたテストが 0 件でも `node --test` が成功終了し、何も検査していない green になることを避けるため。
- `HARNESS_ROOT` は検査対象のルート（既定は `tests/harness/` の 2 階層上）。存在するディレクトリでなければ失敗する。
- `HARNESS_TEMPLATE_ROOT=1` はテンプレートモードの切替で、置換前の明示 token（`PRODUCT_NAME` / `GITHUB_ORG` / `REPO_NAME` / `PROJECT_LANGUAGE`）を許容する。テンプレート資産そのものを検査するときだけテンプレート側の整合検査が設定し、bootstrap 先では設定しない。
- 検査は本文の文言に依存せず、パス・コード表記・数値で判定する。ADR 要約の検証 CLI だけは節の見出し名を使い、オプションで差し替える。

## 検査一覧

| ファイル                                           | 検査内容                                                                                                                                |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `check-harness-structure.test.mjs`                 | サイズ上限、skill 正本と adapter の 1:1・薄さ、検証ゲート名の整合、文書間の名前の整合（skill 表・rule 表・routine カタログ・pnpm の版） |
| `check-doc-placeholders.test.mjs`                  | docs/ の散文に未解決のプレースホルダ・未置換の明示 token・空 owner の症状がない                                                         |
| `check-harness-refs.test.mjs`                      | ハーネス文書のインラインコードに書かれたパスの実在                                                                                      |
| `check-gh-usage.test.mjs`                          | `gh` 照会の `--limit`・search フィルタの排除・owner の直書き禁止                                                                        |
| `check-workflows.test.mjs`                         | workflow が空でなく、jobs を持つ                                                                                                        |
| `check-agent-launch-paths.test.mjs`                | agent の起動経路（または orphan-allow の宣言）                                                                                          |
| `check-adr-compression-lossless.mjs` / `.test.mjs` | ADR の要約圧縮の無損失検証 CLI と、その自己テスト                                                                                       |
| `harness-gates-e2e.test.mjs`                       | 違反の無い最小のルートで全 gate が通り、gate ごとに違反を注入すると失敗する                                                             |
| `harness-support.test.mjs`                         | `support/` のヘルパとランナーの自己テスト、空のルートでの退化ガード                                                                     |

共有ヘルパは `support/` に置く。`repo-files.mjs` はルートの解決・ファイル列挙・除外定数の検査、`markdown.mjs` はルートに依存しない markdown の簡易解析・frontmatter の読み取り・計測、`gates.mjs` は走査系の gate を子プロセスで実行するヘルパである。

判定の詳細（検査の範囲・限界・除外の理由）は各ファイルの冒頭コメントに書く。

### ADR 要約の検証 CLI

```bash
node tests/harness/check-adr-compression-lossless.mjs <before> <after>
```

要約を始める直前の ADR（`<before>`）と要約後の ADR（`<after>`）を比べ、無損失なら終了コード 0 を返す。判定の詳細と終了コードは `check-adr-compression-lossless.mjs` の冒頭コメントに書く。節の見出しは `--decision-heading` / `--related-heading` で、相互参照の抽出規則は `REFERENCE_RULES`（先頭の定数）で、プロジェクトの ADR の書式に合わせて差し替える。`verifyCompression()` を import すれば `node:test` からも呼べる。

## 除外定数と許容リスト

除外は検査ファイルの先頭の定数に置く。理由（`reason`）の無い除外は許さない。生きた出現を持たない除外（対象が消えたのに除外だけが残ったもの）は stale として失敗にする。除外が残っていると、後で同じ形の違反が混入しても黙って通るため。

| 定数                      | 所在                               | 内容                                                                                                                                                                                                 |
| ------------------------- | ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SIZE_ALLOWLIST`          | `check-harness-structure.test.mjs` | サイズ上限を超えた既存ファイルの一時的な許容。上限内に収まったら削除する                                                                                                                             |
| `MISSING_PATH_EXCLUSIONS` | `check-harness-refs.test.mjs`      | 実在しないが参照として正しいパス（ワークスペースのパッケージ置き場、設定ファイルの候補パスなど）。導入先の文書構成によって現れないものは `optional: true`（テンプレート資産でだけ stale を検査する） |

置換対象外の記入欄（コピーして埋める様式）は、ファイルの冒頭 5 行以内に `<!-- harness:form -->` を置いて自己宣言する。記入欄は未解決プレースホルダの検査から外れる。

既存の repo にハーネスを導入するとき、導入先に既に違反がある場合は、該当する除外定数へ理由付きで登録して green の状態で導入し、違反を解消するたびに除外を削除する。ある検査を導入先で使わないときは、その `*.test.mjs` を削除する（`tests/harness/` に検査ファイルが 0 件になった場合だけ、ランナーが失敗するため `ci.yml` の step も外す）。

## 検査を追加する手順

1. `check-<対象>.test.mjs` の名前で `tests/harness/` に置く。`run.mjs` が `*.test.mjs` を自動で列挙するため、配線は不要。
2. 検査対象のルートは `support/repo-files.mjs` の `ROOT` と `readRepoFile` / `listFiles` などを通して解決する。`process.cwd()` や固定の絶対パスを使わない。
3. 退化ガードを置く。走査対象が 0 件のときは失敗にする。列挙や抽出が壊れて 0 件になった検査が、何も検査していないのに green になるのを避けるため。空のルートで失敗することは `harness-support.test.mjs` が `check-*.test.mjs` に対して自動で確認する（ルートの内容に依存しない検査は `support/gates.mjs` の `ROOT_INDEPENDENT` に登録する）。あわせて `harness-gates-e2e.test.mjs` に、違反を 1 つ注入すると失敗することを確認するケースを足す。
4. 除外は定数にし、`reason` を必須にして、`findStaleExclusions` で stale を検出する。
5. 検出ロジックは純関数に切り出し、同じファイルの `自己テスト` の `describe` で固定入力から検証する。自己テストの固定入力に波括弧 2 つのプレースホルダなど bootstrap 時の一括置換で書き換わる文字列が必要なときは、`OPEN` / `CLOSE`（`support/repo-files.mjs`）で実行時に組み立てる。
6. repo 全体を走査するテストには `REPO_SCAN_TEST_TIMEOUT_MS` を timeout として付ける。固定入力だけを扱う自己テストには付けない。
7. 判定をプロジェクト言語に依存させない。見出し名や本文の文言を固定した判定が必要な場合は、ファイル先頭の定数にして差し替え点を示す。
8. gate を子プロセスで起動するテストは、`support/gates.mjs` の `spawnGate` を使う（環境変数 `NODE_TEST_CONTEXT` などを取り除いて起動する。残すと子の `node:test` が入れ子と判断して何も実行しない）。
9. 本書の検査一覧と、除外定数を持つ場合は定数の表を更新する。

## 限界

- markdown の解析は簡易版で、複数行にまたがるインラインコード、HTML ブロック、インデントによるコードブロックは判定しない。
- workflow は YAML としてパースしない。インデントの崩れやタブの混入は検出できない。構文と式まで検査する場合は、専用の linter を CI に追加する。
- `gh` コマンドの検査はシェルの構文を解析しない。変数に入れたコマンド名や、複数行にまたがる引用文字列は判定できない。
- パス参照は接頭辞（`docs/`、`.claude/` など）で始まるトークンだけを見る。ファイル名だけの参照と、節名・見出しの参照は判定しない。
