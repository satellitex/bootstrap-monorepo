# readme-sync（README ↔ 実コードの定期突合）

この文書は `/readme-sync` の手順正本である。各 README を `origin/main` の現状コードと突き合わせ、食い違いのうち README 側が古いものだけを更新して PR にする。実装側に問題がありそうな食い違いは README を編集せず、根拠付きで PR 本文に記録する。README 以外のドキュメント鮮度（`/docs-sync` 担当）・ソースコメント（`/code-sync` 担当）は扱わない。

## Purpose

各 README（パッケージ・アプリ・ディレクトリ単位の説明文書）と現状コードの鮮度境界を守る。
README が言及するコマンド・構成・ファイルが実体と食い違ったまま放置されるのを防ぐ。

## Source of truth

突合先は `origin/main` 上の実コード・設定ファイルである。README は実体に追従する側だが、食い違ったときに正しいのが常に実装とは限らない
（要件を実装が満たしていない場合がある）。README を実装に合わせてよいかどうかは、
`docs/harness/skills/shared/implementation-consistency.md` の分類で決める。

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
3. 差分追跡（git diff）ではなく、**現状コードと README の直接照合による内容判断**で食い違いを検出する。
   実装側の根拠（パスと識別子）を示せない食い違いは検出として扱わない。
4. 食い違いごとに、`docs/harness/skills/shared/implementation-consistency.md` の手順で
   「記述修正 / 実装疑い / 判定不能」に分類する（分類の定義は `docs/styles/coding_guide/docs.md` の
   「矛盾の分類」節）。README は記述層に当たり、既定は「記述修正」である。

検出カテゴリの目安:

| カテゴリ | 例 | 重大度 |
|---|---|---|
| 実体不在 | README が挙げるファイル・script・コマンドが存在しない | critical |
| 内容乖離 | ディレクトリ構成・手順・オプションが現状と異なる | major |
| 表記揺れ | 名称のケース・綴りの揺れ | minor |

## Auto-edit policy

- 編集してよいのは **README 側のみ**。コード正本（実装ファイル・設定ファイル）は編集しない。
- README を直してよいのは「記述修正」と分類した食い違いだけである。主張そのものを現状コードの事実に合わせて置換する
  （新機能の説明の創作・構成の再設計提案はしない）。
- 「実装疑い」（README の記述が要件に沿い、実装がそれを満たしていない）と「判定不能」（正とする側が決まらない）は
  README を編集しない。README を実装に合わせると仕様違反の記録ごと消えてしまうため、根拠（README の記述・
  実装側のパスと識別子・分類の理由）を PR 本文の「実装側判断要」に記録して人間に委ねる。判定不能は、決めた
  正とする側と理由を添える。
- 判断が割れる大きな再構成は PR body に「提案」として記載し、本文編集は最小限にする。

## Branch & PR policy

検出 0 件時は `docs/harness/skills/shared/sync-prelude.md` の規約どおり何も作らず終了する。
README の編集が 0 件で「実装疑い」「判定不能」だけのときも、ブランチも PR も作らず、所見を根拠付きで完了報告に
列挙して終了する（`docs/harness/skills/shared/sync-prelude.md` の「編集を伴わない所見だけの run」）。
編集がある場合は更新案を各 README に適用した上で `docs/harness/skills/shared/sync-pr-flow.md` を
Read してその手順（既存 open PR ガード → ブランチ → commit → PR）に従う。本 skill の差分:

| 項目 | 値 |
|------|-----|
| 変更なしメッセージ | `[readme-sync] 変更なし。各 README は origin/main の現状コードと整合しています。` |
| ブランチ | `agent/readme-sync-{YYYY-MM-DD}` |
| git add | 更新した README のパスのみ |
| commit | `docs: sync README with current code (YYYY-MM-DD)` |
| PR title | `docs: README sync (YYYY-MM-DD)` |
| PR body | 標準 5 節（`docs/harness/skills/shared/pr-creation.md`）に、更新した README ごとの「食い違っていた箇所 / 更新内容」と、別区分の「実装側判断要」を加える |

## Validation

docs のみの変更のため、`gate:docs`（`docs/harness/skills/shared/verification-gates.md`）を実行する。

## Report shape

- 変更なし時: 変更なしメッセージのみを console に出力する。
- PR 作成時: PR body に標準 5 節と次の 2 区分を書き、PR URL を console に報告する。
  1. README 別の食い違い一覧と更新内容（「記述修正」）
  2. 実装側判断要（「実装疑い」「判定不能」。形式は `docs/harness/skills/shared/implementation-consistency.md`。自動起票しない旨を注記）
- 編集なしで終了する場合: 「実装側判断要」を同じ形式で完了報告に列挙する。
- 既存 open PR ガード発火時: 既存 PR の番号・URL と今回の検出件数を報告する（sync-pr-flow §1）。

## Language

報告・PR body・Issue 本文は project language に従う（正本: `docs/harness/OPERATING_MODEL.md` の言語ポリシー節）。コード識別子・コマンド・ファイル名は原文のまま保持する。
