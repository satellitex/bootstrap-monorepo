#!/usr/bin/env bash
set -euo pipefail

# PostToolUse Hook: ファイル編集後に静的チェックを実行し、
# 失敗時のみ上限付きの diagnostics を additionalContext として注入する。
#
# TypeScript/JavaScript: eslint + typecheck (tsc --noEmit) + test (pnpm test)
#
# 各チェックはスクリプト内タイムアウト付きで実行する（既定秒数は timeout_* の定義箇所を参照）。
#
# 入力の file_path は絶対パス・相対パスのどちらでもよい。作業ツリーのルートは hook の cwd
# ではなく入力ファイル側から決め、以降の検査はそのルートを cwd にして行う。ルート外のファイルは
# 検査せず通過する（解決の規則は ../bin/hook-utils.sh の locate_repo_path）。

## --- 共通ユーティリティ読み込み ---
HOOK_UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/hook-utils.sh"
export HOOK_LOG_PREFIX="post-edit"
# shellcheck source=../bin/hook-utils.sh
source "$HOOK_UTILS"

## --- メインスクリプト ---

# 各チェックが呼ぶ外部コマンドの注入 seam: PROJ_*_CMD が設定されていればそれを使う
# （テスト用 stub 注入）。未設定なら本番デフォルトを使う。
# setup_toolchain が mise shims / /opt/homebrew/bin を PATH 先頭へ足すため、PATH 前置の stub は
# 実コマンドに shadow され得る。環境変数での明示注入だけが実コマンド非依存を保証する。
eslint_cmd=(npx eslint)
tsc_cmd=(npx tsc)
[[ -z "${PROJ_ESLINT_CMD:-}" ]] || eslint_cmd=("$PROJ_ESLINT_CMD")
[[ -z "${PROJ_TSC_CMD:-}" ]] || tsc_cmd=("$PROJ_TSC_CMD")
pnpm_bin="${PROJ_PNPM_CMD:-pnpm}"

# 各チェックのタイムアウト秒。PROJ_POST_EDIT_TIMEOUT_SEC はテスト専用の一括上書き seam で、
# 未設定時は既定値（eslint 30 / typecheck 30 / test 60）を使う。
timeout_eslint="${PROJ_POST_EDIT_TIMEOUT_SEC:-30}"
timeout_typecheck="${PROJ_POST_EDIT_TIMEOUT_SEC:-30}"
timeout_test="${PROJ_POST_EDIT_TIMEOUT_SEC:-60}"

# jq 自体も mise の shim で解決され得るため、入力の解析より前に PATH だけ通す。
setup_toolchain_path
input="$(cat)"
file_raw="$(jq -r '.tool_input.file_path // .tool_input.path // empty' <<< "$input")"

# 対象拡張子でなければ、mise の準備や作業ツリーの解決より前に通過する（編集のたびに走るため）。
# 既定スタック外の言語を採用する場合は、この case に拡張子を足し、下の検査を言語別に分ける。
case "$file_raw" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *) exit 0 ;;
esac

setup_toolchain

# 入力ファイルが属する作業ツリーのルートと、ルート基準の相対パスを決める。
# 絶対パスのままだと、パッケージ判定（apps/<name> / packages/<name>）が一致せず
# typecheck と package 単位の test が無言で skip される。
locate_repo_path "$file_raw"
file="$REPO_PATH_REL"
if [ -z "$file" ]; then
  exit 0
fi
# hook の cwd と作業ツリーが一致しない起動（別 worktree からの起動など）でも、
# 編集したファイルの作業ツリーで検査する（`cd` が mise の chpwd 関数に差し替えられても
# 影響を受けないよう builtin を使う）。
if [ "$(pwd -P)" != "$REPO_PATH_ROOT" ]; then
  builtin cd "$REPO_PATH_ROOT"
fi

diag=""
tc_out=""
test_out=""

lint_out="$(run_limited_check "$timeout_eslint" "eslint" 80 "${eslint_cmd[@]}" --no-warn-ignored "$file")" || true

# typecheck と test はパッケージ単位。tsconfig.json と package.json は、属するパッケージの
# ディレクトリ（ルート基準）を直接見る。
pkg_dir="$(_pkg_dir_of_rel "$file")"
if [ -n "$pkg_dir" ]; then
  if [ -f "$pkg_dir/tsconfig.json" ]; then
    tc_out="$(run_limited_check "$timeout_typecheck" "typecheck" 100 "${tsc_cmd[@]}" --noEmit -p "$pkg_dir/tsconfig.json")" || true
  fi
  if [ -f "$pkg_dir/package.json" ]; then
    # name と scripts.test は 1 回の jq で読む（1 行目が name、2 行目が scripts.test）。
    pkg_name=""
    pkg_test=""
    { IFS= read -r pkg_name; IFS= read -r pkg_test; } \
      < <(jq -r '(.name // ""), (.scripts.test // "")' "$pkg_dir/package.json" 2>/dev/null) || true
    if [ -n "$pkg_name" ] && [ -n "$pkg_test" ]; then
      test_out="$(run_limited_check "$timeout_test" "test" 100 "$pnpm_bin" --filter "$pkg_name" test)" || true
    fi
  fi
fi

# 出力を結合
if [ -n "$lint_out" ]; then
  diag="${diag}[eslint]
${lint_out}
"
fi
if [ -n "$tc_out" ]; then
  diag="${diag}[typecheck]
${tc_out}
"
fi
if [ -n "$test_out" ]; then
  diag="${diag}[test]
${test_out}
"
fi

# --- 言語別チェックの追加例 -----------------------------------------------------
# 既定スタック外の言語を採用する場合は、上の拡張子 case に拡張子を足し、上の TS / JS の検査を
# `case "$file" in *.ts|*.tsx|*.js|*.jsx) ... ;;` の分岐に包んで、その隣に分岐を足す。
# コンパイル/lint 相当の高速チェックを run_limited_check（タイムアウト付き・失敗時のみ出力）で
# 包み、実行コマンドは PROJ_*_CMD の注入 seam を用意する。
#   *.<ext>)
#     diag="$(run_limited_check 60 "<additional-language-check>" 100 <command> "$file")" || true
#     ;;
# 追加した分岐は tests/test-post-edit-check.sh にケースを追加してから配線する。
# -------------------------------------------------------------------------------

# 失敗がある場合のみ additionalContext として注入
if [ -n "$diag" ]; then
  emit_hook_context PostToolUse "$diag"
fi
