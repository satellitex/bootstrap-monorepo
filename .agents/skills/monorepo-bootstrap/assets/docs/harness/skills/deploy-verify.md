# deploy-verify — デプロイ一気通貫と release 反映

この文書は `/deploy-verify` の tool-neutral な正本手順の骨格である。具体のステップ表（deploy コマンド・migration・seed・smoke 等）は PJ の deploy 手段が確定するまで placeholder とし、bootstrap 時に具体化する。個別ステップの実行ロジック（正本 runbook・スクリプト）はここに再実装しない。

## 目的

最新取り込みから deploy・検証までを単一フローに集約し、各ステップの成否を明示的に判定（失敗を握り潰さない）する運用 skill。各ステップは PJ の既存タスクランナー・runbook（`docs/runbooks/INDEX.md` から辿る）をラップするだけで、実行ロジックは再実装しない。prod への反映は、main を release へ反映する PR（release 反映 PR）の作成から、マージ後の step 単位の確認までを含む。

## 承認モデル（要旨）

- main = dev 環境 / release = prod 環境のブランチモデルを前提とする。main は壊れても復旧可能な開発環境であり、開発過程ではセキュリティより柔軟性を優先する。
- dev（main）への deploy は自律実行する（人間承認を待たない）。
- prod（release）への deploy のみ手順を踏む: 「release 反映（prod）」節の前提ゲート（main の安全性確認）を満たし、release 反映 PR を作成する。反映の確認は release 反映 PR のマージ 1 か所に置く。マージは人間の操作だが、`--merge` で明示的に指示された場合はマージとマージ後の確認まで行ってよい。
- prod 反映の job に別の承認者（deployment environment の required reviewers 等）を重ねて置かない。承認が二重になり、自己承認を禁じる設定では承認者が不在になりうるため。
- 人間の明示承認が必須なのは次の 2 つのみ: 課金が発生する操作（有償リソースの新規作成・プラン変更）と、秘密値の挿入・変更。deploy フロー中にこれらが必要になった場合は、その操作の直前で停止して承認を得る。無人 run では、その操作を行わず、実施する場合の内容・根拠・影響を成果物に残して人間へ渡し、依存しないステップは続ける。扱いは実行モードによる（→ `docs/harness/skills/shared/unattended-contract.md`）。

## 入力

| 項目            | 必須 | 既定  | 説明                                                                                          |
| --------------- | ---- | ----- | --------------------------------------------------------------------------------------------- |
| 対象環境        | No   | `dev` | `dev`（main）/ `prod`（release）                                                              |
| `--dry-run`     | No   | off   | 各ステップの実行計画のみ提示し、副作用のあるコマンドは実行しない                              |
| `--from <step>` | No   | 先頭  | 途中ステップから再開する。前段が成功済みのときの再実行用                                      |
| `--merge`       | No   | off   | prod のみ。release 反映 PR のマージとマージ後の確認まで実行する。省略時は PR 作成までで止める |

## フロー骨格

```
/deploy-verify [env] [--dry-run] [--from <step>] [--merge]
  ├── 0.   前提検査（env / 認証 / ローカルツール）── 不足なら設定手順を提示して停止
  ├── 0.5  prod のみ: release 反映（R1 反映対象の確定 → R2 前提ゲート → R3 反映 PR の作成
  │        → R4 反映前プレビューの確認 → R5 マージ → R6 マージ後の確認）
  ├── 1..N ステップ逐次実行（下記ステップ表）。prod では R6 でステップの結果を確認する
  │        各ステップ: 実行前にコマンド表示 → 実行 → 終了コード判定
  │        0 以外なら即停止 → 失敗ハンドリング（create-issue 起票）
  └── 完了: 成果サマリを提示
```

各ステップは直前のステップが成功（終了コード 0）した場合のみ次へ進む。失敗したら以降のステップは実行せず「失敗ハンドリング」に遷移する。

## ステップ表（placeholder — bootstrap 時に具体化する）

> TODO(記入方法: PJ の deploy 手段（タスクランナー・CI/CD・ホスティング）が確定したら、以下の表を実コマンドで埋め、各行の「破壊的」欄と env 制約（dev 専用ステップ等）を明記する。行の追加・削除も可)

| Step      | 目的                           | ラップするコマンド / runbook             | 環境     | 破壊的 |
| --------- | ------------------------------ | ---------------------------------------- | -------- | ------ |
| 1 pull    | 最新コードを取り込む           | `git pull --ff-only`（現ブランチ）       | dev/prod | 低     |
| 2 deploy  | ビルド成果物の配備             | TODO(記入方法: PJ の deploy コマンド)    | dev/prod | 高     |
| 3 migrate | DB migration（採用時のみ）     | TODO(記入方法: PJ の migration コマンド) | dev/prod | 高     |
| 4 seed    | 検証用データ投入（採用時のみ） | TODO(記入方法: PJ の seed コマンド)      | dev のみ | 中     |
| 5 smoke   | deploy 先への疎通・smoke 検証  | TODO(記入方法: PJ の smoke 検証コマンド) | dev/prod | 低     |

prod では、`deploy` 以降のステップは release 反映のマージ後（R6）に実行・確認する。release への反映を契機に CI/CD が deploy する PJ では、`deploy` 行は CI の run を指し、本 skill は完了までのポーリングと判定を担う。

## Step 0: 前提検査

副作用のあるステップに入る前に、前提の環境変数・認証・ローカルツールを検査する。不足があれば該当 runbook を参照した設定手順をユーザに提示し、処理を停止する（推測で先へ進めない）。検査項目は PJ の deploy 手段に合わせて具体化する（例: クラウド認証の有効性、コンテナランタイムの起動、`gh auth status`、検証用 `.env` の必須値）。

前提が全て揃ったら、実行計画（対象 env・実行するステップ・スキップするステップとその理由）を 1 度提示してから次へ進む。`--dry-run` の場合はここで各ステップの計画提示のみ行って終了する。

## release 反映（prod）

main の最新内容を release へ反映する手順。release 反映 PR を作る経路はこの手順に限る（`docs/harness/skills/shared/pr-creation.md` の base 判定は既定ブランチ固定で、release を base にしないため）。

不変条件:

- release へ直接 push しない。hotfix 用の別 PR も作らない。head は常に main とする（反映内容に余計な変更が混ざらないようにするため）。履歴の分岐からの復旧（下記）だけが例外。
- マージ方式は merge commit のみとする。squash や rebase でマージすると release の履歴が main から分岐し、次回の反映 PR が conflict 状態になって、PR を契機に起動する CI が動かなくなる。リポジトリ全体の既定マージ方式が squash の場合も、反映 PR のマージでは merge commit を明示して選ぶ。ブランチ保護で release ブランチに限って許可マージ方式を merge commit のみに制限できる場合は、制限する。
- release 反映 PR は draft にしない。
- 照会が失敗したら判定を続けず停止する（`docs/harness/skills/shared/gh-query-fail-closed.md`）。

### R1: 反映対象の確定

`origin/release..origin/main` は反映対象の数え過ぎを招くため使わない。同期点（release に反映済みの最後の main 側 commit）を導出し、それ以降だけを対象にする。

`origin/main` と `origin/release` を fetch し、`git merge-base origin/main origin/release` を同期点の候補にする。候補の commit の tree が `origin/release` の tree と一致すれば、履歴は分岐しておらず、同期点が確定する。反映対象は、同期点以降の main の first-parent 履歴（`git log --first-parent --oneline <同期点>..origin/main`）である。

tree が一致しない場合は、履歴が分岐している。release の tree と一致する main 側の commit（`git log --format='%H %T' origin/main` の tree の列から探す）を同期点にする。squash や rebase の履歴が混ざった release でも、反映済みの変更を数え直さずに済む。

- tree が一致する main 側の commit が無い場合は、release に main 由来でない変更が入っている。同期点を導出できないため、反映を見送り、状況を報告して終了する。
- 履歴が分岐していると分かった場合は、反映 PR を作る前に、下記「履歴が分岐したときの復旧」を先に行う。
- 反映対象が無い（`origin/release` と `origin/main` の tree が一致する）場合は、「反映対象なし」と報告して終了する。
- 反映対象に、PJ が破壊的変更として扱う変更（例: 破壊的な migration）が含まれる場合は、R3 の PR 本文に明記する。

### R2: 前提ゲート

次をすべて満たしているときだけ R3 へ進む。満たさない項目があれば PR を作らず、不足を報告して終了する。ゲート未充足は失敗ではなく反映の見送りなので、Issue は起票しない。前提を満たしてから再実行する。

1. main の先頭 commit に対する CI が全て成功している。実行中なら完了まで待つ。
2. dev への反映が main の先頭に追いついている。TODO(記入方法: dev への反映を確認するコマンド。dev への自動反映が無い PJ は「なし」と書く)
3. release 宛ての open PR が他に無い（二重の反映と二重の deploy を避けるため）。
4. release の履歴が分岐していない（R1 で確認済み）。
5. PJ 固有の追加ゲートを満たしている。TODO(記入方法: 反映前に確認する PJ 固有のゲート。無ければ「なし」と書く)

### R3: 反映 PR の作成

base を `release`、head を `main` にした通常の PR（draft にしない）を作る。title は `chore(release): main を release へ反映 (YYYY-MM-DD)` とする。closing keyword は付けない（既定ブランチ向けの PR ではないため発火しない）。

PR 本文は `docs/harness/skills/shared/pr-creation.md` の標準節に、反映固有の節を加えて書く。

| 節                                     | 書くこと                                                                                         |
| -------------------------------------- | ------------------------------------------------------------------------------------------------ |
| 背景                                   | 反映の目的と対象                                                                                 |
| 方針と却下案                           | merge commit で反映する方針と、squash / rebase を退けた理由                                      |
| スコープ外                             | 今回反映しない変更（無ければ「なし」）                                                           |
| 検証結果                               | R2 の前提ゲートの各項目と結果、R4 の反映前プレビューの確認結果（プレビューが無い PJ は「なし」） |
| リスク                                 | 破壊的な変更の有無（R1）と、問題が出たときの戻し方                                               |
| 反映対象（追加）                       | 同期点の SHA・main の先頭 SHA、反映対象の PR / commit 一覧（R1 の出力）                          |
| マージ前チェック（追加）               | チェックボックス形式の確認項目                                                                   |
| マージコマンドとマージ後の確認（追加） | `gh pr merge <番号> --merge` と、R6 の項目                                                       |

作成した PR の head SHA を記録する（R6 で使う）。

### R4: 反映前プレビューの確認

反映によって配備先が変わる内容を CI が事前に出力する PJ（`<iac-tool>` の変更プレビュー等）では、その出力を全文読み、意図しないリソースの削除・置換が無いことを確認する。要約や件数だけで判断しない（出力の一部だけを見て全体を判断すると、削除や置換を見落とすため）。TODO(取得方法: 反映前プレビューの取得元。PR の check・コメント・artifact のいずれか。プレビューを出さない PJ は「なし」と書く)

確認結果は PR 本文の検証結果に追記する。意図しない変更が見つかった場合は、マージせず、原因を報告して終了する。

### R5: マージ

マージは人間の操作である。PR の URL とマージコマンド（`gh pr merge <番号> --merge`）を提示して終了する。`--merge` が指定された場合は、R2 のゲートと R4 の確認が済んでいることを再確認したうえで、このコマンドを実行して R6 に進む。

### R6: マージ後の確認

マージ後、次を確認する。非同期に走る検証（CI 上の deploy 等）は dispatch しっぱなしにせず、完了までポーリングして結論を判定する。

1. release の先頭が merge commit で、親が 2 つであること（`git rev-list --parents -n 1 origin/release` の出力が 3 語）。
2. release の tree が、反映した main の commit（R3 で記録した head SHA）の tree と一致すること（`git rev-parse origin/release^{tree}` と `<head SHA>^{tree}` の比較）。
3. release への反映を契機に起動するはずの deploy の run が起動していること。起動していなければ、反映で変更されたパスが workflow の path filter に掛かっていない可能性を調べる。
4. deploy の run を step 単位で確認する。job の conclusion が success でも、前提検査の条件で各 step が skipped のまま success になる経路がある。step 単位の conclusion と、新しい revision が起動した証跡（PJ の健全性確認コマンド）で確認する。TODO(記入方法: マージ後の健全性確認コマンド)
5. ステップ表の `migrate`・`smoke` など、prod に適用するステップの結果を確認する。

いずれかが満たされない場合は失敗として「失敗ハンドリング」に遷移する。

### 履歴が分岐したときの復旧

| 症状                                                              | 原因                                                                  | 対処                                                                                                                                                                                                                       |
| ----------------------------------------------------------------- | --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 反映 PR が conflict 状態になり、PR を契機に起動する CI が動かない | release の履歴が main から分岐している（squash や rebase で反映した） | 通常の conflict 解消では直らない。main の tree を持ち、親が main と release の両方である合流 commit を作り、そのブランチを head にした PR を merge commit でマージして履歴をつなぎ直す。以後は merge commit のみで反映する |
| 反映対象の数が実際より多い                                        | 同期点に古い共通祖先を使っている                                      | R1 の tree 一致で同期点を導出する                                                                                                                                                                                          |
| 反映後に deploy が起動しない                                      | 反映で変更されたパスが deploy workflow の path filter に掛からない    | workflow の起動条件を確認する。反映の確認は R6 の step 単位確認で行う                                                                                                                                                      |
| main の dev 反映が追いついていない                                | dev への deploy が実行中、または失敗している                          | R2 で停止し、完了または原因の解消を待って再実行する                                                                                                                                                                        |

合流 commit は、`git commit-tree` で `origin/main` の tree を使い、親を `origin/main` と `origin/release` にして作る。この commit を `release-reconnect-<YYYY-MM-DD>` ブランチとして push し、base を `release` にした PR を作る。この PR の内容は main の tree と同一になる。マージ後に R1 の同期点の確認が通ることを確かめる。

## Step 1..N: 実行と成否判定

各ステップは以下の規律で実行する:

1. 実行前にコマンドを表示する。
2. コマンドを実行し、終了コードを捕捉する。
3. 終了コード 0 以外なら即停止し「失敗ハンドリング」へ。標準出力/標準エラーは失敗分析のため末尾を保持する。
4. 成功なら結果を要約して次へ。非同期に走る検証（CI 上の smoke 等）は dispatch しっぱなしにせず、完了までポーリングして結論を判定する。

## 失敗ハンドリング（create-issue 起票）

いずれかのステップが失敗したら:

1. 即座に後続ステップを止める（握り潰さない）。
2. 原因を分析する: 終了コード・ログ末尾の抜粋・PJ の既知の失敗パターン（bootstrap 時にここへ表として蓄積する）から推定原因を組み立てる。
3. `/create-issue`（`docs/harness/skills/create-issue.md`）で Issue を起票する。body に含める:
   - 失敗ステップ（どの Step / どのコマンドか、対象 env）
   - エラー抜粋（秘匿値はマスクする。DB URL・key・password・token は載せない）
   - 終了コード / 判定結果
   - 推定原因
   - 再現手順: `/deploy-verify <env> --from <失敗ステップ>` と、前提として必要な env/認証
   - 参照: 該当 runbook / ログの参照先
   - ラベル: インフラ系コンポーネントラベル。優先度は影響度に応じて（本番影響なら `priority:high`）。ハーネス起因なら `harness:harness` も付与
4. 起票した Issue 番号をユーザに報告し、フローを終了する。

`--dry-run` 時はコマンドを実行しないため、本ハンドリングは発火しない。

## 完了処理

全ステップ成功時、ユーザに以下を報告する:

- 対象 env / 配備した revision（`git rev-parse HEAD` 等。prod では反映した main の SHA と release の merge commit）
- 実行したステップと結果
- スキップしたステップとその理由（prod で dev 専用ステップを飛ばした等）
- prod で PR 作成までで止めた場合は、PR の URL とマージコマンド

## 制約

- 各ステップの実行ロジックは再実装せず、PJ のタスクランナー / runbook を呼ぶだけにする（実行ロジックが二重にあると、どちらかが古くなるため）
- 失敗は握り潰さず、終了コードが 0 以外なら即停止して起票する（壊れた状態の上で後続のステップを進めないため）
- 前提が未充足なら推測で進めず停止し、runbook 参照の設定手順を提示する（誤った環境へ変更を加えないため）
- 課金を伴う新規リソース作成・秘密値挿入は、人間承認の後に実行する（それ以外の deploy 操作は承認モデルに従い自律実行する）
- release へは直接 push せず、release 反映 PR を作る。マージ方式は merge commit のみとする（squash や rebase では release の履歴が main から分岐し、次回の反映 PR が conflict になるため）
- 失敗 Issue・ログ抜粋の秘匿値はマスクする（起票先に資格情報が残らないようにするため）
- `--dry-run` は計画の提示までにとどめ、副作用のあるコマンドを実行しない（環境を変えずに結果を確認できるようにするため）

## 関連

- `docs/runbooks/INDEX.md` — ラップ対象 runbook の一覧
- `docs/harness/skills/create-issue.md` — 失敗時の起票先
- `docs/harness/skills/shared/gh-query-fail-closed.md` — 照会失敗時に判定を続けない規約
- `docs/harness/skills/shared/unattended-contract.md` — 確認ゲートの扱い（対話 run / 無人 run）
- `docs/harness/OPERATING_MODEL.md` — 承認モデルの正本
