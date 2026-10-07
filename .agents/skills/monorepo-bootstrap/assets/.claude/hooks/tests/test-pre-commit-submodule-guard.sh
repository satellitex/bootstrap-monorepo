#!/usr/bin/env bash
set -euo pipefail

# pre-commit-submodule-guard.sh（opt-in:submodule）の hermetic テスト。
# bash / git / jq のみで動く。一時 git repo の index に偽の gitlink（mode 160000）を直接書き、
# submodule の実体を用意せずに「staged 変更に submodule pointer が含まれる」状態を再現する。
# 監視対象パスは PROJ_SUBMODULE_WATCH_PATH で隔離 repo 内の一時パスへ向ける。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../pre-commit-submodule-guard.sh"

# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
require_hook

# 偽の gitlink に使う commit id（実在しなくてよい）。
SHA_A="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
SHA_B="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

# index に偽の gitlink を追加 / 更新する（$1 パス、$2 commit id）。
stage_gitlink() {
  git update-index --add --cacheinfo "160000,$2,$1"
}

# hook を repo 内で実行して stdout を返す。$1 repo、$2 command、$3 入力の cwd（省略時は無し）。
# PROJ_* の環境変数は呼び出し側が前置して渡す。
run_hook() {
  local repo="$1" command="$2" stdin_cwd="${3:-}"
  (
    cd "$repo"
    jq -n --arg c "$command" --arg d "$stdin_cwd" \
      '{tool_input: {command: $c}} + (if $d == "" then {} else {cwd: $d} end)' | bash "$HOOK"
  )
}

# --------------------------------------------------------------------------
# Test 1 (防御ガード): git commit 以外のコマンドは、gitlink が staged でも無出力で通過する。
# --------------------------------------------------------------------------
test1_non_commit_passthrough() {
  local repo out
  repo="$(make_repo)"
  (cd "$repo" && stage_gitlink "vendor/dep" "$SHA_A")
  out="$(PROJ_SUBMODULE_WATCH_PATH=vendor run_hook "$repo" "git status")"
  [[ -z "$out" ]] || fail "test1: non-commit command must pass through with no output (out=$out)"
  out="$(PROJ_SUBMODULE_WATCH_PATH=vendor run_hook "$repo" "git push origin main")"
  [[ -z "$out" ]] || fail "test1: push must be left to the push hook (out=$out)"
  rm -rf "$repo"
  echo "PASS test1: non-commit command passes through"
}

# --------------------------------------------------------------------------
# Test 2: 監視対象パス配下に新規 gitlink が staged なら deny し、理由に path と復旧・override
# の手順を含める。
# --------------------------------------------------------------------------
test2_new_gitlink_denied() {
  local repo out reason
  repo="$(make_repo)"
  (cd "$repo" && stage_gitlink "vendor/dep" "$SHA_A")
  out="$(PROJ_SUBMODULE_WATCH_PATH=vendor run_hook "$repo" "git commit -m 'add dep'")"
  [[ "$(hook_decision "$out")" == "deny" ]] \
    || fail "test2: a staged gitlink under the watch path must deny (out=$out)"
  reason="$(hook_reason "$out")"
  grep -qF 'vendor/dep' <<< "$reason" \
    || fail "test2: deny reason should name the gitlink path (reason=$reason)"
  grep -qF 'PROJ_ALLOW_SUBMODULE_PIN_UPDATE=1' <<< "$reason" \
    || fail "test2: deny reason should mention the override (reason=$reason)"
  grep -qF 'git restore --staged vendor' <<< "$reason" \
    || fail "test2: deny reason should include the recovery command (reason=$reason)"
  rm -rf "$repo"
  echo "PASS test2: new gitlink under the watch path is denied"
}

# --------------------------------------------------------------------------
# Test 3: 既存 pointer の更新（old / new とも mode 160000）も deny する。
# --------------------------------------------------------------------------
test3_pointer_update_denied() {
  local repo out
  repo="$(make_repo)"
  (
    cd "$repo"
    stage_gitlink "vendor/dep" "$SHA_A"
    git commit -q -m "add dep"
    stage_gitlink "vendor/dep" "$SHA_B"
  )
  out="$(PROJ_SUBMODULE_WATCH_PATH=vendor run_hook "$repo" "git commit -m 'bump dep'")"
  [[ "$(hook_decision "$out")" == "deny" ]] \
    || fail "test3: a pointer update under the watch path must deny (out=$out)"
  rm -rf "$repo"
  echo "PASS test3: pointer update is denied"
}

# --------------------------------------------------------------------------
# Test 4: PROJ_ALLOW_SUBMODULE_PIN_UPDATE=1 の override は deny せず、skip した旨を
# additionalContext で伝える。値が 1 以外なら override にならない。
# --------------------------------------------------------------------------
test4_override() {
  local repo out ctx
  repo="$(make_repo)"
  (cd "$repo" && stage_gitlink "vendor/dep" "$SHA_A")
  out="$(PROJ_SUBMODULE_WATCH_PATH=vendor PROJ_ALLOW_SUBMODULE_PIN_UPDATE=1 \
    run_hook "$repo" "git commit -m 'bump dep'")"
  [[ "$(hook_decision "$out")" != "deny" ]] \
    || fail "test4: override must not deny (out=$out)"
  ctx="$(hook_ctx "$out")"
  grep -qF 'PROJ_ALLOW_SUBMODULE_PIN_UPDATE=1' <<< "$ctx" \
    || fail "test4: override should leave a note in additionalContext (out=$out)"
  out="$(PROJ_SUBMODULE_WATCH_PATH=vendor PROJ_ALLOW_SUBMODULE_PIN_UPDATE=true \
    run_hook "$repo" "git commit -m 'bump dep'")"
  [[ "$(hook_decision "$out")" == "deny" ]] \
    || fail "test4: only the value 1 may override (out=$out)"
  rm -rf "$repo"
  echo "PASS test4: override passes only with PROJ_ALLOW_SUBMODULE_PIN_UPDATE=1"
}

# --------------------------------------------------------------------------
# Test 5: gitlink を含まない staged 変更（監視対象パス配下の通常ファイル、監視対象外の gitlink）は
# 無出力で通過する。
# --------------------------------------------------------------------------
test5_non_gitlink_changes_pass() {
  local repo out
  repo="$(make_repo)"
  (
    cd "$repo"
    mkdir -p vendor/dep-src
    printf 'x\n' > vendor/dep-src/file.txt
    git add vendor/dep-src/file.txt
  )
  out="$(PROJ_SUBMODULE_WATCH_PATH=vendor run_hook "$repo" "git commit -m 'add file'")"
  [[ -z "$out" ]] || fail "test5: a regular file under the watch path must pass (out=$out)"
  (cd "$repo" && stage_gitlink "other/dep" "$SHA_A")
  out="$(PROJ_SUBMODULE_WATCH_PATH=vendor run_hook "$repo" "git commit -m 'add file'")"
  [[ -z "$out" ]] || fail "test5: a gitlink outside the watch path must pass (out=$out)"
  rm -rf "$repo"
  echo "PASS test5: non-gitlink changes and gitlinks outside the watch path pass"
}

# --------------------------------------------------------------------------
# Test 6: 監視対象パスは PROJ_SUBMODULE_WATCH_PATH で差し替えられる。
# 既定値（vendor）の外にある gitlink は、監視対象に指定したときだけ deny される。
# --------------------------------------------------------------------------
test6_watch_path_is_configurable() {
  local repo out
  repo="$(make_repo)"
  (cd "$repo" && stage_gitlink "libs/dep" "$SHA_A")
  out="$(PROJ_SUBMODULE_WATCH_PATH=vendor run_hook "$repo" "git commit -m 'x'")"
  [[ -z "$out" ]] || fail "test6: gitlink under libs must pass while watching vendor (out=$out)"
  out="$(PROJ_SUBMODULE_WATCH_PATH=libs run_hook "$repo" "git commit -m 'x'")"
  [[ "$(hook_decision "$out")" == "deny" ]] \
    || fail "test6: gitlink under libs must deny while watching libs (out=$out)"
  rm -rf "$repo"
  echo "PASS test6: watch path is configurable"
}

# --------------------------------------------------------------------------
# Test 7: staged 変更が無ければ無出力で通過する。
# --------------------------------------------------------------------------
test7_nothing_staged_passes() {
  local repo out
  repo="$(make_repo)"
  out="$(PROJ_SUBMODULE_WATCH_PATH=vendor run_hook "$repo" "git commit -m 'empty'")"
  [[ -z "$out" ]] || fail "test7: nothing staged must pass with no output (out=$out)"
  rm -rf "$repo"
  echo "PASS test7: nothing staged passes"
}

# --------------------------------------------------------------------------
# Test 8: `git -C <dir> commit` と `cd <dir> && git commit` は、hook の cwd が commit 先と異なっていても、
# commit 先の作業ツリーの staged 変更を検査する。commit 先に gitlink が無ければ通過する。
# --------------------------------------------------------------------------
test8_git_dash_c_checks_target_worktree() {
  local repo clean other out cmd
  repo="$(make_repo)"
  clean="$(make_repo)"
  other="$(mktemp -d)"
  (cd "$repo" && stage_gitlink "vendor/dep" "$SHA_A")
  for cmd in "git -C $repo commit -m x" "cd $repo && git commit -m x"; do
    out="$(PROJ_SUBMODULE_WATCH_PATH=vendor run_hook "$other" "$cmd" "$other")"
    [[ "$(hook_decision "$out")" == "deny" ]] \
      || fail "test8: a gitlink staged in the target worktree must deny (cmd=$cmd, out=$out)"
  done
  out="$(PROJ_SUBMODULE_WATCH_PATH=vendor run_hook "$repo" "git -C $clean commit -m x" "$repo")"
  [[ -z "$out" ]] \
    || fail "test8: a gitlink staged in another worktree must not affect the target (out=$out)"
  rm -rf "$repo" "$clean" "$other"
  echo "PASS test8: git -C / cd commit checks the target worktree"
}

# --------------------------------------------------------------------------
# Test 9: commit 先を静的に決められない形は deny する（検査できないまま commit を通さない）。
# override（PROJ_ALLOW_SUBMODULE_PIN_UPDATE=1）があれば通す。commit より前に cd 以外のコマンドが
# 走る形は、hook 時点の staged 状態が commit の内容と一致しないため、対象にしない。
# --------------------------------------------------------------------------
test9_unresolved_denied_and_preceded_passes() {
  local repo out reason
  repo="$(make_repo)"
  (cd "$repo" && stage_gitlink "vendor/dep" "$SHA_A")

  out="$(PROJ_SUBMODULE_WATCH_PATH=vendor run_hook "$repo" 'cd "$TARGET_DIR" && git commit -m x' "$repo")"
  [[ "$(hook_decision "$out")" == "deny" ]] \
    || fail "test9: an unresolvable commit target must deny (out=$out)"
  reason="$(hook_reason "$out")"
  grep -q '作業ツリー' <<< "$reason" \
    || fail "test9: deny reason should explain the target could not be resolved (reason=$reason)"
  out="$(PROJ_SUBMODULE_WATCH_PATH=vendor PROJ_ALLOW_SUBMODULE_PIN_UPDATE=1 \
    run_hook "$repo" 'cd "$TARGET_DIR" && git commit -m x' "$repo")"
  [[ "$(hook_decision "$out")" != "deny" ]] \
    || fail "test9: the override must also apply to an unresolvable target (out=$out)"

  out="$(PROJ_SUBMODULE_WATCH_PATH=vendor run_hook "$repo" 'git add -A && git commit -m x' "$repo")"
  [[ -z "$out" ]] \
    || fail "test9: a commit preceded by another command must pass through silently (out=$out)"
  rm -rf "$repo"
  echo "PASS test9: unresolvable target is denied, preceded commit passes"
}

test1_non_commit_passthrough
test2_new_gitlink_denied
test3_pointer_update_denied
test4_override
test5_non_gitlink_changes_pass
test6_watch_path_is_configurable
test7_nothing_staged_passes
test8_git_dash_c_checks_target_worktree
test9_unresolved_denied_and_preceded_passes

echo "ALL PASS"
