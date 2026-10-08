# .claude/hooks 運用ガイド

この文書は `.claude/hooks/` 配下の hook 群が成立するための外部契約、fail-open / fail-closed の設計原則、opt-in hook の有効化手順、hook 増減時の規約を定義する。個々の hook の詳細挙動は各スクリプト冒頭のコメントに、検証ゲートのコマンド定義と hook / CI の分担は `docs/harness/skills/shared/verification-gates.md` に書く（本書には書かない）。

## 構成

| ファイル                           | イベント                                                    | 区分                                           |
| ---------------------------------- | ----------------------------------------------------------- | ---------------------------------------------- |
| session-start.sh                   | SessionStart                                                | core（配線済み）                               |
| pre-format-check.sh                | PreToolUse: `Bash(git commit *)` / `Bash(git -C *)`         | core（配線済み）                               |
| pre-push-ci-check.sh               | PreToolUse: `Bash(git push *)` / `Bash(git -C *)`           | core（配線済み）                               |
| post-edit-check.sh                 | PostToolUse: `Write\|Edit`                                  | core（配線済み）                               |
| pre-commit-submodule-guard.sh      | PreToolUse: `Bash(git commit *)` / `Bash(git -C *)`         | opt-in:submodule（未配線）                     |
| post-edit-projection-reminder.sh   | PostToolUse: `Write\|Edit`                                  | opt-in:public-site（未配線）                   |
| ../bin/hook-utils.sh               | （hooks が source する共通ユーティリティ）                  | core                                           |
| ../bin/submodule-guard.sh          | （session-start / submodule 系が source する）              | opt-in:submodule                               |
| tests/run-all.sh + tests/test-*.sh | （CI の test job が実行する hermetic テスト）               | core（opt-in hook のテストは hook と同じ区分） |
| tests/lib.sh                       | （各 test-*.sh が source する共通ヘルパ。実行対象ではない） | core                                           |

post-edit-check.sh の既定の対象言語は TS / JS（`.ts` / `.tsx` / `.js` / `.jsx`）で、eslint・`tsc --noEmit`・package 単位の `pnpm test` を実行する。対象外の拡張子は、mise の準備や作業ツリーの解決より前に通過する。eslint と TypeScript は root の devDependencies に含まれない既定外の前提である。採用しない場合は hook の拡張子 case と `tests/test-post-edit-check.sh` のケースを同時に削除し、他言語を扱う場合は hook 内の「言語別チェックの追加例」に従って拡張子 case と検査を足す。

## 外部契約 4 点（この 4 点が揃えば hooks は無改変で動く）

1. **root `package.json` の 6 script**: `build` / `test` / `lint` / `typecheck` / `format` / `format:check`。pre-push hook と CI はこの名前を呼ぶ。名前の契約と、変える場合の同時更新の範囲は `docs/harness/skills/shared/verification-gates.md`「コマンド定義」「変更時の注意」に従う。`harness:test` は契約外の補助 script で、`ci.yml` が直接呼ぶ。
2. **`.mise.toml` の pin**: node / pnpm / jq / gitleaks。hooks は mise shims 経由でこれらを解決する（jq は hook の JSON 入出力に必須）。
3. **workspace レイアウト**: パッケージは `apps/*` と `packages/*` に置く（root の `pnpm-workspace.yaml` が同じ 2 つを列挙する）。`hook-utils.sh` の `_pkg_dir_of_rel` が `apps/<name>` と `packages/<name>` の判定を 1 か所で持ち、パッケージ単位の typecheck / test の解決はそれに従う。レイアウトを変える場合は `pnpm-workspace.yaml` と `_pkg_dir_of_rel` の 2 か所を揃える。post-edit-check が受ける `file_path` は絶対パス・相対パスのどちらでもよく、作業ツリーのルートは入力ファイル側から決まる。
4. **秘密検知ツール設定**: gitleaks。誤検知の除外は root の `.gitleaks.toml` の `[allowlist]` regexes に値ベース（`\b` 厳密一致）で追記する。`.gitleaks.toml` は gitleaks の既定ルールを継承する最小構成で収録済みで、`[allowlist]` はコメントアウトした雛形として置いてある（値が 1 件も無い `[allowlist]` は gitleaks が設定エラーにするため、値を入れてからコメントを外す）。ファイルが無い場合も既定ルールで走る。

## hook と CI の分担

どのゲートを hook と CI のどちらが実行するか、hook にだけ置かれる検査をどう扱うかは `docs/harness/skills/shared/verification-gates.md`「ゲートごとの実行先」が正本である。ここには hook 側の性質だけを書く。

- hook は Claude Code 経由の操作だけに効く best-effort のローカルガードで、事故を手前で止める。Claude Code 外の端末・他ツールからの操作や、hook の `if` に一致しない形（`git -c ...` など）の操作は素通りするため、意図的な回避を防ぐ境界ではない。
- 全履歴の秘密走査など定期検査を足す場合は `docs/harness/scheduled-operations.md` の設計ガイドに従う。

## 設計原則: fail-open / fail-closed

- **ツールチェーン不在は fail-open（skip して通す）**: pnpm が PATH に無い、`node_modules` が未 install、gitleaks が未導入、といった「環境が未整備」の状態では、hook は skip した旨を `additionalContext`（または stderr）に残して操作を通す。worktree 直後の commit / push を環境都合でブロックしない。skip した検査を CI が担保するかどうかは、`verification-gates.md` の分担に従う。環境を整えて（`mise install`、`pnpm install --frozen-lockfile`）から操作し直すと完全に検査される。
- **検査スクリプト不在は fail-closed（deny）**: pre-push の `run_step` に配線した検査コマンドの実体が無い場合は deny する。検査の消失を沈黙させない（検査を外すなら配線ごと外し、テストも同時更新する）。
- **検査対象の作業ツリーを特定できないときは fail-closed（deny）**: 誤った作業ツリーを検査して緑にするより、止めて作業ツリーを明示させるほうが安全である。検査を担う pre-push と commit 系の hook が対象で、整形だけの pre-format-check は整形せずに通す。判定の詳細は次節。

## 検査対象の作業ツリー

hook プロセスの cwd は、操作対象の作業ツリーと一致するとは限らない（別 worktree からの起動など）。hook 入力の `cwd` と `if` の照合範囲の仕様は Claude Code の hooks reference（<https://code.claude.com/docs/en/hooks>）に従う。

- **Bash の git 操作（pre-push と commit 系の hook）**: 入力の `cwd` と、command 内の `cd <dir>` / `git [<global option>...] -C <dir> <subcommand>` を静的に解釈して対象の作業ツリーのルート（物理パス）を決め、以降の検査と書き換えをそのルート基準で行う。解釈は `../bin/hook-utils.sh` の `resolve_git_target` が持ち、これらの hook が共有する。解釈する形は `&&` / `;` で並べた `cd` と `git ... <subcommand>` だけで、シェル構文の完全な解析はしない。
  - 作業ツリーを決められない形の一覧と、検査対象外として通す別 repository への push は、`pre-push-ci-check.sh` 冒頭のコメントに書く。決められたときだけ検査し、誤った作業ツリーを検査して緑にしない。
  - 決められないときの動作は hook ごとに異なる。pre-push と、検査を担う commit 系の hook は deny する（fail-closed）。pre-format-check は整形せずに通す。整形は補助で、`format:check` が pre-push と CI で検証する。
  - commit 系の hook は、`git commit` が `cd` 以外のコマンドより前に実行される command だけを対象にする。`git add -A && git commit` のように前に別のコマンドが走る形は、hook 時点の staged 状態が commit の内容と一致しないため通過する。
  - `if` は `git -C <dir> <subcommand>` を `git push *` や `git commit *` と照合しない。そのため `settings.json` は、pre-push-ci-check と pre-format-check（opt-in の commit 系 hook も）を `Bash(git push *)` / `Bash(git commit *)` に加えて `Bash(git -C *)` の `if` でも起動し、script 側で対象のサブコマンドかどうかを判定する。`git -c` や `--git-dir` など他のグローバルオプションが先頭に来る形は `if` に一致せず、hook が起動しない。
- **編集後検査（post-edit-check）**: 入力ファイルの最も近い既存の祖先ディレクトリで `git rev-parse --show-toplevel` を実行して作業ツリーのルートを決め、そのルートを cwd にして eslint / tsc / `pnpm --filter` を実行する。パスは symlink を解決した物理パスで比較する。作業ツリー外のファイルは検査せず通す。

## opt-in hook の有効化手順

### submodule 採用時（pre-commit-submodule-guard.sh）

1. `pre-commit-submodule-guard.sh` 冒頭の `WATCH_PATH` 既定値を実際の submodule 親パスに変更する。
2. `session-start.sh` の「opt-in: submodule 採用時に有効化」区画のコメントアウトを外し、同じパスを渡す（セッション開始時の自動初期化が第一防御、本 hook が誤コミットへの二重防御）。
3. `.claude/settings.json` の `PreToolUse` → `matcher: "Bash"` の `hooks` 配列に以下の 2 件を追加する（`if` を 2 本にする理由は「検査対象の作業ツリー」節に書く）:

```json
[
  {
    "type": "command",
    "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/pre-commit-submodule-guard.sh",
    "if": "Bash(git commit *)",
    "timeout": 30,
    "statusMessage": "Checking submodule pointer changes..."
  },
  {
    "type": "command",
    "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/pre-commit-submodule-guard.sh",
    "if": "Bash(git -C *)",
    "timeout": 30,
    "statusMessage": "Checking submodule pointer changes..."
  }
]
```

### 公開射影採用時（post-edit-projection-reminder.sh / opt-in:public-site）

1. hook 冒頭の `TARGET_DOCS`（射影元の内部正本。作業ツリーのルート基準で、複数は `:` 区切り）と `PROJECTION_DOC`（公開版）を採用構成に合わせて確認する。各値は `PROJ_PROJECTION_*` の環境変数で上書きできる。テスト（`tests/test-post-edit-projection-reminder.sh`）はこの環境変数で値を渡すため、既定値を変えてもテストは変わらない。
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
- テストは hermetic に保つ: `mktemp` の隔離 git repo で実行し、外部コマンドは `PROJ_*_CMD` 環境変数の注入 seam で stub 化し、hook の JSON 出力は jq で検証する。実 prettier / pnpm / gitleaks / eslint / tsc に依存させない。`tests/lib.sh` が共通ヘルパを持つ（隔離 repo の作成 `init_git_repo` / `make_repo`、argv と cwd を記録する stub の `write_stub`、hook 出力の取り出し `hook_ctx` / `hook_decision` / `hook_reason`）。新しいテストはこれを source して使う。`lib.sh` は `test-*.sh` ではないため `run-all.sh` の実行対象にならず、hook との 1:1 対応の対象にも含めない。
- `tests/run-all.sh` は `test-*.sh` を並列に実行し、出力は完了後に名前順に表示する。テストは互いに独立に保つ（共有の一時ファイルや固定のパスを使わない）。
- opt-in hook のテストも hermetic なため、ファイルが存在すれば常時実行する（配線の有無とテスト実行は独立）。opt-in グループを採用しない場合は、hook 本体とそのテストを一緒に削除する。
- CI の test job が `bash .claude/hooks/tests/run-all.sh` を実行する。マージ前にローカルでも同コマンドで green を確認する。
