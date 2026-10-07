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
#
# commit する作業ツリーは、入力の cwd と、command 内の `cd <dir>` / `git -C <dir> commit` から
# ../bin/hook-utils.sh の resolve_git_target で決める。決められない形は検査できないため deny する。
# 対象は、commit が cd 以外のコマンドより前に実行される command だけである。

# 監視対象の submodule 親パス。採用 repo の実際の submodule 親パスに変更する。
# PROJ_SUBMODULE_WATCH_PATH はテスト用の上書き seam。
WATCH_PATH="${PROJ_SUBMODULE_WATCH_PATH:-vendor}"

hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../bin/hook-utils.sh
source "$hook_dir/../bin/hook-utils.sh"

# stdin（hook JSON）を先に退避
input="$(cat)"

# commit を含まない入力は即通過する（`Bash(git -C *)` で起動された `git -C <dir> status` 等）。
[[ "$input" == *commit* ]] || exit 0

read_bash_input "$input"

# commit 先の作業ツリーを決める。git commit を含まない command は通過する（if フィルタの保険）。
# commit より前に cd 以外のコマンド（git add など）が走る command も通過する。hook 時点の
# staged 状態が commit の内容と一致せず、検査が当てにならないため。
resolve_git_target commit "$HOOK_CMD" "$HOOK_BASE_DIR"
[ "$GIT_TARGET_PRECEDED" -eq 0 ] || exit 0
[ -n "${GIT_TARGET_ROOT}${GIT_TARGET_UNRESOLVED}" ] || exit 0

# 意図的な pin 更新の override。
if [[ "${PROJ_ALLOW_SUBMODULE_PIN_UPDATE:-}" == "1" ]]; then
  emit_hook_context PreToolUse "pre-commit-submodule-guard: PROJ_ALLOW_SUBMODULE_PIN_UPDATE=1 のため ${WATCH_PATH} の submodule pointer 変更チェックをスキップしました"
  exit 0
fi

if [ -n "$GIT_TARGET_UNRESOLVED" ]; then
  emit_hook_deny "pre-commit-submodule-guard: commit 先の作業ツリーを静的に特定できないため commit を中止しました（${GIT_TARGET_UNRESOLVED}）。cd / git -C の引数に変数・コマンド置換・~・glob を使わず、対象の作業ツリーの中で \`git commit\` を単独で実行してください。"
  exit 0
fi

# 以降の検査は commit 先の作業ツリーのルートで行う。
cd "$GIT_TARGET_ROOT"

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

emit_hook_deny "$reason"
