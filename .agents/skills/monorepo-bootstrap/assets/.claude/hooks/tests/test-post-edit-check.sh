#!/usr/bin/env bash
set -euo pipefail

# post-edit-check.sh の hermetic テスト。
# bash / git / jq のみで動く（実 eslint / tsc / pnpm 不要、すべて stub 注入）。
# 一時 git repo と一時 HOME を作り、各テスト後にクリーンアップする。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../post-edit-check.sh"

if [[ ! -f "$HOOK" ]]; then
  echo "FAIL: hook not found: $HOOK" >&2
  exit 1
fi

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# 隔離した一時 repo を作る。hook が resolve_tsconfig / resolve_package / has_test_script を
# 通過するために apps/api の package.json（scripts.test あり）と tsconfig.json が要る。
make_repo() {
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "$tmp"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    git config commit.gpgsign false
    mkdir -p apps/api/src
    printf '%s\n' '{"name":"@example/api","scripts":{"test":"vitest"}}' > apps/api/package.json
    printf '%s\n' '{}' > apps/api/tsconfig.json
    printf '%s\n' 'export const sample = 1;' > apps/api/src/sample.ts
    printf '%s\n' '# sample' > NOTES.md
    git add -A
    git commit -q -m "init"
  )
  printf '%s' "$tmp"
}

# stub 群を置く一時ディレクトリを作る。
make_stub_dir() {
  mktemp -d
}

# 実行可能な stub コマンドを作る。
# $1 stub_dir / $2 コマンド名 / $3 exit code / $4 標準出力に出すメッセージ /
# $5 終了前の sleep 秒（既定 0、タイムアウト検証用）
#
# stub は受領した argv を "<stub>.args" に記録する。出力だけを見ていると seam 化で
# 引数が落ちる退行（eslint の --no-warn-ignored 欠落など）に気付けないため、引数も pin する。
# argv ゼロでも .args を作れるようリダイレクトはループの外に置く（呼び出し有無の判定に使う）。
write_stub() {
  local dir="$1" name="$2" code="$3" msg="$4" sleep_sec="${5:-0}"
  cat > "$dir/$name" <<STUB
#!/usr/bin/env bash
{ for a in "\$@"; do printf '%s\n' "\$a"; done; } >> "$dir/$name.args"
if [ "$sleep_sec" -gt 0 ]; then
  sleep $sleep_sec
fi
if [ -n "$msg" ]; then
  printf '%s\n' "$msg"
fi
exit $code
STUB
  chmod +x "$dir/$name"
}

# stub が受領した argv を空白区切りの 1 行に平坦化して返す（未呼び出しなら FAIL）。
args_of() {
  local args_file="$1" label="$2"
  [[ -f "$args_file" ]] || fail "$label: stub was not invoked ($args_file missing)"
  tr '\n' ' ' < "$args_file"
}

# hook を隔離 repo の中で実行して stdout を返す。
# compact_file が cwd 直下に .claude/state/hook-logs を作るため、必ず repo 内で実行する。
# stub の注入（PROJ_*_CMD）は呼び出し側が本関数の前置環境変数として渡す。
# PATH 前置ではなく環境変数注入を使うのは、hook が mise shims / /opt/homebrew/bin を
# PATH 先頭に足すため PATH 上の stub が実コマンドに shadow され得るため。
run_hook_in() {
  local repo="$1" file="$2"
  (
    cd "$repo"
    printf '{"tool_input":{"file_path":"%s"}}' "$file" | bash "$HOOK"
  )
}

# additionalContext を取り出す（無ければ空文字）。
ctx_of() {
  printf '%s' "$1" | jq -r '.hookSpecificOutput.additionalContext // empty'
}

# --------------------------------------------------------------------------
# Test 1 (防御ガード): 対象外拡張子は無出力で通過し、外部コマンドを一切呼ばない。
# stub を全て注入したうえで .args が 1 つも生成されないことで未実行を確認する。
# --------------------------------------------------------------------------
test1_non_target_extension() {
  local repo stub_dir out f
  repo="$(make_repo)"
  stub_dir="$(make_stub_dir)"
  write_stub "$stub_dir" eslint 1 "eslint-stub: should not run"
  write_stub "$stub_dir" tsc 1 "tsc-stub: should not run"
  write_stub "$stub_dir" pnpm 1 "pnpm-stub: should not run"
  out="$(HOME="$repo" \
    PROJ_ESLINT_CMD="$stub_dir/eslint" \
    PROJ_TSC_CMD="$stub_dir/tsc" \
    PROJ_PNPM_CMD="$stub_dir/pnpm" \
    run_hook_in "$repo" "NOTES.md")"
  [[ -z "$out" ]] || fail "test1: non-target extension must pass through with no output (out=$out)"
  for f in eslint tsc pnpm; do
    [[ ! -f "$stub_dir/$f.args" ]] \
      || fail "test1: $f must not be invoked for a non-target extension"
  done
  rm -rf "$repo" "$stub_dir"
  echo "PASS test1: non-target extension passes through without running checks"
}

# --------------------------------------------------------------------------
# Test 2: .ts は eslint / typecheck / test の失敗出力がラベル付きで結合される。
# 各チェックが受領した argv も pin し、seam 化で引数が落ちる退行を検出する。
# --------------------------------------------------------------------------
test2_ts_all_checks_combined() {
  local repo stub_dir out ctx marker eslint_args tsc_args pnpm_args
  repo="$(make_repo)"
  stub_dir="$(make_stub_dir)"
  write_stub "$stub_dir" eslint 1 "eslint-stub: lint error"
  write_stub "$stub_dir" tsc 1 "tsc-stub: type error"
  write_stub "$stub_dir" pnpm 1 "pnpm-stub: test failed"
  out="$(HOME="$repo" \
    PROJ_ESLINT_CMD="$stub_dir/eslint" \
    PROJ_TSC_CMD="$stub_dir/tsc" \
    PROJ_PNPM_CMD="$stub_dir/pnpm" \
    run_hook_in "$repo" "apps/api/src/sample.ts")"
  ctx="$(ctx_of "$out")"
  [[ -n "$ctx" ]] || fail "test2: check failures must return additionalContext (out=$out)"
  for marker in '[eslint]' '[typecheck]' '[test]' \
    'eslint-stub: lint error' 'tsc-stub: type error' 'pnpm-stub: test failed'; do
    printf '%s' "$ctx" | grep -qF "$marker" \
      || fail "test2: additionalContext should contain '$marker' (ctx=$ctx)"
  done

  eslint_args="$(args_of "$stub_dir/eslint.args" test2)"
  printf '%s' "$eslint_args" | grep -qF -- '--no-warn-ignored apps/api/src/sample.ts' \
    || fail "test2: eslint argv should be '--no-warn-ignored <file>' (args=$eslint_args)"
  tsc_args="$(args_of "$stub_dir/tsc.args" test2)"
  printf '%s' "$tsc_args" | grep -qF -- '--noEmit -p apps/api/tsconfig.json' \
    || fail "test2: tsc argv should be '--noEmit -p <tsconfig>' (args=$tsc_args)"
  pnpm_args="$(args_of "$stub_dir/pnpm.args" test2)"
  printf '%s' "$pnpm_args" | grep -qF -- '--filter @example/api test' \
    || fail "test2: pnpm argv should be '--filter <pkg> test' (args=$pnpm_args)"
  rm -rf "$repo" "$stub_dir"
  echo "PASS test2: ts eslint/typecheck/test failures are combined with expected argv"
}

# --------------------------------------------------------------------------
# Test 3: 全チェック成功時は何も出力しない（成功時のノイズ注入をしない）。
# 3 つの .args の存在も確認し、無出力が「実行されて成功」であって
# 「実行されずに空」ではないことを保証する。
# --------------------------------------------------------------------------
test3_ts_all_pass_no_output() {
  local repo stub_dir out f
  repo="$(make_repo)"
  stub_dir="$(make_stub_dir)"
  write_stub "$stub_dir" eslint 0 ""
  write_stub "$stub_dir" tsc 0 ""
  write_stub "$stub_dir" pnpm 0 ""
  out="$(HOME="$repo" \
    PROJ_ESLINT_CMD="$stub_dir/eslint" \
    PROJ_TSC_CMD="$stub_dir/tsc" \
    PROJ_PNPM_CMD="$stub_dir/pnpm" \
    run_hook_in "$repo" "apps/api/src/sample.ts")"
  [[ -z "$out" ]] || fail "test3: all-pass must produce no output (out=$out)"
  for f in eslint tsc pnpm; do
    [[ -f "$stub_dir/$f.args" ]] \
      || fail "test3: $f was not invoked (all-pass must mean the checks actually ran)"
  done
  rm -rf "$repo" "$stub_dir"
  echo "PASS test3: all checks run and pass with no output"
}

# --------------------------------------------------------------------------
# Test 4: タイムアウトしたチェックは timeout 表示になり、後続チェックは継続する。
# PROJ_POST_EDIT_TIMEOUT_SEC は全チェックに一括適用されるため、eslint 以外は上限内に
# 必ず終わる即時終了 stub にする（typecheck が実出力を返すことで継続を確認する）。
# hook-utils の polling fallback（timeout / gtimeout 不在環境）は 1 秒粒度で状態を見るため、
# 即時終了 stub が誤って timeout 扱いにならない上限として 2 秒を使う。
# --------------------------------------------------------------------------
test4_timeout_continues() {
  local repo stub_dir out ctx
  repo="$(make_repo)"
  stub_dir="$(make_stub_dir)"
  write_stub "$stub_dir" eslint 0 "eslint-stub: should not be reported" 10
  write_stub "$stub_dir" tsc 1 "tsc-stub: type error"
  write_stub "$stub_dir" pnpm 0 ""
  out="$(HOME="$repo" \
    PROJ_POST_EDIT_TIMEOUT_SEC=2 \
    PROJ_ESLINT_CMD="$stub_dir/eslint" \
    PROJ_TSC_CMD="$stub_dir/tsc" \
    PROJ_PNPM_CMD="$stub_dir/pnpm" \
    run_hook_in "$repo" "apps/api/src/sample.ts")"
  ctx="$(ctx_of "$out")"
  printf '%s' "$ctx" | grep -qF '[eslint] timed out after 2s' \
    || fail "test4: eslint timeout should be reported (ctx=$ctx)"
  printf '%s' "$ctx" | grep -qF 'tsc-stub: type error' \
    || fail "test4: checks after a timeout must still run and report output (ctx=$ctx)"
  rm -rf "$repo" "$stub_dir"
  echo "PASS test4: timeout is reported and later checks continue"
}

# --------------------------------------------------------------------------
# Test 5: seam 未設定時の既定コマンドと既定タイムアウト秒を pin する。
# test1〜4 は PROJ_*_CMD を注入するため seam の既定分岐を一度も通らず、既定値の破壊
# （eslint → eslintx、timeout 60 → 5 等）を検出できない。既定値が壊れると CI は緑の
# ままローカルだけ壊れるため、既定分岐だけを別建てで検証する。
#
# 方式: hook 本体を一時レイアウトへ copy し、隣に hook-utils の shim を置いて
# run_limited_check だけを argv 記録に差し替える。外部コマンドは一切実行されず
# （記録して return 0 するだけ）、resolve_tsconfig / resolve_package / has_test_script は
# 実物を使うため、本番コードパスが実際に組み立てた argv を assert できる。
# 本テストは hook が utils を "$(dirname "$0")/../bin/hook-utils.sh" で解決する前提に
# 依存する。hook 側の解決ロジックを変えた場合は一時レイアウトも追随させること。
# --------------------------------------------------------------------------
test5_default_commands_and_timeouts() {
  local repo work log expected actual
  repo="$(make_repo)"
  work="$(mktemp -d)"
  mkdir -p "$work/hooks" "$work/bin"
  log="$work/calls.log"

  # hook-utils の shim: 実物を source した後 run_limited_check だけを上書きする。
  # 記録形式は "<タイムアウト秒> <argv...>"（$2=label / $3=行上限 は検証対象外）。
  cat > "$work/bin/hook-utils.sh" <<SHIM
source "$SCRIPT_DIR/../../bin/hook-utils.sh"
run_limited_check() {
  printf '%s' "\$1" >> "$log"
  printf ' %s' "\${@:4}" >> "$log"
  printf '\n' >> "$log"
  return 0
}
SHIM
  cp "$HOOK" "$work/hooks/post-edit-check.sh"

  # 全 seam を env -u で外して既定分岐を通す。
  (
    cd "$repo"
    printf '{"tool_input":{"file_path":"apps/api/src/sample.ts"}}' \
      | env -u PROJ_ESLINT_CMD -u PROJ_TSC_CMD -u PROJ_PNPM_CMD \
          -u PROJ_POST_EDIT_TIMEOUT_SEC HOME="$repo" \
          bash "$work/hooks/post-edit-check.sh" > /dev/null
  )

  expected="$(printf '%s\n' \
    '30 npx eslint --no-warn-ignored apps/api/src/sample.ts' \
    '30 npx tsc --noEmit -p apps/api/tsconfig.json' \
    '60 pnpm --filter @example/api test')"
  actual="$(cat "$log")"
  [[ "$actual" == "$expected" ]] || fail "test5: default commands/timeouts drifted
--- expected ---
$expected
--- actual ---
$actual"
  rm -rf "$repo" "$work"
  echo "PASS test5: default commands and timeouts are unchanged"
}

test1_non_target_extension
test2_ts_all_checks_combined
test3_ts_all_pass_no_output
test4_timeout_continues
test5_default_commands_and_timeouts

echo "ALL PASS"
