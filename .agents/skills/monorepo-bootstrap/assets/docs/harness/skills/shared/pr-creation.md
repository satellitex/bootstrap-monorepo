# PR 作成共通手順（base 判定 + 衝突検査 + closing keyword 注入 + 本文の標準節）

この文書は PR 自動作成の共通手順（検証 → commit → push → base 判定 → open 前の衝突検査 → 本文の組み立て → `gh pr create`）と、PR 本文の標準節を定める。skill 固有の差分（commit type 候補、標準節に加える skill 固有の節）は書かない（呼び出し側の skill 文書が指定する）。検証ゲートの組合せの定義は `docs/harness/skills/shared/verification-gates.md` が担当する。

各 skill / フロー本体は最終 Step で本ファイルを Read し、その手順に従う。

## 手順

以下を順に実行し、最後に PR URL を出力する。タスク毎に既にコミット済みの場合は 2 をスキップして 3 (push) に進む。

1. 検証ゲートを実行する（`gate:commit`。`*.md` の編集だけの変更は `gate:docs`。組合せの定義 → `docs/harness/skills/shared/verification-gates.md`）。`format:check` が NG なら整形を適用してから再検査する
2. `git add`（更新したファイルのみ個別指定）+ `git commit`（Conventional Commits 形式。type は呼び出し側指定）
3. `git push -u origin <current-branch>`（`--no-verify` を付けない。hook が失敗したら原因を直して再実行する。hook が担う検査を迂回すると、CI で初めて赤くなり往復が増えるため）
4. **base ブランチを判定する**（「## base ブランチの判定」に従う）。`$BASE_BRANCH` を得る。
5. **open 前の衝突検査**を行う（「## open 前の衝突検査」に従う）。
6. PR 本文を組み立てる。構成は「## PR 本文の標準節」に呼び出し側が指定する節を加えたものとし、Issue との linkage は「## closing keyword の注入」に従って**決定的に**埋める（placeholder のまま残さない）。
7. `gh pr create --base "$BASE_BRANCH"` で PR を作成する（通常 PR。「## draft にしない」に従う）。直前に「## closing keyword の注入」の self-check を通す。

## base ブランチの判定

このリポジトリの長期統合ブランチは `main` のみである（`main` = dev 環境、`release` = prod 環境。`release` へは prod リリース手順でのみ反映するため、自動 PR の base にはしない）。したがって `$BASE_BRANCH` は常に既定ブランチ（`main`）に固定する。

`gh pr create` は `--base` 未指定でもリポジトリのデフォルトブランチを base に使うが、fetch 失敗や ref 不在で誤った base へ静かにフォールバックすることを避けるため、Step 4 で `origin/main` を fetch し、HEAD との merge-base を計算できることを確認してから `$BASE_BRANCH` を `main` に固定する。計算できなければ PR を作らず、失敗として報告する。原因が shallow clone（`git rev-parse --is-shallow-repository` が `true`）の場合は `git fetch --unshallow` を案内し、それ以外は origin への fetch 権限とネットワーク接続の確認を案内する。

本手順は各フローが共通で参照するため、この 1 ファイルの修正のみで横断的に base 追従が有効になる。base は PR 作成時点のコミットグラフから再計算できるため、各 skill 文書側に起点ブランチ情報をリレーする口は不要。

### 積み上げ PR を作らない

前の PR のブランチを base にする積み上げ PR（直列の後続 PR を前 PR の上に積む運用）は作らない。理由は 2 つある。

- closing keyword は既定ブランチ向けの PR でのみ発火する。base が前 PR のブランチだと、マージ時の Issue の auto-close と Projects の Status 自動更新が効かない。
- 後続 PR の差分が前 PR の変更に依存するため、前 PR がレビューで変わるたびに後続 PR の rebase とレビューのやり直しが発生する。

直列に進める必要がある後続の作業は、前 PR のマージ後に `origin/main` を起点に着手する。マージを待つ間に実装だけ先行する場合も、PR の open は前 PR のマージ後（`origin/main` へ rebase した後）まで保留する。

## open 前の衝突検査

並列に open している他の PR との衝突は、PR を open する前に予測する。衝突が予測される PR は open せず、相手の PR のマージ後に `origin/main` へ rebase してから open する。open 後に衝突が判明すると、レビュー済みの PR が merge できなくなるためである。open を保留した場合は、ブランチを push 済みのまま、保留した事実と相手の PR を完了報告に記載する。

`git merge-tree --write-tree` は git 2.38 以上が前提で、作業ツリーとインデックスを変更しない。git 2.38 未満かどうかは、`git merge-tree --write-tree HEAD HEAD` が成功するかで判定し、未対応の環境では検査を skip して、skip した事実を PR 本文の「リスク」節に書く。

open 中の他 PR の head ブランチ一覧は `docs/harness/skills/shared/gh-query-fail-closed.md` に従って取得し、自分の head ブランチを除く。各 head ブランチ `<b>` について `origin/<b>` を fetch し、`git merge-tree --write-tree --name-only HEAD origin/<b>` で仮マージする。終了コード 0 は衝突なし、1 は衝突ありで、出力の 2 行目から空行までが衝突ファイルである。衝突ありの PR は、ブランチ名と衝突ファイルを列挙する。`origin/<b>` を解決できない PR は、skip して報告する。

## draft にしない

PR は通常 PR（ready for review）で作る。draft の PR は CI 上のレビュー自動化や自動マージ判定の対象外になりやすく、後から ready にする操作が実行環境の権限判定で止められることがある。止められた PR は、人が ready にするまで draft のまま残る。作成経路ごとに次のとおり明示し、ツールの既定値や実行環境の指示に任せない。

| 経路                           | 指定                                                                                       |
| ------------------------------ | ------------------------------------------------------------------------------------------ |
| `gh pr create`                 | `--draft` を付けない                                                                       |
| REST（`gh api`）               | `-F draft=false` を付ける（→ `docs/harness/skills/shared/gh-query-fail-closed.md` 規約 5） |
| MCP（PR 作成 API を持つ tool） | `draft: false` を引数に明示する                                                            |

人間が draft での作成を明示的に指示した場合だけ、その指示に従って draft にしてよい（draft PR を承認 gate として使うのは、人間の明示指示がある場合に限る）。

## PR 本文の標準節

計画・判断の根拠・検証結果は、PR 本文と commit、設計判断としての ADR に残す。PR 本文は次の 5 節を標準とする。該当する内容がない節は、節ごと省かず「なし」と書く（省略した節と、確認し忘れた節を区別できなくなるため）。

```markdown
<linkage 行（Closes #<番号> 等。「## closing keyword の注入」に従う）>

## 背景

## 方針と却下案

## スコープ外

## 検証結果

## リスク
```

| 節           | 書くこと                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 背景         | この変更が必要な理由と、対象の Issue・事象。Issue がある場合は受入条件をチェックリストで引用する                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| 方針と却下案 | 採った方針と理由、退けた案と退けた理由（1 案ごとに 1 行）。選択肢や判断待ちが残っていた Issue でも、確認を求める形にせず確定した案として書く（案の選び方 → `docs/styles/team-feedback/single-solution.md`）。人間はこの記録を PR のレビューで覆せる。人間の確認・判断を求める見出しを置くのは、選んだ案が承認必須 2 種（課金・秘密値）に該当する場合と、`docs/harness/OPERATING_MODEL.md` の「人間引き渡し境界」に定めた区分に該当する場合だけである。複数案からの選択や既存方針の撤回など、設計判断として残すべきものは ADR に記録し、リンクを添える |
| スコープ外   | この PR で扱わなかったことと、その追跡先（Issue 番号）。Issue scope を超える指摘は scope 内で対応せず、ここへ記録する                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| 検証結果     | 実行した検証ゲート（`gate:commit` 等の名前と結果）、追加・変更したテストの要旨、手動確認の内容。未検証の範囲は「未検証: <範囲と理由>」と書く                                                                                                                                                                                                                                                                                                                                                                                                          |
| リスク       | 影響範囲、互換性、問題が出たときの戻し方、残る不確実性。衝突検査を skip した場合はその旨をここに書く                                                                                                                                                                                                                                                                                                                                                                                                                                                  |

### bootstrap / adopt の PR に加える節

repository の立ち上げ（bootstrap）と既存 repository への導入（adopt）の PR は、標準 5 節に次の 2 節を加える。作業中の途中成果（技術選定や実装計画の確定前の内容）も、PR 本文の節として書き、確定した内容を移管先の文書へ移したうえで、節には移管先への参照だけを残す。

| 節                       | 書くこと                                                                                                                                |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| 承認ログ（課金・秘密値） | 承認必須 2 種に該当する操作ごとの、承認依頼の内容・承認者・承認日時・対象。秘密値そのものは書かない（取得場所や投入先の名前だけを書く） |
| 移管先の文書             | 成果物を移した文書のパスの一覧と、各文書へ移した内容の 1 行要約。移管先の規則は bootstrap / adopt の手順に従う                          |

## closing keyword の注入

PR merge 時の Issue auto-close / Projects Status 自動更新は **PR body の closing keyword
（`Closes` / `Fixes` / `Resolves` + `#<num>`）で発火する**。PR title 内の `#<num>` 言及は
GitHub 上のリンク表示はされるが auto-close は発火しない。したがって linkage は title ではなく
body へ確実に注入する。

**前提: closing keyword はリポジトリのデフォルトブランチ（`main`）向け PR でのみ発火する**
（GitHub Docs "Linking a pull request to an issue"）。`$BASE_BRANCH` が `main` 以外になった場合、
body に `Closes #<num>` を含めても merge 時の auto-close は発火しない。この場合は起票元 Issue を
完了させる意図の PR でもケース3 に従う。

- **ケース1（`$BASE_BRANCH=main` かつ起票元 Issue を完了させる通常 PR）**: 着手時に取得した起票元
  issue 番号を使い、body に `Closes #<issue_number>` を記載する。複数 Issue を close する
  場合は `Closes #1, Closes #2` と closing keyword を個別に付ける（`Closes #1 #2` は 1 個目しか
  発火しない）。
- **ケース2（partial PR: 大きな親 Issue の一部のみを対応し、親をまだ close すべきでない）**:
  `Closes #<parent>` は使わず `関連: #<parent>` で linkage のみ残す（auto-close を発火させない）。
  body 冒頭で親 Issue のどの部分を対応したかを明示する。
- **ケース3（`$BASE_BRANCH` が `main` 以外）**: base は常に既定ブランチへ固定されるため、このケースは
  通常発生しない。別の長期統合ブランチ運用を導入した場合に備えた一般手順として残す。その場合 closing
  keyword は発火しないため、起票元 Issue を完了させる意図でも `関連: #<num>` を使い、body 冒頭に
  「auto-close 対象外。Issue close は `main` 統合時または手動で行う」旨を明記する。
- **起票元 Issue が無い保守 PR**（sync 系の定期実行等）: closing keyword は不要。特定 Issue 起点で
  実行した場合のみ `関連: #<番号>` を記載する。
- **self-check（`gh pr create` の直前に実施）**: ケース1 なら body に `Closes #<num>`、
  ケース2 / ケース3 なら `関連: #<num>` が含まれることを確認する。placeholder（番号未記入）の
  状態で PR を作成しない。

## 呼び出し側で指定すべき差分

| 項目             | 内容                                                                                                                                                                                                      |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| commit type 候補 | 各 skill の性質に合った Conventional Commits の type（例: 実装は `feat` / `fix` / `refactor`、ハーネス変更は `feat(skill)` / `refactor(harness)` / `docs(harness)`、環境整備は `chore` / `ci` / `build`） |
| 標準節に加える節 | 検出サマリ、受入条件チェックリスト、設計判断 → ADR リンクなど、skill ごとに必要な節。標準 5 節（背景 / 方針と却下案 / スコープ外 / 検証結果 / リスク）は全 skill 共通で、呼び出し側は節を足すだけにする   |
