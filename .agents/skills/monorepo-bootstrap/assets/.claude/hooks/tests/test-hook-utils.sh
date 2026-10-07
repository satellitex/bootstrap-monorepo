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

# --------------------------------------------------------------------------
# 以降はパス正規化（絶対パス・symlink・hook の cwd と作業ツリーが異なる起動）の検証。
# 隔離した一時 git repo を作り、apps/api の package.json / tsconfig.json を置く。
# --------------------------------------------------------------------------
make_workspace_repo() {
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "$tmp"
    git init -q
    mkdir -p apps/api/src packages/lib/src
    printf '{"name":"@example/api","scripts":{"test":"vitest"}}\n' > apps/api/package.json
    printf '{}\n' > apps/api/tsconfig.json
    printf 'export const a = 1;\n' > apps/api/src/index.ts
    printf '{"name":"@example/lib"}\n' > packages/lib/package.json
    printf '# apps\n' > apps/README.md
  )
  printf '%s' "$tmp"
}

# --------------------------------------------------------------------------
# Test 9: normalize_repo_path — 相対パスは git 管理外でもそのまま返す（先頭 ./ は除去）。
# --------------------------------------------------------------------------
test9_normalize_relative() {
  local tmpdir out
  tmpdir="$(mktemp -d)"
  (
    cd "$tmpdir"
    out="$(normalize_repo_path "apps/api/src/index.ts")"
    [[ "$out" == "apps/api/src/index.ts" ]] \
      || fail "test9: relative path should be returned as-is, got: $out"
    out="$(normalize_repo_path "./apps/api/src/index.ts")"
    [[ "$out" == "apps/api/src/index.ts" ]] \
      || fail "test9: leading ./ should be stripped, got: $out"
    out="$(normalize_repo_path "")"
    [[ -z "$out" ]] || fail "test9: empty input should return empty, got: $out"
  )
  rm -rf "$tmpdir"
  echo "PASS test9: normalize_repo_path keeps relative paths"
}

# --------------------------------------------------------------------------
# Test 10: normalize_repo_path — 絶対パスは作業ツリーのルート基準へ相対化する。
# hook の cwd が別ディレクトリでも、ルートは入力ファイル側から決まる。
# --------------------------------------------------------------------------
test10_normalize_absolute() {
  local repo other out
  repo="$(make_workspace_repo)"
  other="$(mktemp -d)"
  (
    cd "$repo"
    out="$(normalize_repo_path "$repo/apps/api/src/index.ts")"
    [[ "$out" == "apps/api/src/index.ts" ]] \
      || fail "test10: absolute path (cwd=repo) should be relativized, got: $out"
    cd "$other"
    out="$(normalize_repo_path "$repo/apps/api/src/index.ts")"
    [[ "$out" == "apps/api/src/index.ts" ]] \
      || fail "test10: absolute path (cwd elsewhere) should be relativized from the file's own root, got: $out"
    cd "$repo/apps/api"
    out="$(normalize_repo_path "src/index.ts")"
    [[ "$out" == "apps/api/src/index.ts" ]] \
      || fail "test10: relative path from a subdirectory should be root-relative, got: $out"
  )
  rm -rf "$repo" "$other"
  echo "PASS test10: normalize_repo_path relativizes absolute paths from the file's root"
}

# --------------------------------------------------------------------------
# Test 11: symlink — 作業ツリーが symlink 経由のパスで渡されても相対化できる。
# 作業ツリーのルートは物理パスで返る。symlink を辿って repo 外へ出るパスは空文字にする。
# --------------------------------------------------------------------------
test11_normalize_symlink() {
  local repo link_parent link outside out expected_root
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
    out="$(normalize_repo_path "$link/apps/api/src/index.ts")"
    [[ "$out" == "apps/api/src/index.ts" ]] \
      || fail "test11: path via a symlinked root should be relativized, got: $out"
    out="$(resolve_repo_root "$link/apps/api/src/index.ts")"
    [[ "$out" == "$expected_root" ]] \
      || fail "test11: root should be the physical path ($expected_root), got: $out"
    out="$(normalize_repo_path "$repo/apps/escape/escaped.ts")"
    [[ -z "$out" ]] \
      || fail "test11: path escaping the worktree through a symlink should be empty, got: $out"
  )
  rm -rf "$repo" "$link_parent" "$outside"
  echo "PASS test11: normalize_repo_path handles symlinked roots and escapes"
}

# --------------------------------------------------------------------------
# Test 12: ルート外・未作成のパス。
# 別の作業ツリーや git 管理外のパスは空文字。未作成のファイルは既存の祖先から解決する。
# --------------------------------------------------------------------------
test12_normalize_outside_and_missing() {
  local repo other out
  repo="$(make_workspace_repo)"
  other="$(mktemp -d)"
  printf 'x\n' > "$other/foo.ts"
  (
    cd "$repo"
    out="$(normalize_repo_path "$other/foo.ts")"
    [[ -z "$out" ]] \
      || fail "test12: path outside the worktree should be empty, got: $out"
    out="$(normalize_repo_path "$repo/apps/api/src/not/yet/created.ts")"
    [[ "$out" == "apps/api/src/not/yet/created.ts" ]] \
      || fail "test12: missing file should resolve from an existing ancestor, got: $out"
  )
  rm -rf "$repo" "$other"
  echo "PASS test12: normalize_repo_path returns empty outside the worktree"
}

# --------------------------------------------------------------------------
# Test 13: resolve_package / resolve_tsconfig / resolve_package_dir は絶対パスでも解決する。
# hook の cwd が作業ツリーと異なっていても、ルート基準の相対パスを返す。
# --------------------------------------------------------------------------
test13_resolve_with_absolute_path() {
  local repo other out
  repo="$(make_workspace_repo)"
  other="$(mktemp -d)"
  (
    cd "$other"
    out="$(resolve_package "$repo/apps/api/src/index.ts")"
    [[ "$out" == "@example/api" ]] \
      || fail "test13: resolve_package should resolve an absolute path, got: $out"
    out="$(resolve_tsconfig "$repo/apps/api/src/index.ts")"
    [[ "$out" == "apps/api/tsconfig.json" ]] \
      || fail "test13: resolve_tsconfig should return a root-relative path, got: $out"
    out="$(resolve_package_dir "$repo/apps/api/src/index.ts")"
    [[ "$out" == "apps/api" ]] \
      || fail "test13: resolve_package_dir should return apps/api, got: $out"
    out="$(resolve_tsconfig "$repo/packages/lib/src/x.ts")"
    [[ -z "$out" ]] \
      || fail "test13: package without tsconfig should resolve to empty, got: $out"
    out="$(resolve_package_dir "$repo/apps/README.md")"
    [[ -z "$out" ]] \
      || fail "test13: a file directly under apps/ is not in a package, got: $out"
    out="$(resolve_package "$other/scripts/foo.ts")"
    [[ -z "$out" ]] \
      || fail "test13: out-of-worktree path should resolve to empty, got: $out"
  )
  rm -rf "$repo" "$other"
  echo "PASS test13: package resolution works for absolute paths"
}

test1_compact_output_short
test2_compact_output_truncates
test3_compact_file_short
test4_resolve_package_apps
test5_resolve_package_outside
test6_resolve_tsconfig
test7_has_test_script
test8_run_limited_check
test9_normalize_relative
test10_normalize_absolute
test11_normalize_symlink
test12_normalize_outside_and_missing
test13_resolve_with_absolute_path

echo "ALL PASS"
