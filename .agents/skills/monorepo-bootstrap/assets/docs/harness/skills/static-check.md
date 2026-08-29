# static-check — 検証ゲート一括実行・表形式報告

この文書は `/static-check` の tool-neutral な正本手順である。実行するコマンドの定義は `docs/harness/skills/shared/verification-gates.md` に一元化されており、ここには複製しない。

## 目的

プロジェクト全体の検証ゲート（format:check・lint・typecheck・test・build）を一括実行し、結果を表形式で報告する。

## 入力

| 項目 | 必須 | 説明 | 例 |
|------|------|------|----|
| `--docs` | No | 文書のみ変更時の軽量モード。実行するゲートは `docs/harness/skills/shared/verification-gates.md` の「docs のみ変更」組合せに従う | `/static-check --docs` |

## フロー

### Step 1: チェック実行

`docs/harness/skills/shared/verification-gates.md` を Read し、定義されている全コマンドを順次実行する。

- **通常タスク（デフォルト）**: 「実装完了の検収」組合せ（定義されている全コマンド）を実行する
- **文書系タスク（`--docs`）**: 「docs のみ変更」組合せを実行する（実行対象は verification-gates.md が正本。本文書に複製しない）

各コマンドは順次実行し、**1 つが失敗しても残りを実行する**（全結果を収集する）。

### Step 2: 結果報告

各コマンドの成否を一覧で報告する:

```
## 静的チェック結果

| チェック | 結果 |
|---------|------|
| pnpm run format:check | PASS / FAIL |
| pnpm run lint | PASS / FAIL |
| pnpm run typecheck | PASS / FAIL |
| pnpm run test | PASS / FAIL |
| pnpm run build | PASS / FAIL |
```

（コマンド名は verification-gates.md の定義に従う。上表は既定スタックの例）

失敗したコマンドがある場合は、エラー出力の末尾（最大 30 行）を報告する。

### Step 3: 判定

- 全コマンド PASS → 「静的チェック: 全て通過」と報告
- 1 つでも FAIL → 「静的チェック: 失敗あり」と報告し、失敗内容を提示

## 制約

- `--no-verify` 禁止
- 既存テストの失敗が今回の変更と無関係な場合は、その旨を明記する（例: ランタイムバージョン不一致等）
- コマンド定義を本文書へ複製しない（SSOT は `docs/harness/skills/shared/verification-gates.md`）

## 関連

- `docs/harness/skills/shared/verification-gates.md` — 検証ゲートコマンド定義の正本
- `docs/harness/skills/handle-review.md` / `docs/harness/skills/multi-issue.md` — 同じゲート定義を参照する呼び出し元
