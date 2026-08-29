#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# SessionStart hook
# ------------------------------------------------------------------------------
# Claude Code のリモート実行環境では mise やその配下のツールチェーンが
# pre-installed されない。本フックは
#   1. mise を $HOME/.local/bin に install (idempotent)
#   2. .mise.toml に列挙された全 tool (node / pnpm / jq / gitleaks / ...) を install
#   3. $CLAUDE_ENV_FILE に PATH と mise activate を書き出してセッション全体で
#      pnpm / node / mise を解決可能にする
#   4. pnpm install で workspace 依存をセットアップ (pre-push CI check 等が
#      node_modules を要求するため)
# を行う。ローカル env では何もしない (CLAUDE_CODE_REMOTE が未設定なら exit 0)。
# ==============================================================================

repo_root="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# --- opt-in: submodule 採用時に有効化 -----------------------------------------
# git worktree add は submodule を初期化しない。未初期化のまま build が走ると、
# 依存の実体が無い・pin と異なる内容が取得される等の事故につながる。submodule を
# 採用する場合は以下のコメントアウトを外し、"vendor" を実際の submodule 親パスに
# 変更する（ローカル/リモート問わず、下の早期 return より前に常に実行する）。
# ensure_submodule_init は idempotent（初期化済みなら status 確認のみで no-op）。
# ブロック全体を subshell + `|| true` で非致命化する（repo_root 不在・guard
# スクリプト不在等の斜め構成でも `set -e` がセッション開始をブロックせず、cwd も
# 汚さない）。
#
# hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# guard_lib="$hook_dir/../bin/submodule-guard.sh"
# if [ -d "$repo_root" ] && [ -f "$guard_lib" ]; then
#   (
#     cd "$repo_root"
#     # shellcheck source=../bin/submodule-guard.sh
#     source "$guard_lib"
#     ensure_submodule_init "vendor"
#   ) || true
# fi
# ------------------------------------------------------------------------------

# ローカル env では以降（mise / pnpm install）を skip。CLAUDE_CODE_REMOTE は
# Claude Code のリモート実行環境側で "true" が設定される。
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$repo_root"

mise_bin="$HOME/.local/bin/mise"
export PATH="$HOME/.local/bin:$PATH"

# 1. mise install (idempotent)
if ! command -v mise >/dev/null 2>&1; then
  curl -fsSL https://mise.run | sh
fi

# 2. .mise.toml を信頼 + 全 tool を install (mise 自身が idempotent)
"$mise_bin" trust --quiet "$repo_root" || true
"$mise_bin" install

# 3. セッション PATH に mise shims を追加し、mise activate を仕込む
#    （以降の Bash tool 呼び出しで pnpm / node / jq が解決される）
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo 'export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"'
    echo 'eval "$($HOME/.local/bin/mise activate bash 2>/dev/null)" || true'
  } >> "$CLAUDE_ENV_FILE"
fi

# 4. workspace 依存をセットアップ (pre-push CI hook が node_modules を要求)
#    pnpm は mise install で導入済み。--frozen-lockfile で lock とのズレを検出。
export PATH="$HOME/.local/share/mise/shims:$PATH"
pnpm install --frozen-lockfile

echo "session-start hook done: mise / pnpm ready"
