# .claude/hooks 運用ガイド

この文書は `.claude/hooks/` 配下の hook 群が成立するための外部契約、fail-open / fail-closed の設計原則、hook と CI の分担、opt-in hook の有効化手順、hook 増減時の規約を定義する。個々の hook の詳細挙動は各スクリプト冒頭のコメントに、検証ゲートのコマンド定義は `docs/harness/skills/shared/verification-gates.md` に書く（本書には書かない）。

## 構成

| ファイル                           | イベント                                          | 区分                                           |
| ---------------------------------- | ------------------------------------------------- | ---------------------------------------------- |
| session-start.sh                   | SessionStart                                      | core（配線済み）                               |
| pre-format-check.sh                | PreToolUse: `Bash(git commit *)`                  | core（配線済み）                               |
| pre-push-ci-check.sh               | PreToolUse: `Bash(git push *)` / `Bash(git -C *)` | core（配線済み）                               |
| post-edit-check.sh                 | PostToolUse: `Write\|Edit`                        | core（配線済み）                               |
| pre-commit-submodule-guard.sh      | PreToolUse: `Bash(git commit *)`                  | opt-in:submodule（未配線）                     |
| post-edit-projection-reminder.sh   | PostToolUse: `Write\|Edit`                        | opt-in:public-site（未配線）                   |
| ../bin/hook-utils.sh               | （hooks が source する共通ユーティリティ）        | core                                           |
| ../bin/submodule-guard.sh          | （session-start / submodule 系が source する）    | opt-in:submodule                               |
| tests/run-all.sh + tests/test-*.sh | （CI の test job が実行する hermetic テスト）     | core（opt-in hook のテストは hook と同じ区分） |

post-edit-check.sh の既定の対象言語は TS / JS（`.ts` / `.tsx` / `.js` / `.jsx`）で、eslint・`tsc --noEmit`・package 単位の `pnpm test` を実行する。eslint と TypeScript は root の devDependencies に含まれない既定外の前提である。採用しない場合は該当の case と `tests/test-post-edit-check.sh` のケースを同時に削除し、他言語を扱う場合は hook 内の「言語別チェックの追加例」に従って case 分岐を足す。

## 外部契約 4 点（この 4 点が揃えば hooks は無改変で動く）

1. **root `package.json` の 6 script**: `build` / `test` / `lint` / `typecheck` / `format` / `format:check`。pre-push hook と CI はこの名前を呼ぶ。名前を変える場合は hooks・`.github/workflows/ci.yml`・`docs/harness/skills/shared/verification-gates.md` を同時更新する。`harness:test` は契約外の補助 script で、`ci.yml` が直接呼ぶ。
2. **`.mise.toml` の pin**: node / pnpm / jq / gitleaks。hooks は mise shims 経由でこれらを解決する（jq は hook の JSON 入出力に必須）。
3. **workspace レイアウト**: パッケージは `apps/*` と `packages/*` に置く（root の `pnpm-workspace.yaml` が同じ 2 つを列挙する）。`hook-utils.sh` の `resolve_package` / `resolve_tsconfig` がこの 2 プレフィックスを前提にパッケージ単位の typecheck / test を解決する。post-edit-check が受ける `file_path` は絶対パス・相対パスのどちらでもよく、作業ツリーのルートは入力ファイル側から決まる。
4. **秘密検知ツール設定**: gitleaks。誤検知の除外は root の `.gitleaks.toml` の `[allowlist]` regexes に値ベース（`\b` 厳密一致）で追記する。`.gitleaks.toml` は gitleaks の既定ルールを継承する最小構成で収録済みで、`[allowlist]` はコメントアウトした雛形として置いてある（値が 1 件も無い `[allowlist]` は gitleaks が設定エラーにするため、値を入れてからコメントを外す）。ファイルが無い場合も既定ルールで走る。

## hook と CI の分担

hook と CI は効く範囲が異なる。2 段で捉える。

| 段                               | 効く範囲                                                                                        | 検査                                                                                                |
| -------------------------------- | ----------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| hook                             | Claude Code 経由の操作だけ。`--no-verify`・Claude Code 外の端末・他ツールからの操作は素通りする | commit 前の整形、push 前の秘密検知と `gate:push`、編集直後の eslint / typecheck / package 単位 test |
| CI（`.github/workflows/ci.yml`） | PR と main への push の全経路                                                                   | `gate:ci`、hooks のテスト、ハーネス機械検査（`pnpm harness:test`）                                  |

- hook は事故を手前で止める best-effort のローカルガードで、意図的な回避を防ぐ境界ではない。
- `gate:push` のうち `gate:ci` に含まれない `lint` / `typecheck` と、秘密検知は、hook にだけ置かれている。CI では実行されないため、hook を経由しない push では担保されない。迂回を許容できない検査は `ci.yml` に足し、`docs/harness/skills/shared/verification-gates.md` の組合せを同一 PR で更新する（ゲート名の定義は同書が正本）。
- 全履歴の秘密走査など定期検査を足す場合は `docs/harness/scheduled-operations.md` の設計ガイドに従う。

## 設計原則: fail-open / fail-closed

- **ツールチェーン不在は fail-open（skip して通す）**: pnpm が PATH に無い、`node_modules` が未 install、gitleaks が未導入、といった「環境が未整備」の状態では、hook は skip した旨を `additionalContext`（または stderr）に残して操作を通す。worktree 直後の commit / push を環境都合でブロックしない。skip した検査のうち `gate:ci` に含まれるものは CI が担保するが、`lint` / `typecheck` / 秘密検知は担保されない。環境を整えて（`mise install`、`pnpm install --frozen-lockfile`）から操作し直すと完全に検査される。
- **検査スクリプト不在は fail-closed（deny）**: pre-push の `run_step` に配線した検査コマンドの実体が無い場合は deny する。検査の消失を沈黙させない（検査を外すなら配線ごと外し、テストも同時更新する）。
- **検査対象の作業ツリーを特定できないときは fail-closed（deny）**: 誤った作業ツリーを検査して緑にするより、止めて作業ツリーを明示させるほうが安全である。判定の詳細は次節。

## 検査対象の作業ツリー

hook プロセスの cwd は、操作対象の作業ツリーと一致するとは限らない（別 worktree からの起動など）。hook 入力の `cwd` と `if` の照合範囲の仕様は Claude Code の hooks reference（<https://code.claude.com/docs/en/hooks>）に従う。

- **pre-push（push 先の作業ツリー）**: `pre-push-ci-check.sh` は、stdin の `cwd` と command 内の `cd <dir>` / `git [<global option>...] -C <dir> push` を静的に解釈して push 先の作業ツリーのルート（物理パス）を決め、秘密検知・`.gitleaks.toml`・`node_modules`・pnpm script をすべてそのルート基準で実行する。解釈する形は `&&` / `;` で並べた `cd` と `git ... push` だけで、シェル構文の完全な解析はしない。
  - 次の形は push 先を決められないため deny する: `cd` / `-C` の引数に変数・コマンド置換・`~`・glob を含む、存在しない・git 管理外のディレクトリ、`cd` のオプション、`--git-dir` / `--work-tree` / `GIT_DIR` / `GIT_WORK_TREE`、括弧・波括弧の内側の `cd`、異なる作業ツリーへの push が 1 コマンドに複数ある。deny されたら、対象の作業ツリーの中で `git push` を単独で実行する。
  - push 元と共有 git ディレクトリが異なる repository（submodule や別 clone）への push は、この project の検査対象外として通す。
  - `settings.json` は同じ hook を `Bash(git push *)` と `Bash(git -C *)` の 2 本の `if` で起動する。`if` は `git -C <dir>` を `git push *` と照合しないため、2 本目が必要になる。`git -c` や `--git-dir` など他のグローバルオプションが先頭に来る形は `if` に一致せず hook が起動しない。
- **編集後検査（post-edit-check）**: 入力ファイルの最も近い既存の祖先ディレクトリで `git rev-parse --show-toplevel` を実行して作業ツリーのルートを決め、そのルートを cwd にして eslint / tsc / `pnpm --filter` を実行する。パスは symlink を解決した物理パスで比較する。作業ツリー外のファイルは検査せず通す。
- **commit 側の hook（pre-format-check / pre-commit-submodule-guard）**: hook プロセスの cwd の作業ツリーを対象にする。`git -C <dir> commit` 形式は `if` に載せていない（既知の制限）。

## opt-in hook の有効化手順

### submodule 採用時（pre-commit-submodule-guard.sh）

1. `pre-commit-submodule-guard.sh` 冒頭の `WATCH_PATH` 既定値を実際の submodule 親パスに変更する。
2. `session-start.sh` の「opt-in: submodule 採用時に有効化」区画のコメントアウトを外し、同じパスを渡す（セッション開始時の自動初期化が第一防御、本 hook が誤コミットへの二重防御）。
3. `.claude/settings.json` の `PreToolUse` → `matcher: "Bash"` の `hooks` 配列に以下を追加する（pre-format-check より**前**に置く）:

```json
{
  "type": "command",
  "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/pre-commit-submodule-guard.sh",
  "if": "Bash(git commit *)",
  "timeout": 30,
  "statusMessage": "Checking submodule pointer changes..."
}
```

### 公開射影採用時（post-edit-projection-reminder.sh / opt-in:public-site）

1. hook 冒頭の `TARGET_DOCS`（射影元の内部正本）と `PROJECTION_DOC`（公開版）を採用構成に合わせて確認する。テスト（`tests/test-post-edit-projection-reminder.sh`）は hook 冒頭のこれらの定義（各 1 行の代入）を読み取るため、値を変えてもテストは追随する。
2. `.claude/settings.json` の `PostToolUse` → `matcher: "Write|Edit"` の `hooks` 配列に以下を追加する:

```json
{
  "type": "command",
  "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/post-edit-projection-reminder.sh",
  "timeout": 30,
  "statusMessage": "Checking projection drift..."
}
```

## hook を増減する時の規約

- `settings.json` の `command` は `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/<hook ファイル名>` の形で書く。Bash tool が `cd` した後など、cwd が作業ツリーのルートでない状態でも hook を起動でき、起動の失敗で検査が外れることを防ぐ。
- hook の追加・削除・挙動変更は、`tests/test-<hook ファイル名>.sh` の追加・削除・更新と**同一 PR** で行う（`pre-push-ci-check.sh` のテストは `tests/test-pre-push-ci-check.sh`）。`tests/run-all.sh` は `tests/test-*.sh` を自動列挙して実行する（prefix を外したファイルは実行されない）。
- `tests/run-all.sh` は実行の前に、`hooks/*.sh` のそれぞれに対応する `tests/test-<hook ファイル名>` が存在することを検査し、欠けていれば fail する。対応を要求しない hook は `run-all.sh` の `EXEMPT_HOOKS` に理由付きで置く。現状の対象は `session-start.sh` のみで、主処理が mise / pnpm install などネットワーク副作用で、hermetic に検証できる範囲が限られるためである。`../bin/` 配下のユーティリティのテスト（`test-hook-utils.sh` など）は hook との 1:1 対応の対象に含めない。
- テストは hermetic に保つ: `mktemp` の隔離 git repo で実行し、外部コマンドは `PROJ_*_CMD` 環境変数の注入 seam で stub 化し、hook の JSON 出力は jq で検証する。実 prettier / pnpm / gitleaks / eslint / tsc に依存させない。
- opt-in hook のテストも hermetic なため、ファイルが存在すれば常時実行する（配線の有無とテスト実行は独立）。opt-in グループを採用しない場合は、hook 本体とそのテストを一緒に削除する。
- CI の test job が `bash .claude/hooks/tests/run-all.sh` を実行する。マージ前にローカルでも同コマンドで green を確認する。
