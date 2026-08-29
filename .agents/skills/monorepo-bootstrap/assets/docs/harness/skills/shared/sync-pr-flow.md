# Sync 系共通後段フロー（ブランチ・commit・PR 作成）

この文書は sync 系 skill が検出「あり」の場合に共通で実行する「既存 open PR ガード → ブランチ作成 → commit → PR 作成」を定める。検査手順そのもの・検出 0 件時の終了（`docs/harness/skills/shared/sync-prelude.md` 担当）・PR body の中身（各 skill 文書の差分テーブルが指定）は書かない。

前提: 本フローに入る時点で検出結果は非空である（0 件時は sync-prelude の規約で既に終了している）。
skill 固有の差分（変更なしメッセージ、ブランチ slug、`git add` 対象、commit message、PR title / body 構成）は
呼び出し側 skill 文書の差分テーブルが指定する。

## 1. 既存 open PR ガード（ブランチ作成前）

ブランチを切る前に、「呼び出し側の差分テーブルが指定するブランチ名から日付部分を除いた prefix」
= `agent/<skill名>`（日付・末尾ハイフンを含めない）で既存 open PR の**存在**を確認する
（候補 ID・変更ファイル集合等による内容の包含判定ではなく、存在判定のみ）。

**疎通 canary（fail-closed）**: 絞り込みと直交した最小照会で照会経路の生存を先に確認する。
canary が落ちた場合、「既存 open PR なし」に倒さず**照会経路の異常として非ゼロ終了**する
（`docs/harness/skills/shared/gh-query-fail-closed.md` 規約 2）:

```bash
[ "$(gh pr list --state all --limit 1 --json number --jq 'length')" -eq 1 ] || {
  echo "ERROR: PR 照会経路の疎通 canary が失敗。既存 open PR なしと解釈せず停止する" >&2
  exit 1
}
```

canary 通過後、**絞り込み前の生 JSON を一度変数に受けてから**ローカルで絞り込む。`--jq` で
直接絞り込むと出力が絞り込み後の配列になり、**絞り込み前の取得件数が `--limit` に達したか
（打ち切りが起きたか）を観測できない**ため:

```bash
raw="$(gh pr list --state open --limit 1000 --json number,url,headRefName)"

# 打ち切り検知: 取得件数が --limit に達していたら絞り込み前に PR が落ちている可能性がある。
# 「既存 open PR なし」に倒さず、--limit を上げて再取得する。
[ "$(jq 'length' <<<"$raw")" -lt 1000 ] || {
  echo "ERROR: 取得件数が --limit に達した。--limit を上げて再取得する" >&2
  exit 1
}

jq '[.[] | select(.headRefName | startswith("agent/<skill名>"))]' <<<"$raw"
```

- **絞り込み結果が 1 件以上**: 既存 open PR がこの skill の未マージ成果を表す。ブランチも
  commit も PR も作らず、**本共通フロー（§2 以降）を実行せずに戻る**（**異常ではなく正常終了**）。
  呼び出し側 skill 文書に PR 作成より後の Step がある場合は、**その Step は必ず実行する**
  （見送るのは PR 作成までであり、skill 全体ではない）。呼び出し側指定の「変更なしメッセージ」
  は出さない（変更は実在するため嘘になる）。既存 PR の番号・URL と今回の検出件数を stdout に
  報告する。呼び出し側が検出フェーズで既に編集を適用済みの場合、その編集は commit / push しない。
  作業ツリーの復旧は次の条件付きで行う:
  - **実行開始時点で作業ツリーが clean だったことを確認できる場合のみ**、呼び出し側の差分テーブルが
    指定する `git add` 対象パスに限定して `git restore -- <path...>` する
  - **確認できない場合は復旧しない**。`git restore` はパス単位でしか戻せず、自動編集の hunk と
    人間の未コミット変更を区別できないため、同じファイルに人間の作業があると**それを回復不能に
    破棄する**。この破壊を避けることを、下記の混入リスクより優先する
  - 復旧しなかった場合は、**未 commit の編集が残っている旨と対象パスを stdout に明示する**。
    残したままにすると、編集が checkout 中のブランチに残り、次回実行や別フローの `git add` で
    無関係な PR に混入し得るため、人間が気付けるようにする
- **絞り込み結果が 0 件**: 次節（§2. ブランチ作成）に進む。

見送った検出は origin/main からの再導出のため、既存 PR がマージ / クローズされた後の次回実行で必ず
再検出される（**lossless な deferral**）。既存 PR ブランチへの追加コミットは (i) レビュー状態を
無言に無効化し (ii) 古い基点に新しい基点の編集を積んで diff の意味を壊すため行わない。

## 2. ブランチ作成

`git switch -c agent/<skill名>-{YYYY-MM-DD} origin/main` で `origin/main` 基点のブランチを切る
（`YYYY-MM-DD` は実行日）。同名ブランチが既に存在する場合は `-2` 等のサフィックスで別名にする。
これは同日再実行時のブランチ名衝突を避けるためであり、重複 PR の抑止機構ではない（抑止は §1 が担う）。

## 3. commit / push

1. 呼び出し側 skill 文書が定める編集を適用する
2. 更新したファイルのみ `git add` する（`git add -A` 等の広域指定禁止）
3. Conventional Commits 形式で commit する（メッセージは呼び出し側指定）
4. `git push -u origin <branch>`（**`--no-verify` 禁止**。CI 同等の事前チェックは
   `.claude/hooks/pre-push-ci-check.sh` が push 時に自動実行する。検証コマンドの定義は
   `docs/harness/skills/shared/verification-gates.md` を正本とする）

## 4. PR 作成

`gh pr create` で**通常 PR** を作成する（base の判定は `docs/harness/skills/shared/pr-creation.md`
に従う。`--draft` は使わない）。title / body は呼び出し側 skill 文書の差分テーブルに従う。
起票元 Issue が無い保守 PR のため closing keyword は不要（特定 Issue 起点で実行した場合は
body に `関連: #<番号>` を記載する）。PR 作成後、PR URL を console に報告する。

**1 スキャン = 1 PR**。1 回の実行で検出した全候補を 1 つの PR にまとめ、候補ごとに PR を分けない。
