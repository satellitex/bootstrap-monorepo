#!/usr/bin/env bash
set -euo pipefail

# PreToolUse Hook (opt-in:submodule): git commit 前に、staged 変更に監視対象パス配下の
# submodule pointer（gitlink, mode 160000）変更が含まれていないか検査する。
#
# 背景: worktree / 新規 clone で submodule 未初期化のまま `git add -A` すると、
# ビルドツールが pin ではなく default branch tip を clone した状態の submodule
# pointer をそのまま commit してしまう事故がある。session-start hook 側の
# 自動初期化（.claude/bin/submodule-guard.sh）が第一防御、本 hook が誤コミットに
# 対する二重防御となる。
#
# 意図的な pin 更新は妨げない:
# - 依存更新 bot は CI/bot 経路（PR 作成）でローカル PreToolUse hook を通らないため無関係
# - 人間が意図して submodule を更新する場合は PROJ_ALLOW_SUBMODULE_PIN_UPDATE=1
#   で override できる

# 監視対象の submodule 親パス。採用 repo の実際の submodule 親パスに変更する。
# PROJ_SUBMODULE_WATCH_PATH はテスト用の上書き seam。
WATCH_PATH="${PROJ_SUBMODULE_WATCH_PATH:-vendor}"

# stdin（hook JSON）を先に退避
input="$(cat)"

# 防御ガード: git commit 以外のコマンドなら即通過（if フィルタの保険）
cmd="$(jq -r '.tool_input.command // ""' <<< "$input")"
if [[ "$cmd" != git\ commit* ]]; then
  exit 0
fi

# 意図的な pin 更新の override。
if [[ "${PROJ_ALLOW_SUBMODULE_PIN_UPDATE:-}" == "1" ]]; then
  jq -n --arg path "$WATCH_PATH" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: ("pre-commit-submodule-guard: PROJ_ALLOW_SUBMODULE_PIN_UPDATE=1 のため " + $path + " の submodule pointer 変更チェックをスキップしました")
    }
  }'
  exit 0
fi

# staged 変更に監視対象パス配下の gitlink (mode 160000) 変更が含まれるか検査する。
# raw diff の形式: ":<old_mode> <new_mode> <old_sha> <new_sha> <status>\t<path>"
# 新規追加 submodule は old_mode=000000 / 既存 pointer の更新は old_mode=new_mode=160000。
# いずれかの mode が 160000 なら submodule pointer 変更とみなす。
gitlink_paths="$(
  git diff --cached --raw -- "$WATCH_PATH" 2>/dev/null \
    | awk -F'\t' '{ split($1, f, " "); if (f[1] == ":160000" || f[2] == "160000") print $2 }'
)"

if [[ -z "$gitlink_paths" ]]; then
  exit 0
fi

path_list=" ${gitlink_paths//$'\n'/ }"

reason="${WATCH_PATH} 配下の submodule pointer (gitlink) 変更が commit に含まれています:${path_list}
worktree / 新規 clone で submodule 未初期化のまま build すると、ビルドツールが pin ではなく
default branch tip を clone し pointer が drift することがあります。
意図しない drift の場合の復旧:
  git restore --staged ${WATCH_PATH} && git submodule update --init --recursive --force ${WATCH_PATH}
意図的な pin 更新（人間の判断による）の場合は、PROJ_ALLOW_SUBMODULE_PIN_UPDATE=1 を設定して再実行してください。"

jq -n --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
