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

- 依存は Node 標準（`node:test` / `node:fs` ほか）だけで、Node 22 以上で動く。turbo と workspace package は経由しない。repo 外のファイルを読む検査を task のキャッシュや path filter の裏に置くと、検査したい変更に限って実行されなくなる。path filter を足す場合は、`tests/harness/**`、`docs/**`、`.claude/**`、`.github/workflows/**`、ルート直下の `*.md` と `package.json` を含める。
- `run.mjs` を経由する理由は 2 つある。Node 21 以降は `node --test <ディレクトリ>` がディレクトリをファイルとして解決して失敗する。また検査ファイルが 0 件、または実行されたテストが 0 件（全件 skip を含む）でも `node --test` は成功終了するため、何も検査していないのに green になる。ランナーはどちらも失敗にする。
- `HARNESS_ROOT` は検査対象のルート（既定は `tests/harness/` の 2 階層上）。存在するディレクトリでなければ失敗する。
- ルートが `MANIFEST.md` を持つ場合はテンプレート資産そのものとみなし、置換前の明示 token（`PRODUCT_NAME` / `GITHUB_ORG` / `REPO_NAME` / `PROJECT_LANGUAGE`）を許容する。bootstrap 先には `MANIFEST.md` を配布しないため、通常はこの許容が働かない。
- 検査は本文の文言に依存せず、パス・コード表記・数値で判定する。ADR 要約の検証 CLI だけは節の見出し名を使い、オプションで差し替える。

## 検査一覧

| ファイル                                           | 検査内容                                                                        |
| -------------------------------------------------- | ------------------------------------------------------------------------------- |
| `check-harness-structure.test.mjs`                 | サイズ上限、skill 正本と adapter の 1:1・薄さ、検証ゲート名の整合               |
| `check-doc-placeholders.test.mjs`                  | docs/ の散文に未解決のプレースホルダ・未置換の明示 token・空 owner の症状がない |
| `check-harness-refs.test.mjs`                      | ハーネス文書のインラインコードに書かれたパスの実在                              |
| `check-gh-usage.test.mjs`                          | `gh` 照会の `--limit`・search フィルタの排除・owner の直書き禁止                |
| `check-workflows.test.mjs`                         | workflow が空でなく、jobs を持つ                                                |
| `check-agent-launch-paths.test.mjs`                | agent の起動経路（または orphan-allow の宣言）                                  |
| `check-adr-compression-lossless.mjs` / `.test.mjs` | ADR の要約圧縮の無損失検証 CLI と、その自己テスト                               |
| `harness-gates-e2e.test.mjs`                       | 違反の無い最小のルートで全 gate が通り、gate ごとに違反を注入すると失敗する     |
| `harness-support.test.mjs`                         | `support/` のヘルパとランナーの自己テスト、空のルートでの退化ガード             |

`support/repo-files.mjs` は検査が共有するヘルパ（ルートの解決、ファイル列挙、markdown の簡易解析、frontmatter の読み取り、除外定数の検査）を持つ。

### 各検査の範囲

- `check-harness-structure.test.mjs`
  - サイズ上限は `docs/harness/harness_authoring_guide.md` のサイズ表から読む。種別は行頭セルのパス表記（`OPERATING_MODEL.md` / `docs/harness/skills/` / `.claude/skills/…/SKILL.md` / `.claude/agents/` / `description`）、上限は第 2 セルの `≤<数値>` で判定するため、表を編集するときはこの 2 点を保つ。入口文書（OPERATING_MODEL・CLAUDE・AGENTS）、skill 正本、adapter、agent 定義の行数と、adapter の description の文字数を検査する。`docs/harness/skills/shared/`、`docs/harness/skills/<name>/`、各 `references/` は表が上限を定めていないため対象外。
  - `docs/harness/skills/*.md` と `.claude/skills/*/SKILL.md` が同名で 1:1 であること、`docs/harness/skills/<name>/` が同名の正本を持つこと、adapter の `name` がディレクトリ名と一致し description が単一行で正本のパスを参照すること、入口 adapter が `OPERATING_MODEL.md` を参照することを検査する。
  - 検証ゲート名は、`verification-gates.md` の定義表の script が `package.json` の scripts に存在すること、workflow の `pnpm` 呼び出しと pre-push hook の `CI_CHECK_STEPS` が scripts に存在すること、`gate:<name>` の参照がすべて定義済みで定義済みの組合せがどこかで参照されていること、ゲートのコマンド列を許可箇所（`DIRECT_COMMAND_ALLOWED`）以外に直書きしていないことを検査する。
- `check-doc-placeholders.test.mjs`: `docs/**/*.md` の散文（コードブロックとインラインコードの外）。記入欄（`TEMPLATE_FORM_PATHS`）は対象外。TODO の件数は報告するだけで失敗にしない。
- `check-harness-refs.test.mjs`: ハーネス文書（`.claude/agents/`、`.claude/skills/`、`.claude/rules/`、`docs/harness/`、ルート直下の `*.md`）のインラインコード。`docs/` `.claude/` `.github/` `tests/` などの接頭辞で始まるトークンだけを見る。
- `check-gh-usage.test.mjs`: ハーネス文書、`.claude/`、`.github/`、`scripts/`。markdown ではフェンス内の全行と、フラグを伴うインラインコードをコマンドとして扱う。リポジトリ owner のリテラルの検査は bootstrap 先でだけ行い、owner は `GITHUB_REPOSITORY` か `origin` remote から解決する（解決できなければ skip）。
- `check-workflows.test.mjs`: `.github/workflows/*.yml`。
- `check-agent-launch-paths.test.mjs`: `.claude/agents/*.md`。起動側として `docs/harness/skills/`、`.claude/skills/`、他の agent 定義、`.claude/settings.json`、workflow を見る。定期実行のカタログへの記載と、自然文の「〜を起動する」は起動経路に数えない。起動経路を持たない agent を残す場合は、frontmatter の直後 15 行以内に `> orphan-allow: <理由>` を置く。

### ADR 要約の検証 CLI

```bash
node tests/harness/check-adr-compression-lossless.mjs <before> <after>
```

要約を始める直前の ADR（`<before>`）と要約後の ADR（`<after>`）を比べ、次の 5 点をすべて満たすときに終了コード 0 を返す。1 つでも満たさなければ 1、引数や読み込みのエラーは 2 を返す。

1. `## Decision` 節が、空白を正規化したうえで前後で逐語一致する（見出しは前後ともちょうど 1 つ）。
2. `## Related Issues` 節が要約前にあれば、前後で逐語一致する。
3. 要約前の相互参照（ADR id・リポジトリ内パス・Issue / PR 番号・要件 ID）が要約後にもすべて残る。
4. Status の値が前後で変わらない。読み取れない場合は無損失を証明できないとして失敗にする。
5. 要約後のバイト数が要約前より小さい。

`adr-compress:summarized` を含む行（要約済みの注記）は比較から除く。節の見出しは `--decision-heading` / `--related-heading` で、相互参照の抽出規則は `REFERENCE_RULES`（先頭の定数）で、プロジェクトの ADR の書式に合わせて差し替える。`verifyCompression()` を import すれば `node:test` からも呼べる。

## 除外定数と許容リスト

除外は検査ファイルの先頭の定数に置く。理由（`reason`）の無い除外は許さない。生きた出現を持たない除外（対象が消えたのに除外だけが残ったもの）は stale として失敗にする。除外が残っていると、後で同じ形の違反が混入しても黙って通るため。

| 定数                      | 所在                               | 内容                                                                                                                                                                                                 |
| ------------------------- | ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SIZE_ALLOWLIST`          | `check-harness-structure.test.mjs` | サイズ上限を超えた既存ファイルの一時的な許容。上限内に収まったら削除する                                                                                                                             |
| `DIRECT_COMMAND_ALLOWED`  | `check-harness-structure.test.mjs` | ゲートのコマンド名を直接書いてよい文書。`docs/harness/skills/shared/verification-gates.md` の記述と揃える                                                                                            |
| `MISSING_PATH_EXCLUSIONS` | `check-harness-refs.test.mjs`      | 実在しないが参照として正しいパス（ワークスペースのパッケージ置き場、設定ファイルの候補パスなど）。導入先の文書構成によって現れないものは `optional: true`（テンプレート資産でだけ stale を検査する） |
| `TEMPLATE_FORM_PATHS`     | `support/repo-files.mjs`           | 置換対象外の記入欄（コピーして埋める様式）を置くパス。未解決プレースホルダの検査から外す                                                                                                             |

既存の repo にハーネスを導入するとき、導入先に既に違反がある場合は、該当する除外定数へ理由付きで登録して green の状態で導入し、違反を解消するたびに除外を削除する。ある検査を導入先で使わないときは、その `*.test.mjs` を削除する（`tests/harness/` に検査ファイルが 0 件になった場合だけ、ランナーが失敗するため `ci.yml` の step も外す）。

## 検査を追加する手順

1. `check-<対象>.test.mjs` の名前で `tests/harness/` に置く。`run.mjs` が `*.test.mjs` を自動で列挙するため、配線は不要。
2. 検査対象のルートは `support/repo-files.mjs` の `ROOT` と `readRepoFile` / `listFiles` などを通して解決する。`process.cwd()` や固定の絶対パスを使わない。
3. 退化ガードを置く。走査対象が 0 件のときは失敗にする。列挙や抽出が壊れて 0 件になった検査が、何も検査していないのに green になるのを避けるため。空のルートで失敗することは `harness-support.test.mjs` が `check-*.test.mjs` に対して自動で確認する（ルートの内容に依存しない検査は同ファイルの `ROOT_INDEPENDENT` に登録する）。あわせて `harness-gates-e2e.test.mjs` に、違反を 1 つ注入すると失敗することを確認するケースを足す。
4. 除外は定数にし、`reason` を必須にして、`findStaleExclusions` で stale を検出する。
5. 検出ロジックは純関数に切り出し、同じファイルの `自己テスト` の `describe` で固定入力から検証する。自己テストの固定入力に波括弧 2 つのプレースホルダなど bootstrap 時の一括置換で書き換わる文字列が必要なときは、実行時に組み立てる。
6. repo 全体を走査するテストには `REPO_SCAN_TEST_TIMEOUT_MS` を timeout として付ける。固定入力だけを扱う自己テストには付けない。
7. 判定をプロジェクト言語に依存させない。見出し名や本文の文言を固定した判定が必要な場合は、ファイル先頭の定数にして差し替え点を示す。
8. 子プロセスを起動するテストは、環境変数 `NODE_TEST_CONTEXT` を取り除いて起動する（残すと子の `node:test` が入れ子と判断して何も実行しない）。
9. 本書の検査一覧と、除外定数を持つ場合は定数の表を更新する。

## 限界

- markdown の解析は簡易版で、複数行にまたがるインラインコード、HTML ブロック、インデントによるコードブロックは判定しない。
- workflow は YAML としてパースしない。インデントの崩れやタブの混入は検出できない。構文と式まで検査する場合は、専用の linter を CI に追加する。
- `gh` コマンドの検査はシェルの構文を解析しない。変数に入れたコマンド名や、複数行にまたがる引用文字列は判定できない。
- パス参照は接頭辞（`docs/`、`.claude/` など）で始まるトークンだけを見る。ファイル名だけの参照と、節名・見出しの参照は判定しない。
