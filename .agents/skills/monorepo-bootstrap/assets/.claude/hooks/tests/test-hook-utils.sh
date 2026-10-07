#!/usr/bin/env bash
set -euo pipefail

# hook-utils.sh の hermetic ユニットテスト。
# bash / git / jq のみで動く（pnpm 不要）。
# .claude/bin/hook-utils.sh が提供する各関数を個別にテストする。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_UTILS="$SCRIPT_DIR/../../bin/hook-utils.sh"

# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
require_hook "$HOOK_UTILS"

# shellcheck source=../../bin/hook-utils.sh
source "$HOOK_UTILS"

# --------------------------------------------------------------------------
# Test 1: compact_output — 短い出力はそのまま返す（圧縮しない）。
# --------------------------------------------------------------------------
test1_compact_output_short() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  (
    cd "$tmpdir"
    export HOOK_LOG_PREFIX="test"
    local input="line1
line2
line3"
    local out
    out="$(compact_output "label" "$input" 200)"
    [[ "$out" == "$input" ]] \
      || fail "test1: short output should be returned as-is (got: $out)"
  )
  rm -rf "$tmpdir"
  echo "PASS test1: compact_output returns short output as-is"
}

# --------------------------------------------------------------------------
# Test 2: compact_output — 上限超えで head/tail 形式に圧縮する。
# --------------------------------------------------------------------------
test2_compact_output_truncates() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  (
    cd "$tmpdir"
    export HOOK_LOG_PREFIX="test"
    local input=""
    local i=1
    while [ "$i" -le 210 ]; do
      input="${input}line${i}
"
      i=$((i + 1))
    done
    local out
    out="$(compact_output "label" "$input" 10)"
    grep -q 'omitted\|Full log' <<< "$out" \
      || fail "test2: large output should be compacted"
    grep -q 'line1' <<< "$out" \
      || fail "test2: first line should appear in compacted output"
    grep -q 'line210' <<< "$out" \
      || fail "test2: last line should appear in compacted output"
    # ログファイルが prefix 付きで保存されていること
    ls .claude/state/hook-logs/test-label-*.log >/dev/null 2>&1 \
      || fail "test2: full log file with HOOK_LOG_PREFIX should be saved"
  )
  rm -rf "$tmpdir"
  echo "PASS test2: compact_output truncates large output with head/tail"
}

# --------------------------------------------------------------------------
# Test 3: compact_file — ファイル入力版が短い内容をそのまま返す。
# --------------------------------------------------------------------------
test3_compact_file_short() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  (
    cd "$tmpdir"
    export HOOK_LOG_PREFIX="test"
    printf 'aaa\nbbb\n' > input.txt
    local out
    out="$(compact_file "label" "input.txt" 100)"
    [[ "$out" == "aaa
bbb" ]] || fail "test3: compact_file should return file content as-is (got: $out)"
  )
  rm -rf "$tmpdir"
  echo "PASS test3: compact_file returns short file content as-is"
}

# --------------------------------------------------------------------------
# Test 4: resolve_package — apps/<name> から package.json の name を返す。
# パッケージ外のファイルは空文字を返す。
# --------------------------------------------------------------------------
test4_resolve_package() {
  local repo pkg
  repo="$(make_workspace_repo)"
  (
    cd "$repo"
    pkg="$(resolve_package "apps/api/src/index.ts")"
    [[ "$pkg" == "@example/api" ]] \
      || fail "test4: resolve_package should return @example/api, got: $pkg"
    pkg="$(resolve_package "packages/lib/src/index.ts")"
    [[ "$pkg" == "@example/lib" ]] \
      || fail "test4: resolve_package should return @example/lib for packages/*, got: $pkg"
    pkg="$(resolve_package "scripts/foo.ts")"
    [[ -z "$pkg" ]] \
      || fail "test4: resolve_package should return empty for out-of-package path, got: $pkg"
  )
  rm -rf "$repo"
  echo "PASS test4: resolve_package resolves apps / packages and returns empty outside"
}

# --------------------------------------------------------------------------
# Test 5: resolve_tsconfig — tsconfig.json の有無でパス / 空文字を返す。
# --------------------------------------------------------------------------
test5_resolve_tsconfig() {
  local repo ts
  repo="$(make_workspace_repo)"
  (
    cd "$repo"
    ts="$(resolve_tsconfig "apps/api/src/index.ts")"
    [[ "$ts" == "apps/api/tsconfig.json" ]] \
      || fail "test5: resolve_tsconfig should return apps/api/tsconfig.json, got: $ts"
    ts="$(resolve_tsconfig "packages/lib/src/index.ts")"
    [[ -z "$ts" ]] \
      || fail "test5: resolve_tsconfig should return empty when no tsconfig, got: $ts"
  )
  rm -rf "$repo"
  echo "PASS test5: resolve_tsconfig returns path or empty"
}

# --------------------------------------------------------------------------
# Test 6: has_test_script — scripts.test の有無で 0 / 1 を返す。
# --------------------------------------------------------------------------
test6_has_test_script() {
  local repo
  repo="$(make_workspace_repo)"
  (
    cd "$repo"
    has_test_script "apps/api" \
      || fail "test6: has_test_script should return 0 when scripts.test exists"
    if has_test_script "packages/lib"; then
      fail "test6: has_test_script should return 1 when no test script"
    fi
  )
  rm -rf "$repo"
  echo "PASS test6: has_test_script returns 0/1 by scripts.test"
}

# --------------------------------------------------------------------------
# Test 7: run_limited_check — 成功は空出力、失敗は compact された出力。
# --------------------------------------------------------------------------
test7_run_limited_check() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  (
    cd "$tmpdir"
    export HOOK_LOG_PREFIX="test"
    local out
    out="$(run_limited_check 5 "ok-label" 100 true)"
    [[ -z "$out" ]] \
      || fail "test7: successful command should produce no output (out=$out)"
    out="$(run_limited_check 5 "ng-label" 100 bash -c 'echo "error output"; exit 1')"
    [[ -n "$out" ]] \
      || fail "test7: failed command should produce output (got empty)"
    grep -q 'error output' <<< "$out" \
      || fail "test7: output should contain command output (out=$out)"
  )
  rm -rf "$tmpdir"
  echo "PASS test7: run_limited_check success empty / failure compacted"
}

# --------------------------------------------------------------------------
# Test 8: run_limited_check — 期限を超えた検査は timeout 表示になり、検査コマンドの子も止まる。
# 期限までの待ちは 1 秒程度で済み（検査コマンドの完了を待たない）、stderr に job 通知を出さない。
# --------------------------------------------------------------------------
test8_run_limited_check_timeout() {
  local tmpdir out started elapsed child errors
  tmpdir="$(mktemp -d)"
  (
    cd "$tmpdir"
    export HOOK_LOG_PREFIX="test"
    started=$SECONDS
    out="$(run_limited_check 1 "slow-label" 100 bash -c 'sleep 30 & echo $! > child.pid; wait' 2> stderr.log)"
    elapsed=$((SECONDS - started))
    [[ "$out" == "[slow-label] timed out after 1s" ]] \
      || fail "test8: timeout should be reported (out=$out)"
    [[ "$elapsed" -lt 10 ]] \
      || fail "test8: timeout must not wait for the command to finish (elapsed=${elapsed}s)"
    [[ ! -s stderr.log ]] \
      || { errors="$(cat stderr.log)"; fail "test8: timeout must not print job notices to stderr (stderr=$errors)"; }
    child="$(cat child.pid)"
    local i=0
    while kill -0 "$child" 2>/dev/null && [[ "$i" -lt 20 ]]; do
      sleep 0.1
      i=$((i + 1))
    done
    ! kill -0 "$child" 2>/dev/null \
      || { kill "$child" 2>/dev/null || true; fail "test8: the command's child process must be stopped on timeout"; }
  )
  rm -rf "$tmpdir"
  echo "PASS test8: run_limited_check reports timeout and stops the command's children"
}

# --------------------------------------------------------------------------
# Test 9: run_limited_check — timeout / gtimeout がある環境では、その終了コード 124 を timeout 扱いにする。
# gtimeout を優先して探すため、同名の偽コマンドを PATH の先頭に置いて環境差を除く。
# --------------------------------------------------------------------------
test9_run_limited_check_with_timeout_command() {
  local tmpdir fake out
  tmpdir="$(mktemp -d)"
  fake="$(mktemp -d)"
  printf '#!/usr/bin/env bash\nshift\ncase "$1" in\n  slow-cmd) exit 124 ;;\nesac\nexec "$@"\n' > "$fake/gtimeout"
  chmod +x "$fake/gtimeout"
  (
    cd "$tmpdir"
    export HOOK_LOG_PREFIX="test"
    export PATH="$fake:$PATH"
    out="$(run_limited_check 7 "slow-label" 100 slow-cmd)"
    [[ "$out" == "[slow-label] timed out after 7s" ]] \
      || fail "test9: exit code 124 from timeout should be reported as a timeout (out=$out)"
    out="$(run_limited_check 7 "ok-label" 100 true)"
    [[ -z "$out" ]] || fail "test9: success through timeout should produce no output (out=$out)"
    out="$(run_limited_check 7 "ng-label" 100 bash -c 'echo broken; exit 2')"
    grep -q 'broken' <<< "$out" \
      || fail "test9: failure through timeout should return the command output (out=$out)"
  )
  rm -rf "$tmpdir" "$fake"
  echo "PASS test9: run_limited_check handles timeout / gtimeout exit codes"
}

# --------------------------------------------------------------------------
# 以降はパス正規化（絶対パス・symlink・hook の cwd と作業ツリーが異なる起動）の検証。
# locate_repo_path は結果を REPO_PATH_ROOT / REPO_PATH_REL に返す（サブシェルを増やさない）。
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# Test 10: locate_repo_path — 相対パスは git 管理外でもそのまま返す（先頭 ./ は除去）。
# normalize_repo_path は同じ相対パスを返す。
# --------------------------------------------------------------------------
test10_locate_relative() {
  local tmpdir out
  tmpdir="$(mktemp -d)"
  (
    cd "$tmpdir"
    locate_repo_path "apps/api/src/index.ts"
    [[ "$REPO_PATH_REL" == "apps/api/src/index.ts" ]] \
      || fail "test10: relative path should be returned as-is, got: $REPO_PATH_REL"
    locate_repo_path "./apps/api/src/index.ts"
    [[ "$REPO_PATH_REL" == "apps/api/src/index.ts" ]] \
      || fail "test10: leading ./ should be stripped, got: $REPO_PATH_REL"
    locate_repo_path ""
    [[ -z "$REPO_PATH_REL" && -z "$REPO_PATH_ROOT" ]] \
      || fail "test10: empty input should return empty, got: root=$REPO_PATH_ROOT rel=$REPO_PATH_REL"
    out="$(normalize_repo_path "apps/api/src/index.ts")"
    [[ "$out" == "apps/api/src/index.ts" ]] \
      || fail "test10: normalize_repo_path should return the relative path, got: $out"
  )
  rm -rf "$tmpdir"
  echo "PASS test10: locate_repo_path keeps relative paths"
}

# --------------------------------------------------------------------------
# Test 11: locate_repo_path — 絶対パスは作業ツリーのルート基準へ相対化する。
# hook の cwd が別ディレクトリでも、ルートは入力ファイル側から決まる。
# --------------------------------------------------------------------------
test11_locate_absolute() {
  local repo other root
  repo="$(make_workspace_repo)"
  other="$(mktemp -d)"
  root="$(cd -P "$repo" && pwd -P)"
  (
    cd "$repo"
    locate_repo_path "$repo/apps/api/src/index.ts"
    [[ "$REPO_PATH_REL" == "apps/api/src/index.ts" && "$REPO_PATH_ROOT" == "$root" ]] \
      || fail "test11: absolute path (cwd=repo) should be relativized, got: root=$REPO_PATH_ROOT rel=$REPO_PATH_REL"
    cd "$other"
    locate_repo_path "$repo/apps/api/src/index.ts"
    [[ "$REPO_PATH_REL" == "apps/api/src/index.ts" && "$REPO_PATH_ROOT" == "$root" ]] \
      || fail "test11: absolute path (cwd elsewhere) should be relativized from the file's own root, got: root=$REPO_PATH_ROOT rel=$REPO_PATH_REL"
    cd "$repo/apps/api"
    locate_repo_path "src/index.ts"
    [[ "$REPO_PATH_REL" == "apps/api/src/index.ts" && "$REPO_PATH_ROOT" == "$root" ]] \
      || fail "test11: relative path from a subdirectory should be root-relative, got: root=$REPO_PATH_ROOT rel=$REPO_PATH_REL"
  )
  rm -rf "$repo" "$other"
  echo "PASS test11: locate_repo_path relativizes absolute paths from the file's root"
}

# --------------------------------------------------------------------------
# Test 12: symlink — 作業ツリーが symlink 経由のパスで渡されても相対化できる。
# 作業ツリーのルートは物理パスで返る。symlink を辿って repo 外へ出るパスは空文字にする。
# --------------------------------------------------------------------------
test12_locate_symlink() {
  local repo link_parent link outside expected_root
  repo="$(make_workspace_repo)"
  link_parent="$(mktemp -d)"
  link="$link_parent/via-link"
  ln -s "$repo" "$link"
  outside="$(mktemp -d)"
  printf 'x\n' > "$outside/escaped.ts"
  ln -s "$outside" "$repo/apps/escape"
  expected_root="$(cd -P "$repo" && pwd -P)"
  (
    cd "$link_parent"
    locate_repo_path "$link/apps/api/src/index.ts"
    [[ "$REPO_PATH_REL" == "apps/api/src/index.ts" ]] \
      || fail "test12: path via a symlinked root should be relativized, got: $REPO_PATH_REL"
    [[ "$REPO_PATH_ROOT" == "$expected_root" ]] \
      || fail "test12: root should be the physical path ($expected_root), got: $REPO_PATH_ROOT"
    locate_repo_path "$repo/apps/escape/escaped.ts"
    [[ -z "$REPO_PATH_REL" && -z "$REPO_PATH_ROOT" ]] \
      || fail "test12: path escaping the worktree through a symlink should be empty, got: root=$REPO_PATH_ROOT rel=$REPO_PATH_REL"
  )
  rm -rf "$repo" "$link_parent" "$outside"
  echo "PASS test12: locate_repo_path handles symlinked roots and escapes"
}

# --------------------------------------------------------------------------
# Test 13: ルート外・未作成のパス。
# 別の作業ツリーや git 管理外のパスは空文字。未作成のファイルは既存の祖先から解決する。
# --------------------------------------------------------------------------
test13_locate_outside_and_missing() {
  local repo other
  repo="$(make_workspace_repo)"
  other="$(mktemp -d)"
  printf 'x\n' > "$other/foo.ts"
  (
    cd "$repo"
    locate_repo_path "$other/foo.ts"
    [[ -z "$REPO_PATH_REL" ]] \
      || fail "test13: path outside the worktree should be empty, got: $REPO_PATH_REL"
    locate_repo_path "$repo/apps/api/src/not/yet/created.ts"
    [[ "$REPO_PATH_REL" == "apps/api/src/not/yet/created.ts" ]] \
      || fail "test13: missing file should resolve from an existing ancestor, got: $REPO_PATH_REL"
    locate_repo_path "/no/such/dir/at/all.ts"
    [[ -z "$REPO_PATH_REL" ]] \
      || fail "test13: a path whose ancestors are all missing should be empty, got: $REPO_PATH_REL"
  )
  rm -rf "$repo" "$other"
  echo "PASS test13: locate_repo_path returns empty outside the worktree"
}

# --------------------------------------------------------------------------
# Test 14: _pkg_dir_of_rel — apps/<name> と packages/<name> の判定は 1 か所にある。
# パッケージ直下でないパス（apps 直下のファイルなど）はパッケージ外。
# --------------------------------------------------------------------------
test14_pkg_dir_of_rel() {
  local out pair
  for pair in "apps/api/src/index.ts:apps/api" "packages/lib/package.json:packages/lib" "apps/api/x:apps/api"; do
    out="$(_pkg_dir_of_rel "${pair%%:*}")"
    [[ "$out" == "${pair#*:}" ]] \
      || fail "test14: ${pair%%:*} should map to ${pair#*:}, got: $out"
  done
  for pair in apps/README.md scripts/foo.ts docs/apps/x.md apps/api ""; do
    out="$(_pkg_dir_of_rel "$pair")"
    [[ -z "$out" ]] || fail "test14: '$pair' is not in a package, got: $out"
  done
  echo "PASS test14: _pkg_dir_of_rel maps package paths and rejects others"
}

# --------------------------------------------------------------------------
# Test 15: resolve_package / resolve_tsconfig / resolve_package_dir は絶対パスでも解決する。
# hook の cwd が作業ツリーと異なっていても、ルート基準の相対パスを返す。
# --------------------------------------------------------------------------
test15_resolve_with_absolute_path() {
  local repo other out
  repo="$(make_workspace_repo)"
  other="$(mktemp -d)"
  (
    cd "$other"
    out="$(resolve_package "$repo/apps/api/src/index.ts")"
    [[ "$out" == "@example/api" ]] \
      || fail "test15: resolve_package should resolve an absolute path, got: $out"
    out="$(resolve_tsconfig "$repo/apps/api/src/index.ts")"
    [[ "$out" == "apps/api/tsconfig.json" ]] \
      || fail "test15: resolve_tsconfig should return a root-relative path, got: $out"
    out="$(resolve_package_dir "$repo/apps/api/src/index.ts")"
    [[ "$out" == "apps/api" ]] \
      || fail "test15: resolve_package_dir should return apps/api, got: $out"
    out="$(resolve_tsconfig "$repo/packages/lib/src/index.ts")"
    [[ -z "$out" ]] \
      || fail "test15: package without tsconfig should resolve to empty, got: $out"
    out="$(resolve_package_dir "$repo/apps/README.md")"
    [[ -z "$out" ]] \
      || fail "test15: a file directly under apps/ is not in a package, got: $out"
    out="$(resolve_package "$other/scripts/foo.ts")"
    [[ -z "$out" ]] \
      || fail "test15: out-of-worktree path should resolve to empty, got: $out"
  )
  rm -rf "$repo" "$other"
  echo "PASS test15: package resolution works for absolute paths"
}

# --------------------------------------------------------------------------
# Test 16: emit_hook_context / emit_hook_deny — hook の出力 JSON の形。
# --------------------------------------------------------------------------
test16_emit_hook_output() {
  local out
  out="$(emit_hook_context PostToolUse $'line1\n"quoted"')"
  [[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')" == "PostToolUse" ]] \
    || fail "test16: emit_hook_context should set the event name (out=$out)"
  [[ "$(hook_ctx "$out")" == $'line1\n"quoted"' ]] \
    || fail "test16: emit_hook_context should carry the message verbatim (out=$out)"
  [[ -z "$(hook_decision "$out")" ]] \
    || fail "test16: emit_hook_context must not carry a decision (out=$out)"

  out="$(emit_hook_deny "blocked: reason")"
  [[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')" == "PreToolUse" ]] \
    || fail "test16: emit_hook_deny should use the PreToolUse event (out=$out)"
  [[ "$(hook_decision "$out")" == "deny" && "$(hook_reason "$out")" == "blocked: reason" ]] \
    || fail "test16: emit_hook_deny should deny with the reason (out=$out)"
  echo "PASS test16: emit_hook_context / emit_hook_deny produce the hook JSON"
}

# --------------------------------------------------------------------------
# Test 17: read_bash_input — command と cwd を 1 回の jq で取り出す。
# command の改行・クォートは保たれ、cwd が無ければ hook の cwd になる。
# --------------------------------------------------------------------------
test17_read_bash_input() {
  local json
  json="$(jq -n --arg c $'git commit -m "a\nb"' --arg d "/x y" '{tool_input: {command: $c}, cwd: $d}')"
  read_bash_input "$json"
  [[ "$HOOK_CMD" == $'git commit -m "a\nb"' ]] \
    || fail "test17: command should be read verbatim, got: $HOOK_CMD"
  [[ "$HOOK_BASE_DIR" == "/x y" ]] \
    || fail "test17: cwd should be read from the input, got: $HOOK_BASE_DIR"

  read_bash_input '{"tool_input":{"command":"git status"}}'
  [[ "$HOOK_CMD" == "git status" && "$HOOK_BASE_DIR" == "$PWD" ]] \
    || fail "test17: a missing cwd should fall back to the hook's cwd, got: cmd=$HOOK_CMD dir=$HOOK_BASE_DIR"

  read_bash_input '{}'
  [[ -z "$HOOK_CMD" ]] || fail "test17: a missing command should be empty, got: $HOOK_CMD"
  echo "PASS test17: read_bash_input reads command and cwd"
}

# --------------------------------------------------------------------------
# 以降は resolve_git_target（command が作用する作業ツリーの静的な解決）の検証。
# 結果は GIT_TARGET_ROOT / GIT_TARGET_DIR / GIT_TARGET_PRECEDED / GIT_TARGET_UNRESOLVED に返る。
# main checkout と worktree（.claude/worktrees/wt）を使い、物理パスで比較する。
# --------------------------------------------------------------------------

# resolve_git_target を呼び、ルートが期待値（空文字は「対象なし」）で、未解決の理由が空であることを確認する。
# $1 label / $2 サブコマンド / $3 command / $4 cwd / $5 期待するルート
assert_target_root() {
  local label="$1" sub="$2" cmd="$3" base="$4" expected="$5"
  resolve_git_target "$sub" "$cmd" "$base"
  [[ -z "$GIT_TARGET_UNRESOLVED" ]] \
    || fail "$label: must resolve (cmd=$cmd, unresolved=$GIT_TARGET_UNRESOLVED)"
  [[ "$GIT_TARGET_ROOT" == "$expected" ]] \
    || fail "$label: root should be '$expected' (cmd=$cmd, got: $GIT_TARGET_ROOT)"
}

# --------------------------------------------------------------------------
# Test 18: cwd・`cd <dir>`・`git -C <dir>`（グローバルオプション併用、相対パス、symlink を含む）から
# 対象の作業ツリーのルートを決める。cwd がサブディレクトリでもルートを返す。
# --------------------------------------------------------------------------
test18_resolve_git_target_roots() {
  local main wt link_parent
  { read -r main; read -r wt; } < <(make_main_with_worktree)
  mkdir -p "$wt/sub/dir"
  link_parent="$(mktemp -d)"
  ln -s "$wt" "$link_parent/wt-link"

  assert_target_root test18 push "git push origin wt-branch" "$wt" "$wt"
  assert_target_root test18 push "git push" "$wt/sub/dir" "$wt"
  assert_target_root test18 push "cd $wt && git push origin wt-branch" "$main" "$wt"
  assert_target_root test18 push "git -C $wt push" "$main" "$wt"
  assert_target_root test18 push "git -c core.quotepath=off -C $wt push origin wt-branch" "$main" "$wt"
  assert_target_root test18 push "cd .claude/worktrees/wt && git push" "$main" "$wt"
  assert_target_root test18 push "git -C .claude/worktrees/wt push" "$main" "$wt"
  assert_target_root test18 push "cd sub && git push" "$wt" "$wt"
  assert_target_root test18 push "cd $link_parent/wt-link && git push" "$main" "$wt"
  assert_target_root test18 push "GIT_TERMINAL_PROMPT=0 git push" "$wt" "$wt"
  assert_target_root test18 push "git push && git push origin x" "$wt" "$wt"

  # cd / -C を経ない command は、ルートを求めたディレクトリが cwd と同じ値になる。
  resolve_git_target push "git push" "$wt/sub/dir"
  [[ "$GIT_TARGET_DIR" == "$wt/sub/dir" ]] \
    || fail "test18: without cd / -C the target dir should equal the cwd (got: $GIT_TARGET_DIR)"
  resolve_git_target push "git -C $wt push" "$main"
  [[ "$GIT_TARGET_DIR" == "$wt" ]] \
    || fail "test18: with -C the target dir should be the -C directory (got: $GIT_TARGET_DIR)"

  rm -rf "$(dirname "$main")" "$link_parent"
  echo "PASS test18: resolve_git_target resolves the target worktree root"
}

# --------------------------------------------------------------------------
# Test 19: 対象のサブコマンドを含まない command は、ルートも未解決の理由も空で返す。
# 別のサブコマンド・文字列としての出現・引数としての出現は対象にしない。
# --------------------------------------------------------------------------
test19_resolve_git_target_no_subcommand() {
  local main wt cmd
  { read -r main; read -r wt; } < <(make_main_with_worktree)
  for cmd in \
    "git status" \
    "git -C $wt status" \
    "git -C $wt log --grep push" \
    "git -C $wt commit -m 'fix push handling'" \
    "git -C $wt stash push" \
    "echo git push" \
    "cd $wt" \
    ""; do
    assert_target_root test19 push "$cmd" "$main" ""
  done
  assert_target_root test19 commit "git -C $wt push origin x" "$main" ""
  assert_target_root test19 commit "git commit-tree HEAD^{tree}" "$main" ""
  rm -rf "$(dirname "$main")"
  echo "PASS test19: commands without the subcommand resolve to no target"
}

# --------------------------------------------------------------------------
# Test 20: 作業ツリーを静的に決められない形は、ルートを空にして未解決の理由を返す。
# 誤った作業ツリーを対象にしないための判定で、呼び出し側が通過させるか止めるかを選ぶ。
# --------------------------------------------------------------------------
test20_resolve_git_target_unresolved() {
  local main wt plain cmd
  { read -r main; read -r wt; } < <(make_main_with_worktree)
  plain="$(mktemp -d)"
  for cmd in \
    'cd "$WT_DIR" && git push' \
    'cd $(pwd) && git push' \
    'git -C ~/work push' \
    'git -C "$(dirname "$PWD")" push' \
    'cd .claude/worktrees/* && git push' \
    "cd $main/does-not-exist && git push" \
    "git -C $plain push" \
    "git --git-dir=$main/.git push" \
    "git --work-tree=$wt push" \
    "GIT_DIR=$main/.git git push" \
    "GIT_WORK_TREE=$wt git push" \
    "(cd $wt && git push)" \
    "{ cd $wt && git push; }" \
    "cd -P $wt && git push" \
    "cd && git push" \
    "cd $wt && git push && cd $main && git push"; do
    resolve_git_target push "$cmd" "$main"
    [[ -n "$GIT_TARGET_UNRESOLVED" && -z "$GIT_TARGET_ROOT" ]] \
      || fail "test20: unresolvable target must report a reason and no root (cmd=$cmd, root=$GIT_TARGET_ROOT)"
  done
  resolve_git_target push "git push" "$plain"
  [[ -n "$GIT_TARGET_UNRESOLVED" ]] \
    || fail "test20: a cwd outside any worktree must be unresolved"
  resolve_git_target push "git push" "$main"
  [[ -z "$GIT_TARGET_UNRESOLVED" && "$GIT_TARGET_ROOT" == "$main" ]] \
    || fail "test20: results must be reset on every call (root=$GIT_TARGET_ROOT, unresolved=$GIT_TARGET_UNRESOLVED)"
  rm -rf "$(dirname "$main")" "$plain"
  echo "PASS test20: unresolvable targets report a reason and no root"
}

# --------------------------------------------------------------------------
# Test 21: サブコマンドは引数で選ぶ。commit でも同じ規則で `git -C <dir> commit` と
# `cd <dir> && git commit` の対象を決められる。SUB より前に cd 以外のコマンドが走る command は
# GIT_TARGET_PRECEDED が 1 になる（cd と環境変数の代入は数えない）。
# --------------------------------------------------------------------------
test21_resolve_git_target_commit_and_preceded() {
  local main wt cmd
  { read -r main; read -r wt; } < <(make_main_with_worktree)

  assert_target_root test21 commit "git -C $wt commit -m x" "$main" "$wt"
  assert_target_root test21 commit "cd $wt && git commit -m x" "$main" "$wt"
  assert_target_root test21 commit "git commit -m x" "$wt" "$wt"

  for cmd in "git commit -m x" "git -C $wt commit -m x" "cd $wt && git commit -m x" \
    "GIT_AUTHOR_NAME=a git commit -m x" "git commit -m x && git push"; do
    resolve_git_target commit "$cmd" "$main"
    [[ "$GIT_TARGET_PRECEDED" -eq 0 ]] \
      || fail "test21: nothing but cd precedes the commit (cmd=$cmd, preceded=$GIT_TARGET_PRECEDED)"
  done
  for cmd in "git add -A && git commit -m x" "echo hi; git commit -m x" \
    "cd $wt && git add -A && git commit -m x" "git commit -m a && git commit -m b"; do
    resolve_git_target commit "$cmd" "$main"
    [[ "$GIT_TARGET_PRECEDED" -eq 1 ]] \
      || fail "test21: another command precedes the commit (cmd=$cmd, preceded=$GIT_TARGET_PRECEDED)"
  done
  rm -rf "$(dirname "$main")"
  echo "PASS test21: resolve_git_target handles commit and reports preceding commands"
}

# --------------------------------------------------------------------------
# Test 22: 多バイト文字を含む command でも、語の分割と対象の解決が崩れない。
# tokenize はバイト単位に揃えて走査するが、値は元の文字列のまま返す。
# --------------------------------------------------------------------------
test22_resolve_git_target_multibyte() {
  local base tmp expected
  tmp="$(mktemp -d)"
  base="$tmp/日本語 dir"
  mkdir -p "$base"
  init_git_repo "$base"
  expected="$(cd -P "$base" && pwd -P)"
  assert_target_root test22 commit "git -C \"$base\" commit -m 'メッセージ 日本語'" "$tmp" "$expected"
  tokenize "git commit -m 'メッセージ 日本語' && echo ok"
  [[ "${tok_val[3]}" == "メッセージ 日本語" && "${tok_val[4]}" == "&&" ]] \
    || fail "test22: a quoted multibyte word should stay one token (got: ${tok_val[3]} / ${tok_val[4]})"
  rm -rf "$tmp"
  echo "PASS test22: resolve_git_target handles multibyte commands"
}

test1_compact_output_short
test2_compact_output_truncates
test3_compact_file_short
test4_resolve_package
test5_resolve_tsconfig
test6_has_test_script
test7_run_limited_check
test8_run_limited_check_timeout
test9_run_limited_check_with_timeout_command
test10_locate_relative
test11_locate_absolute
test12_locate_symlink
test13_locate_outside_and_missing
test14_pkg_dir_of_rel
test15_resolve_with_absolute_path
test16_emit_hook_output
test17_read_bash_input
test18_resolve_git_target_roots
test19_resolve_git_target_no_subcommand
test20_resolve_git_target_unresolved
test21_resolve_git_target_commit_and_preceded
test22_resolve_git_target_multibyte

echo "ALL PASS"
