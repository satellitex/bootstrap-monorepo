#!/usr/bin/env bash
set -euo pipefail

# pre-push-ci-check.sh の hermetic テスト。
# bash / git / jq のみで動く（実 pnpm / gitleaks 不要、pnpm は PATH stub、
# gitleaks は PROJ_GITLEAKS_CMD で stub 注入）。
# push 先の作業ツリーの特定（cd / git -C の解釈、別 worktree からの起動）も同じ構成で検証する。
# 一時 git repo と一時 HOME を作り、各テスト後にクリーンアップする。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../pre-push-ci-check.sh"

if [[ ! -f "$HOOK" ]]; then
  echo "FAIL: hook not found: $HOOK" >&2
  exit 1
fi

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# 隔離した一時 repo を作る（node_modules ありの install 済み状態を模倣）
make_repo() {
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "$tmp"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    git config commit.gpgsign false
    printf 'hello\n' > README.md
    git add README.md
    git commit -q -m "init"
    mkdir -p node_modules
  )
  printf '%s' "$tmp"
}

# pnpm + gitleaks stub を作る（第1引数: pnpm の exit code、第2引数: pnpm の出力）。
# pnpm は PATH 前置、gitleaks は常に成功 stub（leak なし）を作り PROJ_GITLEAKS_CMD で
# 注入する。hook が PATH に mise shims / /opt/homebrew/bin を前置するため、テスト環境に
# 実 gitleaks（mise shim）が存在すると PATH stub が shadow され得る。command 注入 seam
# 経由でのみ実 gitleaks 非依存に保てる。
make_pnpm_stub() {
  local exit_code="${1:-0}"
  local msg="${2:-}"
  local stub_dir
  stub_dir="$(mktemp -d)"
  cat > "$stub_dir/pnpm" <<STUB
#!/usr/bin/env bash
if [ -n "$msg" ]; then
  printf '%s\n' "$msg"
fi
exit $exit_code
STUB
  chmod +x "$stub_dir/pnpm"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$stub_dir/gitleaks"
  chmod +x "$stub_dir/gitleaks"
  printf '%s' "$stub_dir"
}

# gitleaks の挙動だけを差し替える stub dir を作る（第1引数: exit code、第2引数: stderr 出力）。
# 生成した "$dir/gitleaks" を PROJ_GITLEAKS_CMD で hook に注入して挙動を制御する
# （make_pnpm_stub の gitleaks(exit 0) を上書きしたいテストで使う）。
make_gitleaks_stub() {
  local exit_code="${1:-0}"
  local stderr_msg="${2:-}"
  local stub_dir
  stub_dir="$(mktemp -d)"
  cat > "$stub_dir/gitleaks" <<STUB
#!/usr/bin/env bash
if [ -n "$stderr_msg" ]; then
  printf '%s\n' "$stderr_msg" >&2
fi
exit $exit_code
STUB
  chmod +x "$stub_dir/gitleaks"
  printf '%s' "$stub_dir"
}

# gitleaks に渡された argv を記録するだけの stub を作る（leak なしで exit 0）。
# 記録先は "$stub_dir/argv"。スキャン範囲の指定漏れを検出するために使う。
make_gitleaks_argv_stub() {
  local stub_dir
  stub_dir="$(mktemp -d)"
  cat > "$stub_dir/gitleaks" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$stub_dir/argv"
exit 0
STUB
  chmod +x "$stub_dir/gitleaks"
  printf '%s' "$stub_dir"
}

# gitleaks の「スキャン範囲の解釈」だけを模した stub を作る。
# 実 gitleaks は使わず、--log-opts で渡された range を実 git log で解決し、範囲内の
# commit の patch に PLANTED_SECRET が現れたら leak 検出（exit 99）とする。
# これにより「どの commit が検査対象か」という本質だけを hermetic に検証できる
# （gitleaks 自体の検出ロジックは本 hook の責務ではないため模さない）。
make_gitleaks_range_stub() {
  local stub_dir
  stub_dir="$(mktemp -d)"
  cat > "$stub_dir/gitleaks" <<'STUB'
#!/usr/bin/env bash
range=""
for a in "$@"; do
  case "$a" in
    --log-opts=*) range="${a#--log-opts=}" ;;
  esac
done
if [ -z "$range" ]; then
  # 範囲指定なし = fetch 済みの全 ref を走査（範囲限定が失われた場合の挙動）
  out="$(git log --all -p 2>/dev/null || true)"
else
  # range は "--all --not --remotes" のような複数トークンなので意図的に word split する
  # shellcheck disable=SC2086
  out="$(git log -p $range 2>/dev/null || true)"
fi
if printf '%s' "$out" | grep -q 'PLANTED_SECRET'; then
  exit 99
fi
exit 0
STUB
  chmod +x "$stub_dir/gitleaks"
  printf '%s' "$stub_dir"
}

# bare remote を持つ repo を作る。origin/main と、PLANTED_SECRET を含む commit を持つ
# 「既に remote 上にある他 branch」(origin/other) を用意し、HEAD は clean な未 push
# branch (mywork) にしておく。「他 branch の値が自分の push を止めない」検証に使う。
make_repo_with_remote() {
  local tmp
  tmp="$(mktemp -d)"
  git init -q --bare "$tmp/remote.git"
  git init -q "$tmp/work"
  (
    cd "$tmp/work"
    git config user.email "test@example.com"
    git config user.name "Test"
    git config commit.gpgsign false
    printf 'hello\n' > README.md
    git add README.md
    git commit -q -m "init"
    mkdir -p node_modules
    git remote add origin "$tmp/remote.git"
    git push -q origin HEAD:refs/heads/main

    # 他 branch: 誤検知値に相当するマーカーを含み、既に remote へ push 済み
    git checkout -q -b other
    printf 'PLANTED_SECRET\n' > other-doc.md
    git add other-doc.md
    git commit -q -m "docs: other branch value"
    git push -q origin other

    # 自分の作業 branch: clean な未 push commit のみ
    git checkout -q -B mywork origin/main
    printf 'clean\n' > mine.txt
    git add mine.txt
    git commit -q -m "feat: clean change"

    git fetch -q origin
  )
  printf '%s' "$tmp/work"
}

run_hook_json() {
  local json="$1"
  printf '%s' "$json" | bash "$HOOK"
}

# --------------------------------------------------------------------------
# Test 1 (防御ガード): git push 以外のコマンドは即通過し、出力なし。
# --------------------------------------------------------------------------
test1_non_push_passthrough() {
  local repo
  repo="$(make_repo)"
  (
    cd "$repo"
    local out
    out="$(run_hook_json '{"tool_input":{"command":"git status"}}')"
    [[ -z "$out" ]] || fail "test1: non-push command must pass through with no output (out=$out)"
  )
  rm -rf "$repo"
  echo "PASS test1: non-push command passthrough"
}

# --------------------------------------------------------------------------
# Test 2: node_modules が無い場合は skip して additionalContext を返す。
# --------------------------------------------------------------------------
test2_no_node_modules_skip() {
  local repo stub_dir
  repo="$(make_repo)"
  stub_dir="$(make_pnpm_stub 0)"
  (
    cd "$repo"
    rm -rf node_modules
    local out ctx
    out="$(PROJ_GITLEAKS_CMD="$stub_dir/gitleaks" PATH="$stub_dir:$PATH" bash -c 'printf %s "{\"tool_input\":{\"command\":\"git push origin main\"}}" | bash '"$HOOK")"
    ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')"
    [[ -n "$ctx" ]] || fail "test2: missing node_modules must return additionalContext (out=$out)"
    printf '%s' "$ctx" | grep -qi 'skip' || fail "test2: skip message expected (ctx=$ctx)"
  )
  rm -rf "$repo" "$stub_dir"
  echo "PASS test2: no node_modules returns skip"
}

# --------------------------------------------------------------------------
# Test 3: 全 CI チェック通過で additionalContext の通過記録を返す（deny でない）。
# --------------------------------------------------------------------------
test3_all_checks_pass() {
  local repo stub_dir
  repo="$(make_repo)"
  stub_dir="$(make_pnpm_stub 0)"
  (
    cd "$repo"
    local out ctx decision
    out="$(PROJ_GITLEAKS_CMD="$stub_dir/gitleaks" PATH="$stub_dir:$PATH" bash -c 'printf %s "{\"tool_input\":{\"command\":\"git push origin main\"}}" | bash '"$HOOK")"
    ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')"
    [[ -n "$ctx" ]] || fail "test3: all-pass must return additionalContext (out=$out)"
    printf '%s' "$ctx" | grep -q 'passed' || fail "test3: pass message expected (ctx=$ctx)"
    decision="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty')"
    [[ "$decision" != "deny" ]] || fail "test3: must not deny on all-pass (out=$out)"
  )
  rm -rf "$repo" "$stub_dir"
  echo "PASS test3: all checks pass returns additionalContext"
}

# --------------------------------------------------------------------------
# Test 4: CI チェック失敗で deny + 失敗ステップ名（format:check）が理由に含まれる。
# --------------------------------------------------------------------------
test4_check_failure_deny() {
  local repo stub_dir
  repo="$(make_repo)"
  stub_dir="$(make_pnpm_stub 1 "lint error: something is wrong")"
  (
    cd "$repo"
    local out decision reason
    out="$(PROJ_GITLEAKS_CMD="$stub_dir/gitleaks" PATH="$stub_dir:$PATH" bash -c 'printf %s "{\"tool_input\":{\"command\":\"git push origin main\"}}" | bash '"$HOOK")"
    decision="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty')"
    [[ "$decision" == "deny" ]] \
      || fail "test4: CI failure must deny push (decision=$decision, out=$out)"
    reason="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty')"
    printf '%s' "$reason" | grep -q 'format:check' \
      || fail "test4: deny reason should contain failing step name (reason=$reason)"
  )
  rm -rf "$repo" "$stub_dir"
  echo "PASS test4: CI failure returns deny with step name"
}

# --------------------------------------------------------------------------
# Test 5: gitleaks の実行失敗（例: mise shim の「No version is set」で exit 1）は
# leak 検出と区別して skip し、deny せず後続チェックまで通過する。
# --------------------------------------------------------------------------
test5_gitleaks_execution_error_skip() {
  local repo stub_dir gl_stub
  repo="$(make_repo)"
  stub_dir="$(make_pnpm_stub 0)"
  gl_stub="$(make_gitleaks_stub 1 "No version is set for shim: gitleaks")"
  (
    cd "$repo"
    local out decision ctx
    out="$(PROJ_GITLEAKS_CMD="$gl_stub/gitleaks" PATH="$stub_dir:$PATH" bash -c 'printf %s "{\"tool_input\":{\"command\":\"git push origin main\"}}" | bash '"$HOOK")"
    decision="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty')"
    [[ "$decision" != "deny" ]] \
      || fail "test5: gitleaks execution error must not deny push (out=$out)"
    ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')"
    printf '%s' "$ctx" | grep -q 'passed' \
      || fail "test5: must continue to remaining checks after gitleaks execution error (ctx=$ctx)"
  )
  rm -rf "$repo" "$stub_dir" "$gl_stub"
  echo "PASS test5: gitleaks execution error skips and continues"
}

# --------------------------------------------------------------------------
# Test 6: gitleaks の leak 検出（--exit-code 99 で rc=99）は deny する。
# --------------------------------------------------------------------------
test6_gitleaks_leak_deny() {
  local repo stub_dir gl_stub
  repo="$(make_repo)"
  stub_dir="$(make_pnpm_stub 0)"
  gl_stub="$(make_gitleaks_stub 99 "")"
  (
    cd "$repo"
    local out decision reason
    out="$(PROJ_GITLEAKS_CMD="$gl_stub/gitleaks" PATH="$stub_dir:$PATH" bash -c 'printf %s "{\"tool_input\":{\"command\":\"git push origin main\"}}" | bash '"$HOOK")"
    decision="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty')"
    [[ "$decision" == "deny" ]] \
      || fail "test6: gitleaks leak (rc=99) must deny push (out=$out)"
    reason="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty')"
    printf '%s' "$reason" | grep -qi 'gitleaks' \
      || fail "test6: deny reason should mention gitleaks (reason=$reason)"
  )
  rm -rf "$repo" "$stub_dir" "$gl_stub"
  echo "PASS test6: gitleaks leak returns deny"
}

# --------------------------------------------------------------------------
# Test 7: gitleaks のスキャン範囲を「まだ remote に出ていないローカル commit」
# （--all --not --remotes）へ限定して呼び出す。範囲指定が失われると fetch 済みの
# 全 ref が対象に戻り、自分が push しない他 branch の誤検知で全 push が止まる。
# --------------------------------------------------------------------------
test7_gitleaks_scan_scope_limited_to_outgoing() {
  local repo stub_dir gl_stub
  repo="$(make_repo)"
  stub_dir="$(make_pnpm_stub 0)"
  gl_stub="$(make_gitleaks_argv_stub)"
  (
    cd "$repo"
    PROJ_GITLEAKS_CMD="$gl_stub/gitleaks" PATH="$stub_dir:$PATH" bash -c 'printf %s "{\"tool_input\":{\"command\":\"git push origin main\"}}" | bash '"$HOOK" > /dev/null
    [[ -f "$gl_stub/argv" ]] \
      || fail "test7: gitleaks was not invoked at all"
    grep -qF -- '--log-opts=--all --not --remotes' "$gl_stub/argv" \
      || fail "test7: gitleaks must be scoped to unpushed local refs (argv=$(cat "$gl_stub/argv"))"
  )
  rm -rf "$repo" "$stub_dir" "$gl_stub"
  echo "PASS test7: gitleaks scan scope limited to unpushed local refs"
}

# --------------------------------------------------------------------------
# Test 8: 既に remote 上にある他 branch のみに存在する検出値は push を止めない
# （他 branch の誤検知 1 件で当該 checkout の全 push が止まる事象の回帰防止）。
# 一方で自分の未 push commit に含まれる値は従来どおり deny する（検知力の担保）。
# --------------------------------------------------------------------------
test8_other_branch_value_does_not_block_push() {
  local repo stub_dir gl_stub
  repo="$(make_repo_with_remote)"
  stub_dir="$(make_pnpm_stub 0)"
  gl_stub="$(make_gitleaks_range_stub)"
  (
    cd "$repo"
    local out decision
    out="$(PROJ_GITLEAKS_CMD="$gl_stub/gitleaks" PATH="$stub_dir:$PATH" bash -c 'printf %s "{\"tool_input\":{\"command\":\"git push origin mywork\"}}" | bash '"$HOOK")"
    decision="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty')"
    [[ "$decision" != "deny" ]] \
      || fail "test8: value only on another already-pushed branch must not block push (out=$out)"

    # 同じ値を自分の未 push commit に入れると deny されること（範囲限定が検知力を
    # 落としていないことの確認）
    printf 'PLANTED_SECRET\n' > mine-leak.txt
    git add mine-leak.txt
    git commit -q -m "feat: oops"
    out="$(PROJ_GITLEAKS_CMD="$gl_stub/gitleaks" PATH="$stub_dir:$PATH" bash -c 'printf %s "{\"tool_input\":{\"command\":\"git push origin mywork\"}}" | bash '"$HOOK")"
    decision="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty')"
    [[ "$decision" == "deny" ]] \
      || fail "test8: value in own unpushed commit must still deny push (out=$out)"
  )
  rm -rf "$repo" "$stub_dir" "$gl_stub"
  echo "PASS test8: other-branch value passes, own unpushed value denies"
}

# --------------------------------------------------------------------------
# Test 9: checkout 中の HEAD とは別のローカル ref を送る場合
# （`git push origin secret-branch:secret-branch`）も検査対象に含める。
# 範囲を HEAD だけに絞ると、clean な branch を checkout したまま秘密を含む別 branch を
# 送れてしまい、hook を素通りして remote に公開できる。
# --------------------------------------------------------------------------
test9_non_head_ref_push_is_scanned() {
  local repo stub_dir gl_stub
  repo="$(make_repo_with_remote)"
  stub_dir="$(make_pnpm_stub 0)"
  gl_stub="$(make_gitleaks_range_stub)"
  (
    cd "$repo"
    # HEAD (mywork) は clean のまま、未 push のローカル branch にだけ秘密を仕込む
    git checkout -q -b secret-branch
    printf 'PLANTED_SECRET\n' > sneaky.txt
    git add sneaky.txt
    git commit -q -m "feat: sneak"
    git checkout -q mywork

    local out decision
    out="$(PROJ_GITLEAKS_CMD="$gl_stub/gitleaks" PATH="$stub_dir:$PATH" bash -c 'printf %s "{\"tool_input\":{\"command\":\"git push origin secret-branch:secret-branch\"}}" | bash '"$HOOK")"
    decision="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty')"
    [[ "$decision" == "deny" ]] \
      || fail "test9: secret on a non-HEAD unpushed branch must deny push (out=$out)"
  )
  rm -rf "$repo" "$stub_dir" "$gl_stub"
  echo "PASS test9: secret on non-HEAD unpushed ref still denies"
}

# --------------------------------------------------------------------------
# Test 10: refs/heads・refs/tags 以外の名前空間（例: refs/changes/*）にしか到達できない
# commit も検査対象に含める。`git push origin refs/changes/x:refs/heads/x` で送れるため、
# branch/tag だけを列挙すると素通りする。
# --------------------------------------------------------------------------
test10_custom_ref_namespace_is_scanned() {
  local repo stub_dir gl_stub
  repo="$(make_repo_with_remote)"
  stub_dir="$(make_pnpm_stub 0)"
  gl_stub="$(make_gitleaks_range_stub)"
  (
    cd "$repo"
    # 秘密を custom ref からのみ到達可能にする（branch からは切り離す）
    printf 'PLANTED_SECRET\n' > sneaky.txt
    git add sneaky.txt
    git commit -q -m "feat: sneak"
    git update-ref refs/changes/secret HEAD
    git reset -q --hard HEAD~1

    local out decision
    out="$(PROJ_GITLEAKS_CMD="$gl_stub/gitleaks" PATH="$stub_dir:$PATH" bash -c 'printf %s "{\"tool_input\":{\"command\":\"git push origin refs/changes/secret:refs/heads/secret\"}}" | bash '"$HOOK")"
    decision="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty')"
    [[ "$decision" == "deny" ]] \
      || fail "test10: secret reachable only from a custom ref must deny push (out=$out)"
  )
  rm -rf "$repo" "$stub_dir" "$gl_stub"
  echo "PASS test10: secret on custom ref namespace still denies"
}

# --------------------------------------------------------------------------
# 以降は push 先の作業ツリーの特定（cd / git -C の静的解釈、解決不能は deny）の検証。
# hook プロセスの cwd を main checkout にしたまま、別 worktree へ push する起動を再現する。
# --------------------------------------------------------------------------

# main checkout と、その配下の worktree（.claude/worktrees/wt）を作る。両方に node_modules を置く。
# 出力: "<main の物理パス>" と "<worktree の物理パス>" を改行区切りで返す。
make_main_with_worktree() {
  local tmp main wt
  tmp="$(mktemp -d)"
  main="$tmp/main"
  git init -q "$main"
  (
    cd "$main"
    git config user.email "test@example.com"
    git config user.name "Test"
    git config commit.gpgsign false
    printf 'hello\n' > README.md
    git add README.md
    git commit -q -m "init"
    mkdir -p node_modules
    git worktree add -q .claude/worktrees/wt -b wt-branch
    mkdir -p .claude/worktrees/wt/node_modules
  )
  main="$(cd -P "$main" && pwd -P)"
  wt="$(cd -P "$main/.claude/worktrees/wt" && pwd -P)"
  printf '%s\n%s\n' "$main" "$wt"
}

# 実行場所を記録する stub を作る。pnpm は cwd（物理パス）と argv を、gitleaks は cwd を
# "$stub_dir/<name>.cwd" に追記する。どちらも成功（leak なし）で終わる。
make_recording_stubs() {
  local stub_dir
  stub_dir="$(mktemp -d)"
  cat > "$stub_dir/pnpm" <<STUB
#!/usr/bin/env bash
pwd -P >> "$stub_dir/pnpm.cwd"
printf '%s\n' "\$*" >> "$stub_dir/pnpm.args"
exit 0
STUB
  cat > "$stub_dir/gitleaks" <<STUB
#!/usr/bin/env bash
pwd -P >> "$stub_dir/gitleaks.cwd"
exit 0
STUB
  chmod +x "$stub_dir/pnpm" "$stub_dir/gitleaks"
  printf '%s' "$stub_dir"
}

# hook を process cwd = $1 で実行し、stdin に command=$2 / cwd=$3（空なら cwd 無し）の JSON を渡す。
# $4 は pnpm stub の dir、$5 は gitleaks stub の dir（省略時は $4）。
run_hook_at() {
  local proc_cwd="$1" command="$2" stdin_cwd="${3:-}" stub_dir="$4" gl_dir="${5:-$4}" json
  if [[ -n "$stdin_cwd" ]]; then
    json="$(jq -n --arg c "$command" --arg d "$stdin_cwd" '{tool_input:{command:$c},cwd:$d}')"
  else
    json="$(jq -n --arg c "$command" '{tool_input:{command:$c}}')"
  fi
  (
    cd "$proc_cwd"
    printf '%s' "$json" | PROJ_GITLEAKS_CMD="$gl_dir/gitleaks" PATH="$stub_dir:$PATH" bash "$HOOK"
  )
}

# 記録ファイルの全行が期待する作業ツリーのルートであること、かつ 1 行以上あることを確認する。
assert_ran_only_in() {
  local file="$1" expected="$2" label="$3" lines
  [[ -f "$file" ]] || fail "$label: expected checks to run, but $file was not written"
  lines="$(sort -u "$file")"
  [[ "$lines" == "$expected" ]] \
    || fail "$label: checks must run only in $expected, ran in: $lines"
}

assert_pnpm_steps_ran() {
  local stub_dir="$1" label="$2" step
  for step in format:check lint typecheck build; do
    grep -qxF "$step" "$stub_dir/pnpm.args" \
      || fail "$label: pnpm step '$step' was not run (args=$(tr '\n' ' ' < "$stub_dir/pnpm.args"))"
  done
}

# --------------------------------------------------------------------------
# Test 11: `cd <worktree> && git push` は worktree のルートで全 step を実行する。
# hook プロセスの cwd と stdin の cwd が main checkout でも、検査対象は push 先。
# --------------------------------------------------------------------------
test11_cd_prefix_checks_target_worktree() {
  local paths main wt stub_dir out
  paths="$(make_main_with_worktree)"
  main="$(printf '%s\n' "$paths" | sed -n 1p)"
  wt="$(printf '%s\n' "$paths" | sed -n 2p)"
  stub_dir="$(make_recording_stubs)"
  out="$(run_hook_at "$main" "cd $wt && git push origin wt-branch" "$main" "$stub_dir")"
  printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty' | grep -q 'passed' \
    || fail "test11: expected a pass record (out=$out)"
  assert_ran_only_in "$stub_dir/pnpm.cwd" "$wt" test11
  assert_ran_only_in "$stub_dir/gitleaks.cwd" "$wt" test11
  assert_pnpm_steps_ran "$stub_dir" test11
  rm -rf "$(dirname "$main")" "$stub_dir"
  echo "PASS test11: cd-prefixed push checks the target worktree"
}

# --------------------------------------------------------------------------
# Test 12: `git -C <worktree> push` も同様に push 先の worktree を検査する。
# グローバルオプション（-c）が前置されても解釈できる。
# --------------------------------------------------------------------------
test12_git_dash_c_checks_target_worktree() {
  local paths main wt stub_dir out
  paths="$(make_main_with_worktree)"
  main="$(printf '%s\n' "$paths" | sed -n 1p)"
  wt="$(printf '%s\n' "$paths" | sed -n 2p)"
  stub_dir="$(make_recording_stubs)"
  out="$(run_hook_at "$main" "git -c core.quotepath=off -C $wt push origin wt-branch" "$main" "$stub_dir")"
  printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty' | grep -q 'passed' \
    || fail "test12: expected a pass record (out=$out)"
  assert_ran_only_in "$stub_dir/pnpm.cwd" "$wt" test12
  assert_pnpm_steps_ran "$stub_dir" test12
  rm -rf "$(dirname "$main")" "$stub_dir"
  echo "PASS test12: git -C push checks the target worktree"
}

# --------------------------------------------------------------------------
# Test 13: 前置なしの `git push` は stdin の cwd（Bash の現在の cwd）の作業ツリーを検査する。
# hook プロセスの cwd が main checkout でも、stdin の cwd が worktree ならそちらが対象。
# サブディレクトリが cwd のときも、検査は作業ツリーのルートで行う。
# --------------------------------------------------------------------------
test13_stdin_cwd_selects_worktree() {
  local paths main wt stub_dir out
  paths="$(make_main_with_worktree)"
  main="$(printf '%s\n' "$paths" | sed -n 1p)"
  wt="$(printf '%s\n' "$paths" | sed -n 2p)"
  stub_dir="$(make_recording_stubs)"
  out="$(run_hook_at "$main" "git push origin wt-branch" "$wt" "$stub_dir")"
  printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty' | grep -q 'passed' \
    || fail "test13: expected a pass record (out=$out)"
  assert_ran_only_in "$stub_dir/pnpm.cwd" "$wt" test13

  rm -f "$stub_dir/pnpm.cwd" "$stub_dir/pnpm.args"
  mkdir -p "$wt/sub/dir"
  out="$(run_hook_at "$main" "git push" "$wt/sub/dir" "$stub_dir")"
  assert_ran_only_in "$stub_dir/pnpm.cwd" "$wt" test13
  rm -rf "$(dirname "$main")" "$stub_dir"
  echo "PASS test13: stdin cwd selects the worktree root"
}

# --------------------------------------------------------------------------
# Test 14: push 先を静的に決められない形は deny する（検査せず、誤った tree を緑にしない）。
# --------------------------------------------------------------------------
test14_unresolvable_target_denies() {
  local paths main wt stub_dir plain out decision reason cmd
  paths="$(make_main_with_worktree)"
  main="$(printf '%s\n' "$paths" | sed -n 1p)"
  wt="$(printf '%s\n' "$paths" | sed -n 2p)"
  plain="$(mktemp -d)"
  stub_dir="$(make_recording_stubs)"
  for cmd in \
    'cd "$WT_DIR" && git push' \
    'cd $(pwd) && git push' \
    'git -C ~/work push' \
    'git -C "$(dirname "$PWD")" push' \
    'cd .claude/worktrees/* && git push' \
    "cd $main/does-not-exist && git push" \
    "git -C $plain push" \
    "git --git-dir=$main/.git push" \
    "GIT_DIR=$main/.git git push" \
    "(cd $wt && git push)" \
    "cd -P $wt && git push" \
    "cd $wt && git push && cd $main && git push"; do
    out="$(run_hook_at "$main" "$cmd" "$main" "$stub_dir")"
    decision="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty')"
    [[ "$decision" == "deny" ]] \
      || fail "test14: unresolvable push target must deny (cmd=$cmd, out=$out)"
    reason="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty')"
    printf '%s' "$reason" | grep -q '作業ツリー' \
      || fail "test14: deny reason should explain the target could not be resolved (cmd=$cmd, reason=$reason)"
  done
  [[ ! -f "$stub_dir/pnpm.args" && ! -f "$stub_dir/gitleaks.cwd" ]] \
    || fail "test14: no check may run when the push target is unresolved"
  rm -rf "$(dirname "$main")" "$stub_dir" "$plain"
  echo "PASS test14: unresolvable push target is denied without running checks"
}

# --------------------------------------------------------------------------
# Test 15: push でない git -C / 複合コマンドは通過し、push を含む複合コマンドは検査する。
# `Bash(git -C *)` で hook が起動されても、push 以外の操作を妨げない。
# --------------------------------------------------------------------------
test15_non_push_and_compound_commands() {
  local paths main wt stub_dir out cmd
  paths="$(make_main_with_worktree)"
  main="$(printf '%s\n' "$paths" | sed -n 1p)"
  wt="$(printf '%s\n' "$paths" | sed -n 2p)"
  stub_dir="$(make_recording_stubs)"
  for cmd in \
    "git -C $wt status" \
    "git -C $wt log --grep push" \
    "git -C $wt commit -m 'fix push handling'" \
    "git -C $wt stash push" \
    "echo git push"; do
    out="$(run_hook_at "$main" "$cmd" "$main" "$stub_dir")"
    [[ -z "$out" ]] || fail "test15: non-push command must pass through silently (cmd=$cmd, out=$out)"
  done
  [[ ! -f "$stub_dir/pnpm.args" ]] || fail "test15: non-push commands must not run checks"

  out="$(run_hook_at "$main" "git status && git push origin wt-branch" "$wt" "$stub_dir")"
  printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty' | grep -q 'passed' \
    || fail "test15: a push after another command must still be checked (out=$out)"
  assert_ran_only_in "$stub_dir/pnpm.cwd" "$wt" test15
  rm -rf "$(dirname "$main")" "$stub_dir"
  echo "PASS test15: non-push commands pass through, compound pushes are checked"
}

# --------------------------------------------------------------------------
# Test 16: symlink 経由の cd 先は物理パスの作業ツリーを検査する。
# --------------------------------------------------------------------------
test16_symlinked_target_uses_physical_root() {
  local paths main wt stub_dir link_parent out
  paths="$(make_main_with_worktree)"
  main="$(printf '%s\n' "$paths" | sed -n 1p)"
  wt="$(printf '%s\n' "$paths" | sed -n 2p)"
  stub_dir="$(make_recording_stubs)"
  link_parent="$(mktemp -d)"
  ln -s "$wt" "$link_parent/wt-link"
  out="$(run_hook_at "$main" "cd $link_parent/wt-link && git push" "$main" "$stub_dir")"
  printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty' | grep -q 'passed' \
    || fail "test16: expected a pass record (out=$out)"
  assert_ran_only_in "$stub_dir/pnpm.cwd" "$wt" test16
  rm -rf "$(dirname "$main")" "$stub_dir" "$link_parent"
  echo "PASS test16: symlinked push target resolves to the physical worktree root"
}

# --------------------------------------------------------------------------
# Test 17: 別 repository への push（push 元と共有 git ディレクトリが異なる）は検査対象外。
# --------------------------------------------------------------------------
test17_other_repository_is_skipped() {
  local paths main stub_dir other out
  paths="$(make_main_with_worktree)"
  main="$(printf '%s\n' "$paths" | sed -n 1p)"
  stub_dir="$(make_recording_stubs)"
  other="$(make_repo)"
  out="$(run_hook_at "$main" "git -C $other push" "$main" "$stub_dir")"
  [[ -z "$out" ]] || fail "test17: push to another repository must pass through (out=$out)"
  [[ ! -f "$stub_dir/pnpm.args" && ! -f "$stub_dir/gitleaks.cwd" ]] \
    || fail "test17: no check may run for another repository"
  rm -rf "$(dirname "$main")" "$stub_dir" "$other"
  echo "PASS test17: push to another repository is out of scope"
}

# --------------------------------------------------------------------------
# Test 18: push 先の作業ツリーの .gitleaks.toml を使う（hook の cwd 側の設定ではない）。
# main にだけ .gitleaks.toml がある状態で worktree を検査すると --config は付かない。
# --------------------------------------------------------------------------
test18_gitleaks_config_comes_from_target_worktree() {
  local paths main wt stub_dir gl_stub
  paths="$(make_main_with_worktree)"
  main="$(printf '%s\n' "$paths" | sed -n 1p)"
  wt="$(printf '%s\n' "$paths" | sed -n 2p)"
  stub_dir="$(make_recording_stubs)"
  gl_stub="$(make_gitleaks_argv_stub)"
  printf 'title = "main only"\n' > "$main/.gitleaks.toml"
  run_hook_at "$main" "git -C $wt push" "$main" "$stub_dir" "$gl_stub" > /dev/null
  [[ -f "$gl_stub/argv" ]] || fail "test18: gitleaks was not invoked"
  if grep -qF -- '--config' "$gl_stub/argv"; then
    fail "test18: the main checkout's .gitleaks.toml must not apply to the worktree (argv=$(cat "$gl_stub/argv"))"
  fi
  printf 'title = "worktree"\n' > "$wt/.gitleaks.toml"
  run_hook_at "$main" "git -C $wt push" "$main" "$stub_dir" "$gl_stub" > /dev/null
  grep -qF -- '--config .gitleaks.toml' "$gl_stub/argv" \
    || fail "test18: the worktree's own .gitleaks.toml must be used (argv=$(cat "$gl_stub/argv"))"
  rm -rf "$(dirname "$main")" "$stub_dir" "$gl_stub"
  echo "PASS test18: gitleaks config is taken from the target worktree"
}

test1_non_push_passthrough
test2_no_node_modules_skip
test3_all_checks_pass
test4_check_failure_deny
test5_gitleaks_execution_error_skip
test6_gitleaks_leak_deny
test7_gitleaks_scan_scope_limited_to_outgoing
test8_other_branch_value_does_not_block_push
test9_non_head_ref_push_is_scanned
test10_custom_ref_namespace_is_scanned
test11_cd_prefix_checks_target_worktree
test12_git_dash_c_checks_target_worktree
test13_stdin_cwd_selects_worktree
test14_unresolvable_target_denies
test15_non_push_and_compound_commands
test16_symlinked_target_uses_physical_root
test17_other_repository_is_skipped
test18_gitleaks_config_comes_from_target_worktree

echo "ALL PASS"
