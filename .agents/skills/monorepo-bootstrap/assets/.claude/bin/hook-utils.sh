#!/usr/bin/env bash
# hook-utils.sh — hooks 共通ユーティリティ
#
# 各 hook の先頭付近で以下のように source する:
#
#   HOOK_UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/hook-utils.sh"
#   export HOOK_LOG_PREFIX="pre-push"   # ログファイル名 prefix（hook 毎に設定）
#   # shellcheck source=../bin/hook-utils.sh
#   source "$HOOK_UTILS"
#
# 提供する関数:
#   locate_repo_path FILE_PATH       — 入力ファイルが属する作業ツリーのルートと相対パスの解決
#   normalize_repo_path FILE_PATH    — 作業ツリーのルート基準の相対パス
#   resolve_repo_root FILE_PATH      — 入力ファイルが属する作業ツリーのルート（物理パス）
#   resolve_package_dir FILE_PATH    — ファイルが属する apps/<name> または packages/<name>
#   resolve_package FILE_PATH        — pnpm workspace パッケージ名の解決
#   resolve_tsconfig FILE_PATH       — 最寄り tsconfig.json の解決
#   compact_file LABEL FILE [LIMIT]  — ファイル内容を行/文字上限で圧縮（完全ログ保存）
#   compact_output LABEL STR [LIMIT] — 文字列を行/文字上限で圧縮（完全ログ保存）
#   run_limited_check SEC LABEL LIMIT CMD... — タイムアウト付き実行（失敗時のみ出力）
#   has_test_script PKG_DIR          — package.json の scripts.test 有無

# locate_repo_path: 入力ファイルが属する作業ツリーのルートと、そのルート基準の相対パスを決める。
# 結果はサブシェルを増やさないよう変数で返す:
#   REPO_PATH_ROOT - 作業ツリーのルート（物理パス）。解決できない / ルート外なら空文字
#   REPO_PATH_REL  - ルート基準の相対パス。解決できない / ルート外なら空文字
#
# - 絶対パスと相対パスの両方を受ける。相対パスは cwd 基準で絶対化してから扱う。
# - ルートは hook の cwd ではなく入力ファイル側から決める。入力ファイルの最も近い既存の
#   祖先ディレクトリで `git rev-parse --show-toplevel` を実行する（hook の cwd が編集対象の
#   作業ツリーと一致しない起動でも、そのファイルが属する作業ツリーを基準にできる）。
#   git 管理外のときは cwd をルートとみなす。
# - ルートとファイルの双方を物理パス（symlink 解決後）に揃えて比較する。作業ツリーが
#   symlink 経由のパス（例: /tmp が /private/tmp への symlink）で渡されても相対化できる。
# - 未作成・削除済みのファイルでも、既存の祖先ディレクトリから解決する。
#
# 引数:
#   $1 - ファイルパス（絶対 / 相対）
locate_repo_path() {
  local input="$1" abs cur rest phys full root
  REPO_PATH_ROOT=""
  REPO_PATH_REL=""
  [ -n "$input" ] || return 0

  case "$input" in
    /*) abs="$input" ;;
    *) abs="$PWD/${input#./}" ;;
  esac

  # 最も近い既存の祖先ディレクトリまで遡り、辿った残りを rest に積む。
  cur="$(dirname "$abs")"
  rest="$(basename "$abs")"
  while [ ! -d "$cur" ] && [ "$cur" != "/" ] && [ "$cur" != "." ]; do
    rest="$(basename "$cur")/$rest"
    cur="$(dirname "$cur")"
  done

  phys="$(cd -P "$cur" 2>/dev/null && pwd -P)" || return 0
  [ -n "$phys" ] || return 0
  if [ "$phys" = "/" ]; then
    full="/$rest"
  else
    full="$phys/$rest"
  fi

  root="$(cd "$phys" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || root=""
  if [ -z "$root" ]; then
    root="$(pwd -P)"
  fi

  case "$full" in
    "$root"/*)
      REPO_PATH_ROOT="$root"
      REPO_PATH_REL="${full#"$root"/}"
      ;;
  esac
}

# normalize_repo_path: 作業ツリーのルート基準の相対パスを返す（解決の規則は locate_repo_path）。
# ルート外・解決不能の場合は空文字を返す（呼び出し側は検査を skip する）。
#
# 引数:
#   $1 - ファイルパス（絶対 / 相対）
# 出力:
#   相対パス（例: apps/api/src/index.ts）。解決できない場合は空文字
normalize_repo_path() {
  locate_repo_path "$1"
  printf '%s\n' "$REPO_PATH_REL"
}

# resolve_repo_root: 入力ファイルが属する作業ツリーのルート（物理パス）を返す。
# 後続の相対参照（package.json / tsconfig.json の存在確認、tsc / pnpm の実行）は、
# このルートを cwd にして行う。ルート外・解決不能の場合は空文字を返す。
#
# 引数:
#   $1 - ファイルパス（絶対 / 相対）
resolve_repo_root() {
  locate_repo_path "$1"
  printf '%s\n' "$REPO_PATH_ROOT"
}

# resolve_package_dir: ファイルが属する workspace パッケージのディレクトリを返す。
# apps/<name> または packages/<name>（ルート基準の相対パス）。パッケージ外は空文字。
#
# 引数:
#   $1 - ファイルパス（絶対 / 相対）
resolve_package_dir() {
  locate_repo_path "$1"
  if [[ "$REPO_PATH_REL" =~ ^(apps/[^/]+)/ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  elif [[ "$REPO_PATH_REL" =~ ^(packages/[^/]+)/ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf '\n'
  fi
}

# resolve_package: ファイルパスから pnpm workspace パッケージ名を返す。
# apps/<name> / packages/<name> 部分を抽出し、package.json の name フィールドを読む。
# パッケージ外のファイルの場合は空文字を返す。
#
# 引数:
#   $1 - ファイルパス（絶対 / 相対）
# 出力:
#   パッケージ名（例: @example/api）。特定できない場合は空文字
resolve_package() {
  local pkg_dir="" root
  locate_repo_path "$1"
  root="$REPO_PATH_ROOT"
  if [[ "$REPO_PATH_REL" =~ ^(apps/[^/]+)/ ]]; then
    pkg_dir="${BASH_REMATCH[1]}"
  elif [[ "$REPO_PATH_REL" =~ ^(packages/[^/]+)/ ]]; then
    pkg_dir="${BASH_REMATCH[1]}"
  else
    echo ""
    return 0
  fi

  local pkg_json="$root/$pkg_dir/package.json"
  if [ -f "$pkg_json" ]; then
    jq -r '.name // empty' "$pkg_json"
  else
    echo ""
  fi
}

# resolve_tsconfig: ファイルパスから最も近い tsconfig.json のパスを返す。
# apps/<name>/tsconfig.json or packages/<name>/tsconfig.json。
# 見つからなければ空文字を返す。戻り値はルート基準の相対パスで、ルートを cwd にして使う。
#
# 引数:
#   $1 - ファイルパス（絶対 / 相対）
# 出力:
#   tsconfig.json のパス。見つからない場合は空文字
resolve_tsconfig() {
  local pkg_dir="" root
  locate_repo_path "$1"
  root="$REPO_PATH_ROOT"
  if [[ "$REPO_PATH_REL" =~ ^(apps/[^/]+)/ ]]; then
    pkg_dir="${BASH_REMATCH[1]}"
  elif [[ "$REPO_PATH_REL" =~ ^(packages/[^/]+)/ ]]; then
    pkg_dir="${BASH_REMATCH[1]}"
  else
    echo ""
    return 0
  fi

  if [ -f "$root/$pkg_dir/tsconfig.json" ]; then
    echo "$pkg_dir/tsconfig.json"
  else
    echo ""
  fi
}

# compact_file: hook 出力を line_limit に丸め、完全ログを ignored state 配下に保存する。
compact_file() {
  local label="$1"
  local output_file="$2"
  local line_limit="${3:-100}"
  local head_lines=$((line_limit / 2))
  local tail_lines=$((line_limit - head_lines))
  local char_limit=60000
  local char_head=$((char_limit / 2))
  local char_tail=$((char_limit - char_head))
  local safe_label ts log_path line_count char_count

  safe_label="$(printf '%s' "$label" | tr -cs '[:alnum:]._-' '-')"
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p .claude/state/hook-logs
  log_path=".claude/state/hook-logs/${HOOK_LOG_PREFIX:-hook}-${safe_label}-${ts}.log"
  cp "$output_file" "$log_path"
  line_count="$(wc -l < "$log_path" | tr -d ' ')"
  char_count="$(wc -c < "$log_path" | tr -d ' ')"

  if [ "$line_count" -le "$line_limit" ] && [ "$char_count" -le "$char_limit" ]; then
    cat "$log_path"
    return 0
  fi

  if [ "$line_count" -le "$line_limit" ]; then
    {
      printf 'Full log: %s (%s bytes). Showing first %s and last %s bytes.\n\n' "$log_path" "$char_count" "$char_head" "$char_tail"
      head -c "$char_head" "$log_path"
      printf '\n... omitted %s bytes ...\n\n' "$((char_count - char_limit))"
      tail -c "$char_tail" "$log_path"
    }
    return 0
  fi

  {
    printf 'Full log: %s (%s lines). Showing first %s and last %s lines.\n\n' "$log_path" "$line_count" "$head_lines" "$tail_lines"
    sed -n "1,${head_lines}p" "$log_path"
    printf '\n... omitted %s lines ...\n\n' "$((line_count - line_limit))"
    tail -n "$tail_lines" "$log_path"
  }
}

# run_limited_check: 成功時は空、失敗/timeout 時だけ compact した stdout+stderr を返す。
run_limited_check() {
  local timeout_sec="$1"
  local label="$2"
  local line_limit="$3"
  shift 3

  local output_file
  output_file="$(mktemp)"

  local timeout_cmd=""
  if command -v gtimeout >/dev/null 2>&1; then
    timeout_cmd="gtimeout"
  elif command -v timeout >/dev/null 2>&1; then
    timeout_cmd="timeout"
  fi

  if [ -n "$timeout_cmd" ]; then
    local status
    set +e
    "$timeout_cmd" "$timeout_sec" "$@" >"$output_file" 2>&1
    status=$?
    set -e

    if [ "$status" -eq 0 ]; then
      rm -f "$output_file"
      return 0
    fi

    if [ "$status" -eq 124 ]; then
      printf '[%s] timed out after %ss\n' "$label" "$timeout_sec"
    else
      compact_file "$label" "$output_file" "$line_limit"
    fi
    rm -f "$output_file"
    return 0
  fi

  local status_file
  status_file="$(mktemp)"
  (
    set +e
    "$@" >"$output_file" 2>&1
    printf '%s\n' "$?" > "$status_file"
  ) &
  local pid=$!
  # 完了を 0.1 秒間隔で確認する（1 秒間隔だと、即時に終わる検査でも 1 秒かかる）。
  local ticks=0 max_ticks=$((timeout_sec * 10))
  while [ "$ticks" -lt "$max_ticks" ]; do
    if [ -s "$status_file" ]; then
      local status
      status="$(cat "$status_file")"
      wait "$pid"
      if [ "$status" -ne 0 ]; then
        compact_file "$label" "$output_file" "$line_limit"
      fi
      rm -f "$output_file" "$status_file"
      return 0
    fi
    sleep 0.1
    ticks=$((ticks + 1))
  done

  # サブシェルだけでなく、その子（検査コマンド）も止める。
  pkill -P "$pid" 2>/dev/null || true
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  rm -f "$output_file" "$status_file"
  printf '[%s] timed out after %ss\n' "$label" "$timeout_sec"
}

# has_test_script: パッケージディレクトリの package.json に scripts.test が存在するかチェック。
# 存在すれば exit 0、なければ exit 1。
#
# 引数:
#   $1 - パッケージディレクトリのパス
# 戻り値:
#   0 - test スクリプトが存在する
#   1 - test スクリプトが存在しない
has_test_script() {
  local pkg_dir="$1"
  local pkg_json="$pkg_dir/package.json"

  if [ ! -f "$pkg_json" ]; then
    return 1
  fi

  local test_script
  test_script="$(jq -r '.scripts.test // empty' "$pkg_json" 2>/dev/null)"
  if [ -n "$test_script" ]; then
    return 0
  else
    return 1
  fi
}

# compact_output: compact_file の文字列入力版。
compact_output() {
  local label="$1"
  local output="$2"
  local line_limit="${3:-200}"
  local head_lines=$((line_limit / 2))
  local tail_lines=$((line_limit - head_lines))
  local char_limit=60000
  local char_head=$((char_limit / 2))
  local char_tail=$((char_limit - char_head))
  local safe_label ts log_path line_count char_count

  safe_label="$(printf '%s' "$label" | tr -cs '[:alnum:]._-' '-')"
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p .claude/state/hook-logs
  log_path=".claude/state/hook-logs/${HOOK_LOG_PREFIX:-hook}-${safe_label}-${ts}.log"
  printf '%s\n' "$output" > "$log_path"
  line_count="$(wc -l < "$log_path" | tr -d ' ')"
  char_count="$(wc -c < "$log_path" | tr -d ' ')"

  if [ "$line_count" -le "$line_limit" ] && [ "$char_count" -le "$char_limit" ]; then
    printf '%s' "$output"
    return 0
  fi

  if [ "$line_count" -le "$line_limit" ]; then
    {
      printf 'Full log: %s (%s bytes). Showing first %s and last %s bytes.\n\n' "$log_path" "$char_count" "$char_head" "$char_tail"
      head -c "$char_head" "$log_path"
      printf '\n... omitted %s bytes ...\n\n' "$((char_count - char_limit))"
      tail -c "$char_tail" "$log_path"
    }
    return 0
  fi

  {
    printf 'Full log: %s (%s lines). Showing first %s and last %s lines.\n\n' "$log_path" "$line_count" "$head_lines" "$tail_lines"
    sed -n "1,${head_lines}p" "$log_path"
    printf '\n... omitted %s lines ...\n\n' "$((line_count - line_limit))"
    tail -n "$tail_lines" "$log_path"
  }
}
