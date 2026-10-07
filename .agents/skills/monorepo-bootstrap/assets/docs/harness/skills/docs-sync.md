# docs-sync（現状層ドキュメントの鮮度・3 原則・実装整合・INDEX の検査）

この文書は `/docs-sync` の手順正本である。docs の「現状層」ドキュメントとルート直下の運用文書を `origin/main` の実コード・設定・要件と突き合わせ、鮮度ドリフト・実装との内容矛盾・「現状の事実のみ」3 原則違反を検出して修正 PR にする。docs-sync が更新主体と定められた `INDEX.md` の行も、実ファイルに合わせて整える。README（`/readme-sync` 担当）・ソースコメント（`/code-sync` 担当）・skill / agent 定義の重複（`/gc-scan` 担当）は扱わない。

## Purpose

現状層ドキュメントが次の状態で残ることを防ぐ。

1. 実体（コード・設定・要件）と食い違ったまま残る（鮮度ドリフトと内容矛盾）。
2. 経緯・時系列・チケット番号の散文混入で「現状の事実」でなくなる。
3. `INDEX.md` の行が実ファイルとずれる（掲載漏れ・リンク切れ）。

## Source of truth

- 検出ポリシーの SSOT: `docs/styles/coding_guide/docs.md`
  （4 層モデル / 3 原則〔No-Time / No-Ticket-In-Prose / No-Counterfactual〕/ シグナル語 lexicon /
  例外規定 / 実装整合の原則 / 退避先判定基準）。本文書にはポリシーを複製しない。
- 記述と実装の矛盾の検出・分類・記録の手順: `docs/harness/skills/shared/implementation-consistency.md`
- INDEX の更新主体の割当: `docs/harness/skills/shared/index-writer-policy.md`
- per-file 鮮度検証ロジックの SSOT: `.claude/skills/docs-sync/references/freshness-policy.md`
  （プロジェクト固有 profile。検証対象ファイルと観点を定義する）。
- 突合先の実体は `origin/main` 上のコード・設定・`docs/requirements/`。

## Compared against

現状層ドキュメント（下記 Scope の対象）の記述内容と、INDEX 所管対象の `INDEX.md` の行。

## Scope

検証対象は 4 つの単位で管理する。

### per-file 鮮度検証対象（profile 参照）

実コード・設定との突合検証を行う対象とその検証観点は
`.claude/skills/docs-sync/references/freshness-policy.md` を SSOT とする（本文書には対象表を持たない。
対象の追加・変更は profile 側の編集だけで完結させる 2 層構造）。

### policy scan 対象（glob スコープ）

3 原則を適用する対象。新規ファイル種の追加は本表の INCLUDE / EXCLUDE glob の拡張だけで対応できる。
（プロジェクト構成に応じて調整してよいが、EXCLUDE の責務分離の理由は保つこと。）

| INCLUDE                                                                                              | EXCLUDE                                                                                                                                                                                          |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `docs/product/**/*.md`                                                                               | `docs/adr/**`（決定層 / Why。時系列・経緯が本質）                                                                                                                                                |
| `docs/styles/**/*.md`                                                                                | `docs/notes/**`（調査層。時系列前提）                                                                                                                                                            |
| `docs/harness/*.md`（直下の運用正本）                                                                | `docs/postmortems/**`（opt-in 区画採用時。インシデント記録は時系列の経緯を書く場）                                                                                                               |
| `.claude/rules/*.md`                                                                                 | `docs/requirements/**` / `docs/customer/**`（AI 編集対象外の正本）                                                                                                                               |
| リポジトリ root 直下の `*.md`（`README.md` を除く。`CLAUDE.md` / `AGENTS.md` / `DEVELOPMENT.md` 等） | `**/README.md`（`/readme-sync` 担当、責務分離）                                                                                                                                                  |
|                                                                                                      | `docs/styles/coding_guide/docs.md`（本 skill の SSOT 自身。違反例・lexicon を verbatim に含むため 3 原則 scan の対象外。リポジトリ内パスの実在検査は per-file 対象）                             |
|                                                                                                      | `docs/harness/skills/**` / `.claude/agents/**` / `.claude/skills/**`（操作仕様文書。手順例の `#N` 等を含むため対象外。重複は `/gc-scan` 担当、サイズ・1:1 対応・パス実在は CI の機械検査が担当） |
|                                                                                                      | `node_modules/`、ビルド成果物、`.git/`、`.claude/worktrees/`                                                                                                                                     |

対象ファイル列挙は **`origin/main` の tree** に対して実行する（後続の
`git show origin/main:<path>` と ref を揃える）。実装は同等の結果を返せばよく、
`git ls-tree -r --name-only origin/main` に INCLUDE → EXCLUDE の順で grep フィルタをかける形でよい。
root 直下の `*.md` は、パスに `/` を含まない `^[^/]+\.md$` で絞り、`README.md` を除く。

root 直下の運用文書（`CLAUDE.md` / `AGENTS.md` / `DEVELOPMENT.md`）も「現状の事実のみ」の文体を保つ。
導入先の初期状態によっては、初回の実行で違反が出ることがある。

### 実装整合の突合対象

`docs/harness/skills/shared/implementation-consistency.md` が呼び出し側に求める項目を、次のとおり定める。

| 項目                 | 値                                                                                                                                                                         |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 走査対象             | policy scan 対象・per-file 対象・`docs/runbooks/**/*.md`（`INDEX.md` と `README.md` を除く）。毎回全件を対象にする（巡回による分割が必要な規模になったら導入先が追加する） |
| 突合先               | `origin/main` の実装（コード・設定・CI・スクリプト）と、規範層の記述                                                                                                       |
| 編集可能スコープ     | 走査対象のうち、policy scan の EXCLUDE に当たらないファイル                                                                                                                |
| 記述層・規範層の範囲 | 規範層は `docs/requirements/**`。`docs/customer/**` を採用している場合はそれも含む（`docs.md` の層の表が正本）。突合先として読むだけで編集しない。他の走査対象は記述層     |
| 報告先               | 修正は PR 本文の「鮮度ドリフト・主張の修正」、「実装疑い」「判定不能」は「実装側判断要」                                                                                   |

### INDEX 所管対象

`INDEX.md` の更新主体は `docs/harness/skills/shared/index-writer-policy.md` の割当表が定める。
docs-sync は、割当表で docs-sync が主体とされた `INDEX.md`（反映漏れを補う役割を含む）だけを編集する。
policy scan の EXCLUDE にある区画（`docs/notes/**` 等）の INDEX でも、割当表が docs-sync を主体とするものは、
INDEX 行の突合に限って対象にする。他の主体の INDEX（ADR の INDEX など）で行の過不足を見つけても編集せず、
PR 本文に「`/<主体 skill> 実行要`」と報告する。

## Detection

```
/docs-sync
  +-- 0. docs/styles/coding_guide/docs.md を Read（線引きポリシーと実装整合の原則をロード）
  +-- 1. 共通 prelude（origin/main fetch）
  +-- 2. per-file 対象（profile）・policy scan 対象（glob）・INDEX 所管対象を列挙
  +-- 3. per-file 鮮度ドリフトをスキャン（freshness-policy.md の観点を適用）
  +-- 4. policy scan 対象 全件 に signal lexicon で 3 原則違反をスキャン
  +-- 5. 違反ごとに退避先の既存性を確認して fix_action を割り当て
  +-- 6. 実装整合: 記述が名指しする主張を実装と突き合わせ、3 分類
  +-- 7. INDEX 所管対象を実ファイルと突合（行の追記・削除）
  +-- 8. 自動編集（削除 / drift 修正 / 脚注化 / 主張の修正 / INDEX 行 の 5 種のみ）
  +-- 9. 変更なし終了 or ブランチ → commit → PR（sync-pr-flow）
```

- **Step 0**: `docs/styles/coding_guide/docs.md` を Read し、3 原則・lexicon・例外規定・退避先判定基準・
  実装整合の原則を取得する。都度 Read することで、人間と skill が同じ規約を見る。
- **Step 1**: `docs/harness/skills/shared/sync-prelude.md` を Read し、その手順に従う。
- **Step 3（鮮度ドリフト）**: profile の per-file ルール（実在チェック・版数突合・リンク解決）を適用し、
  検出を `drifts:`（file / severity / location / issue / fix_proposal）として蓄積する。
  policy scan 対象の他ファイルには適用しない。
- **Step 4（ポリシー違反）**: lexicon の regex を policy scan 対象全件の本文に適用し、違反候補を
  `policy_violations:`（file / principle / location / matched / excerpt）として蓄積する。機械的な
  grep だけではバージョン番号・要件 ID・例示コード・末尾脚注等を誤検出するため、各マッチを
  `docs.md` の「例外規定（保持して良いもの）」と文脈判定で照合し、該当するものは違反扱いしない。
- **Step 5（退避先の既存性確認）**: 各違反について `docs/harness/skills/shared/sync-noise-filter.md` の
  「違反の退避先の既存性を確認する」手順に従い、退避先を判定して `fix_action`
  （`delete` / `replace_with_link <existing_path>` / `needs_new_doc <推奨退避先タイプ>`）を割り当てる。
  `needs_new_doc` は自動編集しない。
- **Step 6（実装整合）**: 「実装整合の突合対象」の本文が名指しする主張（アンカー付き主張。定義は `docs.md` の
  実装整合の原則）を、`docs/harness/skills/shared/implementation-consistency.md` の手順で `origin/main` の
  実装と突き合わせる。食い違いは「記述修正 / 実装疑い / 判定不能」に分類し（定義は `docs.md` の「矛盾の分類」節）、
  実装側の根拠（パスと識別子）を示せない食い違いは検出として扱わない。Step 3 の検出と重なる主張は Step 3 を
  優先し、重複して数えない。文書を編集するのは「記述修正」だけで、Auto-edit の「主張の修正」で主張そのものを
  置換する。「実装疑い」「判定不能」は文書を編集せず、同手順の形式で PR 本文の「実装側判断要」に記録する。
- **Step 7（INDEX の突合）**: INDEX 所管対象の各 `INDEX.md` を、同じディレクトリ配下（INDEX が掲載している
  サブディレクトリを含む）の `*.md` のうち `INDEX.md` と `README.md` を除いたもの（leaf）と、行の第 1 セルの
  リンク先パスの完全一致で対応づける。
  - ファイルがあって行がない: leaf を `git show origin/main:<path>` で読み、既存行と同じ列構成で 1 行を追記する。
    要旨は leaf の冒頭見出しとリード文に書かれていることだけで作り、書かれていない事実を補わない
    （リード文がなければ見出しを要旨にする）。leaf から読めない列は `-` とする。既存の並び順の規則に従って挿入する。
  - 行があってファイルがない: 行を削除する。
  - 見出しや本文に件数の表記があれば、行数に合わせて更新する。
  - 既存行の要旨は書き換えない（要旨の鮮度は Step 6 の対象）。経過措置として実装 PR が足した行は、
    ペアリングで整合しているため変更しない。

## Auto-edit policy

自動で行ってよい編集は以下 5 種に限定する。それ以外（新規 ADR / research の作成、本文の大幅再構成、
節の追加・統合、コードの編集）は行わず、`needs_new_doc` は PR body に「起票要候補」として明記して人間に委ねる。

| アクション           | 対象                                    | 編集内容                                                       |
| -------------------- | --------------------------------------- | -------------------------------------------------------------- |
| 削除                 | `fix_action: delete`                    | 該当行 or 該当節を削除                                         |
| drift 修正           | `severity: critical` / `major` の drift | 単純な値置換（壊れたパス・古い版数）                           |
| 脚注化               | `fix_action: replace_with_link`         | 本文中の参照を末尾「関連リソース」節へ移動して箇条書きリンク化 |
| 主張の修正           | Step 6 で「記述修正」と分類した食い違い | 主張そのものの置換のみ。節や手順の増減はしない                 |
| INDEX 行の追記・削除 | Step 7 の突合結果                       | 行単位の追記・削除と件数表記の同期                             |

EXCLUDE スコープには 3 原則違反の編集を行わない（per-file 対象の drift 修正と、INDEX 所管対象の INDEX 行は、上表の範囲で編集する）。
「実装疑い」「判定不能」の食い違いでは、文書を実装に合わせて書き換えない。実装が要件を満たしていないときに
記述を実装へ合わせると、仕様違反の記録ごと消えてしまうため、判断は人間に委ねる。

## Branch & PR policy

検出 0 件時は sync-prelude の規約どおり何も作らず終了する。編集が 0 件で「実装疑い」「判定不能」「起票要候補」
だけが残る run も、ブランチも PR も作らず、所見を根拠付きで完了報告に列挙して終了する
（`docs/harness/skills/shared/sync-prelude.md` の「編集を伴わない所見だけの run」）。編集がある場合は
`docs/harness/skills/shared/sync-pr-flow.md` を Read してその手順に従う。本 skill の差分:

| 項目               | 値                                                                                                              |
| ------------------ | --------------------------------------------------------------------------------------------------------------- |
| 変更なしメッセージ | `[docs-sync] 変更なし。現状層ドキュメントは origin/main の現状と整合しています。`                               |
| ブランチ           | `agent/docs-sync-{YYYY-MM-DD}`                                                                                  |
| git add            | 更新した文書ファイル（INCLUDE スコープ・per-file 対象・`docs/runbooks/` 配下・INDEX 所管対象の `INDEX.md`）のみ |
| commit             | `docs: sync current-state docs with current code (YYYY-MM-DD)`                                                  |
| PR title           | `docs: docs-sync (YYYY-MM-DD)`                                                                                  |
| PR body            | 標準 5 節（`docs/harness/skills/shared/pr-creation.md`）に、下記 Report shape の 6 区分を加える                 |

## Validation

docs のみの変更のため、`gate:docs`（`docs/harness/skills/shared/verification-gates.md`）を実行する。

## Report shape

PR body は標準 5 節に加えて、次の 6 区分で整理する:

1. **鮮度ドリフト・主張の修正**: file / location / fix の表（主張の修正は実装側の根拠パスと識別子を併記）
2. **削除した経緯記述**: 退避先リンク付き
3. **INDEX 行の追記・削除**: INDEX / 追記または削除した行 / 他の主体の INDEX に見つけた過不足（`/<主体 skill> 実行要`）
4. **起票要候補**: 推奨退避先タイプ付き（自動起票しない旨を注記）
5. **実装側判断要**: 「実装疑い」「判定不能」の一覧（形式は `docs/harness/skills/shared/implementation-consistency.md`。自動起票しない旨を注記）
6. **検出ログ概要**: drift / 違反 / 実装整合の分類別件数 / 自動修正 / 起票要の件数

## Language

報告・PR body・Issue 本文は project language に従う（正本: `docs/harness/OPERATING_MODEL.md` の言語ポリシー節）。コード識別子・パス・regex は原文のまま保持する。

## Self-check

- [ ] `coding_guide/docs.md` と `freshness-policy.md`（profile）を Read してから検査した
- [ ] 例外規定との照合をスキップしていない（バージョン番号・要件 ID・末尾脚注・コードブロック）
- [ ] 「実装疑い」「判定不能」の食い違いで文書を編集していない
- [ ] INDEX 行は、割当表で docs-sync が主体の INDEX だけを編集した
- [ ] 編集 0 件のとき PR を作成していない
- [ ] PR body が標準 5 節と 6 区分で構成されている
- [ ] README.md を編集していない（責務は `/readme-sync`）
