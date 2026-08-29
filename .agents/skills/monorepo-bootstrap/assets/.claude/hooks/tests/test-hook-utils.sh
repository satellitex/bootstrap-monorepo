#!/usr/bin/env bash
set -euo pipefail

# hook-utils.sh の hermetic ユニットテスト。
# bash / jq のみで動く（git / pnpm 不要）。
# .claude/bin/hook-utils.sh が提供する各関数を個別にテストする。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_UTILS="$SCRIPT_DIR/../../bin/hook-utils.sh"

if [[ ! -f "$HOOK_UTILS" ]]; then
  echo "FAIL: hook-utils.sh not found: $HOOK_UTILS" >&2
  exit 1
fi

# shellcheck source=../../bin/hook-utils.sh
source "$HOOK_UTILS"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

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
    printf '%s' "$out" | grep -q 'omitted\|Full log' \
      || fail "test2: large output should be compacted"
    printf '%s' "$out" | grep -q 'line1' \
      || fail "test2: first line should appear in compacted output"
    printf '%s' "$out" | grep -q 'line210' \
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
# --------------------------------------------------------------------------
test4_resolve_package_apps() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  (
    cd "$tmpdir"
    mkdir -p apps/myapp/src
    printf '{"name":"@example/myapp","version":"1.0.0"}\n' > apps/myapp/package.json
    local pkg
    pkg="$(resolve_package "apps/myapp/src/index.ts")"
    [[ "$pkg" == "@example/myapp" ]] \
      || fail "test4: resolve_package should return @example/myapp, got: $pkg"
  )
  rm -rf "$tmpdir"
  echo "PASS test4: resolve_package resolves apps package"
}

# --------------------------------------------------------------------------
# Test 5: resolve_package — パッケージ外のファイルは空文字を返す。
# --------------------------------------------------------------------------
test5_resolve_package_outside() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  (
    cd "$tmpdir"
    local pkg
    pkg="$(resolve_package "scripts/foo.ts")"
    [[ -z "$pkg" ]] \
      || fail "test5: resolve_package should return empty for out-of-package path, got: $pkg"
  )
  rm -rf "$tmpdir"
  echo "PASS test5: resolve_package returns empty for out-of-package path"
}

# --------------------------------------------------------------------------
# Test 6: resolve_tsconfig — tsconfig.json の有無でパス / 空文字を返す。
# --------------------------------------------------------------------------
test6_resolve_tsconfig() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  (
    cd "$tmpdir"
    mkdir -p apps/api/src packages/bare/src
    printf '{"compilerOptions":{}}\n' > apps/api/tsconfig.json
    local ts
    ts="$(resolve_tsconfig "apps/api/src/index.ts")"
    [[ "$ts" == "apps/api/tsconfig.json" ]] \
      || fail "test6: resolve_tsconfig should return apps/api/tsconfig.json, got: $ts"
    ts="$(resolve_tsconfig "packages/bare/src/index.ts")"
    [[ -z "$ts" ]] \
      || fail "test6: resolve_tsconfig should return empty when no tsconfig, got: $ts"
  )
  rm -rf "$tmpdir"
  echo "PASS test6: resolve_tsconfig returns path or empty"
}

# --------------------------------------------------------------------------
# Test 7: has_test_script — scripts.test の有無で 0 / 1 を返す。
# --------------------------------------------------------------------------
test7_has_test_script() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  (
    cd "$tmpdir"
    mkdir -p packages/foo packages/bar
    printf '{"scripts":{"test":"vitest run"}}\n' > packages/foo/package.json
    printf '{"scripts":{"build":"tsc"}}\n' > packages/bar/package.json
    has_test_script "packages/foo" \
      || fail "test7: has_test_script should return 0 when scripts.test exists"
    if has_test_script "packages/bar"; then
      fail "test7: has_test_script should return 1 when no test script"
    fi
  )
  rm -rf "$tmpdir"
  echo "PASS test7: has_test_script returns 0/1 by scripts.test"
}

# --------------------------------------------------------------------------
# Test 8: run_limited_check — 成功は空出力、失敗は compact された出力。
# --------------------------------------------------------------------------
test8_run_limited_check() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  (
    cd "$tmpdir"
    export HOOK_LOG_PREFIX="test"
    local out
    out="$(run_limited_check 5 "ok-label" 100 true)"
    [[ -z "$out" ]] \
      || fail "test8: successful command should produce no output (out=$out)"
    out="$(run_limited_check 5 "ng-label" 100 bash -c 'echo "error output"; exit 1')"
    [[ -n "$out" ]] \
      || fail "test8: failed command should produce output (got empty)"
    printf '%s' "$out" | grep -q 'error output' \
      || fail "test8: output should contain command output (out=$out)"
  )
  rm -rf "$tmpdir"
  echo "PASS test8: run_limited_check success empty / failure compacted"
}

test1_compact_output_short
test2_compact_output_truncates
test3_compact_file_short
test4_resolve_package_apps
test5_resolve_package_outside
test6_resolve_tsconfig
test7_has_test_script
test8_run_limited_check

echo "ALL PASS"
