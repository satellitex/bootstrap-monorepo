#!/usr/bin/env bash
set -euo pipefail

# post-edit-projection-reminder.sh（opt-in:public-site）の hermetic テスト。
# bash / git / jq のみで動く。stdin に PostToolUse の JSON を渡し、出力の JSON を jq で検証する。
# 対象ドキュメントなどの設定値は PROJ_PROJECTION_* の環境変数（seam）で渡すため、採用 repo が
# hook 冒頭の既定値を変更してもテストは変わらない。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../post-edit-projection-reminder.sh"

# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
require_hook

# seam に渡す設定値。射影元は 2 つ（":" 区切り）にして、複数指定も検証する。
TARGET="docs/internal/design.md"
TARGET_B="docs/internal/flows.md"
export PROJ_PROJECTION_TARGET_DOCS="$TARGET:$TARGET_B"
export PROJ_PROJECTION_DOC="docs/public/design.md"
export PROJ_PROJECTION_SYNC_SKILL="/sync-public"
export PROJ_PROJECTION_RULES=".claude/skills/sync-public/rules.md"

# 作業ツリー。絶対パスの判定は、ファイルが属する作業ツリーのルート基準で行う。
REPO="$(make_repo)"
mkdir -p "$REPO/docs/internal" "$REPO/docs/public"

# stdin に tool_input（キーは $1、値は $2）を渡し、作業ツリーの中で hook を実行する。
run_hook_with() {
  local key="$1" value="$2"
  (
    cd "$REPO"
    jq -n --arg k "$key" --arg v "$value" '{tool_input: {($k): $v}}' | bash "$HOOK"
  )
}

# --------------------------------------------------------------------------
# Test 1: 射影元ドキュメント（相対パス）の編集で、リマインドが additionalContext に入る。
# 内容: 編集した射影元、射影先、追従に使う skill 名、射影ルール。PostToolUse 用のイベント名で出力する。
# --------------------------------------------------------------------------
test1_relative_path_reminds() {
  local out ctx event
  out="$(run_hook_with file_path "$TARGET")"
  event="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName // empty')"
  [[ "$event" == "PostToolUse" ]] || fail "test1: hookEventName should be PostToolUse (out=$out)"
  ctx="$(hook_ctx "$out")"
  [[ -n "$ctx" ]] || fail "test1: editing a source doc must inject a reminder (out=$out)"
  grep -qF "$TARGET" <<< "$ctx" || fail "test1: reminder should name the edited source doc (ctx=$ctx)"
  grep -qF "$PROJ_PROJECTION_DOC" <<< "$ctx" || fail "test1: reminder should name the projection doc (ctx=$ctx)"
  grep -qF "$PROJ_PROJECTION_SYNC_SKILL" <<< "$ctx" || fail "test1: reminder should name the sync skill (ctx=$ctx)"
  grep -qF "$PROJ_PROJECTION_RULES" <<< "$ctx" || fail "test1: reminder should name the projection rules (ctx=$ctx)"
  echo "PASS test1: relative path edit injects the reminder"
}

# --------------------------------------------------------------------------
# Test 2: 絶対パスでも作業ツリーのルート基準で判定する（PostToolUse の file_path は絶対パスで渡される）。
# 2 つ目の射影元も対象になる。
# --------------------------------------------------------------------------
test2_absolute_path_reminds() {
  local out
  out="$(run_hook_with file_path "$REPO/$TARGET")"
  [[ -n "$(hook_ctx "$out")" ]] || fail "test2: absolute path of a source doc must inject a reminder (out=$out)"
  out="$(run_hook_with file_path "$REPO/$TARGET_B")"
  [[ -n "$(hook_ctx "$out")" ]] || fail "test2: every configured source doc must inject a reminder (out=$out)"
  echo "PASS test2: absolute path edit injects the reminder"
}

# --------------------------------------------------------------------------
# Test 3: file_path が無く path に入っている入力も扱う（.tool_input.path へのフォールバック）。
# --------------------------------------------------------------------------
test3_path_key_fallback() {
  local out
  out="$(run_hook_with path "$TARGET")"
  [[ -n "$(hook_ctx "$out")" ]] || fail "test3: tool_input.path must be accepted (out=$out)"
  echo "PASS test3: tool_input.path fallback injects the reminder"
}

# --------------------------------------------------------------------------
# Test 4: 対象外のファイルは無出力で通過する（他の PostToolUse hook を妨げない）。
# 射影先そのもの、射影元に似た名前（接尾辞違い・別ディレクトリ・祖先ディレクトリ違い）、
# 作業ツリー外の同名ファイル、無関係なソースを含める。
# --------------------------------------------------------------------------
test4_non_target_passes_silently() {
  local out file other
  other="$(mktemp -d)"
  mkdir -p "$other/docs/internal"
  for file in "$PROJ_PROJECTION_DOC" "${TARGET}.bak" "docs/internal/other.md" "notes/design.md" \
    "notes/$TARGET" "$REPO/notes/$TARGET" "$other/$TARGET" "apps/app/src/index.ts"; do
    out="$(run_hook_with file_path "$file")"
    [[ -z "$out" ]] || fail "test4: non-target file must pass with no output (file=$file, out=$out)"
  done
  rm -rf "$other"
  echo "PASS test4: non-target files pass with no output"
}

# --------------------------------------------------------------------------
# Test 5: file_path 抽出不可の入力（キー欠落・空文字・空オブジェクト）は無出力で exit 0 する。
# --------------------------------------------------------------------------
test5_missing_path_passes_silently() {
  local out
  out="$(cd "$REPO" && printf '%s' '{}' | bash "$HOOK")"
  [[ -z "$out" ]] || fail "test5: empty object must pass with no output (out=$out)"
  out="$(cd "$REPO" && printf '%s' '{"tool_input":{}}' | bash "$HOOK")"
  [[ -z "$out" ]] || fail "test5: missing file_path must pass with no output (out=$out)"
  out="$(run_hook_with file_path "")"
  [[ -z "$out" ]] || fail "test5: empty file_path must pass with no output (out=$out)"
  echo "PASS test5: missing file_path passes with no output"
}

test1_relative_path_reminds
test2_absolute_path_reminds
test3_path_key_fallback
test4_non_target_passes_silently
test5_missing_path_passes_silently

rm -rf "$REPO"
echo "ALL PASS"
