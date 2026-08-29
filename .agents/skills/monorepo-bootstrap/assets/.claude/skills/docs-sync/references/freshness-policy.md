# 鮮度検証ルール（per-file drift detection・プロジェクト profile）

この文書は `/docs-sync` の per-file 鮮度検証対象とファイル別検証観点を定義するプロジェクト固有 profile である。手順本体・policy scan の glob スコープは書かない（正本は `docs/harness/skills/docs-sync.md`。線引きポリシー本体は `docs/styles/coding_guide/docs.md`）。

## スコープ定義

`/docs-sync` は 2 層構造でファイルを扱う。本ファイルが定義するのは **per-file 鮮度検証対象**のみ。
policy scan 対象（INCLUDE / EXCLUDE glob）は `docs/harness/skills/docs-sync.md` の
「Scope」節を SSOT とし、本ファイルでは扱わない。

`**/README.md` は `/readme-sync` の担当であり、per-file 対象に加えない（責務分離）。

## 検証観点の型

per-file 検証は以下 3 型の組合せで書く。各対象ファイルの検証ルールは、この型に当てはめて
「観点 / 検出方法 / 重大度」の表として定義する。

| 型 | 内容 | 検出方法の例 |
|---|---|---|
| **実在チェック** | 文書が名指しするファイル・リソース・script・パッケージが `origin/main` 上に実在するか | `git cat-file -e origin/main:<path>` / `git grep -F '<name>' origin/main -- '<glob>'` |
| **版数突合** | 文書中のバージョン記述が版数の正本（`.mise.toml` の `[tools]`、`package.json` 等）と一致するか | `git show origin/main:.mise.toml` で取得して突合 |
| **リンク解決** | markdown リンク（`[text](../path)` 形式）の相対パスを正規化した先が実在するか | パス解決後 `git cat-file -e origin/main:<resolved>` |

## 重大度の凡例

| Severity | 意味 | 対応 |
|----------|------|------|
| critical | 実体が存在しない参照（壊れたパス・存在しないリソース） | 自動修正候補、PR body に必ず記載 |
| major | 言及切れリンク・版数不一致 | 自動修正候補、PR body に記載 |
| minor | 命名揺れ・表記ゆれ | PR body に提案のみ記載、本文編集は最小限 |

## per-file 鮮度検証対象

<!-- bootstrap 時の記入指示: プロジェクトの現状層文書に合わせて対象と観点を具体化する。
     各行の「検証観点」は上記 3 型（実在チェック / 版数突合 / リンク解決）で構成し、
     突合先（コード・設定・要件のパス）を明記すること。行の追加・削除は自由。 -->

| パス | 検証観点（placeholder — bootstrap 時に具体化する） |
|------|----------------|
| `docs/product/ARCHITECTURE.md` | 実在チェック: 本文が名指しするコンポーネント・ディレクトリが `apps/*` / `packages/*` に実在するか。リンク解決: 文中リンクの実在。TODO(取得方法: ARCHITECTURE.md の骨格確定後、依存方向・責務分離テーブル等の固有観点を追記する) |
| `docs/product/TECH_STACK.md` | 版数突合: `.mise.toml` `[tools]` のツール版数と本文の版数記述。実在チェック: 確定スタック一覧のライブラリ名が monorepo 内のいずれかの `package.json` の dependencies / devDependencies に存在するか |
| `docs/product/TERMS.md` | 実在チェック: 「初出」列の要件 ID（`(?:BR|IF|DATA|FR|NFR|SEC)-\d{4}(?:-FIX)?`）に対応するファイルが `docs/requirements/` に実在するか |

## 共通の検出フロー

1. 対象ファイルを `git show origin/main:<path>` で読み込む
2. 上表の検証観点に従い、各観点で実在 / 版数 / リンクのチェックを実施する
3. 検出された違反を以下の形式でメモリ上に蓄積する:

```yaml
drifts:
  - file: docs/product/TECH_STACK.md
    severity: major
    location: "<該当節 + 該当行の引用>"
    issue: "<検出された不一致の説明>"
    fix_proposal: "<自動修正案 or 提案>"
```

4. skill 本体（`docs/harness/skills/docs-sync.md` の Step 5 / Step 7）でこの蓄積を読み、
   PR body に整形して投入する

## 検証対象の拡張手順

拡張内容に応じて編集先が異なる。

- **policy scan スコープを増やす場合**: `docs/harness/skills/docs-sync.md` の「Scope」表
  （INCLUDE / EXCLUDE glob）に行を足す。本ファイルは変更しない。
- **既存対象の検証観点を増やす場合**: 上表の該当行に観点を追記する（新しい種類の参照が
  文書に増えたら、その参照の実在チェック方法を書く）。skill 本体は変更不要。
- **per-file 対象ファイル自体を増やす場合**: 上表に行を追加する。skill 本体は profile を
  参照する設計のため変更不要。
