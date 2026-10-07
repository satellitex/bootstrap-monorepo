# PR 作成共通手順（base + 衝突検査 + closing keyword 注入 + 本文の標準節）

この文書は PR 自動作成の共通手順（検証 → commit → push → base の確認 → open 前の衝突検査 → 本文の組み立て → `gh pr create`）と、PR 本文の標準節、`gh` が使えない run の書き込み経路を定める。skill 固有の差分（commit type 候補、標準節に加える skill 固有の節）は書かない（呼び出し側の skill 文書が指定する）。検証ゲートの組合せの定義は `docs/harness/skills/shared/verification-gates.md` が担当する。

各 skill / フロー本体は最終 Step で本ファイルを Read し、その手順に従う。

## 手順

以下を順に実行し、最後に PR URL を出力する。タスク毎に既にコミット済みの場合は 2 をスキップして 3 (push) に進む。

1. 検証ゲートを実行する（`gate:commit`。`*.md` の編集だけの変更は `gate:docs`。組合せの定義 → `docs/harness/skills/shared/verification-gates.md`）。`format:check` が NG なら整形を適用してから再検査する
2. `git add`（更新したファイルのみ個別指定）+ `git commit`（Conventional Commits 形式。type は呼び出し側指定）
3. `git push -u origin <current-branch>`（`--no-verify` を付けない。hook が失敗したら原因を直して再実行する。hook が担う検査を迂回すると、`format:check` / `build` の失敗は CI で初めて赤くなって往復が増え、`lint` / `typecheck` / 秘密検知の失敗は CI が実行しないため検出されないまま残り得るため）
4. **base を確認する**（「## PR の base」に従う）。
5. **open 前の衝突検査**を行う（「## open 前の衝突検査」に従う）。
6. PR 本文を組み立てる。構成は「## PR 本文の標準節」に呼び出し側が指定する節を加えたものとし、Issue との linkage は「## closing keyword の注入」に従って**決定的に**埋める（placeholder のまま残さない）。
7. `gh pr create --base main` で PR を作成する（通常 PR。「## draft にしない」に従う）。直前に「## closing keyword の注入」の self-check を通す。

## PR の base

PR の base は常に既定ブランチ（`main`）である。`release` には prod リリース手順（→ `docs/harness/skills/deploy-verify.md`「release 反映（prod）」）でのみ反映するため、自動 PR の base にしない。

`gh pr create` は `--base` 未指定でも既定ブランチを base に使うが、fetch 失敗や ref 不在で誤った base へ静かにフォールバックすることを避けるため、Step 4 で `origin/main` を fetch し、HEAD との merge-base を計算できることを確認する。計算できなければ PR を作らず、失敗として報告する。原因が shallow clone（`git rev-parse --is-shallow-repository` が `true`）の場合は `git fetch --unshallow` を案内し、それ以外は origin への fetch 権限とネットワーク接続の確認を案内する。

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

| 経路                           | 指定                                                  |
| ------------------------------ | ----------------------------------------------------- |
| `gh pr create`                 | `--draft` を付けない                                  |
| REST（`gh api`）               | `-F draft=false` を付ける（→ 本書「書き込みの経路」） |
| MCP（PR 作成 API を持つ tool） | `draft: false` を引数に明示する                       |

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

PR merge 時の Issue auto-close と Projects の Status 自動更新は、PR body の closing keyword で発火する。PR title の `#<num>` では発火しないため、linkage は title ではなく body へ確実に注入する。PR の base は常に既定ブランチなので、発火の条件は満たされる。keyword の文法・複数 Issue の書き方・NG / OK は `docs/styles/team-feedback/pr-closing-keyword.md`「How to apply」に従う。

- **通常 PR（起票元 Issue を完了させる）**: 着手時に取得した起票元 Issue 番号から、body に `Closes #<issue_number>` を記載する。
- **partial PR（大きな親 Issue の一部のみを対応し、親をまだ close すべきでない）**: `関連: #<parent>` で linkage のみ残す（`Closes` は使わない。記載の作法 → 同「How to apply」）。
- **起票元 Issue が無い保守 PR**（sync 系の定期実行等）: closing keyword は不要。特定 Issue 起点で実行した場合のみ `関連: #<番号>` を記載する。
- **self-check（`gh pr create` の直前に実施）**: 通常 PR なら body に `Closes #<num>`、partial PR なら `関連: #<num>` が含まれることを確認する。placeholder（番号未記入）の状態で PR を作成しない。

## 書き込みの経路

GraphQL が使えない run や `gh` が無い run では、読み取りの経路切替（判定表と canary → `docs/harness/skills/shared/gh-query-fail-closed.md` 規約 5）に合わせて、PR 作成・ラベル付与・コメント投稿も同じ run で REST（`gh api`）または MCP に揃える。読み取りだけを切り替えると、最後の書き込みが GraphQL 前提で失敗し、検出済みの成果が PR 化されない。REST に相当する操作がないものは切り替えず、省いたことを完了報告に書く。

REST は次の API で行う。

- PR 作成は `POST /repos/{owner}/{repo}/pulls` に title・head・base・body を渡し、`draft` に偽を明示する。`gh api` の `-F` は `true` / `false` / 整数を JSON の型に変換し、`@<ファイル>` でファイルの内容を値にするため、`draft` と本文のファイルには `-F` を使う（`-f` は常に文字列になる）。応答の `html_url` が PR の URL である。
- ラベル付与は、`GET /repos/{owner}/{repo}/labels/<名前>` で実在を確かめてから `POST /repos/{owner}/{repo}/issues/<N>/labels` に渡す。未作成なら付与せず、名前を報告する。
- コメント投稿は `POST /repos/{owner}/{repo}/issues/<N>/comments` に本文を渡す。

MCP は、PR を作成できる tool（`create_pull_request` 等。tool 名の接頭辞は実行環境が決める）で `draft: false` を明示し、通常 PR で作成する。tool の仕様は版により変わり得るため、使う前に実際のスキーマを確認する。owner / repo は `git remote get-url origin` から解決し、リテラルを埋めない（→ `docs/harness/skills/shared/gh-query-fail-closed.md` 規約 4）。

## 呼び出し側で指定すべき差分

| 項目             | 内容                                                                                                                                                                                                      |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| commit type 候補 | 各 skill の性質に合った Conventional Commits の type（例: 実装は `feat` / `fix` / `refactor`、ハーネス変更は `feat(skill)` / `refactor(harness)` / `docs(harness)`、環境整備は `chore` / `ci` / `build`） |
| 標準節に加える節 | 検出サマリ、受入条件チェックリスト、設計判断 → ADR リンクなど、skill ごとに必要な節。標準節（「PR 本文の標準節」）は全 skill 共通で、呼び出し側は節を足すだけにする                                       |
