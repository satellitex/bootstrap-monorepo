# review-cycle — LGTM までの自律ポーリング

この文書は `/review-cycle` の tool-neutral な正本手順である。各イテレーションのコメント処理は `docs/harness/skills/handle-review.md` に委譲し、通知先マッピングは `.claude/skills/review-cycle/references/notification-mapping.md`（profile）に分離する。ここにはループ制御と終了判定のみを書く。

## 目的

PR のレビューコメントを承認されるまで繰り返し対応し、完了時に PR author へ結果を通知する。各イテレーションでは `/handle-review` の手順に従う。

## 入力

| 項目 | 必須 | 説明 | 例 |
|------|------|------|----|
| PR 番号 | No | 対象 PR。省略時は現在ブランチの PR を自動検出 | `/review-cycle #<N>` |

## フロー

```
/review-cycle [#PR]
  ├─ 1. PR 特定・author 取得
  ├─ 2. ループ（最大 10 回）
  │    ├─ 2.1 CI 完了待機
  │    ├─ 2.2 未解決コメント + 未処理 COMMENTED レビューの確認
  │    ├─ 2.3 すべて 0 件 → 承認チェック → LGTM なら終了
  │    ├─ 2.4 /handle-review の実行
  │    ├─ 2.5 全コメント「対応不要」→ 終了
  │    └─ 2.6 変更あり → 新規レビュー待機 → 2.1 へ
  ├─ 3. 完了通知
  └─ 4. 結果報告
```

## Step 1: PR 特定

PR 番号が未指定の場合、現在ブランチから自動検出する。PR の **author**（GitHub ユーザー名）を取得しておく（Step 3 の通知で使用）。

## Step 2: ループ

最大 **10 回**までイテレーションする。

### 2.1: CI 完了待機

`gh pr checks` で CI ステータスをポーリングし、全チェック（CI レビュー bot を導入している場合はそのチェックを含む）が完了するまで待機する。

- ポーリング間隔: 1 分
- 待機上限: 10 分
- 全チェックが既に完了している場合は即座に次へ進む

### 2.2: 未解決コメント + 未処理 COMMENTED レビューの確認

以下を取得する:

1. 未解決の review comment（スレッド）
2. `CHANGES_REQUESTED` レビュー（本文付き）
3. **本文付きの `COMMENTED` レビュー**（bot からの指摘を含む）— 本文が空のもの（GitHub が line comment 時に自動生成するレビュー）は除外

イテレーション間で**処理済みレビュー ID** を保持し、前回のイテレーションで `/handle-review` に渡した `COMMENTED` レビューを重複処理しない。

**非アクション CI noise filter（必須）:**

以下はレビュー対応対象ではないため、本文を `/handle-review` に渡さない。長文 body を会話へ貼り付けない。マーカー文字列は **PJ の CI レビュー bot / 自動コメント bot のマーカーに合わせて bootstrap 時に調整する**。

- IaC plan 等の機械生成コメント（bot の固定 HTML コメントマーカーで判定する）
- CI レビュー bot の auto マーカー付きコメントで本文が `LGTM` のみのものは、対応対象からは除外するが **auto LGTM シグナルとして保持**する
- GitHub Actions の check status / workflow log 通知のみで、file / line / fix suggestion を含まない CI イベント

機械生成コメントの確認が必要な場合は、コメント本文ではなく artifact / workflow run URL を開いて必要箇所だけ読む。auto LGTM シグナルは件数だけで捨てず、コメント/レビュー ID・投稿時刻・紐づく commit SHA（取得できる場合）を記録して Step 2.3 の終了判定に使う。

### 2.3: アクション不要の場合

未解決コメントが 0 件 **かつ** 未処理の `COMMENTED` レビューも 0 件の場合:

- PR の最新レビュー状態を確認する
- `APPROVED` → **ループ終了（理由: LGTM）**
- 最新 head に対する CI レビュー bot の auto LGTM シグナルがある → **ループ終了（理由: LGTM）**
- それ以外 → 2 分待機して 2.2 に戻る（最大 3 回空振り。超過で終了）

未処理の `COMMENTED` レビューが存在する場合は 2.4 に進む。

### 2.4: /handle-review の実行

`docs/harness/skills/handle-review.md` の Step 1〜8 に従ってコメントを処理する。

### 2.5: 結果判定

handle-review の結果サマリ（Step 8）を確認する:

- **全コメントが「対応不要」（Changes committed: No）** → **ループ終了（理由: all-skipped）**
- **変更あり（Changes committed: Yes）** → 2.6 に進む

### 2.6: 新規レビュー待機

**2 分待機**して新規レビューコメントの投稿を待ち、2.1 に戻る。CI 待機は次のイテレーションの 2.1 で行われるため、ここでは待たない。

## Step 3: 完了通知

ループ終了後、PR author に結果を通知する。

### 3.1: 通知手段の確認

通知手段（チャットの incoming webhook 等）の設定は `.claude/skills/review-cycle/references/notification-mapping.md`（profile）に従う。webhook URL は環境変数 `PROJ_REVIEW_NOTIFY_WEBHOOK_URL`（無ければプロジェクトルート `.env`）から取得する。**未設定の場合は通知をスキップし、フロー自体は正常終了とする**（profile の設定手順を報告に添える）。

### 3.2: GitHub → 通知先マッピング

profile のマッピング表を読み込み、PR author の GitHub アカウントに対応する通知先メンション名を取得する。マッピングが見つからない場合は GitHub ユーザー名をそのまま表示する。

### 3.3: 通知メッセージ

webhook へ POST する。メッセージ構造:

```
Review Cycle 完了 — #<PR 番号> <PR タイトル>

<メンション> PR のレビュー対応が完了しました。

対応サマリ:
- 修正: N 件
- スキップ（対応不要）: N 件
- Issue 化: N 件
- ループ回数: N

終了理由: LGTM / 全コメント対応不要 / 最大ループ到達
PR: <PR URL>
```

## Step 4: 結果報告

コンソールに最終結果（終了理由・対応サマリ・通知の成否/スキップ理由）を出力する。

## 制約

- ループ上限: 10 回（無限ループ防止）
- CI 待機上限: 10 分
- 新規レビュー待機: 2 分（固定）
- 空振り（コメント 0 件 & 未承認）の連続上限: 3 回
- `/handle-review` の制約をすべて継承する
- 通知手段が未設定でもエラー終了しない（スキップして正常終了）
