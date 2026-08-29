# readme-sync（README ↔ 実コードの定期突合）

この文書は `/readme-sync` の手順正本である。各 README を `origin/main` の現状コードと突き合わせ、食い違いがあれば README を更新して PR にする。README 以外のドキュメント鮮度（`/docs-sync` 担当）・ソースコメント（`/code-sync` 担当）は扱わない。

## Purpose

各 README（パッケージ・アプリ・ディレクトリ単位の説明文書）と現状コードの鮮度境界を守る。
README が言及するコマンド・構成・ファイルが実体と食い違ったまま放置されるのを防ぐ。

## Source of truth

`origin/main` 上の実コード・設定ファイル（README は実体に追従する側であり、正本はコード）。

## Compared against

`**/README.md`（ケース揺れの `Readme.md` / `readme.md` を含む）の記述内容。

## Scope

- INCLUDE: リポジトリ内の全 README（root / `apps/*` / `packages/*` / `docs/` 配下等）
- EXCLUDE: `node_modules/`、ビルド成果物ディレクトリ（`dist/` 等）、`.git/`、`.claude/worktrees/`

対象ファイルの列挙は `origin/main` の tree に対して行う
（`docs/harness/skills/shared/sync-prelude.md` の規約）。

## Detection

1. **共通 prelude**: `docs/harness/skills/shared/sync-prelude.md` を Read し、`git fetch origin main`
   で比較基準を固定する。
2. 各 README を `git show origin/main:<path>` で取得し、README が言及している領域
   （同ディレクトリ配下のコード、参照されている設定ファイル・script 名・コマンド等）を
   `origin/main` から読み比べる。
3. 差分追跡（git diff）ではなく、**現状コードと README の直接照合による内容判断**で、
   食い違いがある README にのみ「更新案」を作る。

検出カテゴリの目安:

| カテゴリ | 例 | 重大度 |
|---|---|---|
| 実体不在 | README が挙げるファイル・script・コマンドが存在しない | critical |
| 内容乖離 | ディレクトリ構成・手順・オプションが現状と異なる | major |
| 表記揺れ | 名称のケース・綴りの揺れ | minor |

## Auto-edit policy

- 編集してよいのは **README 側のみ**。コード正本（実装ファイル・設定ファイル）は編集しない。
- 更新案は現状コードの事実に合わせる書き換えに限定する（新機能の説明の創作・構成の再設計提案はしない）。
- 判断が割れる大きな再構成は PR body に「提案」として記載し、本文編集は最小限にする。

## Branch & PR policy

検出 0 件時は `docs/harness/skills/shared/sync-prelude.md` の規約どおり何も作らず終了する。
検出ありの場合は更新案を各 README に適用した上で `docs/harness/skills/shared/sync-pr-flow.md` を
Read してその手順（既存 open PR ガード → ブランチ → commit → PR）に従う。本 skill の差分:

| 項目 | 値 |
|------|-----|
| 変更なしメッセージ | `[readme-sync] 変更なし。各 README は origin/main の現状コードと整合しています。` |
| ブランチ | `agent/readme-sync-{YYYY-MM-DD}` |
| git add | 更新した README のパスのみ |
| commit | `docs: sync README with current code (YYYY-MM-DD)` |
| PR title | `docs: README sync (YYYY-MM-DD)` |
| PR body | 更新した README ごとに「食い違っていた箇所 / 更新内容」を列挙 |

## Validation

docs のみの変更のため `pnpm run format:check`
（`docs/harness/skills/shared/verification-gates.md` の「docs のみ変更」組合せ）。

## Report shape

- 変更なし時: 変更なしメッセージのみを console に出力する。
- PR 作成時: PR body に README 別の食い違い一覧と更新内容、PR URL を console に報告する。
- 既存 open PR ガード発火時: 既存 PR の番号・URL と今回の検出件数を報告する（sync-pr-flow §1）。

## Language

報告・PR body・Issue 本文は project language に従う（正本: `docs/harness/OPERATING_MODEL.md` の言語ポリシー節）。コード識別子・コマンド・ファイル名は原文のまま保持する。
