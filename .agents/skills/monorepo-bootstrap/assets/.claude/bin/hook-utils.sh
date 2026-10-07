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
#   _pkg_dir_of_rel REL              — 相対パスが属する apps/<name> または packages/<name>
#   resolve_package_dir FILE_PATH    — ファイルが属する apps/<name> または packages/<name>
#   resolve_package FILE_PATH        — pnpm workspace パッケージ名の解決
#   resolve_tsconfig FILE_PATH       — パッケージの tsconfig.json の解決
#   emit_hook_context EVENT MSG      — additionalContext だけを返す hook 出力
#   emit_hook_deny MSG               — PreToolUse の deny 出力
#   setup_toolchain_path             — mise の shims と Homebrew を PATH の先頭へ載せる
#   setup_toolchain                  — .mise.toml の trust / mise activate / PATH の準備
#   read_bash_input INPUT            — Bash tool の入力から command と cwd を取り出す
#   resolve_git_target SUB CMD DIR   — command 中の git SUB が作用する作業ツリーのルートの解決
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
  # abs は常に絶対パスなので、遡りは cur が空になる（"/" の手前）所で終わる。
  cur="${abs%/*}"
  rest="${abs##*/}"
  while [ -n "$cur" ] && [ ! -d "$cur" ]; do
    rest="${cur##*/}/$rest"
    cur="${cur%/*}"
  done

  phys="$(cd -P "${cur:-/}" 2>/dev/null && pwd -P)" || return 0
  full="${phys%/}/$rest"

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

# _pkg_dir_of_rel: ルート基準の相対パスが属する workspace パッケージのディレクトリを返す。
# パッケージを置く場所（apps/<name> と packages/<name>）の定義はここだけに置く。
# パッケージ外は何も出力しない。
#
# 引数:
#   $1 - ルート基準の相対パス
_pkg_dir_of_rel() {
  local re='^((apps|packages)/[^/]+)/'
  if [[ "$1" =~ $re ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  fi
}

# resolve_package_dir: ファイルが属する workspace パッケージのディレクトリを返す。
# apps/<name> または packages/<name>（ルート基準の相対パス）。パッケージ外は空文字。
#
# 引数:
#   $1 - ファイルパス（絶対 / 相対）
resolve_package_dir() {
  locate_repo_path "$1"
  _pkg_dir_of_rel "$REPO_PATH_REL"
}

# resolve_package: ファイルパスから pnpm workspace パッケージ名を返す。
# 属するパッケージの package.json の name フィールドを読む。
# パッケージ外のファイルの場合は空文字を返す。
#
# 引数:
#   $1 - ファイルパス（絶対 / 相対）
# 出力:
#   パッケージ名（例: @example/api）。特定できない場合は空文字
resolve_package() {
  local pkg_dir pkg_json
  locate_repo_path "$1"
  pkg_dir="$(_pkg_dir_of_rel "$REPO_PATH_REL")"
  pkg_json="$REPO_PATH_ROOT/$pkg_dir/package.json"
  if [ -n "$pkg_dir" ] && [ -f "$pkg_json" ]; then
    jq -r '.name // empty' "$pkg_json"
  fi
}

# resolve_tsconfig: ファイルパスが属するパッケージの tsconfig.json のパスを返す。
# apps/<name>/tsconfig.json or packages/<name>/tsconfig.json。
# 見つからなければ空文字を返す。戻り値はルート基準の相対パスで、ルートを cwd にして使う。
#
# 引数:
#   $1 - ファイルパス（絶対 / 相対）
# 出力:
#   tsconfig.json のパス。見つからない場合は空文字
resolve_tsconfig() {
  local pkg_dir
  locate_repo_path "$1"
  pkg_dir="$(_pkg_dir_of_rel "$REPO_PATH_REL")"
  if [ -n "$pkg_dir" ] && [ -f "$REPO_PATH_ROOT/$pkg_dir/tsconfig.json" ]; then
    printf '%s\n' "$pkg_dir/tsconfig.json"
  fi
}

# emit_hook_context: additionalContext だけを返す hook 出力を stdout へ出す。
#
# 引数:
#   $1 - hook のイベント名（PreToolUse / PostToolUse など）
#   $2 - additionalContext の本文
emit_hook_context() {
  jq -n --arg event "$1" --arg msg "$2" '{
    hookSpecificOutput: {
      hookEventName: $event,
      additionalContext: $msg
    }
  }'
}

# emit_hook_deny: PreToolUse の deny 出力を stdout へ出す。出力するだけで終了はしない
# （呼び出し側が続けて exit 0 する）。
#
# 引数:
#   $1 - deny の理由
emit_hook_deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
}

# setup_toolchain_path: mise の shims と Homebrew を PATH の先頭へ載せる。
# jq 自体も mise の shim で解決され得るため、入力の解析より前に呼ぶ。
setup_toolchain_path() {
  export PATH="$HOME/.local/share/mise/shims:/opt/homebrew/bin:$PATH"
}

# setup_toolchain: cwd の作業ツリーの .mise.toml を auto-trust（trust 未完だと shim 経由の
# pnpm 起動が落ちる）し、mise を activate して shims を PATH に載せる。
# cwd を別の作業ツリーへ移したあとは、その作業ツリーのために呼び直す。
setup_toolchain() {
  if [ -f ".mise.toml" ]; then
    mise trust --quiet . 2>/dev/null || true
  fi
  eval "$(mise activate bash 2>/dev/null)" || true
  setup_toolchain_path
}

# read_bash_input: PreToolUse(Bash) の入力から command と cwd を 1 回の jq で取り出す。
# command は改行を含み得るため、値の区切りに NUL を使う。
#   HOOK_CMD      - tool_input.command
#   HOOK_BASE_DIR - 入力の cwd（Bash の現在の cwd）。無ければ hook の cwd
#
# 引数:
#   $1 - hook の入力（JSON 文字列）
read_bash_input() {
  local cwd_given
  { IFS= read -r -d '' HOOK_CMD; IFS= read -r -d '' cwd_given; } \
    < <(jq -j '(.tool_input.command // ""), "\u0000", (.cwd // ""), "\u0000"' <<< "$1")
  HOOK_BASE_DIR="${cwd_given:-$PWD}"
}

# command を語と制御演算子に分割する。結果は tok_val（クォートを外した値）/ tok_op（演算子なら 1）/
# tok_dyn（変数・コマンド置換・~・glob など実行時に値が変わる語なら 1）の並列配列。
# 1 文字ずつ走査するため、LC_ALL=C でバイト単位に揃え、多バイト文字を含む command での遅さを避ける。
_tk_flush() {
  if [ "$_tk_has" -eq 1 ]; then
    tok_val+=("$_tk_cur")
    tok_op+=(0)
    tok_dyn+=("$_tk_dyn")
  fi
  _tk_cur=""
  _tk_has=0
  _tk_dyn=0
}

tokenize() {
  local LC_ALL=C
  local s="$1" n i c two rest quoted depth start run
  n=${#s}
  i=0
  tok_val=()
  tok_op=()
  tok_dyn=()
  _tk_cur=""
  _tk_has=0
  _tk_dyn=0
  while [ "$i" -lt "$n" ]; do
    c="${s:i:1}"
    case "$c" in
      ' ' | $'\t')
        _tk_flush
        i=$((i + 1))
        ;;
      ';' | '&' | '|' | '<' | '>' | '(' | ')' | $'\n')
        _tk_flush
        two="${s:i:2}"
        if [ "$two" = "&&" ] || [ "$two" = "||" ]; then
          tok_val+=("$two")
          i=$((i + 2))
        else
          tok_val+=("$c")
          i=$((i + 1))
        fi
        tok_op+=(1)
        tok_dyn+=(0)
        ;;
      "'")
        _tk_has=1
        rest="${s:i+1}"
        if [[ "$rest" != *"'"* ]]; then
          _tk_dyn=1
          break
        fi
        quoted="${rest%%\'*}"
        _tk_cur+="$quoted"
        i=$((i + ${#quoted} + 2))
        ;;
      '"')
        _tk_has=1
        i=$((i + 1))
        while [ "$i" -lt "$n" ] && [ "${s:i:1}" != '"' ]; do
          # 特別な意味を持たない文字の連続は、1 文字ずつではなくまとめて取り込む（長い入力で遅くなるため）
          rest="${s:i}"
          run="${rest%%[\"\\\$\`]*}"
          if [ -n "$run" ]; then
            _tk_cur+="$run"
            i=$((i + ${#run}))
            continue
          fi
          case "${s:i:1}" in
            '\')
              _tk_dyn=1
              _tk_cur+="${s:i+1:1}"
              i=$((i + 2))
              continue
              ;;
            '$' | '`') _tk_dyn=1 ;;
          esac
          _tk_cur+="${s:i:1}"
          i=$((i + 1))
        done
        if [ "$i" -ge "$n" ]; then
          _tk_dyn=1
        fi
        i=$((i + 1))
        ;;
      '$')
        _tk_has=1
        _tk_dyn=1
        if [ "${s:i+1:1}" = "(" ]; then
          # $( ... ) は対応する閉じ括弧まで 1 語として読み飛ばす（中身は評価せず、原文を語に残す）
          start=$i
          depth=1
          i=$((i + 2))
          while [ "$i" -lt "$n" ] && [ "$depth" -gt 0 ]; do
            rest="${s:i}"
            run="${rest%%[()]*}"
            if [ -n "$run" ]; then
              i=$((i + ${#run}))
              continue
            fi
            case "${s:i:1}" in
              '(') depth=$((depth + 1)) ;;
              ')') depth=$((depth - 1)) ;;
            esac
            i=$((i + 1))
          done
          _tk_cur+="${s:start:i-start}"
        else
          _tk_cur+='$'
          i=$((i + 1))
        fi
        ;;
      '`')
        _tk_has=1
        _tk_dyn=1
        rest="${s:i+1}"
        if [[ "$rest" != *'`'* ]]; then
          break
        fi
        quoted="${rest%%\`*}"
        i=$((i + ${#quoted} + 2))
        ;;
      '\')
        _tk_has=1
        _tk_dyn=1
        _tk_cur+="${s:i+1:1}"
        i=$((i + 2))
        ;;
      '~' | '*' | '?' | '[' | '{')
        _tk_has=1
        _tk_dyn=1
        _tk_cur+="$c"
        i=$((i + 1))
        ;;
      *)
        _tk_has=1
        _tk_cur+="$c"
        i=$((i + 1))
        ;;
    esac
  done
  _tk_flush
}

# resolve_git_target: command 中の `git [<global option>...] SUB` が作用する作業ツリーのルートを静的に決める。
# Bash tool の command が操作する作業ツリーは、入力の cwd と、command 内の `cd <dir>` /
# `git -C <dir>` だけから決まる。hook プロセスの cwd は操作対象と一致するとは限らない。
#
# 解釈するのは、`&&` `;` 区切りの `cd <dir>` と `git [<global option>...] SUB` の並びだけで、
# シェル構文の完全な解析はしない。作業ツリーを静的に決められない形は GIT_TARGET_UNRESOLVED に
# 理由を返す。決められない形の一覧は pre-push-ci-check.sh 冒頭のコメントに書く。
#
# 結果は変数で返す（呼び出しごとに初期化する）:
#   GIT_TARGET_ROOT       - SUB の対象の作業ツリーのルート（物理パス）。SUB を含まない、または
#                           決められない場合は空文字
#   GIT_TARGET_DIR        - ルートを求めたディレクトリ。BASE_DIR と同じ値なら cd / -C の影響を受けていない
#   GIT_TARGET_PRECEDED   - SUB より前に cd 以外のコマンドが実行されるなら 1（index や作業ツリーが
#                           SUB の前に変わり得る。hook の実行時点の状態が SUB の対象と一致しない）
#   GIT_TARGET_UNRESOLVED - SUB を含むが対象を決められない理由。空でなければ呼び出し側が通過させるか止めるかを選ぶ
#
# 引数:
#   $1 - git のサブコマンド（push / commit など）
#   $2 - Bash tool の command
#   $3 - command を実行する cwd
resolve_git_target() {
  local sub="$1" dir="$3" n i w a gdir env_reason cd_reason git_reason reason root
  local cd_seen=0 grouped=0 preceded=0
  GIT_TARGET_ROOT=""
  GIT_TARGET_DIR=""
  GIT_TARGET_PRECEDED=0
  GIT_TARGET_UNRESOLVED=""
  cd_reason=""
  tokenize "$2"
  n=${#tok_val[@]}
  i=0
  while [ "$i" -lt "$n" ]; do
    if [ "${tok_op[i]}" -eq 1 ]; then
      case "${tok_val[i]}" in
        '(' | ')') grouped=1 ;;
      esac
      i=$((i + 1))
      continue
    fi

    # 先頭の環境変数代入（NAME=value）は読み飛ばす。作業ツリーを変える変数は解決不能にする。
    env_reason=""
    while [ "$i" -lt "$n" ] && [ "${tok_op[i]}" -eq 0 ] \
      && [[ "${tok_val[i]}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; do
      case "${tok_val[i]}" in
        GIT_DIR=* | GIT_WORK_TREE=* | GIT_COMMON_DIR=*)
          env_reason="${tok_val[i]%%=*} で作業ツリーが変わる"
          ;;
      esac
      i=$((i + 1))
    done
    if [ "$i" -ge "$n" ] || [ "${tok_op[i]}" -eq 1 ]; then
      continue
    fi

    w="${tok_val[i]}"
    case "$w" in
      '{' | '}')
        grouped=1
        i=$((i + 1))
        continue
        ;;
      cd)
        i=$((i + 1))
        cd_seen=1
        if [ "$i" -lt "$n" ] && [ "${tok_op[i]}" -eq 0 ]; then
          a="${tok_val[i]}"
          if [ "${tok_dyn[i]}" -eq 1 ]; then
            cd_reason="cd の引数（${a}）を静的に解決できない"
          elif [[ "$a" == -* ]]; then
            cd_reason="cd のオプション（${a}）は解釈しない"
          elif [[ "$a" == /* ]]; then
            dir="$a"
            cd_reason=""
          else
            dir="$dir/$a"
          fi
        else
          cd_reason="cd の引数がない"
        fi
        ;;
      git)
        i=$((i + 1))
        gdir="$dir"
        git_reason=""
        w=""
        while [ "$i" -lt "$n" ] && [ "${tok_op[i]}" -eq 0 ]; do
          a="${tok_val[i]}"
          case "$a" in
            "$sub")
              w="$sub"
              break
              ;;
            -C)
              i=$((i + 1))
              if [ "$i" -ge "$n" ] || [ "${tok_op[i]}" -eq 1 ]; then
                break
              fi
              if [ "${tok_dyn[i]}" -eq 1 ]; then
                git_reason="git -C の引数（${tok_val[i]}）を静的に解決できない"
              elif [[ "${tok_val[i]}" == /* ]]; then
                gdir="${tok_val[i]}"
              else
                gdir="$gdir/${tok_val[i]}"
              fi
              ;;
            -c | --namespace | --super-prefix | --config-env | --exec-path)
              i=$((i + 1))
              ;;
            --git-dir | --work-tree)
              git_reason="git ${a} で作業ツリーが変わる"
              i=$((i + 1))
              ;;
            --git-dir=* | --work-tree=*)
              git_reason="git ${a%%=*} で作業ツリーが変わる"
              ;;
            -*) ;;
            *) break ;;
          esac
          i=$((i + 1))
        done
        if [ "$w" = "$sub" ] && [ "$preceded" -eq 1 ]; then
          GIT_TARGET_PRECEDED=1
        fi
        preceded=1
        if [ "$w" = "$sub" ]; then
          reason="${env_reason:-${git_reason:-$cd_reason}}"
          if [ -z "$reason" ] && [ "$cd_seen" -eq 1 ] && [ "$grouped" -eq 1 ]; then
            reason="グループ化されたコマンドの中の cd は解釈しない"
          fi
          if [ -z "$reason" ]; then
            if ! root="$(cd -P "$gdir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" \
              || [ -z "$root" ]; then
              reason="${gdir} は git の作業ツリーではない（または存在しない）"
            fi
          fi
          if [ -z "$reason" ] && [ -n "$GIT_TARGET_ROOT" ] && [ "$root" != "$GIT_TARGET_ROOT" ]; then
            reason="1 つの command に異なる作業ツリーへの ${sub} が含まれる"
          fi
          if [ -n "$reason" ]; then
            GIT_TARGET_ROOT=""
            GIT_TARGET_UNRESOLVED="$reason"
            return 0
          fi
          GIT_TARGET_ROOT="$root"
          GIT_TARGET_DIR="$gdir"
        fi
        ;;
      *)
        preceded=1
        ;;
    esac

    # 次の演算子まで読み飛ばす
    while [ "$i" -lt "$n" ] && [ "${tok_op[i]}" -eq 0 ]; do
      i=$((i + 1))
    done
  done
  return 0
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
# timeout / gtimeout があればそれを使う。無ければ、検査コマンドを独立した process group で
# 起動し、別の watchdog が期限に group ごと止める（検査コマンドの子も止まる）。
run_limited_check() {
  local timeout_sec="$1"
  local label="$2"
  local line_limit="$3"
  shift 3

  local output_file marker status=0 timeout_cmd="" pid watchdog
  output_file="$(mktemp)"
  marker="$output_file.timeout"

  if command -v gtimeout >/dev/null 2>&1; then
    timeout_cmd="gtimeout"
  elif command -v timeout >/dev/null 2>&1; then
    timeout_cmd="timeout"
  fi

  if [ -n "$timeout_cmd" ]; then
    "$timeout_cmd" "$timeout_sec" "$@" >"$output_file" 2>&1 || status=$?
    [ "$status" -ne 124 ] || : > "$marker"
  else
    # set -m で、起動する子が自分の process group の先頭になる（kill -- -PID で group ごと止められる）。
    # watchdog は期限まで sleep し、期限に達したときだけ marker を作って子を止める。
    # 完了後は watchdog を subshell ごと止めるため、marker は作られない。
    set -m
    "$@" >"$output_file" 2>&1 </dev/null &
    pid=$!
    ( sleep "$timeout_sec" && { : > "$marker"; kill -TERM -- "-$pid"; } ) >/dev/null 2>&1 &
    watchdog=$!
    set +m
    wait "$pid" 2>/dev/null || status=$?
    # 2 回目は、1 回目の到着前に watchdog が fork していた sleep を止める（group は成員が残る間は有効）。
    kill -TERM -- "-$watchdog" 2>/dev/null || true
    wait "$watchdog" 2>/dev/null || true
    kill -TERM -- "-$watchdog" 2>/dev/null || true
  fi

  if [ -e "$marker" ]; then
    printf '[%s] timed out after %ss\n' "$label" "$timeout_sec"
  elif [ "$status" -ne 0 ]; then
    compact_file "$label" "$output_file" "$line_limit"
  fi
  rm -f "$output_file" "$marker"
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
