# gh 照会の fail-closed 規約（search 経路の排除 + 疎通 canary + 経路の切替）

この文書は GitHub の list 照会結果を「0 件」で分岐するハーネスが無言に壊れないための共通規約と、GraphQL が使えない run・`gh` が無い run で REST / MCP 経路へ切り替える規則を定める。個別 skill の照会手順・PR / Issue の作成手順は書かない（各 skill 文書と `docs/harness/skills/shared/pr-creation.md` が担当）。

各参照元は自分の照会手順で本ファイルを Read し、その規約に従う。

## 規約 1: list 照会に search 系フィルタ（`--search` / `--label` / `--milestone`）を使わない

`gh issue list` / `gh pr list` にこれらのフラグを付けた形式は GraphQL の search connection 経由で解決される。
search connection は **リポジトリのリダイレクト（owner 変更・リネーム）を解決せず、エラーにもならず
exit 0 + `[]` を返す**。空の結果を「該当なし」と解釈する側は、照会経路が壊れたことに気付けない。

| 経路 | 移管・リネーム済み repo を旧 slug で照会したときの挙動 |
|------|------|
| `gh pr list` / `gh issue list`（フィルタなし）・`gh * view`・`gh api repos/...`・GraphQL `repository(owner:)`・git remote | リダイレクトを追う（正しい結果） |
| `gh pr list` に `--search` / `--label`、`gh issue list` に `--search` / `--label` / `--milestone` を付けた形式 | **追わない。exit 0 + `[]`（無言）** |
| REST `search/issues` | HTTP 422 で hard fail（無言ではない） |

したがって list 照会は **フィルタなしの list + `--json` + ローカル絞り込み**で書く。これで照会が
owner 文字列にも依存しなくなり、次回の移管・リネームでも壊れない。

**短縮形も同じ扱い**。`-l` / `-S` / `-m` はそれぞれ long form と同一の search connection に落ち、
同じく exit 0 + 空配列を返す。取得上限の短縮形 `-L` は正規の `--limit` と同じで問題ない。

**本規約の対象は list 照会のみ。** `gh issue create --milestone` / `gh issue edit --milestone` /
`gh pr edit --add-label` 等の書き込み系は番号やタイトルの解決に失敗すると**非ゼロ終了する**
（無言にならない）ため、フラグをそのまま使ってよい。

## 規約 2: 0 件を「該当なし」と解釈する前に疎通 canary を通す（fail-closed）

規約 1 を守っても「照会経路の異常（認証失効・API 障害・スコープ不足・リダイレクト未解決）」と
「本当に 0 件」は区別できない。0 件を分岐条件に使う手順は、**照会経路そのものが生きていること**を
canary で先に確かめ、canary が落ちたら**該当なしとして先へ進まず、その場で異常として停止する**。

canary は**絞り込み条件から独立**させる（= 絞り込み後の件数を canary にしない）。絞り込み後の集合は
正当に空になり得るため、それを canary にすると健全な「0 件」で誤停止する。`--state all --limit 1` の
最小照会が 1 件返ることを見るのが最も安価で、絞り込み結果と直交する:

```bash
# 疎通 canary（fail-closed）: 照会経路が生きているかだけを見る。絞り込み条件を混ぜない。
[ "$(gh issue list --state all --limit 1 --json number --jq 'length')" -eq 1 ] || {
  echo "ERROR: issue 照会経路の疎通 canary が失敗。0 件を該当なしと解釈せず停止する" >&2
  exit 1
}
```

- canary が落ちたとき、何もしない（起票も PR 作成もラベル操作もしない）だけでは不十分。
  「異常で停止した」ことを stdout に出し、非ゼロ終了 or 明示的な失敗報告で終わる。
- `gh pr list` 側の canary は `gh pr list --state all --limit 1 --json number` を使う。
- 限界: issue / PR が 1 件も存在しない新規リポジトリでは canary が誤検知する。その場合だけ、
  対象リポジトリに合わせて canary の対象を存在が保証される別の照会に差し替える。
- **MCP 等ページング API 経路では canary だけでは足りず、全ページ取得の完了確認が必要**。
  canary は「経路が生きている」ことしか示さず、途中で切り詰まった集合を「該当なし」に化けさせる
  truncation fail-open を防げない。ページング API（`perPage` 上限あり）では `perPage` を上限値にして、
  tool のページング方式（カーソル / ページ番号）に従い、**返却件数が `perPage` 未満になるまで**連結してから
  絞り込む（CLI の `--limit` に相当する保証をページングで作る）。方式と search 系 tool の扱いは
  規約 5 の「MCP 経路」に従う。

## 規約 3: `--limit` の打ち切りを検知する

`gh pr list` / `gh issue list` の取得上限（`--limit`。省略時の既定は 30 件）を超えた分は
**無言に切り捨てられる**。絞り込み前の集合が切り詰まると、絞り込み後の「0 件」が信用できなくなる。

- `--limit` は想定件数より十分大きく取る（例: 1000）。
- **絞り込み前の生 JSON を一度変数に受け**、取得件数が `--limit` に達していないことを確認してから
  ローカルで絞り込む。達していたら「該当なし」に倒さず、`--limit` を上げて再取得する
  （実装形は `docs/harness/skills/shared/sync-pr-flow.md` §1 のスニペットを参照）。
- `--jq` で直接絞り込むと絞り込み前の件数を観測できないため、この検査ができない。

## 規約 4: `--repo <owner>/<repo>` を直書きしない

owner を直書きした箇所は移管・リネームのたびに全件手当てが必要になり、漏れが規約 1 の無言故障に化ける。

- リポジトリの作業ツリー内で実行する前提にし、`--repo` を**付けない**（git remote 由来で解決される）。
- `gh api` は `repos/{owner}/{repo}/...` の**プレースホルダ**を使う（gh が remote から解決する）。
- MCP 等 owner / repo を引数で要求する経路では、値を
  `git remote get-url origin`（作業ツリーの origin remote。`gh` が使える環境では
  `gh repo view --json nameWithOwner --jq .nameWithOwner`、CI では `$GITHUB_REPOSITORY` でもよい）から取り、
  リテラルを埋めない。同一 repo 内の PR を指す `head` に `<owner>:<branch>` 形式は不要で、`<branch>` だけでよい。
- 例外: GitHub Projects V2 の `--owner <org>` は **Project を所有する org** を指し、リポジトリの
  owner ではない（Project は org 所有物でリポジトリ移管では移動しない）。この用途の owner は
  書き換えず、リポジトリ owner ではない旨をコメントで明示する。

## 規約 5: GraphQL が使えない run・gh が無い run は経路を切り替える

実行基盤によっては、`gh` の `--json` 照会や PR 作成が内部で使う GraphQL が無効なセッションがある。`gh` が導入・認証されていない実行環境もある。この状態で規約 2 の canary が落ちると、run は毎回異常終了する。切り替えは 2 段で判断する: 失敗メッセージが下の判定表に一致するときだけ切替を試し、代替経路の canary が通ったときだけ切り替える。どちらかを満たさない失敗（認証失効・ネットワーク断・表にない API 障害）は、経路の問題と読み替えず、規約 2 に従って異常として停止する。

### 判定表

失敗メッセージは部分一致・大文字小文字を区別せずに判定する。

| 症状 | 判定に使う文字列・条件 | 切替先 |
|------|-----------------|--------|
| GraphQL が無効なセッション | `This GraphQL query is not enabled` | REST（`gh api`） |
| rate limit（GraphQL 側の枯渇を含む） | `rate limit` | REST（GraphQL と REST は別の rate limit のため、REST の canary で再判定する） |
| 権限・scope の不足 | `Resource not accessible by integration` / `missing required scopes` | REST（REST の canary も落ちるなら停止する） |
| `gh` が無い | `command not found: gh` / `gh: command not found` | MCP |
| `gh` が未認証 | `gh auth status` が非ゼロ終了 | MCP |

- 文字列は GitHub と `gh` の版により変わり得る。GitHub の公式 docs は rate limit 超過時のメッセージ本文を規定せず、HTTP ステータス（403 / 429）と `x-ratelimit-remaining` ヘッダで示すため、rate limit は文字列と併せてそれらでも確認する。導入先は実機で観測した文字列を表へ追記する。
- 経路の選択は run の開始時に `command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1` で行う。`command -v gh` だけで判定すると、導入済みで未認証の `gh` を gh 経路に倒したまま停止させるため、`gh auth status` までを 1 つの条件とする。成功すれば gh 経路、失敗すれば MCP 経路に進む。

### REST 経路

GraphQL 版 canary（`--json` の多くのフィールドは GraphQL で解決される）の代わりに、`--json` を使わない REST の一覧照会で疎通を確認する。絞り込み条件から独立させる原則は規約 2 と同じである。応答が配列であることも合わせて確かめるのは、非 2xx 応答のエラーボディが件数 1 のオブジェクトと誤読されないようにするためである。

```bash
gh api 'repos/{owner}/{repo}/pulls?state=all&per_page=1' | jq -e 'type == "array" and length == 1' >/dev/null || {
  echo "ERROR: PR 照会経路の疎通 canary が失敗（REST）。0 件を該当なしと解釈せず停止する" >&2
  exit 1
}
```

Issue 側は `repos/{owner}/{repo}/issues?state=all&per_page=1` に読み替える。canary が通ったら、次の規則で切り替える。

- 読み取りだけでなく書き込み（PR 作成・ラベル付与・コメント）も同じ run で REST に揃える。読み取りだけを切り替えると、最後の書き込みが GraphQL 前提で失敗し、検出済みの成果が PR 化されない。
- REST で取得する照会にも規約 2・3 を適用する。終了コードと応答の型を検査し、`--paginate --slurp` で全ページを 1 個の配列にまとめてから絞り込む（`--slurp` は `--jq` と併用できないため、絞り込みは外部の `jq` へパイプする）。
- REST に相当する操作がないもの（Projects V2 への追加など）は切り替えず、省いたことを完了報告に書く。
- `-F` は `true` / `false` / 整数を JSON の型に変換し、`@<ファイル>` でファイルの内容を値にする。`key[]=値` は配列になる。

sync 系の手順が使う操作の対応表（GraphQL 前提の形 → REST）:

| 操作 | `gh` の形 | REST の形 |
|------|-----------|-----------|
| 疎通 canary | `gh pr list --state all --limit 1 --json number` | 上記の REST canary |
| open PR の一覧（head ブランチで絞り込み） | `gh pr list --state open --limit 1000 --json number,url,headRefName` | `raw="$(gh api 'repos/{owner}/{repo}/pulls?state=open&per_page=100' --paginate --slurp)"` を受け、終了コードと `jq -e 'all(.[]; type == "array")'` で型を確かめてから `jq '[.[][] \| select(.head.ref \| startswith("<prefix>"))]'` で絞る（`headRefName` は `head.ref`、`url` は `html_url`） |
| PR 作成 | `gh pr create --base <base> ...` | `gh api -X POST 'repos/{owner}/{repo}/pulls' -f title=<題名> -f head=<ブランチ> -f base=<base> -F body=@<本文ファイル> -F draft=false --jq .html_url` |
| ラベル付与 | `gh pr edit <N> --add-label <名前>` | ラベルの実在を `gh api 'repos/{owner}/{repo}/labels/<名前>'` で確かめてから `gh api -X POST 'repos/{owner}/{repo}/issues/<N>/labels' -f 'labels[]=<名前>'`。未作成なら付与せず、名前を報告する |
| コメント投稿 | `gh pr comment <N> --body-file <ファイル>` | `gh api -X POST 'repos/{owner}/{repo}/issues/<N>/comments' -F body=@<本文ファイル>` |

### MCP 経路

`gh` が使えない run では、PR / Issue を扱える MCP tool（`issue_read` / `pull_request_read` / `list_issues` / `list_pull_requests` / `create_pull_request` 等。tool 名の接頭辞は実行環境が決める）で同じ操作を行う。tool の仕様は版により変わり得るため、使う前に実際のスキーマを確認する。MCP 経路が無い run は、規約 2 に従って異常として停止する。

- owner / repo は `git remote get-url origin` から解決し、tool の引数にリテラルを埋めない（規約 4 と同じ理由）。
- canary は、既知の実在する Issue / PR を `get` できること、または `list_issues`（絞り込みなし・`perPage: 1`）が要素数 1 の配列で応答することで満たす。「エラーにならない」だけでは、0 件の応答を経路の生存の証拠にしてしまうため足りない。
- `search_issues` / `search_pull_requests` は、あいまい一致の検索であり、0 件を「該当なし」と読む厳密な判定に使えない。list 系の tool を使い、ローカルで絞り込む。
- list 系の tool はページング方式が tool ごとに異なる（`list_issues` はカーソル方式で `pageInfo.endCursor` を `after` へ渡して進め、`list_pull_requests` はページ番号方式である）。方式はスキーマで確認し、返却件数が `perPage` 未満になるまで連結してから絞り込む。
- ページ取得の途中でエラーが返ったときは、件数を報告せず停止する。総件数との突合は行わない（応答に対象総数を示すフィールドがないため。網羅性は「返却件数が `perPage` 未満になるまで連結した」ことだけで判定する）。
- PR は `draft: false` を明示して通常 PR で作成する（`docs/harness/skills/shared/pr-creation.md`）。

## 実装スニペット（plain list + ローカル絞り込み）

| 目的 | 旧（search 経路・無言故障） | 新（plain list + ローカル絞り込み） |
|------|---------------------------|--------------------------------|
| ラベル絞り込み | `--label "<name>"` | `--json number,labels` + `jq '[.[] \| select(any(.labels[]?; .name == "<name>"))]'` |
| マイルストーン絞り込み | `--milestone "<title>"` | `--json number,milestone` + `jq '[.[] \| select(.milestone.title == "<title>")]'` |
| head ブランチ絞り込み | `--search 'head:<prefix>'` | `--json number,headRefName` + `jq '[.[] \| select(.headRefName \| startswith("<prefix>"))]'` |

補足の設計原則:

- **並び順キーが絞り込みキーを支配する経路を選ぶ**。取得上限のある list は「並び順の先頭 N 件」の
  切り出しであり、絞り込みキーが並び順キーと別物だと、窓の外に並んだ該当項目が取得集合に入らず
  無言に落ちる。時刻範囲などで絞る場合は、絞り込みキー以上の値を持つ並び順キー（例:
  `merged_at <= updated_at`）でページングし、並び順キーが窓の開始を下回る地点への到達で網羅を証明する。
- **ページ取得の結果は「終了コード」と「型」を先に検査する**。`gh api` は非 2xx で非ゼロ終了する一方で
  エラーボディを stdout に出すため、未検査だと後段の件数判定がエラーオブジェクトのキー数を「件数」と
  読み、照会エラーが「汲み尽くした」= 網羅の証明に化ける。応答が JSON 配列であることも
  `jq -e 'type == "array"'` で確認する（空ボディでは件数が空文字になり数値比較が誤って真になる）。
- **時刻の大小比較は jq 内で行う**。`[ "$a" \< "$b" ]` は bash では文字列比較として通るが
  zsh では構文エラーになり、`|| exit 1` 側に落ちて健全な実行が止まる。
- **`gh` の `--jq` は jq CLI のフラグを取れない**（`--arg` 等は使えない）。シェル変数を jq に渡す場合は
  `gh ... --json ... | jq --arg b "$b" '...'` と外部 jq にパイプする。
