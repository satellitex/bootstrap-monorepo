#!/usr/bin/env bash
set -euo pipefail

# pre-push-ci-check.sh の hermetic テスト。
# bash / git / jq のみで動く（実 pnpm / gitleaks 不要、pnpm は PATH stub、
# gitleaks は PROJ_GITLEAKS_CMD で stub 注入）。
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

echo "ALL PASS"
