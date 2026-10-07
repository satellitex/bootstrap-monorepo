# review-cycle — LGTM までの自律対応

この文書は `/review-cycle` の tool-neutral な正本手順である。レビューコメントの処理は `docs/harness/skills/handle-review.md` に委譲し、通知先マッピングは `.claude/skills/review-cycle/references/notification-mapping.md`、conflict 解消・CI 修正の PJ 固有値は `.claude/skills/review-cycle/references/ci-and-conflict-profile.md`（いずれも profile）に分離する。ここにはループ制御・判定表・終了条件・通知の不変条件を書く。

## 目的

PR を、承認されるか、これ以上自動で進められなくなるまで繰り返し対応する。各イテレーションでは、PR の状態を観測し、判定表に従って merge conflict の解消・レビューコメントの対応（`/handle-review`）・CI 失敗の修正のいずれかを行う。終了時に PR author へ終了理由を通知する。

## 入力

| 項目 | 必須 | 説明 | 例 |
|------|------|------|----|
| PR 番号 | No | 対象 PR。省略時は現在ブランチの PR を自動検出 | `/review-cycle #<N>` |

## フロー

```
/review-cycle [#PR]
  ├─ 1. PR 特定・author 取得
  ├─ 2. ループ（最大 10 回）
  │    ├─ 2.1 CI 完了待機 → 状態の取得（PR 状態・CI・指摘）
  │    ├─ 2.2 判定表（上から評価し最初に一致した行を採る）
  │    ├─ 2.3 conflict 解消 / 2.4 /handle-review / 2.5 CI 失敗の修正（判定表が指す動作）
  │    └─ 2.6 変更を push した場合は新規レビュー待機 → 2.1 へ
  ├─ 3. 終了通知
  └─ 4. 結果報告
```

## Step 1: PR 特定

PR 番号が未指定の場合、現在ブランチから自動検出する。PR の author（GitHub ユーザー名）を取得しておく（Step 3 の通知で使用）。

## Step 2: ループ

最大 10 回までイテレーションする。

### 2.1: CI 完了待機と状態の取得

`gh pr checks` で CI ステータスをポーリングし、全チェック（CI レビュー bot を導入している場合はそのチェックを含む）が完了するまで待機する。

- ポーリング間隔: 1 分
- 待機上限: 10 分
- 全チェックが既に完了している場合は即座に次へ進む

その後、判定表の入力として次を取得する:

1. PR の state（open / closed / merged）・draft か・`mergeable`・最新のレビュー状態（`gh pr view <PR> --json state,isDraft,mergeable,reviewDecision,headRefOid`）
2. CI の結果（全 check の conclusion）
3. 未処理の指摘: 未解決の review comment（スレッド）、`CHANGES_REQUESTED` レビュー（本文付き）、本文付きの `COMMENTED` レビュー（bot からの指摘を含む。本文が空のもの、つまり GitHub が line comment 時に自動生成するレビューは除外）。イテレーション間で処理済みの Comment ID（`/handle-review` のサマリが返す `rc:` / `rv:` / `ic:`）を保持し、同じ指摘を重複処理しない

非アクション CI noise filter: 以下はレビュー対応対象ではないため、本文を `/handle-review` に渡さない。長文 body を会話へ貼り付けない。マーカー文字列は PJ の CI レビュー bot / 自動コメント bot のマーカーに合わせて bootstrap 時に調整する。

- IaC plan 等の機械生成コメント（bot の固定 HTML コメントマーカーで判定する）
- CI レビュー bot の auto マーカー付きコメントで本文が `LGTM` のみのものは、対応対象からは除外するが、auto LGTM シグナルとして保持する
- GitHub Actions の check status / workflow log 通知のみで、file / line / fix suggestion を含まない CI イベント

機械生成コメントの確認が必要な場合は、コメント本文ではなく artifact / workflow run URL を開いて必要箇所だけ読む。auto LGTM シグナルは件数だけで捨てず、コメント/レビュー ID・投稿時刻・紐づく commit SHA（取得できる場合）を記録して判定表の行 9 に使う。

### 2.2: 判定表

上から評価し、最初に一致した行を採る。終端シグナル（行 9・10）より、未処理の指摘・conflict・赤 CI の対応を優先する。承認済みでも conflict や赤 CI の PR は merge できず、LGTM と通知しても人の手戻りになるため。

| 順 | 条件 | 動作 | 終了理由 | 優先する理由 |
|----|------|------|----------|--------------|
| 1 | PR が closed または merged | 終了 | `closed` | 対応する対象が無い |
| 2 | イテレーションが 10 回に達した、または待機行（6・8・11）が連続 3 回 | 終了 | `budget` | 無限ループの防止 |
| 3 | draft であり、PJ が CI レビュー bot を導入している | 終了 | `draft-hold` | draft の PR では bot が起動せず、レビュー結果が届かない（bot を導入していない PJ ではこの行を無効にする） |
| 4 | merge conflict がある（`mergeable` が `CONFLICTING`） | 2.3 で解消する。解消できなければ終了 | `conflict` | conflict 中の PR は push しても CI が起動しないため、指摘対応・CI 修正より先に解消する |
| 5 | 未処理の指摘がある | 2.4 で `/handle-review` を実行する | — | 指摘対応は CI 修正より先に行う。1 回の push で両方を直せることが多い |
| 6 | CI に fail があり、未完了の check も残る | 待機して再判定する | — | 全 check の完了後にまとめて直す。部分的な観測で直すと、修正と実行の回数を浪費する |
| 7 | CI が fail し、全 check が完了している | 2.5 で修正する。分類によっては終了 | `ci` | 赤 CI のままでは merge できない |
| 8 | `mergeable` が `UNKNOWN` | 待機して再判定する | — | GitHub が再計算中で、conflict の有無が未確定のため終端にしない |
| 9 | 最新レビューが `APPROVED`、または最新 head に対する CI レビュー bot の auto LGTM シグナルがある | 終了 | `LGTM` | 行 4〜7 で、conflict・赤 CI・未処理の指摘が無いことを確認済み |
| 10 | 直近の `/handle-review` が全コメントを「対応不要」と判定した（`Changes committed: No`） | 終了 | `all-skipped` | これ以上自動で進められる対応が無い |
| 11 | 上記のいずれにも当たらない（指摘 0 件・未承認） | 2 分待機して再判定する | — | 新規のレビューや承認を待つ |

待機行（6・8・11）は連続回数を数え、動作行（4・5・7）を実行したら数え直す。CI レビュー bot を導入している PJ で、bot の投稿が進行中の間は push しない待機行（理由: push すると bot の進行中の投稿が破棄されることがある）が必要な場合は、`.claude/skills/review-cycle/references/ci-and-conflict-profile.md` に条件を記入し、行 4 の前に足す。

### 2.3: merge conflict の解消

base ブランチを PR ブランチへ merge して解消する。

1. `git fetch origin` し、base ブランチ（`origin/main`）を `git merge` する。rebase と force push は使わない。push 済みの履歴を書き換えると、他のセッションの worktree とレビューコメントの anchor が壊れるため。`--no-verify` も使わない。
2. 双方の変更の意図を保持して解消する。どちらか一方を採るだけの解消は、もう一方の変更を消すため行わない。
3. lockfile と生成物は手で混ぜない。base 側を採ってから、生成コマンドで再生成する（lockfile は `pnpm install`。その他の生成物と、連番を持つ生成物の採番規則は profile に従う）。連番を持つ生成物（migration 等）は、番号が base → head の順に単調増加になるよう採番し直す。
4. 検証ゲート（`gate:commit`。定義 → `docs/harness/skills/shared/verification-gates.md`）を通してから push する。
5. 解消できない場合、検証ゲートを通らない場合、解消が人間引き渡し境界（`docs/harness/OPERATING_MODEL.md` の承認モデル節。既定は空）に当たる場合は、`git merge --abort` して `conflict` で終了する。中途半端な解消を push すると、壊れた状態が head に載り、CI の失敗原因を切り分けにくくなるため。

### 2.4: /handle-review の実行

`docs/harness/skills/handle-review.md` の Step 1〜8 に従ってコメントを処理する。未処理の指摘の Comment ID を渡す。返ってきたサマリの Comment ID を処理済みとして保持し、`Changes committed` の値を判定表の行 10 に使う。

### 2.5: CI 失敗の修正

失敗した job のログを読み、原因を次の 3 つに分類する。

| 分類 | 判定 | 対応 |
|------|------|------|
| PR 差分起因 | PR の変更が原因の失敗 | 最小の差分で修正する。テストの弱体化・skip の追加・閾値の緩和はせず、実装を直す |
| 一過性 | ネットワーク・runner の障害など、再実行で通り得る失敗（CI レビュー bot の既知の一過性障害は profile に記入） | 失敗した job だけを同一 run に対して 1 回だけ再実行する（`gh run rerun <run-id> --failed`）。再び失敗したら一過性として扱わず、他の分類で判定し直す |
| base 由来 | PR の差分と無関係で、base ブランチの最新 run でも同じ失敗が出ている | この PR では直さず、`ci` で終了する。判定は失敗ログと base の最新 run の照合で行う |

修正した場合は検証ゲート（`gate:commit`）を通してから push する。修正の push と再実行の合計回数が profile の上限（既定 3）に達したら `ci` で終了する。修正が人間引き渡し境界に当たる場合は、変更せずに `ci` で終了する。

### 2.6: 新規レビュー待機

変更を push した場合は、2 分待機して新規レビューの投稿を待ち、2.1 に戻る。CI 待機は次のイテレーションの 2.1 で行うため、ここでは待たない。

## Step 3: 終了通知

ループ終了後、PR author に終了理由を通知する。送信先の解決順・未設定時の扱い・資格情報の扱い・送信結果の扱いは `docs/harness/skills/shared/notification-contract.md` に従う。

### 3.1: 通知の種別と主旨

通知は `docs/harness/skills/shared/notification-contract.md` の 2 区分（情報通知 / エスカレーション通知）のどちらかに宣言する。`LGTM` 以外の終了理由の文面は、完了を示す語を使わない。

| 終了理由 | 種別 | 通知の主旨 |
|----------|------|------------|
| `LGTM` | 情報通知 | レビュー対応が完了し、承認された |
| `all-skipped` | 情報通知 | 全コメントが対応不要と判定され、これ以上の自動対応は無い（承認は未了） |
| `closed` | 情報通知 | PR が closed / merged のため終了した |
| `draft-hold` | エスカレーション通知 | draft のためレビュー結果が届かない。ready にするか判断が必要 |
| `budget` | エスカレーション通知 | 回数の上限に達した。残っている状態（未処理の指摘・CI・conflict）を添える |
| `conflict` | エスカレーション通知 | conflict を自動で解消できなかった。人による解消が必要 |
| `ci` | エスカレーション通知 | CI の失敗を自動で解消できなかった（base 由来または修正回数の上限） |

### 3.2: GitHub → 通知先マッピング

profile のマッピング表を読み込み、PR author の GitHub アカウントに対応する通知先メンション名を取得する。マッピングが見つからない場合は GitHub ユーザー名をそのまま表示する。

### 3.3: 通知メッセージ

webhook へ POST する。メッセージ構造:

```
Review Cycle <完了 | 要対応> — #<PR 番号> <PR タイトル>

<メンション> <通知の主旨の 1 文>

対応サマリ:
- 修正: N 件
- スキップ（対応不要）: N 件
- Issue 化: N 件
- conflict 解消: N 回 / CI 修正: N 回
- ループ回数: N

終了理由: LGTM / all-skipped / closed / draft-hold / budget / conflict / ci
PR: <PR URL>
```

見出しの「完了」は `LGTM` と `all-skipped` のときだけ使い、他の終了理由は「要対応」とする。

### 3.4: 通知の不変条件

- 通知するのは終了時の 1 回だけで、途中経過は通知しない。
- 通知の直前に PR の state・draft・`mergeable` を取り直し、終了理由の根拠が消えている場合は通知しない（例: `conflict` で終了した後に、人が解消した）。通知しなかった事実と理由は報告に書く。
- webhook URL は送信先としてのみ使い、payload・標準出力・標準エラー・ログ・通知本文・報告に含めない。資格情報が成果物に残るため（資格情報の扱い → `notification-contract.md`）。
- 通知手段が未設定のとき、情報通知は skip して正常終了し、エスカレーション通知は通知できなかったことを失敗として報告して終了する（人が気付けない終了にしないため）。profile の設定手順を報告に添える。

## Step 4: 結果報告

コンソールに最終結果（終了理由・対応サマリ・通知の成否/スキップ理由）を出力する。

## 制約

- ループ上限: 10 回（無限ループ防止。上限到達と待機行の連続は `budget` で終了する）
- CI 待機上限: 10 分
- 新規レビュー待機: 2 分（固定）
- 待機行（判定表の 6・8・11）の連続上限: 3 回
- CI 修正と再実行の合計上限: 既定 3 回（profile で変更可）
- conflict は merge のみで解消する（rebase・force push・`--no-verify` を使わない）
- `/handle-review` の制約をすべて継承する
