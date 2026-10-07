#!/usr/bin/env bash
set -euo pipefail

# PreToolUse Hook: git commit 前に、hook 開始時点で staged 済みのファイルのみを
# formatter (既定: prettier) で整形し、それらのファイルのみを再 stage してから
# コミットする。別ファイルの unstaged 変更は混入しない。同一ファイル内に未 stage の
# hunk が残る部分 staging はファイル単位の git add で安全に保持できないため deny する。
#
# commit する作業ツリーは、入力の cwd と、command 内の `cd <dir>` / `git -C <dir> commit` から
# ../bin/hook-utils.sh の resolve_git_target で決める。決められない形（変数を含む cd 先など）は
# 整形せずに通す（整形は補助で、format:check が pre-push と CI で検証される）。
# 対象は、commit が cd 以外のコマンドより前に実行される command だけである。

# 共通ユーティリティ読み込み（compact_output で deny 理由を切り詰める）。
# mise の準備（setup_toolchain）より前に読み込む。
hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_UTILS="$hook_dir/../bin/hook-utils.sh"
export HOOK_LOG_PREFIX="pre-format-check"
# shellcheck source=../bin/hook-utils.sh
source "$HOOK_UTILS"

# stdin（hook JSON）を先に退避（formatter が消費する前に）
input="$(cat)"

# commit を含まない入力は即通過する（`Bash(git -C *)` で起動された `git -C <dir> status` 等）。
[[ "$input" == *commit* ]] || exit 0

# jq 自体も mise の shim で解決され得るため、入力の解析より前に行う。
# commit は worktree セッションの最初期に起きうるため、ここで .mise.toml を trust しておかないと、
# pre-push 側より先にこの hook が壊れた pnpm 解決に当たりやすい。
setup_toolchain

read_bash_input "$input"

# commit 先の作業ツリーを決める。git commit を含まない command は通過する（if フィルタの保険）。
# commit より前に cd 以外のコマンド（git add など）が走る command も通過する。hook 時点の
# staged 状態が commit の内容と一致せず、整形対象も部分 staging の判定も当てにならないため。
resolve_git_target commit "$HOOK_CMD" "$HOOK_BASE_DIR"
[ "$GIT_TARGET_PRECEDED" -eq 0 ] || exit 0
if [ -n "$GIT_TARGET_UNRESOLVED" ]; then
  emit_hook_context PreToolUse "pre-format-check skipped (commit target worktree could not be resolved: ${GIT_TARGET_UNRESOLVED}; CI will still validate format)"
  exit 0
fi
commit_root="$GIT_TARGET_ROOT"
[ -n "$commit_root" ] || exit 0

# 以降の処理はすべて commit 先の作業ツリーのルートで行う。
if [ "$(pwd -P)" != "$commit_root" ]; then
  builtin cd "$commit_root"
  setup_toolchain
fi

# hook 開始時点で staged 済みのファイルを NUL 区切りで取得する（bash 3.2 互換: mapfile 不可）。
staged_files=()
while IFS= read -r -d '' f; do
  staged_files+=("$f")
done < <(git diff --cached --name-only --diff-filter=ACMR -z)

# staged 0 件なら整形対象が無い。set -u 下で空配列を展開する前に通過する。
if [[ "${#staged_files[@]}" -eq 0 ]]; then
  exit 0
fi

# 整形コマンドの注入 seam: PROJ_PRETTIER_CMD が設定されていればそれを使う（テスト用 stub 注入）。
# 未設定なら本番デフォルトの pnpm exec prettier を使う。
# formatter を prettier 以外に差し替える場合はこの既定分岐を変更する。
if [[ -n "${PROJ_PRETTIER_CMD:-}" ]]; then
  formatter=("${PROJ_PRETTIER_CMD}")
else
  # pnpm が解決できない（worktree 未 install 等）場合は整形を skip して通過する。
  # commit を妨げず、format:check は CI / pre-push 側で検証される（fail-open）。
  if ! command -v pnpm >/dev/null 2>&1; then
    emit_hook_context PreToolUse "pre-format-check skipped (pnpm not on PATH; CI will still validate format)"
    exit 0
  fi
  formatter=(pnpm exec prettier)
fi

# 部分 staging の検出: staged 対象ファイルに worktree 差分（未 stage の hunk）が残っている場合、
# 後段でファイル単位に git add し直すと、その未 stage hunk まで commit に混入してしまう。
# ファイル単位では安全に保持できないため deny する（整形で worktree が変わる前に判定する）。
# graceful skip 経路（formatter 不在）はここに到達せず、再 stage もしないため commit は安全。
partial_staged=()
for f in "${staged_files[@]}"; do
  if ! git diff --quiet -- "$f"; then
    partial_staged+=("$f")
  fi
done
if [[ "${#partial_staged[@]}" -gt 0 ]]; then
  partial_list=""
  for f in "${partial_staged[@]}"; do
    partial_list+=" $(printf '%q' "$f")"
  done
  emit_hook_deny "pre-format-check: partially staged files cannot be safely auto-formatted (re-running file-level git add would also stage their unstaged hunks):${partial_list}. Stage the full file or commit these hunks separately, then retry."
  exit 0
fi

# staged files のみを整形する。--ignore-unknown は未対応拡張子の parser 推論エラーを抑止する
# （付けないと No parser could be inferred で非 0 終了する）。.prettierignore は explicit path でも尊重される。
#
# formatter が非 0 終了なら理由を問わず deny する（エラー出力の書式では判定しない。
# 書式判定にすると、壊れた shim の "command not found" 等が無言で素通りする）。
if ! format_output="$("${formatter[@]}" --write --ignore-unknown -- "${staged_files[@]}" 2>&1)"; then
  compacted="$(compact_output "prettier" "$format_output" 200)"
  emit_hook_deny "prettier failed to format staged files — commit blocked to avoid committing unformatted content. Run \`pnpm install\` / verify \`pnpm exec prettier --version\` resolves correctly, or check the prettier config, then retry."$'\n\n'"$compacted"
  exit 0
fi

# 整形した staged files のみを再 stage するようコマンドを書き換える。
# 各ファイルは printf '%q' で安全に shell 引用する（スペース・特殊文字対応）。git add -u は使わない。
# staged files のパスはルート基準なので、Bash の cwd が commit 先のルートそのものの command は
# そのまま git add を前置する。cd / -C を経る command やサブディレクトリが cwd の command は、
# ルートを -C で明示する。
base_phys="$(builtin cd -P "$HOOK_BASE_DIR" 2>/dev/null && pwd -P)" || base_phys=""
if [[ "$base_phys" == "$commit_root" ]]; then
  add_cmd="git add --"
else
  add_cmd="git -C $(printf '%q' "$commit_root") add --"
fi
add_args=""
for f in "${staged_files[@]}"; do
  add_args+=" $(printf '%q' "$f")"
done
new_cmd="${add_cmd}${add_args} && ${HOOK_CMD}"

jq -n --arg cmd "$new_cmd" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    updatedInput: { command: $cmd },
    additionalContext: "prettier formatted staged files before commit"
  }
}'
