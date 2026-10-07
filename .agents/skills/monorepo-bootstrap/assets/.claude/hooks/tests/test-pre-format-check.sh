#!/usr/bin/env bash
set -euo pipefail

# pre-format-check.sh の hermetic テスト。
# bash / git / jq のみで動く（実 prettier 不要、整形は PROJ_PRETTIER_CMD で stub 注入）。
# 一時 git repo と一時 HOME を作り、各テスト後にクリーンアップする。

# 被テスト hook の絶対パス（このテストファイルの位置から解決する）。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../pre-format-check.sh"

# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
require_hook

# hook を DIR を cwd にして実行し、stdout を返す。$1 DIR / $2 command / $3 入力の cwd（省略時は無し）。
# HOME は DIR に向けて、実環境の mise 設定の影響を避ける。PROJ_* は呼び出し側が前置して渡す。
run_hook() {
  local dir="$1" command="$2" stdin_cwd="${3:-}" json
  json="$(jq -n --arg c "$command" --arg d "$stdin_cwd" \
    '{tool_input: {command: $c}} + (if $d == "" then {} else {cwd: $d} end)')"
  (
    cd "$dir"
    printf '%s' "$json" | HOME="$dir" bash "$HOOK"
  )
}

# 書き換え後の command を取り出す（書き換えが無ければ空文字）。
new_command_of() {
  printf '%s' "$1" | jq -r '.hookSpecificOutput.updatedInput.command // empty'
}

# --------------------------------------------------------------------------
# Test 1 (本命・退行テスト):
# staged.txt を stage し、tracked.txt は変更するが stage しない。
# hook が返す書き換えコマンドを実行すると、commit には staged.txt のみが入り、
# tracked.txt の変更は混入せず worktree に未 stage のまま残ることを確認する。
# --------------------------------------------------------------------------
test1_staged_only_commit() {
  local repo
  repo="$(make_repo)"
  (
    cd "$repo"

    printf 'staged-v1\n' > staged.txt
    printf 'tracked-v1\n' > tracked.txt
    git add staged.txt tracked.txt
    git commit -q -m "base"

    # staged.txt を変更して stage、tracked.txt を変更するが stage しない。
    printf 'staged-v2\n' > staged.txt
    git add staged.txt
    printf 'tracked-v2\n' > tracked.txt

    # hook 実行（整形は no-op の true で stub）。
    local out new_cmd
    out="$(PROJ_PRETTIER_CMD=true run_hook "$repo" "git commit -m msg")"

    new_cmd="$(new_command_of "$out")"
    [[ -n "$new_cmd" ]] || fail "test1: hook did not return updatedInput.command (out=$out)"

    # 書き換えコマンドの形を検証する。
    case "$new_cmd" in
      *"git add --"*) : ;;
      *) fail "test1: rewritten command does not contain 'git add --': $new_cmd" ;;
    esac
    case "$new_cmd" in
      *staged.txt*) : ;;
      *) fail "test1: rewritten command does not target staged.txt: $new_cmd" ;;
    esac
    case "$new_cmd" in
      *tracked.txt*) fail "test1: rewritten command must not include tracked.txt: $new_cmd" ;;
    esac
    case "$new_cmd" in
      *"git add -u"*) fail "test1: rewritten command must not use 'git add -u': $new_cmd" ;;
    esac

    # 書き換えコマンドを実行して commit を作る。
    eval "$new_cmd" >/dev/null

    # commit に staged.txt の新内容が入っていること。
    [[ "$(git show HEAD:staged.txt)" == "staged-v2" ]] \
      || fail "test1: HEAD:staged.txt should be staged-v2, got '$(git show HEAD:staged.txt)'"

    # tracked.txt の変更は commit に混入していないこと（HEAD は元内容）。
    [[ "$(git show HEAD:tracked.txt)" == "tracked-v1" ]] \
      || fail "test1: HEAD:tracked.txt must remain tracked-v1, got '$(git show HEAD:tracked.txt)'"

    # tracked.txt が worktree に未 stage のまま残っていること。
    grep -qx tracked.txt <<< "$(git diff --name-only)" \
      || fail "test1: tracked.txt should remain unstaged in worktree"
  )
  rm -rf "$repo"
  echo "PASS test1: staged-only commit (no unstaged leakage)"
}

# --------------------------------------------------------------------------
# Test 2:
# 引数を記録する stub formatter を PROJ_PRETTIER_CMD に渡し、
# stub が受け取ったファイル引数が staged ファイルのみであることを確認する
# （tracked.txt や '.' を含まない）。
# --------------------------------------------------------------------------
test2_formatter_receives_staged_only() {
  local repo stub_dir
  repo="$(make_repo)"
  stub_dir="$(mktemp -d)"
  write_stub "$stub_dir" prettier 0 ""
  (
    cd "$repo"

    printf 'a\n' > a.txt
    printf 'b\n' > b.txt
    git add a.txt b.txt
    git commit -q -m "base"

    # a.txt を変更して stage、b.txt を変更するが stage しない。
    printf 'a2\n' > a.txt
    git add a.txt
    printf 'b2\n' > b.txt
  )
  PROJ_PRETTIER_CMD="$stub_dir/prettier" run_hook "$repo" "git commit -m msg" >/dev/null

  [[ -f "$stub_dir/prettier.args" ]] || fail "test2: stub formatter was not invoked"
  # stub は a.txt を整形対象として受け取っていること。
  grep -qx a.txt "$stub_dir/prettier.args" \
    || fail "test2: formatter did not receive a.txt (args: $(args_of "$stub_dir/prettier.args" test2))"
  # 未 stage の b.txt を受け取っていないこと。
  ! grep -qx b.txt "$stub_dir/prettier.args" \
    || fail "test2: formatter must not receive unstaged b.txt (args: $(args_of "$stub_dir/prettier.args" test2))"
  # '.'（全体整形）を受け取っていないこと。
  ! grep -qx '.' "$stub_dir/prettier.args" \
    || fail "test2: formatter must not receive '.' (whole-tree format)"
  rm -rf "$repo" "$stub_dir"
  echo "PASS test2: formatter receives staged files only"
}

# --------------------------------------------------------------------------
# Test 3: staged 0 件なら整形コマンドを呼ばずそのまま通過する。
# --------------------------------------------------------------------------
test3_no_staged_passthrough() {
  local repo stub_dir out
  repo="$(make_repo)"
  stub_dir="$(mktemp -d)"
  write_stub "$stub_dir" prettier 0 ""

  # 何も stage していない状態（unstaged 変更だけある）。
  printf 'x2\n' > "$repo/README.md"
  out="$(PROJ_PRETTIER_CMD="$stub_dir/prettier" run_hook "$repo" "git commit -m msg")"

  # 整形 stub は呼ばれていないこと。
  [[ ! -f "$stub_dir/prettier.args" ]] || fail "test3: formatter must not be called when nothing is staged"
  # コマンド書き換えも行われていないこと（updatedInput が無い）。
  [[ -z "$(new_command_of "$out")" ]] \
    || fail "test3: hook must not rewrite command when nothing is staged (out=$out)"
  rm -rf "$repo" "$stub_dir"
  echo "PASS test3: passthrough when nothing is staged"
}

# --------------------------------------------------------------------------
# Test 4 (防御ガード): git commit 以外のコマンドは即通過し、整形しない。
# `git -C <dir> status` のように git -C 形式で起動されても、commit でなければ通過する。
# --------------------------------------------------------------------------
test4_non_commit_passthrough() {
  local repo stub_dir out cmd
  repo="$(make_repo)"
  stub_dir="$(mktemp -d)"
  write_stub "$stub_dir" prettier 0 ""
  printf 'x\n' > "$repo/x.txt"
  git -C "$repo" add x.txt

  for cmd in "git status" "git -C $repo status" "git -C $repo log --grep commit" "echo git commit"; do
    out="$(PROJ_PRETTIER_CMD="$stub_dir/prettier" run_hook "$repo" "$cmd")"
    [[ -z "$out" ]] || fail "test4: non-commit command must pass through with no output (cmd=$cmd, out=$out)"
  done
  [[ ! -f "$stub_dir/prettier.args" ]] || fail "test4: formatter must not run for non-commit command"
  rm -rf "$repo" "$stub_dir"
  echo "PASS test4: non-commit command passthrough"
}

# --------------------------------------------------------------------------
# Test 5: 同一ファイル内に未 stage の hunk が残る部分 staging。
# ファイル単位の再 git add では未 stage hunk が混入してしまうため、
# hook は deny を返し、整形 stub も呼ばず、コマンドも書き換えないことを確認する。
# --------------------------------------------------------------------------
test5_partial_staging_denied() {
  local repo stub_dir out commits_before
  repo="$(make_repo)"
  stub_dir="$(mktemp -d)"
  write_stub "$stub_dir" prettier 0 ""
  (
    cd "$repo"

    # 離れた 2 hunk を持つファイルを commit する。
    printf 'l1\na\nb\nc\nd\ne\nf\ng\nh\nl10\n' > f.txt
    git add f.txt
    git commit -q -m "base"

    # worktree で 2 hunk を変更し、index には hunk1 だけを stage する（部分 staging）。
    printf 'HUNK1\na\nb\nc\nd\ne\nf\ng\nh\nHUNK2\n' > f.txt
    git apply --cached - <<'PATCH'
--- a/f.txt
+++ b/f.txt
@@ -1,4 +1,4 @@
-l1
+HUNK1
 a
 b
 c
PATCH

    # 前提確認: index に hunk1 のみ、worktree に hunk2 が未 stage で残る。
    grep -q 'HUNK1' <<< "$(git diff --cached -- f.txt)" || fail "test5: precondition: HUNK1 should be staged"
    grep -q 'HUNK2' <<< "$(git diff -- f.txt)" || fail "test5: precondition: HUNK2 should remain unstaged"
  )
  commits_before="$(git -C "$repo" rev-list --count HEAD)"

  out="$(PROJ_PRETTIER_CMD="$stub_dir/prettier" run_hook "$repo" "git commit -m partial")"

  # deny を返すこと。
  [[ "$(hook_decision "$out")" == "deny" ]] \
    || fail "test5: hook must deny partial staging (out=$out)"
  # 該当ファイル名が理由に含まれること。
  grep -q 'f.txt' <<< "$(hook_reason "$out")" \
    || fail "test5: deny reason should name the partially staged file (out=$out)"
  # コマンド書き換えをしていないこと。
  [[ -z "$(new_command_of "$out")" ]] \
    || fail "test5: hook must not rewrite command on deny (out=$out)"
  # 整形 stub は deny 前に弾かれ呼ばれていないこと。
  [[ ! -f "$stub_dir/prettier.args" ]] || fail "test5: formatter must not run when partial staging is denied"
  # commit は作られておらず（deny）、hunk2 は worktree に未 stage で残ること。
  [[ "$(git -C "$repo" rev-list --count HEAD)" == "$commits_before" ]] \
    || fail "test5: no new commit should be created on deny"
  grep -q 'HUNK2' <<< "$(git -C "$repo" diff -- f.txt)" || fail "test5: unstaged HUNK2 must remain in worktree"
  rm -rf "$repo" "$stub_dir"
  echo "PASS test5: partial staging is denied (no unstaged hunk leakage)"
}

# --------------------------------------------------------------------------
# Test 6 (退行テスト): formatter が特定書式でないエラーメッセージで失敗しても
# hook は無言でコミットを通過させてはいけない（エラー出力の書式に関わらず
# 非 0 終了は常に deny する）。
# --------------------------------------------------------------------------
test6_formatter_failure_denied() {
  local repo stub_dir out
  repo="$(make_repo)"
  stub_dir="$(mktemp -d)"
  # stub formatter: 壊れた pnpm shim を模した、書式化されていない失敗。
  write_stub "$stub_dir" prettier 127 "env: node: No such file or directory"
  printf 'a2\n' > "$repo/a.txt"
  git -C "$repo" add a.txt

  out="$(PROJ_PRETTIER_CMD="$stub_dir/prettier" run_hook "$repo" "git commit -m msg")"

  # hook は deny を返さねばならない（無言の素通りは禁止）。
  [[ "$(hook_decision "$out")" == "deny" ]] \
    || fail "test6: hook must deny when formatter fails (out=$out)"
  # 理由にフォーマッタの失敗内容が含まれること。
  grep -q 'node: No such file or directory' <<< "$(hook_reason "$out")" \
    || fail "test6: deny reason should include formatter failure output (out=$out)"
  # コマンド書き換え（re-stage → commit）をしていないこと。
  [[ -z "$(new_command_of "$out")" ]] \
    || fail "test6: hook must not rewrite command when formatter failed (out=$out)"
  rm -rf "$repo" "$stub_dir"
  echo "PASS test6: formatter failure is denied (no silent pass-through)"
}

# --------------------------------------------------------------------------
# Test 7: `git -C <dir> commit` は、hook の cwd や入力の cwd が commit 先と異なっていても、
# commit 先の作業ツリーで整形し、そのルートを指す git add を前置する。
# 書き換えたコマンドを別ディレクトリから実行すると、commit 先の repository に commit が入る。
# `cd <dir> && git commit` も同じ作業ツリーを対象にする。
# --------------------------------------------------------------------------
test7_git_dash_c_formats_target_worktree() {
  local repo other stub_dir root out new_cmd
  repo="$(make_repo)"
  other="$(mktemp -d)"
  stub_dir="$(mktemp -d)"
  root="$(cd -P "$repo" && pwd -P)"
  write_stub "$stub_dir" prettier 0 ""
  printf 'a\n' > "$repo/a.txt"
  git -C "$repo" add a.txt

  out="$(PROJ_PRETTIER_CMD="$stub_dir/prettier" run_hook "$other" "git -C $repo commit -m msg" "$other")"
  new_cmd="$(new_command_of "$out")"
  [[ -n "$new_cmd" ]] || fail "test7: git -C commit must be rewritten (out=$out)"
  [[ "$new_cmd" == "git -C "*" add -- a.txt && git -C $repo commit -m msg" ]] \
    || fail "test7: the re-stage must target the commit worktree (cmd=$new_cmd)"
  [[ "$(head -n 1 "$stub_dir/prettier.cwd")" == "$root" ]] \
    || fail "test7: the formatter must run in the commit worktree ($root), got: $(head -n 1 "$stub_dir/prettier.cwd")"
  grep -qx a.txt "$stub_dir/prettier.args" \
    || fail "test7: formatter should receive the staged file (args: $(args_of "$stub_dir/prettier.args" test7))"

  (cd "$other" && eval "$new_cmd" >/dev/null)
  [[ "$(git -C "$repo" log -1 --format=%s)" == "msg" ]] \
    || fail "test7: the rewritten command should commit in the target worktree"

  # cd 形式。commit 後なので、新しい staged ファイルを用意し直す。
  rm -f "$stub_dir/prettier.args" "$stub_dir/prettier.cwd"
  printf 'b\n' > "$repo/b.txt"
  git -C "$repo" add b.txt
  out="$(PROJ_PRETTIER_CMD="$stub_dir/prettier" run_hook "$other" "cd $repo && git commit -m msg2" "$other")"
  new_cmd="$(new_command_of "$out")"
  [[ "$new_cmd" == "git -C "*" add -- b.txt && cd $repo && git commit -m msg2" ]] \
    || fail "test7: cd-prefixed commit must be rewritten for the target worktree (cmd=$new_cmd)"
  [[ "$(head -n 1 "$stub_dir/prettier.cwd")" == "$root" ]] \
    || fail "test7: the formatter must run in the cd target worktree ($root)"
  rm -rf "$repo" "$other" "$stub_dir"
  echo "PASS test7: git -C / cd commit is formatted in the target worktree"
}

# --------------------------------------------------------------------------
# Test 8: commit 先を静的に決められない形、commit より前に cd 以外のコマンドが走る形は、
# 整形も書き換えも deny もせずに通す（整形は補助で、format:check が pre-push と CI で検証される）。
# 前者は skip した旨を additionalContext に残す。
# --------------------------------------------------------------------------
test8_unresolved_and_preceded_pass_through() {
  local repo stub_dir out
  repo="$(make_repo)"
  stub_dir="$(mktemp -d)"
  write_stub "$stub_dir" prettier 0 ""
  printf 'a\n' > "$repo/a.txt"
  git -C "$repo" add a.txt

  out="$(PROJ_PRETTIER_CMD="$stub_dir/prettier" run_hook "$repo" 'cd "$TARGET_DIR" && git commit -m msg' "$repo")"
  [[ -z "$(new_command_of "$out")" && "$(hook_decision "$out")" != "deny" ]] \
    || fail "test8: an unresolvable target must not rewrite or deny (out=$out)"
  grep -q 'skipped' <<< "$(hook_ctx "$out")" \
    || fail "test8: an unresolvable target should leave a skip note (out=$out)"

  out="$(PROJ_PRETTIER_CMD="$stub_dir/prettier" run_hook "$repo" 'git add -A && git commit -m msg' "$repo")"
  [[ -z "$out" ]] \
    || fail "test8: a commit preceded by another command must pass through silently (out=$out)"
  [[ ! -f "$stub_dir/prettier.args" ]] || fail "test8: formatter must not run for these forms"
  rm -rf "$repo" "$stub_dir"
  echo "PASS test8: unresolvable and preceded commits pass through"
}

# --------------------------------------------------------------------------
# Test 9: Bash の cwd が作業ツリーのサブディレクトリでも、再 stage はルートを指す。
# staged files のパスはルート基準のため、サブディレクトリでそのまま git add すると
# pathspec が一致せず、書き換えたコマンド全体が失敗する。
# --------------------------------------------------------------------------
test9_subdirectory_cwd_restages_from_root() {
  local repo stub_dir out new_cmd
  repo="$(make_repo)"
  stub_dir="$(mktemp -d)"
  write_stub "$stub_dir" prettier 0 ""
  mkdir -p "$repo/pkg/sub"
  printf 'a\n' > "$repo/pkg/a.txt"
  git -C "$repo" add pkg/a.txt

  out="$(PROJ_PRETTIER_CMD="$stub_dir/prettier" run_hook "$repo" "git commit -m msg" "$repo/pkg/sub")"
  new_cmd="$(new_command_of "$out")"
  [[ "$new_cmd" == "git -C "*" add -- pkg/a.txt && git commit -m msg" ]] \
    || fail "test9: the re-stage must name the worktree root when the cwd is a subdirectory (cmd=$new_cmd)"
  (cd "$repo/pkg/sub" && eval "$new_cmd" >/dev/null)
  [[ "$(git -C "$repo" show --name-only --format= HEAD)" == "pkg/a.txt" ]] \
    || fail "test9: the rewritten command should commit the staged file from the subdirectory"
  rm -rf "$repo" "$stub_dir"
  echo "PASS test9: a subdirectory cwd re-stages from the worktree root"
}

test1_staged_only_commit
test2_formatter_receives_staged_only
test3_no_staged_passthrough
test4_non_commit_passthrough
test5_partial_staging_denied
test6_formatter_failure_denied
test7_git_dash_c_formats_target_worktree
test8_unresolved_and_preceded_pass_through
test9_subdirectory_cwd_restages_from_root

echo "ALL PASS"
