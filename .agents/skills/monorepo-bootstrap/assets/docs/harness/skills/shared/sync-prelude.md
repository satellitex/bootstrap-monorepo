# Sync Prelude（比較基準の固定と 0 件終了）

この文書は sync 系 skill が検査の最初に共通で実行する前段手順（origin/main fetch による比較基準の固定）と、検出 0 件時の終了規約を定める。検査後のブランチ・commit・PR 手順は書かない（`docs/harness/skills/shared/sync-pr-flow.md` が担当）。

## 手順

`git fetch origin main` を実行する。

## 意図

比較・更新・検査の基準を `origin/main` に固定し、HEAD が feature ブランチでも結果がブレないようにする。
以降の `git show origin/main:<path>` / `git ls-tree -r --name-only origin/main` 等の操作はすべて
この fetch 結果に基づき、HEAD / feature ブランチは参照しない（`origin/main` に存在しない
feature 追加ファイルでの停止や、ブランチ差分による検出結果のブレを防ぐ）。

対象ファイルの列挙も `origin/main` の tree に対して行う（列挙と `git show` の ref を揃える）。

## 検出 0 件: 何も作らず終了する

検査の結果、検出（drift / 違反 / 差分）が 0 件のときは、呼び出し側 skill 文書が指定する
「変更なしメッセージ」を console に出力して終了する。**ブランチも commit も PR も作らない**。

- 報告のみの PR（コード・文書の実変更を含まない PR）は作らない。
- 「変更なし」は検査を実行した上での結論であり、検査のスキップとは区別して報告する。
- 検出が 1 件以上あるときのみ `docs/harness/skills/shared/sync-pr-flow.md` の後段フローに進む。
