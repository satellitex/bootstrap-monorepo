# commit 前に format を通す

> この文書は team-shared rule の 1 つ。format 違反を commit 前に解消する規範と、強制経路の分担のみを定める。hook の挙動は `.claude/hooks/README.md` と各 hook 冒頭のコメント、ゲートのコマンド定義は `docs/harness/skills/shared/verification-gates.md` に書く（本書には複製しない）。

git commit を作成する前に、formatter（既定は prettier）で自動修正し、format の検査を通す。format 違反のまま commit・push すると、CI の format job が fail する。

## Why

commit 前に検出すれば数秒で済む。push 後に CI で fail すると、結果を待つ時間と、修正 commit の追加サイクルが生じる。

## How to apply

強制は hook と CI の 2 段で行う（分担 → `docs/harness/skills/shared/verification-gates.md`「ゲートごとの実行先」）。

### hook が有効な経路（Claude Code 経由）

- **commit 前**: pre-format-check hook が、hook 開始時点で staged 済みのファイルだけを整形して再 stage する
- **push 前**: pre-push hook が、`format:check` を含む CI 同等の検査を実行する

この 2 段で、format 違反は自動的に補正・検出される。

### hook が効かない経路（人間の CLI・他のエージェント実行環境）

commit 前に `format` ゲートで自動修正し、`format:check` ゲートで確認する（コマンドの定義 → `verification-gates.md`）。実行を省いた場合は、CI の format job が fail として検出する。

### CI（全経路の最終ゲート）

基礎 CI（`.github/workflows/ci.yml`）の format job が `format:check` を実行する。hook を持たない実行環境では、CI が唯一の強制になる。

## 関連

- `.claude/hooks/pre-format-check.sh` — commit 前の整形 hook
- `.claude/hooks/pre-push-ci-check.sh` — push 前の CI 同等検査 hook
- `.github/workflows/ci.yml` — 基礎 CI の format job
- `docs/harness/skills/shared/verification-gates.md` — 検証ゲートのコマンド定義
