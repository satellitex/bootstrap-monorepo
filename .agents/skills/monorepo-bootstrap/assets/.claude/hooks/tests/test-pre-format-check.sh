#!/usr/bin/env bash
set -euo pipefail

# pre-format-check.sh の hermetic テスト。
# bash / git / jq のみで動く（実 prettier 不要、整形は PROJ_PRETTIER_CMD で stub 注入）。
# 一時 git repo と一時 HOME を作り、各テスト後にクリーンアップする。

# 被テスト hook の絶対パス（このテストファイルの位置から解決する）。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../pre-format-check.sh"

if [[ ! -x "$HOOK" ]]; then
  echo "FAIL: hook not found or not executable: $HOOK" >&2
  exit 1
fi

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# 各テストは隔離した一時 git repo + 一時 HOME で実行する。
make_repo() {
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "$tmp"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    git config commit.gpgsign false
  )
  printf '%s' "$tmp"
}

# --------------------------------------------------------------------------
# Test 1 (本命・退行テスト):
# staged.txt を stage し、tracked.txt は変更するが stage しない。
# hook が返す書き換えコマンドを実行すると、commit には staged.txt のみが入り、
# tracked.txt の変更は混入せず worktree に未 stage のまま残ることを確認する。
# --------------------------------------------------------------------------
test1_staged_only_commit() {
  local repo home
  repo="$(make_repo)"
  home="$(mktemp -d)"
  trap 'rm -rf "$repo" "$home"' RETURN

  (
    cd "$repo"
    export HOME="$home"

    printf 'staged-v1\n' > staged.txt
    printf 'tracked-v1\n' > tracked.txt
    git add staged.txt tracked.txt
    git commit -q -m "init"

    # staged.txt を変更して stage、tracked.txt を変更するが stage しない。
    printf 'staged-v2\n' > staged.txt
    git add staged.txt
    printf 'tracked-v2\n' > tracked.txt

    # hook 実行（整形は no-op の true で stub）。
    local out
    out="$(printf '%s' '{"tool_input":{"command":"git commit -m msg"}}' \
      | PROJ_PRETTIER_CMD=true bash "$HOOK")"

    local new_cmd
    new_cmd="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.command // empty')"
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
      *tracked.txt*) fail "test1: rewritten command must NOT include tracked.txt: $new_cmd" ;;
    esac
    case "$new_cmd" in
      *"git add -u"*) fail "test1: rewritten command must NOT use 'git add -u': $new_cmd" ;;
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
    git diff --name-only | grep -qx tracked.txt \
      || fail "test1: tracked.txt should remain unstaged in worktree"
  )
  trap - RETURN
  rm -rf "$repo" "$home"
  echo "PASS test1: staged-only commit (no unstaged leakage)"
}

# --------------------------------------------------------------------------
# Test 2:
# 引数を記録する stub formatter を PROJ_PRETTIER_CMD に渡し、
# stub が受け取ったファイル引数が staged ファイルのみであることを確認する
# （tracked.txt や '.' を含まない）。
# --------------------------------------------------------------------------
test2_formatter_receives_staged_only() {
  local repo home
  repo="$(make_repo)"
  home="$(mktemp -d)"
  trap 'rm -rf "$repo" "$home"' RETURN

  (
    cd "$repo"
    export HOME="$home"

    printf 'a\n' > a.txt
    printf 'b\n' > b.txt
    git add a.txt b.txt
    git commit -q -m "init"

    # a.txt を変更して stage、b.txt を変更するが stage しない。
    printf 'a2\n' > a.txt
    git add a.txt
    printf 'b2\n' > b.txt

    # stub formatter: 受け取った全引数を 1 行 1 つで args.log に記録する。
    local argslog="$repo/args.log"
    local stub="$repo/stub-prettier.sh"
    cat > "$stub" <<STUB
#!/usr/bin/env bash
for x in "\$@"; do
  printf '%s\n' "\$x" >> "$argslog"
done
STUB
    chmod +x "$stub"

    printf '%s' '{"tool_input":{"command":"git commit -m msg"}}' \
      | PROJ_PRETTIER_CMD="$stub" bash "$HOOK" >/dev/null

    [[ -f "$argslog" ]] || fail "test2: stub formatter was not invoked"

    # stub は a.txt を整形対象として受け取っていること。
    grep -qx a.txt "$argslog" || fail "test2: formatter did not receive a.txt (args: $(tr '\n' ' ' < "$argslog"))"
    # 未 stage の b.txt を受け取っていないこと。
    grep -qx b.txt "$argslog" && fail "test2: formatter must NOT receive unstaged b.txt (args: $(tr '\n' ' ' < "$argslog"))"
    # '.'（全体整形）を受け取っていないこと。
    grep -qx '.' "$argslog" && fail "test2: formatter must NOT receive '.' (whole-tree format)"

    : # b.txt grep が無ヒットで非0でも fail 済みでなければここに来る
  )
  trap - RETURN
  rm -rf "$repo" "$home"
  echo "PASS test2: formatter receives staged files only"
}

# --------------------------------------------------------------------------
# Test 3: staged 0 件なら整形コマンドを呼ばずそのまま通過する。
# --------------------------------------------------------------------------
test3_no_staged_passthrough() {
  local repo home
  repo="$(make_repo)"
  home="$(mktemp -d)"
  trap 'rm -rf "$repo" "$home"' RETURN

  (
    cd "$repo"
    export HOME="$home"

    printf 'x\n' > x.txt
    git add x.txt
    git commit -q -m "init"

    # 何も stage していない状態（unstaged 変更だけある）。
    printf 'x2\n' > x.txt

    local argslog="$repo/args.log"
    local stub="$repo/stub-prettier.sh"
    cat > "$stub" <<STUB
#!/usr/bin/env bash
printf 'called\n' >> "$argslog"
STUB
    chmod +x "$stub"

    local out
    out="$(printf '%s' '{"tool_input":{"command":"git commit -m msg"}}' \
      | PROJ_PRETTIER_CMD="$stub" bash "$HOOK")"

    # 整形 stub は呼ばれていないこと。
    [[ ! -f "$argslog" ]] || fail "test3: formatter must not be called when nothing is staged"
    # コマンド書き換えも行われていないこと（updatedInput が無い）。
    [[ -z "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.command // empty')" ]] \
      || fail "test3: hook must not rewrite command when nothing is staged (out=$out)"
  )
  trap - RETURN
  rm -rf "$repo" "$home"
  echo "PASS test3: passthrough when nothing is staged"
}

# --------------------------------------------------------------------------
# Test 4 (防御ガード): git commit 以外のコマンドは即通過し、整形しない。
# --------------------------------------------------------------------------
test4_non_commit_passthrough() {
  local repo home
  repo="$(make_repo)"
  home="$(mktemp -d)"
  trap 'rm -rf "$repo" "$home"' RETURN

  (
    cd "$repo"
    export HOME="$home"

    printf 'x\n' > x.txt
    git add x.txt

    local argslog="$repo/args.log"
    local stub="$repo/stub-prettier.sh"
    cat > "$stub" <<STUB
#!/usr/bin/env bash
printf 'called\n' >> "$argslog"
STUB
    chmod +x "$stub"

    local out
    out="$(printf '%s' '{"tool_input":{"command":"git status"}}' \
      | PROJ_PRETTIER_CMD="$stub" bash "$HOOK")"

    [[ ! -f "$argslog" ]] || fail "test4: formatter must not run for non-commit command"
    [[ -z "$out" ]] || fail "test4: non-commit command must pass through with no output (out=$out)"
  )
  trap - RETURN
  rm -rf "$repo" "$home"
  echo "PASS test4: non-commit command passthrough"
}

# --------------------------------------------------------------------------
# Test 5: 同一ファイル内に未 stage の hunk が残る部分 staging。
# ファイル単位の再 git add では未 stage hunk が混入してしまうため、
# hook は deny を返し、整形 stub も呼ばず、コマンドも書き換えないことを確認する。
# --------------------------------------------------------------------------
test5_partial_staging_denied() {
  local repo home
  repo="$(make_repo)"
  home="$(mktemp -d)"
  trap 'rm -rf "$repo" "$home"' RETURN

  (
    cd "$repo"
    export HOME="$home"

    # 離れた 2 hunk を持つファイルを初期 commit する。
    printf 'l1\na\nb\nc\nd\ne\nf\ng\nh\nl10\n' > f.txt
    git add f.txt
    git commit -q -m "init"

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
    git diff --cached -- f.txt | grep -q 'HUNK1' || fail "test5: precondition: HUNK1 should be staged"
    git diff -- f.txt | grep -q 'HUNK2' || fail "test5: precondition: HUNK2 should remain unstaged"

    local argslog="$repo/args.log"
    local stub="$repo/stub-prettier.sh"
    cat > "$stub" <<STUB
#!/usr/bin/env bash
printf 'called\n' >> "$argslog"
STUB
    chmod +x "$stub"

    local out
    out="$(printf '%s' '{"tool_input":{"command":"git commit -m partial"}}' \
      | PROJ_PRETTIER_CMD="$stub" bash "$HOOK")"

    # deny を返すこと。
    [[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty')" == "deny" ]] \
      || fail "test5: hook must deny partial staging (out=$out)"
    # 該当ファイル名が理由に含まれること。
    printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' | grep -q 'f.txt' \
      || fail "test5: deny reason should name the partially staged file (out=$out)"
    # コマンド書き換えをしていないこと。
    [[ -z "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.command // empty')" ]] \
      || fail "test5: hook must not rewrite command on deny (out=$out)"
    # 整形 stub は deny 前に弾かれ呼ばれていないこと。
    [[ ! -f "$argslog" ]] || fail "test5: formatter must not run when partial staging is denied"
    # commit は作られておらず（deny）、hunk2 は worktree に未 stage で残ること。
    [[ "$(git rev-list --count HEAD)" == "1" ]] || fail "test5: no new commit should be created on deny"
    git diff -- f.txt | grep -q 'HUNK2' || fail "test5: unstaged HUNK2 must remain in worktree"
  )
  trap - RETURN
  rm -rf "$repo" "$home"
  echo "PASS test5: partial staging is denied (no unstaged hunk leakage)"
}

# --------------------------------------------------------------------------
# Test 6 (退行テスト): formatter が特定書式でないエラーメッセージで失敗しても
# hook は無言でコミットを通過させてはいけない（エラー出力の書式に関わらず
# 非 0 終了は常に deny する）。
# --------------------------------------------------------------------------
test6_formatter_failure_denied() {
  local repo home
  repo="$(make_repo)"
  home="$(mktemp -d)"
  trap 'rm -rf "$repo" "$home"' RETURN

  (
    cd "$repo"
    export HOME="$home"

    printf 'a\n' > a.txt
    git add a.txt
    git commit -q -m "init"

    printf 'a2\n' > a.txt
    git add a.txt

    # stub formatter: 壊れた pnpm shim を模した、書式化されていない失敗。
    local stub="$repo/stub-prettier.sh"
    cat > "$stub" <<'STUB'
#!/usr/bin/env bash
echo "env: node: No such file or directory" >&2
exit 127
STUB
    chmod +x "$stub"

    local out
    out="$(printf '%s' '{"tool_input":{"command":"git commit -m msg"}}' \
      | PROJ_PRETTIER_CMD="$stub" bash "$HOOK")"

    # hook は deny を返さねばならない（無言の素通りは禁止）。
    [[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty')" == "deny" ]] \
      || fail "test6: hook must deny when formatter fails (out=$out)"
    # 理由にフォーマッタの失敗内容が含まれること。
    printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' \
      | grep -q 'node: No such file or directory' \
      || fail "test6: deny reason should include formatter failure output (out=$out)"
    # コマンド書き換え（re-stage → commit）をしていないこと。
    [[ -z "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.command // empty')" ]] \
      || fail "test6: hook must not rewrite command when formatter failed (out=$out)"
  )
  trap - RETURN
  rm -rf "$repo" "$home"
  echo "PASS test6: formatter failure is denied (no silent pass-through)"
}

test1_staged_only_commit
test2_formatter_receives_staged_only
test3_no_staged_passthrough
test4_non_commit_passthrough
test5_partial_staging_denied
test6_formatter_failure_denied

echo "ALL PASS"
