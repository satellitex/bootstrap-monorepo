# docs-sync（現状層ドキュメントの鮮度・3 原則検査）

この文書は `/docs-sync` の手順正本である。docs の「現状層」ドキュメントを `origin/main` の実コード・設定・要件と突き合わせ、鮮度ドリフトと「現状の事実のみ」3 原則違反を検出して修正 PR にする。README（`/readme-sync` 担当）・ソースコメント（`/code-sync` 担当）・skill / agent 定義のサイズや重複（`/gc-scan` 担当）は扱わない。

## Purpose

現状層ドキュメントが (1) 実体（コード・設定・要件）と食い違ったまま残ること、
(2) 経緯・時系列・チケット番号の散文混入で「現状の事実」でなくなること、の 2 つを防ぐ。

## Source of truth

- 検出ポリシーの SSOT: `docs/styles/coding_guide/docs.md`
  （4 層モデル / 3 原則〔No-Time / No-Ticket-In-Prose / No-Counterfactual〕/ シグナル語 lexicon /
  例外規定 / 退避先判定基準）。本文書にはポリシーを複製しない。
- per-file 鮮度検証ロジックの SSOT: `.claude/skills/docs-sync/references/freshness-policy.md`
  （プロジェクト固有 profile。検証対象ファイルと観点を定義する）。
- 突合先の実体は `origin/main` 上のコード・設定・`docs/requirements/`。

## Compared against

現状層ドキュメント（下記 Scope の INCLUDE 集合）の記述内容。

## Scope

検証対象は 2 層構造で管理する。

### per-file 鮮度検証対象（profile 参照）

実コード・設定との突合検証を行う対象とその検証観点は
`.claude/skills/docs-sync/references/freshness-policy.md` を SSOT とする（本文書には対象表を持たない。
対象の追加・変更は profile 側の編集だけで完結させる 2 層構造）。

### policy scan 対象（glob スコープ）

3 原則を適用する対象。新規ファイル種の追加は本表の INCLUDE / EXCLUDE glob の拡張だけで対応できる。
（プロジェクト構成に応じて調整してよいが、EXCLUDE の責務分離の理由は保つこと。）

| INCLUDE | EXCLUDE |
|------|------|
| `docs/product/**/*.md` | `docs/adr/**`（決定層 / Why。時系列・経緯が本質） |
| `docs/styles/**/*.md` | `docs/notes/**`（調査層。時系列前提） |
| `docs/harness/*.md`（直下の運用正本） | `docs/issues/**`（実装計画層、Issue-specific） |
| `.claude/rules/*.md` | `docs/requirements/**` / `docs/customer/**`（AI 編集対象外の正本） |
| | `**/README.md`（`/readme-sync` 担当、責務分離） |
| | `docs/styles/coding_guide/docs.md`（本 skill の SSOT 自身。違反例・lexicon を verbatim に含むため self-scan 対象外） |
| | `docs/harness/skills/**` / `.claude/agents/**` / `.claude/skills/**`（操作仕様文書。手順例の `#N` 等を含むため対象外。サイズ / 重複は `/gc-scan` 担当） |
| | `node_modules/`、ビルド成果物、`.git/`、`.claude/worktrees/` |

対象ファイル列挙は **`origin/main` の tree** に対して実行する（後続の
`git show origin/main:<path>` と ref を揃える）。実装は同等の結果を返せばよく、
`git ls-tree -r --name-only origin/main` に INCLUDE → EXCLUDE の順で grep フィルタをかける形でよい。

## Detection

```
/docs-sync
  +-- 0. docs/styles/coding_guide/docs.md を Read（線引きポリシーをロード）
  +-- 1. 共通 prelude（origin/main fetch）
  +-- 2. per-file 対象（profile）と policy scan 対象（glob）を列挙
  +-- 3. per-file 鮮度ドリフトをスキャン（freshness-policy.md の観点を適用）
  +-- 4. policy scan 対象 全件 に signal lexicon で 3 原則違反をスキャン
  +-- 5. 違反ごとに退避先の既存性を確認して fix_action を割り当て
  +-- 6. 自動編集（削除 / drift 修正 / 脚注化 の 3 種のみ）
  +-- 7. 変更なし終了 or ブランチ → commit → PR（sync-pr-flow）
```

- **Step 0**: `docs/styles/coding_guide/docs.md` を Read し、3 原則・lexicon・例外規定・退避先判定基準を
  取得する。都度 Read することで、人間と skill が同じ規約を見る。
- **Step 1**: `docs/harness/skills/shared/sync-prelude.md` を Read し、その手順に従う。
- **Step 3（鮮度ドリフト）**: profile の per-file ルール（実在チェック・版数突合・リンク解決）を適用し、
  検出を `drifts:`（file / severity / location / issue / fix_proposal）として蓄積する。
  policy scan 対象の他ファイルには適用しない。
- **Step 4（ポリシー違反）**: lexicon の regex を policy scan 対象全件の本文に適用し、違反候補を
  `policy_violations:`（file / principle / location / matched / excerpt）として蓄積する。機械的な
  grep だけではバージョン番号・要件 ID・例示コード・末尾脚注等を誤検出するため、各マッチを
  `docs.md` の「例外規定（保持して良いもの）」と文脈判定で照合し、該当するものは違反扱いしない。
- **Step 5（退避先の既存性確認）**: 各違反について `docs.md` の「退避先の判定基準」で推奨退避先
  （ADR / research / requirements / runbook 等）を判定し、
  `git grep -l <キーワード> origin/main -- '<退避先パス>'` で既存ドキュメントの有無を確認する。
  存在すれば `fix_action: delete` または `replace_with_link <existing_path>`、存在しなければ
  `fix_action: needs_new_doc <推奨退避先タイプ>`（自動編集しない）を割り当てる。

## Auto-edit policy

自動で行ってよい編集は以下 3 種に限定する。それ以外（新規 ADR / research の作成、本文の大幅再構成、
節の追加・統合）は行わず、`needs_new_doc` は PR body に「起票要候補」として明記して人間に委ねる。

| アクション | 対象 | 編集内容 |
|----------|-----|---------|
| 削除 | `fix_action: delete` | 該当行 or 該当節を削除 |
| drift 修正 | `severity: critical` / `major` の drift | 単純な値置換（壊れたパス・古い版数） |
| 脚注化 | `fix_action: replace_with_link` | 本文中の参照を末尾「関連リソース」節へ移動して箇条書きリンク化 |

EXCLUDE スコープには一切手を触れない。

## Branch & PR policy

検出 0 件時は sync-prelude の規約どおり何も作らず終了する。検出ありの場合は
`docs/harness/skills/shared/sync-pr-flow.md` を Read してその手順に従う。本 skill の差分:

| 項目 | 値 |
|------|-----|
| 変更なしメッセージ | `[docs-sync] 変更なし。現状層ドキュメントは origin/main の現状と整合しています。` |
| ブランチ | `agent/docs-sync-{YYYY-MM-DD}` |
| git add | 更新した INCLUDE スコープ内ファイルのみ |
| commit | `docs: sync current-state docs with current code (YYYY-MM-DD)` |
| PR title | `docs: docs-sync (YYYY-MM-DD)` |
| PR body | 下記 Report shape の 4 区分 |

## Validation

docs のみの変更のため `pnpm run format:check`
（`docs/harness/skills/shared/verification-gates.md` の「docs のみ変更」組合せ）。

## Report shape

PR body を 4 区分で整理する:

1. **鮮度ドリフト修正**: file / location / fix の表
2. **削除した経緯記述**: 退避先リンク付き
3. **起票要候補**: 推奨退避先タイプ付き（自動起票しない旨を注記）
4. **検出ログ概要**: drift / 違反 / 自動修正 / 起票要の件数

## Language

報告・PR body・Issue 本文は project language に従う（正本: `docs/harness/OPERATING_MODEL.md` の言語ポリシー節）。コード識別子・パス・regex は原文のまま保持する。

## Self-check

- [ ] `coding_guide/docs.md` と `freshness-policy.md`（profile）を Read してから検査した
- [ ] 例外規定との照合をスキップしていない（バージョン番号・要件 ID・末尾脚注・コードブロック）
- [ ] 違反 0 件のとき PR を作成していない
- [ ] PR body が 4 区分で整理されている
- [ ] README.md を編集していない（責務は `/readme-sync`）
