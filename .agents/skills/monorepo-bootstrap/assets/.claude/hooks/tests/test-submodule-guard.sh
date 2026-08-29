#!/usr/bin/env bash
set -euo pipefail

# .claude/bin/submodule-guard.sh の hermetic テスト（opt-in:submodule）。
# submodule を採用しない bootstrap 先でも hermetic なため常時実行してよいが、
# 対象ユーティリティ自体は submodule 採用時のみ配線される（.claude/hooks/README.md 参照）。
# bash / git のみで動く（network 不要。ローカル file:// submodule remote を使う）。
# 一時 git repo を作り、各テスト後にクリーンアップする。
#
# 提供関数:
#   submodule_needs_init <path> — 指定 path 配下に未初期化 submodule があれば true (exit 0)
#   ensure_submodule_init <path> — 未初期化のときだけ idempotent に init する

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBMODULE_GUARD="$SCRIPT_DIR/../../bin/submodule-guard.sh"

if [[ ! -f "$SUBMODULE_GUARD" ]]; then
  echo "FAIL: submodule-guard.sh not found: $SUBMODULE_GUARD" >&2
  exit 1
fi

# shellcheck source=../../bin/submodule-guard.sh
source "$SUBMODULE_GUARD"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# cwd に git repo を init し、テスト用 user config を設定する（呼び出し側が先に
# mktemp -d + cd 済みであること前提）。3 箇所で使う boilerplate を集約する。
init_git_repo() {
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test"
  git config commit.gpgsign false
}

# --------------------------------------------------------------------------
# テスト用の submodule remote + 親 repo を作る。
# 親 repo には lib/dep という 1 submodule を file:// URL で登録する
# （network 不要、実際のツールチェーン submodule は使わない）。
# --------------------------------------------------------------------------
make_repo_with_submodule() {
  local sub_remote main_repo
  sub_remote="$(mktemp -d)"
  (
    cd "$sub_remote"
    init_git_repo
    printf 'dep content\n' > dep.txt
    git add dep.txt
    git commit -q -m "dep init"
  )

  main_repo="$(mktemp -d)"
  (
    cd "$main_repo"
    init_git_repo
    export GIT_ALLOW_PROTOCOL="file"
    printf 'root\n' > root.txt
    git add root.txt
    git commit -q -m "root init"
    mkdir -p lib
    git submodule add -q "file://$sub_remote" lib/dep >/dev/null 2>&1
    git commit -q -m "add submodule"
  )

  printf '%s\n%s' "$main_repo" "$sub_remote"
}

# --------------------------------------------------------------------------
# Test 1: 未初期化 submodule を検出し、ensure_submodule_init で init される
# （idempotent 初期化の本体）。
# --------------------------------------------------------------------------
test1_uninitialized_detected_and_initialized() {
  local repos main_repo sub_remote
  repos="$(make_repo_with_submodule)"
  main_repo="$(sed -n '1p' <<< "$repos")"
  sub_remote="$(sed -n '2p' <<< "$repos")"

  (
    cd "$main_repo"
    export GIT_ALLOW_PROTOCOL="file"
    # submodule を意図的に deinit して「未初期化」状態を作る。
    git submodule deinit -f lib/dep >/dev/null

    submodule_needs_init "lib" \
      || fail "test1: submodule_needs_init should detect uninitialized submodule under lib"

    ensure_submodule_init "lib"

    [[ -f "lib/dep/dep.txt" ]] \
      || fail "test1: ensure_submodule_init should populate lib/dep/dep.txt after init"

    if submodule_needs_init "lib"; then
      fail "test1: submodule_needs_init should return false after initialization"
    fi
  )
  rm -rf "$main_repo" "$sub_remote"
  echo "PASS test1: uninitialized submodule detected and initialized"
}

# --------------------------------------------------------------------------
# Test 2: 既に初期化済みなら no-op（idempotent）。再実行してもエラーに
# ならず、ファイルはそのまま存在する。
# --------------------------------------------------------------------------
test2_already_initialized_is_noop() {
  local repos main_repo sub_remote
  repos="$(make_repo_with_submodule)"
  main_repo="$(sed -n '1p' <<< "$repos")"
  sub_remote="$(sed -n '2p' <<< "$repos")"

  (
    cd "$main_repo"
    export GIT_ALLOW_PROTOCOL="file"
    # submodule add 直後は初期化済み状態。
    [[ -f "lib/dep/dep.txt" ]] || fail "test2: precondition: submodule should already be initialized"

    if submodule_needs_init "lib"; then
      fail "test2: submodule_needs_init should return false when already initialized"
    fi

    # ensure_submodule_init を再実行してもエラーにならず、内容も変わらない。
    ensure_submodule_init "lib"
    [[ -f "lib/dep/dep.txt" ]] || fail "test2: dep.txt should remain present after no-op re-run"
  )
  rm -rf "$main_repo" "$sub_remote"
  echo "PASS test2: already-initialized submodule is a no-op"
}

# --------------------------------------------------------------------------
# Test 3 (安全性): git repo でない path でも安全に no-op すること
# （別リポジトリでの流用等を想定）。
# --------------------------------------------------------------------------
test3_non_git_dir_is_safe_noop() {
  local tmp
  tmp="$(mktemp -d)"

  (
    cd "$tmp"
    if submodule_needs_init "lib"; then
      fail "test3: submodule_needs_init should return false outside a git repo"
    fi

    ensure_submodule_init "lib" \
      || fail "test3: ensure_submodule_init must not error outside a git repo"
  )
  rm -rf "$tmp"
  echo "PASS test3: non-git directory is a safe no-op"
}

# --------------------------------------------------------------------------
# Test 4 (安全性): submodule 定義自体が存在しない path でも安全に no-op する。
# --------------------------------------------------------------------------
test4_no_submodule_defined_is_safe_noop() {
  local tmp
  tmp="$(mktemp -d)"

  (
    cd "$tmp"
    init_git_repo
    printf 'x\n' > x.txt
    git add x.txt
    git commit -q -m "init"

    if submodule_needs_init "no-such-path"; then
      fail "test4: submodule_needs_init should return false when no submodule is defined"
    fi

    ensure_submodule_init "no-such-path" \
      || fail "test4: ensure_submodule_init must not error when no submodule is defined"
  )
  rm -rf "$tmp"
  echo "PASS test4: path with no submodule defined is a safe no-op"
}

test1_uninitialized_detected_and_initialized
test2_already_initialized_is_noop
test3_non_git_dir_is_safe_noop
test4_no_submodule_defined_is_safe_noop

echo "ALL PASS"
