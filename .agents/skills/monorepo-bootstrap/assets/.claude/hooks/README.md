# .claude/hooks 運用ガイド

この文書は `.claude/hooks/` 配下の hook 群が成立するための外部契約、fail-open / fail-closed の設計原則、opt-in hook の有効化手順、hook 増減時の規約を定義する。個々の hook の詳細挙動は各スクリプト冒頭のコメントに、検証ゲートのコマンド定義は `docs/harness/skills/shared/verification-gates.md` に書く（本書には書かない）。

## 構成

| ファイル | イベント | 区分 |
|---|---|---|
| session-start.sh | SessionStart | core（配線済み） |
| pre-format-check.sh | PreToolUse: `Bash(git commit *)` | core（配線済み） |
| pre-push-ci-check.sh | PreToolUse: `Bash(git push *)` | core（配線済み） |
| post-edit-check.sh | PostToolUse: `Write\|Edit` | core（配線済み） |
| pre-commit-submodule-guard.sh | PreToolUse: `Bash(git commit *)` | opt-in:submodule（未配線） |
| post-edit-projection-reminder.sh | PostToolUse: `Write\|Edit` | opt-in:public-site（未配線） |
| ../bin/hook-utils.sh | （hooks が source する共通ユーティリティ） | core |
| ../bin/submodule-guard.sh | （session-start / submodule 系が source する） | opt-in:submodule |
| tests/run-all.sh + tests/test-*.sh | （CI の test job が実行する hermetic テスト） | core |

## 外部契約 4 点（この 4 点が揃えば hooks は無改変で動く）

1. **root `package.json` の 6 script**: `build` / `test` / `lint` / `typecheck` / `format` / `format:check`。pre-push hook と CI はこの名前を呼ぶ。名前を変える場合は hooks・`.github/workflows/ci.yml`・`docs/harness/skills/shared/verification-gates.md` を同時更新する。
2. **`.mise.toml` の pin**: node / pnpm / jq / gitleaks。hooks は mise shims 経由でこれらを解決する（jq は hook の JSON 入出力に必須）。
3. **workspace レイアウト**: パッケージは `apps/*` と `packages/*` に置く。`hook-utils.sh` の `resolve_package` / `resolve_tsconfig` がこの 2 プレフィックスを前提にパッケージ単位の typecheck / test を解決する。
4. **秘密検知ツール設定**: gitleaks。誤検知の除外はリポジトリルートの `.gitleaks.toml` の `[allowlist]` regexes に値ベースで追記する（`.gitleaks.toml` が無い場合は gitleaks の既定ルールで走る）。

## 設計原則: fail-open / fail-closed

- **ツールチェーン不在は fail-open（skip して CI へ委譲）**: pnpm が PATH に無い、`node_modules` が未 install、gitleaks が未導入、といった「環境が未整備」の状態では、hook は `additionalContext` 付きで skip して操作を通す。worktree 直後の commit / push を環境都合でブロックしない。
- **検査スクリプト不在は fail-closed（deny）**: pre-push の `run_step` に配線した検査コマンドの実体が無い場合は deny する。検査の消失を沈黙させない（検査を外すなら配線ごと外し、テストも同時更新する）。
- **hook は best-effort、権威は CI**: hook は Claude Code 経由の操作にだけ効くローカルガードであり、`--no-verify` や Claude Code 外の端末操作は素通りする。セキュリティ境界・品質の最終ゲートとして設計せず、権威ある検証は CI（`.github/workflows/ci.yml`）に置く。全履歴の秘密走査など定期検査を足す場合は `docs/harness/scheduled-operations.md` の設計ガイドに従う。

## opt-in hook の有効化手順

### submodule 採用時（pre-commit-submodule-guard.sh）

1. `pre-commit-submodule-guard.sh` 冒頭の `WATCH_PATH` 既定値を実際の submodule 親パスに変更する。
2. `session-start.sh` の「opt-in: submodule 採用時に有効化」区画のコメントアウトを外し、同じパスを渡す（セッション開始時の自動初期化が第一防御、本 hook が誤コミットへの二重防御）。
3. `.claude/settings.json` の `PreToolUse` → `matcher: "Bash"` の `hooks` 配列に以下を追加する（pre-format-check より**前**に置く）:

```json
{
  "type": "command",
  "command": "bash .claude/hooks/pre-commit-submodule-guard.sh",
  "if": "Bash(git commit *)",
  "timeout": 30,
  "statusMessage": "Checking submodule pointer changes..."
}
```

### 公開射影採用時（post-edit-projection-reminder.sh / opt-in:public-site）

1. hook 冒頭の `TARGET_DOCS`（射影元の内部正本）と `PROJECTION_DOC`（公開版）を採用構成に合わせて確認する。
2. `.claude/settings.json` の `PostToolUse` → `matcher: "Write|Edit"` の `hooks` 配列に以下を追加する:

```json
{
  "type": "command",
  "command": "bash .claude/hooks/post-edit-projection-reminder.sh",
  "timeout": 30,
  "statusMessage": "Checking projection drift..."
}
```

## hook を増減する時の規約

- hook の追加・削除・挙動変更は、`tests/test-<hook 名>.sh` の追加・削除・更新と**同一 PR** で行う。`tests/run-all.sh` は `tests/test-*.sh` を自動列挙するため、命名規則に従えば配線漏れは起きない（prefix を外すと実行されないので注意）。
- テストは hermetic に保つ: `mktemp` の隔離 git repo で実行し、外部コマンドは `PROJ_*_CMD` 環境変数の注入 seam で stub 化し、hook の JSON 出力は jq で検証する。実 prettier / pnpm / gitleaks / eslint / tsc に依存させない。
- opt-in hook のテストも hermetic であれば常時実行してよい（配線の有無とテスト実行は独立）。
- CI の test job が `bash .claude/hooks/tests/run-all.sh` を実行する。マージ前にローカルでも同コマンドで green を確認する。
