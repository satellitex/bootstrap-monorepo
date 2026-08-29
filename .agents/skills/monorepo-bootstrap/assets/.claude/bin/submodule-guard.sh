#!/usr/bin/env bash
# submodule-guard.sh (opt-in:submodule) — submodule 初期化・検出ユーティリティ
#
# SessionStart hook（session-start.sh の opt-in 区画）がローカル env の早期 return
# より前に source して呼び出す。git submodule status の出力から未初期化 submodule を
# 検出し、未初期化のときだけ `git submodule update --init --recursive` を
# 実行する（初期化済みなら status 確認のみで no-op、数十 ms で完了）。
#
# 背景: worktree / 新規 clone で submodule が未初期化のまま build が走ると、
# ビルドツールが pin ではなく default branch の tip を clone し、submodule
# pointer が drift することがある。
#
# 各 hook の先頭付近で以下のように source する:
#
#   SUBMODULE_GUARD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/submodule-guard.sh"
#   # shellcheck source=../bin/submodule-guard.sh
#   source "$SUBMODULE_GUARD"
#
# 提供する関数:
#   submodule_needs_init PATH  — 指定 path 配下に未初期化 submodule があれば true (exit 0)
#   ensure_submodule_init PATH — 未初期化のときだけ idempotent に init する

# submodule_needs_init: 指定 path 配下に未初期化の submodule があれば 0 (true) を返す。
# git repo でない / path が存在しない / submodule 定義が無い等の場合も
# 安全に 1 (false/no-op) を返す（呼び出し元をブロックしない）。
#
# 引数:
#   $1 - submodule 親 path（例: vendor）
# 戻り値:
#   0 - 未初期化 submodule が存在する
#   1 - 存在しない、または判定できない（安全側 no-op）
submodule_needs_init() {
  local path="$1"
  local status_output

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 1
  fi
  if [ ! -d "$path" ]; then
    return 1
  fi

  status_output="$(git submodule status -- "$path" 2>/dev/null)" || return 1
  if [ -z "$status_output" ]; then
    return 1
  fi

  # git submodule status の行頭記号: '-' = 未初期化、'+' = 差分あり、'U' = 衝突、' ' = 同期済み。
  # 未初期化行が 1 つでもあれば init が必要と判定する。
  if printf '%s\n' "$status_output" | grep -q '^-'; then
    return 0
  fi
  return 1
}

# ensure_submodule_init: 未初期化のときだけ init を実行する（idempotent）。
# 初期化済みの場合は submodule_needs_init の判定のみで即 return するため、
# セッション開始を有意に遅延させない。
# 失敗してもこの関数自体は非致命的に振る舞う（呼び出し元でも `|| true` を推奨）。
#
# 引数:
#   $1 - submodule 親 path（例: vendor）
ensure_submodule_init() {
  local path="$1"

  if ! submodule_needs_init "$path"; then
    return 0
  fi

  echo "submodule-guard: initializing uninitialized submodule(s) under $path ..."
  git submodule update --init --recursive -- "$path" || {
    echo "submodule-guard: WARNING: submodule init failed for $path (continuing; see 'git submodule update --init --recursive --force $path' to retry manually)" >&2
    return 0
  }
}
