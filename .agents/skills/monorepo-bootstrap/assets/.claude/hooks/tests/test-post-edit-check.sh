#!/usr/bin/env bash
set -euo pipefail

# post-edit-check.sh の hermetic テスト。
# bash / git / jq のみで動く（実 eslint / tsc / pnpm 不要、すべて stub 注入）。
# 一時 git repo と一時 HOME を作り、各テスト後にクリーンアップする。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../post-edit-check.sh"

# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
require_hook

# hook を DIR を cwd にして実行し、stdout を返す。$1 DIR / $2 編集したファイル。
# compact_file が cwd 直下に .claude/state/hook-logs を作るため、DIR は書き込める場所にする。
# DIR が作業ツリーと異なる場合は、別 worktree からの起動など、hook の cwd と編集対象の
# 作業ツリーが一致しない起動の再現になる。
run_hook_in() {
  local dir="$1" file="$2"
  (
    cd "$dir"
    printf '{"tool_input":{"file_path":"%s"}}' "$file" | bash "$HOOK"
  )
}

# eslint / tsc / pnpm の stub（$1 の dir に置いたもの）を PROJ_*_CMD で注入して run_hook_in を実行する。
# 残りの引数は run_hook_in に渡す。PATH 前置ではなく環境変数注入を使うのは、hook が mise shims /
# /opt/homebrew/bin を PATH 先頭に足すため PATH 上の stub が実コマンドに shadow され得るため。
run_stubbed() {
  local stub_dir="$1"
  shift
  HOME="$stub_dir" \
    PROJ_ESLINT_CMD="$stub_dir/eslint" \
    PROJ_TSC_CMD="$stub_dir/tsc" \
    PROJ_PNPM_CMD="$stub_dir/pnpm" \
    run_hook_in "$@"
}

# --------------------------------------------------------------------------
# Test 1 (防御ガード): 対象外拡張子は無出力で通過し、外部コマンドを一切呼ばない。
# stub を全て注入したうえで .args が 1 つも生成されないことで未実行を確認する。
# --------------------------------------------------------------------------
test1_non_target_extension() {
  local repo stub_dir out f
  repo="$(make_workspace_repo)"
  stub_dir="$(mktemp -d)"
  write_stub "$stub_dir" eslint 1 "eslint-stub: should not run"
  write_stub "$stub_dir" tsc 1 "tsc-stub: should not run"
  write_stub "$stub_dir" pnpm 1 "pnpm-stub: should not run"
  out="$(run_stubbed "$stub_dir" "$repo" "NOTES.md")"
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
  local repo stub_dir out ctx marker
  repo="$(make_workspace_repo)"
  stub_dir="$(mktemp -d)"
  write_stub "$stub_dir" eslint 1 "eslint-stub: lint error"
  write_stub "$stub_dir" tsc 1 "tsc-stub: type error"
  write_stub "$stub_dir" pnpm 1 "pnpm-stub: test failed"
  out="$(run_stubbed "$stub_dir" "$repo" "apps/api/src/index.ts")"
  ctx="$(hook_ctx "$out")"
  [[ -n "$ctx" ]] || fail "test2: check failures must return additionalContext (out=$out)"
  for marker in '[eslint]' '[typecheck]' '[test]' \
    'eslint-stub: lint error' 'tsc-stub: type error' 'pnpm-stub: test failed'; do
    grep -qF "$marker" <<< "$ctx" \
      || fail "test2: additionalContext should contain '$marker' (ctx=$ctx)"
  done

  grep -qF -- '--no-warn-ignored apps/api/src/index.ts' <<< "$(args_of "$stub_dir/eslint.args" test2)" \
    || fail "test2: eslint argv should be '--no-warn-ignored <file>' (args=$(args_of "$stub_dir/eslint.args" test2))"
  grep -qF -- '--noEmit -p apps/api/tsconfig.json' <<< "$(args_of "$stub_dir/tsc.args" test2)" \
    || fail "test2: tsc argv should be '--noEmit -p <tsconfig>' (args=$(args_of "$stub_dir/tsc.args" test2))"
  grep -qF -- '--filter @example/api test' <<< "$(args_of "$stub_dir/pnpm.args" test2)" \
    || fail "test2: pnpm argv should be '--filter <pkg> test' (args=$(args_of "$stub_dir/pnpm.args" test2))"
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
  repo="$(make_workspace_repo)"
  stub_dir="$(mktemp -d)"
  write_stub "$stub_dir" eslint 0 ""
  write_stub "$stub_dir" tsc 0 ""
  write_stub "$stub_dir" pnpm 0 ""
  out="$(run_stubbed "$stub_dir" "$repo" "apps/api/src/index.ts")"
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
# 上限は 1 秒。即時に終わる stub は上限の前に完了するため、timeout 扱いにならない。
# --------------------------------------------------------------------------
test4_timeout_continues() {
  local repo stub_dir out ctx
  repo="$(make_workspace_repo)"
  stub_dir="$(mktemp -d)"
  write_stub "$stub_dir" eslint 0 "eslint-stub: should not be reported" 10
  write_stub "$stub_dir" tsc 1 "tsc-stub: type error"
  write_stub "$stub_dir" pnpm 0 ""
  out="$(PROJ_POST_EDIT_TIMEOUT_SEC=1 run_stubbed "$stub_dir" "$repo" "apps/api/src/index.ts")"
  ctx="$(hook_ctx "$out")"
  grep -qF '[eslint] timed out after 1s' <<< "$ctx" \
    || fail "test4: eslint timeout should be reported (ctx=$ctx)"
  grep -qF 'tsc-stub: type error' <<< "$ctx" \
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
# （記録して return 0 するだけ）、パッケージの解決（tsconfig.json の有無と package.json の
# name / scripts.test の読み取り）は実物を使うため、本番コードパスが実際に組み立てた argv を
# assert できる。
# 本テストは hook が utils を "$(dirname "$0")/../bin/hook-utils.sh" で解決する前提に
# 依存する。hook 側の解決ロジックを変えた場合は一時レイアウトも追随させること。
# --------------------------------------------------------------------------
test5_default_commands_and_timeouts() {
  local repo work log expected actual
  repo="$(make_workspace_repo)"
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
    printf '{"tool_input":{"file_path":"apps/api/src/index.ts"}}' \
      | env -u PROJ_ESLINT_CMD -u PROJ_TSC_CMD -u PROJ_PNPM_CMD \
          -u PROJ_POST_EDIT_TIMEOUT_SEC HOME="$repo" \
          bash "$work/hooks/post-edit-check.sh" > /dev/null
  )

  expected="$(printf '%s\n' \
    '30 npx eslint --no-warn-ignored apps/api/src/index.ts' \
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

# --------------------------------------------------------------------------
# Test 6: 絶対パス入力でも eslint / typecheck / test が実行される。
# hook の cwd を作業ツリーとは別のディレクトリにして、検査コマンドが編集対象の作業ツリー
# （物理パスのルート）を cwd にして呼ばれ、引数がルート基準の相対パスであることを確認する。
# --------------------------------------------------------------------------
test6_absolute_path_runs_all_checks_in_file_worktree() {
  local repo stub_dir other out ctx root f marker
  repo="$(make_workspace_repo)"
  stub_dir="$(mktemp -d)"
  other="$(mktemp -d)"
  root="$(cd -P "$repo" && pwd -P)"
  write_stub "$stub_dir" eslint 1 "eslint-stub: lint error"
  write_stub "$stub_dir" tsc 1 "tsc-stub: type error"
  write_stub "$stub_dir" pnpm 1 "pnpm-stub: test failed"
  out="$(run_stubbed "$stub_dir" "$other" "$repo/apps/api/src/index.ts")"
  ctx="$(hook_ctx "$out")"
  for marker in '[eslint]' '[typecheck]' '[test]'; do
    grep -qF "$marker" <<< "$ctx" \
      || fail "test6: absolute path input must run all three checks (missing '$marker', ctx=$ctx)"
  done
  grep -qF -- '--no-warn-ignored apps/api/src/index.ts' <<< "$(args_of "$stub_dir/eslint.args" test6)" \
    || fail "test6: eslint should receive the root-relative path"
  grep -qF -- '--noEmit -p apps/api/tsconfig.json' <<< "$(args_of "$stub_dir/tsc.args" test6)" \
    || fail "test6: tsc should receive the root-relative tsconfig"
  grep -qF -- '--filter @example/api test' <<< "$(args_of "$stub_dir/pnpm.args" test6)" \
    || fail "test6: pnpm should receive the package filter"
  for f in eslint tsc pnpm; do
    [[ "$(head -n 1 "$stub_dir/$f.cwd")" == "$root" ]] \
      || fail "test6: $f must run in the file's worktree root ($root), got: $(head -n 1 "$stub_dir/$f.cwd")"
  done
  rm -rf "$repo" "$stub_dir" "$other"
  echo "PASS test6: absolute path runs all checks in the file's worktree"
}

# --------------------------------------------------------------------------
# Test 7: 作業ツリーが symlink 経由のパスで渡されても検査が実行される。
# ルートは物理パスで決まるため、symlink 経由の絶対パスは物理パスへ揃えてから相対化する。
# --------------------------------------------------------------------------
test7_symlinked_worktree_path() {
  local repo stub_dir link_parent link out f
  repo="$(make_workspace_repo)"
  stub_dir="$(mktemp -d)"
  link_parent="$(mktemp -d)"
  link="$link_parent/via-link"
  ln -s "$repo" "$link"
  write_stub "$stub_dir" eslint 0 ""
  write_stub "$stub_dir" tsc 0 ""
  write_stub "$stub_dir" pnpm 0 ""
  out="$(run_stubbed "$stub_dir" "$link_parent" "$link/apps/api/src/index.ts")"
  [[ -z "$out" ]] || fail "test7: all-pass must produce no output (out=$out)"
  for f in eslint tsc pnpm; do
    [[ -f "$stub_dir/$f.args" ]] \
      || fail "test7: $f was not invoked for a path given through a symlinked worktree"
  done
  rm -rf "$repo" "$stub_dir" "$link_parent"
  echo "PASS test7: path through a symlinked worktree is checked"
}

# --------------------------------------------------------------------------
# Test 8: 作業ツリー外のファイルは検査せず通過する（無出力・外部コマンド未実行）。
# --------------------------------------------------------------------------
test8_outside_worktree_passes_through() {
  local repo stub_dir other out f
  repo="$(make_workspace_repo)"
  stub_dir="$(mktemp -d)"
  other="$(mktemp -d)"
  printf 'export const x = 1;\n' > "$other/outside.ts"
  write_stub "$stub_dir" eslint 1 "eslint-stub: should not run"
  write_stub "$stub_dir" tsc 1 "tsc-stub: should not run"
  write_stub "$stub_dir" pnpm 1 "pnpm-stub: should not run"
  out="$(run_stubbed "$stub_dir" "$repo" "$other/outside.ts")"
  [[ -z "$out" ]] || fail "test8: file outside the worktree must pass through (out=$out)"
  for f in eslint tsc pnpm; do
    [[ ! -f "$stub_dir/$f.args" ]] \
      || fail "test8: $f must not run for a file outside the worktree"
  done
  rm -rf "$repo" "$stub_dir" "$other"
  echo "PASS test8: file outside the worktree passes through"
}

# --------------------------------------------------------------------------
# Test 9: パッケージの外のファイルは eslint だけを実行する（typecheck と test は package 単位）。
# tsconfig.json の無いパッケージでは typecheck を、scripts.test の無いパッケージでは test を省く。
# --------------------------------------------------------------------------
test9_package_scoped_checks() {
  local repo stub_dir_outside stub_dir_bare
  repo="$(make_workspace_repo)"
  stub_dir_outside="$(mktemp -d)"
  stub_dir_bare="$(mktemp -d)"
  mkdir -p "$repo/scripts"
  printf 'export const s = 1;\n' > "$repo/scripts/tool.ts"
  write_stub "$stub_dir_outside" eslint 0 ""
  write_stub "$stub_dir_outside" tsc 0 ""
  write_stub "$stub_dir_outside" pnpm 0 ""
  write_stub "$stub_dir_bare" eslint 0 ""
  write_stub "$stub_dir_bare" tsc 0 ""
  write_stub "$stub_dir_bare" pnpm 0 ""

  run_stubbed "$stub_dir_outside" "$repo" "scripts/tool.ts" > /dev/null
  [[ -f "$stub_dir_outside/eslint.args" ]] || fail "test9: eslint should run for a file outside any package"
  [[ ! -f "$stub_dir_outside/tsc.args" && ! -f "$stub_dir_outside/pnpm.args" ]] \
    || fail "test9: typecheck and test are per package and must not run outside a package"

  run_stubbed "$stub_dir_bare" "$repo" "packages/lib/src/index.ts" > /dev/null
  [[ -f "$stub_dir_bare/eslint.args" ]] || fail "test9: eslint should run for packages/*"
  [[ ! -f "$stub_dir_bare/tsc.args" ]] || fail "test9: typecheck must not run for a package without tsconfig.json"
  [[ ! -f "$stub_dir_bare/pnpm.args" ]] || fail "test9: test must not run for a package without scripts.test"
  rm -rf "$repo" "$stub_dir_outside" "$stub_dir_bare"
  echo "PASS test9: typecheck and test run only for packages that define them"
}

test1_non_target_extension
test2_ts_all_checks_combined
test3_ts_all_pass_no_output
test4_timeout_continues
test5_default_commands_and_timeouts
test6_absolute_path_runs_all_checks_in_file_worktree
test7_symlinked_worktree_path
test8_outside_worktree_passes_through
test9_package_scoped_checks

echo "ALL PASS"
