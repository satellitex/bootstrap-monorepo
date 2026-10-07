#!/usr/bin/env bash
# tests/lib.sh — 各 test-*.sh が source する共通ヘルパ。
#
# run-all.sh は test-*.sh だけを実行するため、本ファイルは実行対象にならない。
# set -euo pipefail は source する側が宣言する。EXIT の trap は stub の一時置き場の掃除に使う。
#
# test ファイルの先頭で次のように使う:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   HOOK="$SCRIPT_DIR/../<hook ファイル名>"
#   # shellcheck source=lib.sh
#   source "$SCRIPT_DIR/lib.sh"
#   require_hook
#
# 提供するヘルパ:
#   fail MSG                      — メッセージを出して test を失敗させる
#   require_hook [FILE]           — 被テスト hook（既定は $HOOK）が無ければ FAIL
#   init_git_repo [DIR]           — git repo を作り、test 用 user config と初期 commit を置く
#   make_repo                     — 隔離した一時 git repo（init_git_repo 済み）を作り、パスを返す
#   make_workspace_repo           — apps/api と packages/lib を持つ隔離 git repo を作り、パスを返す
#   make_main_with_worktree       — main checkout と worktree を作り、物理パスを 2 行で返す
#   write_stub DIR NAME CODE MSG [SLEEP] — argv と cwd を記録する stub コマンドを置く
#   args_of ARGS_FILE LABEL       — stub が記録した argv を空白区切りの 1 行にして返す
#   hook_ctx / hook_decision / hook_reason OUT — hook 出力 JSON から値を取り出す
#   assert_passed OUT LABEL       — 通過記録があり deny でないことを確認する

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

require_hook() {
  local file="${1:-$HOOK}"
  [[ -f "$file" ]] || fail "hook not found: $file"
}

# init_git_repo: DIR（省略時は cwd）に git repo を作り、test 用の user config を設定して
# README.md の初期 commit を置く。
init_git_repo() {
  local dir="${1:-.}"
  git init -q "$dir"
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  git -C "$dir" config commit.gpgsign false
  printf 'hello\n' > "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit -q -m "init"
}

# make_repo: 隔離した一時 git repo（init_git_repo 済み）を作り、パスを返す。
make_repo() {
  local tmp
  tmp="$(mktemp -d)"
  init_git_repo "$tmp"
  printf '%s' "$tmp"
}

# make_workspace_repo: パッケージ解決の検証に使う隔離 git repo を作り、パスを返す。
# apps/api は package.json（scripts.test あり）と tsconfig.json を持ち、packages/lib は
# tsconfig.json を持たない。
make_workspace_repo() {
  local tmp
  tmp="$(make_repo)"
  mkdir -p "$tmp/apps/api/src" "$tmp/packages/lib/src"
  printf '%s\n' '{"name":"@example/api","scripts":{"test":"vitest"}}' > "$tmp/apps/api/package.json"
  printf '%s\n' '{}' > "$tmp/apps/api/tsconfig.json"
  printf '%s\n' 'export const a = 1;' > "$tmp/apps/api/src/index.ts"
  printf '%s\n' '{"name":"@example/lib"}' > "$tmp/packages/lib/package.json"
  printf '%s\n' '# apps' > "$tmp/apps/README.md"
  printf '%s\n' '# sample' > "$tmp/NOTES.md"
  printf '%s' "$tmp"
}

# make_main_with_worktree: main checkout と、その配下の worktree（.claude/worktrees/wt）を作る。
# 両方に node_modules を置く。出力: main の物理パスと worktree の物理パスを改行区切りで返す。
make_main_with_worktree() {
  local tmp main wt
  tmp="$(mktemp -d)"
  main="$tmp/main"
  init_git_repo "$main"
  mkdir -p "$main/node_modules"
  git -C "$main" worktree add -q .claude/worktrees/wt -b wt-branch
  mkdir -p "$main/.claude/worktrees/wt/node_modules"
  main="$(cd -P "$main" && pwd -P)"
  wt="$(cd -P "$main/.claude/worktrees/wt" && pwd -P)"
  printf '%s\n%s\n' "$main" "$wt"
}

# write_stub: 実行可能な stub コマンド DIR/NAME を置く。
#   $3 exit code / $4 標準出力に出すメッセージ / $5 終了前の sleep 秒（既定 0、タイムアウト検証用）
#
# stub は受領した argv（1 行 1 引数）を "<stub>.args"、実行時の cwd（物理パス）を "<stub>.cwd" に
# 追記する。出力だけを見ていると seam 化で引数が落ちる退行に気付けないため、引数も pin できる。
# cwd は、検査が対象の作業ツリーで走ったことの確認に使う。argv ゼロでも .args を作る
# （呼び出しの有無の判定に使う）。
#
# stub の実体は内容ごとに 1 度だけ作って共有の置き場に置き、各 DIR には symlink を置く。
# 新しく作った実行ファイルは macOS で初回の実行に時間がかかる（0.3 秒程度）。その遅延を、
# 実体を作った直後の空実行（STUB_PRIME）で吸収し、タイムアウトを短くした test に持ち込まない。
# 記録先は呼び出された symlink の隣（$0）なので、実体は DIR に依存しない。
STUB_CACHE_DIR="${TMPDIR:-/tmp}/hook-test-stubs.$$"
trap 'rm -rf "$STUB_CACHE_DIR"' EXIT

write_stub() {
  local dir="$1" name="$2" code="$3" msg="$4" sleep_sec="${5:-0}"
  local body key base
  body="#!/usr/bin/env bash
[ \"\${STUB_PRIME:-}\" = 1 ] && exit 0
{ for a in \"\$@\"; do printf '%s\\n' \"\$a\"; done; } >> \"\$0.args\"
pwd -P >> \"\$0.cwd\"
if [ $sleep_sec -gt 0 ]; then
  sleep $sleep_sec
fi
if [ -n $(printf '%q' "$msg") ]; then
  printf '%s\\n' $(printf '%q' "$msg")
fi
exit $code"
  key="$(printf '%s' "$body" | cksum | tr ' ' '-')"
  base="$STUB_CACHE_DIR/stub-$key"
  if [[ ! -x "$base" ]]; then
    mkdir -p "$STUB_CACHE_DIR"
    printf '%s\n' "$body" > "$base.$$"
    chmod +x "$base.$$"
    mv "$base.$$" "$base"
    STUB_PRIME=1 "$base"
  fi
  ln -sf "$base" "$dir/$name"
}

# args_of: stub が記録した argv（1 行 1 引数）を空白区切りの 1 行に平坦化して返す（未呼び出しなら FAIL）。
args_of() {
  local args_file="$1" label="$2"
  [[ -f "$args_file" ]] || fail "$label: stub was not invoked ($args_file missing)"
  tr '\n' ' ' < "$args_file"
}

# hook の stdout（JSON）から値を取り出す（無ければ空文字）。
hook_ctx() {
  printf '%s' "$1" | jq -r '.hookSpecificOutput.additionalContext // empty'
}

hook_decision() {
  printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecision // empty'
}

hook_reason() {
  printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty'
}

# assert_passed: 通過記録（additionalContext に passed）があり、deny でないことを確認する。
assert_passed() {
  local out="$1" label="$2"
  [[ "$(hook_decision "$out")" != "deny" ]] || fail "$label: must not deny (out=$out)"
  grep -q 'passed' <<< "$(hook_ctx "$out")" || fail "$label: expected a pass record (out=$out)"
}
