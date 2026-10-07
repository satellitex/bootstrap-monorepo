# adr-compress 圧縮規則（カテゴリ別の検出・手順・stub 形式・INDEX 構造）

> この文書は `/adr-compress` が実行する圧縮の規則と形式の正本である。横断のガードレール（Proposed の保護・Decision の保全・in-place・durable-decision・無損失の証明）は、各カテゴリの規則と「抑制条件」に含まれる。起動方法と PR の差分表は `docs/harness/skills/adr-compress.md`、検出・安全ゲート・PR 化のオーケストレーションは `.claude/agents/adr-compactor.md`、PR 本文の形式は `docs/harness/skills/adr-compress/pr-output-format.md` が担当する。ADR の status model・命名・書き方は `docs/adr/README.md` が正本であり、ここには書かない。

## 共通前提

- `<id>`: ADR のファイル名から `.md` を除いたもの（ファイル名の規則 → `docs/adr/README.md`「書き方」）。
- 比較・更新の基準は `origin/main`。ファイルの列挙と本文の取得は `git ls-tree -r --name-only origin/main -- docs/adr/` と `git show origin/main:<path>` で行う。
- `{adr-slug}`: `<id>` を小文字にし、`_` と `.` を `-` に置換した文字列。
- 候補 ID は `{prefix}-{adr-slug}` とする。`{prefix}` は 0 が `status-follow`、II が `stub`、III が `consolidate`、IV が `summarize`。I の候補 ID は `index-rebuild` 固定。候補 ID は人間レビュー用のトレーサビリティであり、open PR ガードの判定キーではない。
- 各候補は検出根拠の実測値（行数・サイズ・Status 値・グループの件数など）を保持する。実測値のない候補は候補にしない。
- stub 本文と要約注記の固定文は project language で書く（正本: `docs/harness/OPERATING_MODEL.md` の言語ポリシー節）。marker は言語に依存しない HTML コメントとし、再検出の抑止と検証はこの marker で行う。
- II / III はファイルを移動せず、同じパスの本文だけを書き換える。ADR への参照は markdown link に限らず、docs・コード・Issue 本文にファイル名の直書き（bare-id）でも存在しうる。パスを変えなければ、相互リンクと外部参照が構造的に保たれる。`archive/` ディレクトリは作らない。

## Status の読み取り

Status の表記は揺れうるため、次の手順で正規化する。

1. 次の 4 形から Status 値を取り出す。上から順に探し、最初に見つかったものを使う。
   - 表の `Status` 行（`| Status | Accepted |`）
   - `## Status` 節の最初の非空行
   - `- Status:` で始まる箇条書き
   - 太字の Status 行（リンクを含む形を含む）
2. 装飾（太字・バッククォート・リンク記法）を外し、先頭のキーワードを取る。後続の付記（`by ADR-...`、適用範囲の括弧書き）は保持する。
3. 大文字小文字を無視し、Proposed / Accepted / Deprecated / Superseded のいずれかに一致させる。
4. 一致しない場合、またはキーワードが複数並ぶ場合（テンプレートの選択肢が未記入のまま残っている等）は、`status-unparseable` として Proposed 相当に扱う。0 / II / III / IV の対象から外し、PR 本文に記録する。

## 圧縮の実行順とカテゴリの所有

実行順は 0 → II → III → IV → I とする。本体の変更（0 / II / III / IV）をすべて適用したあとに、最終状態に対して I を 1 回実行する。1 つの ADR が II / III / IV の複数に該当する場合は、II > III > IV の優先順位で 1 つのカテゴリだけが本体を所有する。0 は Status 値だけを変える操作であり、所有の競合に入らない。

0 を適用して Accepted になった ADR は、同じ run の II / III / IV の判定でも Accepted として扱う。Proposed の ADR を II / III / IV の対象外とするガードに対する、0 だけの例外である。

## カテゴリ 0: Status 追従（lossless）

**根拠**: ADR 起票 PR は Status を Proposed にして出し、未確定のままマージしない（`docs/adr/README.md`）。そのため、ADR ファイルが `origin/main` に存在すること自体が、追加した PR のマージ済みの構造的な証拠になる。判定に GitHub API は使わず、`git ls-tree` と `git show` だけで行う。

- **検出**: `origin/main` 上で、Status が正規化後に Proposed と判定できた ADR 全件。件数の上限と抑制条件は設けない。`status-unparseable` は対象にしない（未分類を Accepted に書き換えないため）。
- **手順**: Status 値の文字列だけを `Accepted` に置換する。検出した表面形（表・節・箇条書き）を保ち、Date など他のセルと表の整形は変えない。
- **保証する範囲**: マージ済みという機械的な事実だけである。決定が今も有効かどうかと、後継 ADR による Superseded 化の漏れは対象外とする（置換関係の Status は、置換を行う PR が同時に更新する。規約は `docs/adr/README.md`、手順は `docs/harness/skills/create-adr.md`）。
- **idempotency**: 置換後は Accepted になるため、次回の run で再検出されない。
- 保留したい ADR は PR を未マージのまま置く。保留を表す Status や marker は定義しない。
- routine が未登録の間は Proposed が残る。`/adr-compress` を手動で実行すると同じ結果になる。

## カテゴリ I: INDEX 再構築（lossless）

`docs/adr/INDEX.md` を書くのは本 skill だけである（更新主体の割当と経過措置は `docs/harness/skills/shared/index-writer-policy.md`）。実装 PR は INDEX を変更しないため、行は ADR 本体（leaf）から起こす。leaf は冒頭に H1 見出しと Status 表を持つ。

**canonical 構造**:

```markdown
# ADR INDEX

> （INDEX の役割を述べる 2 行の注記。既存の文言を保つ）

## 現行 ADR

### Accepted（確定した決定）

| ADR | 要旨 | Date |
| --- | ---- | ---- |

### Proposed（PR レビュー中・未確定）

| ADR | 要旨 | Date |
| --- | ---- | ---- |

## アーカイブ

### Superseded / Deprecated（無効化済み）

| ADR | 要旨 | 後継 / 無効化理由 |
| --- | ---- | ----------------- |

### プロセス記録（durable-decision を含まない手続き記録）

| ADR | 要旨 | Date |
| --- | ---- | ---- |
```

各表は見出し行と区切り行のあとに ADR 1 件 1 行を置く。表の列幅の整形はフォーマットの適用（`docs/harness/skills/shared/verification-gates.md`）に任せ、行は最小形で書いてよい。

**分類**（Status と marker から決定的に決める）:

| 条件（上から順に判定し、最初に合致した行を使う）       | 配置先                               |
| ------------------------------------------------------ | ------------------------------------ |
| marker `adr-compress:process-record` を持つ            | アーカイブ / プロセス記録            |
| Status が Accepted                                     | 現行 / Accepted                      |
| Status が Proposed、または `status-unparseable`        | 現行 / Proposed                      |
| Status が Superseded / Deprecated（stub 化済みを含む） | アーカイブ / Superseded / Deprecated |

**行の形式**: `| [<id>](./<id>.md) | <要旨> | <Date または 後継 / 無効化理由> |`。セルは 3 つ（区切りの `|` は行頭と行末を含めて 4 個）で、要旨に `|` を含めない。行は `<id>` の昇順に並べる。

- **要旨**: 既存行の要旨はそのまま保つ（未変更のコーパスで diff を出さないため）。既存行がない ADR は、H1 のタイトル（`ADR-...:` の接頭辞を除く）を基本にし、タイトルだけでは決定内容が分からない場合に `## Decision` 節の先頭 1 文を続ける。150 文字以内で、ADR 本体に書かれていない事実を補わない。
- **Date**: Status 表の Date 行の値。
- **後継 / 無効化理由**: Superseded は後継 ADR へのリンク、Deprecated は無効化理由の 1 句（stub 化済みの場合は stub のポインタから取る）。

**file ↔ 行のペアリング**: 実ファイルと INDEX の各行を、第 1 セルのリンク先のファイル名の完全一致で対応づける（行の文章全体から id を拾うと、存在しない ADR の行が残る）。ファイルがあって行がないものは再構築で追加し、行があってファイルがないもの（phantom）は除外する。どちらも PR 本文の「INDEX drift」に記録する。

**構造アサート**: 再構築後に、4 つの表が canonical 構造どおりに存在すること、各行のセルが 3 つであること、すべての ADR ファイルがちょうど 1 回現れることを確認する。

**idempotency**: 本体が変わらず、既存行が保たれるため、未変更のコーパスでは出力が同一になり diff が出ない。

## カテゴリ II: アーカイブ in-place stub 化（lossless）

対象は、(a) Status が Superseded / Deprecated の ADR と、(b) プロセス記録（手続きの経緯だけを記し、恒久的な設計判断を含まない ADR）。Proposed と `status-unparseable` は対象にしない。本体を同じパスのまま stub に置換する。

### II-a: Superseded / Deprecated

full か partial かを次の順で判定する。有効な Decision が残る ADR を full stub にすると、その Decision と再評価のきっかけが失われるため、partial の条件を広く取る。

1. Status の付記に適用範囲の限定（`D3 のみ`、`部分`、`partial` など）があれば partial。
2. 限定がなくても、後継 ADR が元の各 Decision を全文で再記述していなければ partial。後継の 1 行要約は全文の継承と見なさない。
3. 判定できなければ partial。

full は full stub に置換する。partial は有効な Decision を原文のまま全件保持する Decision 保持圧縮形にする。

### II-b: プロセス記録

レビューループの記録や一括修正作業の記録など、手続きの経緯だけを記した ADR をプロセス記録 stub に置換する。

**durable-decision ガード**: ファイル名や体裁がプロセス記録らしくても、本文に恒久的な設計判断（採用方針の選定、代替案の棄却理由、継続的に効くスコープや原則）を含む ADR は stub にしない。IV の閾値を満たせば IV、満たさなければ無変更とし、`durable-decision` として記録する。

### stub の形式

stub は最低限、(1) 元のタイトル、(2) Status と後継または解決先へのリンク、(3) 本文は git 履歴を参照する旨、(4) 再 stub 化を防ぐ marker を含む。

full stub（20 行以内。Deprecated の場合は Status を `Deprecated` にし、後継の代わりに無効化理由を 1 文書く）:

```markdown
# <元のタイトル>

| 項目   | 値                                                          |
| ------ | ----------------------------------------------------------- |
| Status | Superseded by [ADR-<successor-id>](./ADR-<successor-id>.md) |
| Date   | <元の Date>                                                 |

本文は圧縮済みである。元の本文と決定の経緯は git 履歴を参照する（`git log --follow -- docs/adr/<id>.md`）。

<!-- adr-compress:stub -->
```

partial の Decision 保持圧縮形:

```markdown
# <元のタイトル>

| 項目   | 値                                                   |
| ------ | ---------------------------------------------------- |
| Status | Superseded by ADR-<successor-id>（<置換された範囲>） |
| Date   | <元の Date>                                          |

<`## Superseded（日付）` または `## Deprecated（日付）` の節があれば原文のまま保持する>

## Decision

<有効な Decision を原文のまま全件保持する>

Context と Consequences は圧縮済みである。省略した詳細は git 履歴を参照する。

<!-- adr-compress:already-compressed-partial -->
```

プロセス記録 stub（15 行以内）:

```markdown
# <元のタイトル>

| 項目   | 値            |
| ------ | ------------- |
| Status | <元の Status> |
| Date   | <元の Date>   |

手続きの記録であり、恒久的な設計判断を含まない。<何の記録かを 1 文>。本文は git 履歴を参照する。

<!-- adr-compress:process-record -->
```

**idempotency**: marker を持つ ADR は再 stub 化しない。ファイルを移動しないため、移動と再検出の往復も起きない。

## カテゴリ III: 同一 Issue の統合（opt-in・Decision 全保持）

`/adr-compress consolidate` で起動したときだけ実行する。「1 ADR = 1 決定」の規約を変える操作のため、既定では無効である。

- **検出**: 同一グループの ADR が 3 件以上で、全件が non-Proposed。グループのキーは、`{branch-slug}` に Issue 番号を含む命名規約ではその番号、含まない規約では `{branch-slug}` 自体とする。
- **手順**: 各 Decision を節に分けて 1 つの consolidated ADR に統合する。ファイル名は README の規則に従い、`{branch-slug}` を `consolidated`、`{topic-slug}` をグループのキーにする。Status は Accepted、Author は `adr-compactor (consolidation)`。原本は同じパスのまま `Superseded by ADR-<consolidated-id>` の stub にする（形式は II の full stub に従う）。
- 元の各 Decision とその根拠を 1 つも落とさない。落ちる場合は候補から外す。

## カテゴリ IV: 本文の要約圧縮（lossy）

**検出**: ADR 本体が 400 行を超える、または 18KB を超え、かつ non-Proposed で stub ではないもの。

**要約の規則**:

- 圧縮前に `## Decision` 節がちょうど 1 つあることを確認する。0 個または複数なら IV を見送り、`cannot-prove-lossless` として記録する。
- `## Decision` 節と `## Related Issues` 節は 1 文字も変えない。要約するのは Context と Consequences だけにする。
- 削ってよいもの: 重複する Context、レビューの往復ログ、のちに Superseded になった検討途中の叙述。
- 削らないもの: `## Decision` 節の全文、採用した設計、`## Related Issues` 節、本文中の相互参照（ADR id・リポジトリ内パス・Issue / PR 番号・要件 ID）、Status の値。
- 要約した ADR の末尾に、marker `<!-- adr-compress:summarized -->` を含む 1 行の注記を置き、削除した詳細を git 履歴で追えることを書く。

**機械検証**: 要約した ADR ごとに、要約を始める直前の内容を退避し、要約後に検証スクリプトを実行する。0 を適用済みの ADR は、その Status 置換を含む内容を退避する（Status の不変を、0 の変更と切り分けて判定するため）。

```bash
cp docs/adr/<id>.md "$TMPDIR/<id>.before.md"
# 要約を適用する
node tests/harness/check-adr-compression-lossless.mjs "$TMPDIR/<id>.before.md" docs/adr/<id>.md
```

スクリプトは次を判定し、1 つでも満たさなければ非 0 で終了する。

1. `## Decision` 節が空白を正規化したうえで前後で逐語一致する。
2. `## Related Issues` 節が要約前にあれば、逐語一致する。
3. 要約前に現れた相互参照が要約後にもすべて残る。
4. Status の値が変わらない。
5. 要約後のサイズが要約前より小さい。

注記行は marker `adr-compress:summarized` で識別して比較から除く。非 0 で終了した ADR は、退避した内容を書き戻して要約を破棄し、`cannot-prove-lossless` と失敗内容を PR 本文に記録する。スクリプトが存在しない、または実行できない場合も同じ扱いにする。無人 run では前後を読み比べる人がいないため、無損失を証明できない要約は出さない。通過した ADR は要約前後の行数とサイズを PR 本文の証拠表に載せる。

**idempotency**: 要約済みの ADR は閾値を下回るため再検出されない。

## 抑制条件

次に該当する候補は実行せず、理由を記録して PR 本文の「スキップした候補」に載せる。

| 条件                                            | 対象          | 記録する理由                              |
| ----------------------------------------------- | ------------- | ----------------------------------------- |
| Status が Proposed、または `status-unparseable` | II / III / IV | `status-unparseable`（Proposed は無記録） |
| 有効な Decision が 1 つでも落ちる               | II / III / IV | `decision-at-risk`                        |
| 恒久的な設計判断を含むプロセス記録らしい ADR    | II-b          | `durable-decision`                        |
| marker を持つ（圧縮済み）                       | II / IV       | `already-compressed`                      |
| 無損失を証明できない                            | IV            | `cannot-prove-lossless`                   |
| 検出根拠の実測値がない                          | 全カテゴリ    | 候補にしない                              |
