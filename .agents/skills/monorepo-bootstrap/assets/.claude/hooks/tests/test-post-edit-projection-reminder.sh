#!/usr/bin/env bash
set -euo pipefail

# post-edit-projection-reminder.sh（opt-in:public-site）の hermetic テスト。
# bash / jq のみで動く（git 不要）。stdin に PostToolUse の JSON を渡し、出力の JSON を jq で検証する。
# 対象ドキュメントなどの設定値は hook 冒頭の定義（TARGET_DOCS / PROJECTION_DOC / SYNC_SKILL）から
# 読み取るため、採用 repo が設定を変更してもテストはその値に追随する。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../post-edit-projection-reminder.sh"

if [[ ! -f "$HOOK" ]]; then
  echo "FAIL: hook not found: $HOOK" >&2
  exit 1
fi

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# hook 冒頭の設定値を取り込む（1 行の代入のみを対象にする）。
eval "$(grep -E '^(TARGET_DOCS|PROJECTION_DOC|SYNC_SKILL)=' "$HOOK")"
[[ "${#TARGET_DOCS[@]}" -gt 0 && -n "${PROJECTION_DOC:-}" && -n "${SYNC_SKILL:-}" ]] \
  || fail "could not read TARGET_DOCS / PROJECTION_DOC / SYNC_SKILL from the hook (keep each definition on one line)"
TARGET="${TARGET_DOCS[0]}"

# stdin に tool_input（キーは $1、値は $2）を渡して hook を実行する。
run_hook_with() {
  local key="$1" value="$2"
  jq -n --arg k "$key" --arg v "$value" '{tool_input: {($k): $v}}' | bash "$HOOK"
}

ctx_of() {
  printf '%s' "$1" | jq -r '.hookSpecificOutput.additionalContext // empty'
}

# --------------------------------------------------------------------------
# Test 1: 射影元ドキュメント（相対パス）の編集で、リマインドが additionalContext に入る。
# 内容: 編集した射影元、射影先、追従に使う skill 名。PostToolUse 用のイベント名で出力する。
# --------------------------------------------------------------------------
test1_relative_path_reminds() {
  local out ctx event
  out="$(run_hook_with file_path "$TARGET")"
  event="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName // empty')"
  [[ "$event" == "PostToolUse" ]] || fail "test1: hookEventName should be PostToolUse (out=$out)"
  ctx="$(ctx_of "$out")"
  [[ -n "$ctx" ]] || fail "test1: editing a source doc must inject a reminder (out=$out)"
  printf '%s' "$ctx" | grep -qF "$TARGET" || fail "test1: reminder should name the edited source doc (ctx=$ctx)"
  printf '%s' "$ctx" | grep -qF "$PROJECTION_DOC" || fail "test1: reminder should name the projection doc (ctx=$ctx)"
  printf '%s' "$ctx" | grep -qF "$SYNC_SKILL" || fail "test1: reminder should name the sync skill (ctx=$ctx)"
  echo "PASS test1: relative path edit injects the reminder"
}

# --------------------------------------------------------------------------
# Test 2: 絶対パスでも末尾一致で判定する（PostToolUse の file_path は絶対パスで渡される）。
# --------------------------------------------------------------------------
test2_absolute_path_reminds() {
  local out
  out="$(run_hook_with file_path "/abs/path/repo/$TARGET")"
  [[ -n "$(ctx_of "$out")" ]] || fail "test2: absolute path of a source doc must inject a reminder (out=$out)"
  echo "PASS test2: absolute path edit injects the reminder"
}

# --------------------------------------------------------------------------
# Test 3: file_path が無く path に入っている入力も扱う（.tool_input.path へのフォールバック）。
# --------------------------------------------------------------------------
test3_path_key_fallback() {
  local out
  out="$(run_hook_with path "$TARGET")"
  [[ -n "$(ctx_of "$out")" ]] || fail "test3: tool_input.path must be accepted (out=$out)"
  echo "PASS test3: tool_input.path fallback injects the reminder"
}

# --------------------------------------------------------------------------
# Test 4: 対象外のファイルは無出力で通過する（他の PostToolUse hook を妨げない）。
# 射影先そのもの、射影元に似た名前（接尾辞違い・別ディレクトリ）、無関係なソースを含める。
# --------------------------------------------------------------------------
test4_non_target_passes_silently() {
  local out file files
  files=("$PROJECTION_DOC" "${TARGET}.bak" "docs/product/OVERVIEW.md" "apps/app/src/index.ts")
  # 別ディレクトリの同名ファイル。射影元がディレクトリ付きのパスのときだけ「末尾一致しない」ことを確かめられる。
  if [[ "$TARGET" == */* ]]; then
    files+=("notes/$(basename "$TARGET")")
  fi
  for file in "${files[@]}"; do
    out="$(run_hook_with file_path "$file")"
    [[ -z "$out" ]] || fail "test4: non-target file must pass with no output (file=$file, out=$out)"
  done
  echo "PASS test4: non-target files pass with no output"
}

# --------------------------------------------------------------------------
# Test 5: file_path 抽出不可の入力（キー欠落・空文字・空オブジェクト）は無出力で exit 0 する。
# --------------------------------------------------------------------------
test5_missing_path_passes_silently() {
  local out
  out="$(printf '%s' '{}' | bash "$HOOK")"
  [[ -z "$out" ]] || fail "test5: empty object must pass with no output (out=$out)"
  out="$(printf '%s' '{"tool_input":{}}' | bash "$HOOK")"
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

echo "ALL PASS"
