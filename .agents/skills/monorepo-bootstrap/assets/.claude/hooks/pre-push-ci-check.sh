#!/usr/bin/env bash
set -euo pipefail

# PreToolUse Hook: git push 前に秘密検知 (gitleaks) + CI 同等の軽量チェックを実行し、
# 失敗があれば push を deny する。test は CI 側で実行する（pre-push 対象外）。
#
# 実行する root script のリスト。名前は root package.json の scripts と
# docs/harness/skills/shared/verification-gates.md の定義に揃える（3 箇所同時更新）。
CI_CHECK_STEPS=(format:check lint typecheck build)

# --- push 先の作業ツリーの特定 ---------------------------------------------------
# hook プロセスの cwd は、push する作業ツリーと一致するとは限らない（別 worktree からの
# 起動など）。push する作業ツリーが現れるのは stdin の cwd（Bash の現在の cwd）と、command
# 内の `cd <dir>` / `git -C <dir>` だけなので、そこから push 先のルートを決め、以降の
# 相対参照（.gitleaks.toml / node_modules / pnpm script / .mise.toml）をすべてそのルート基準にする。
# hook の cwd のまま検査すると、別の作業ツリーの設定や未追跡ファイルで push が止まる、
# または push 先の違反を見逃す。
#
# 解釈するのは、command 中の `cd <dir>`、`git [<global option>...] push` の並び（`&&` `;` 区切り）
# だけで、シェル構文の完全な解析はしない。次の場合は push 先を静的に決められないため、
# 検査せずに deny する（fail-closed。誤った作業ツリーを検査して緑にするより安全）:
#   - cd / -C の引数に変数・コマンド置換・~・glob・クォートの欠けがある
#   - cd / -C 先が存在しない、または git の作業ツリーではない
#   - --git-dir / --work-tree / GIT_DIR / GIT_WORK_TREE で作業ツリーが変わる
#   - グループ化（括弧・波括弧）の内側で cd している
#   - 1 つの command に、異なる作業ツリーへの push が複数含まれる
# stdin に cwd が無い入力は、hook の cwd を push 元とする。
# push 元の repository とは別の repository（submodule や別 clone）への push は、
# 本 project の検査対象外として通過する。

# hook 自身の位置は cd する前に絶対パスで確定する。
hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 作業ツリーの .mise.toml を auto-trust（trust 未完だと shim 経由の pnpm 起動が落ちる）し、
# mise の shims を PATH に載せる。jq 自体も mise の shim で解決され得るため、入力の解析より前に行う。
setup_toolchain() {
  if [ -f ".mise.toml" ]; then
    mise trust --quiet . 2>/dev/null || true
  fi
  eval "$(mise activate bash 2>/dev/null)" || true
  export PATH="$HOME/.local/share/mise/shims:/opt/homebrew/bin:$PATH"
}

input="$(cat)"

# push を含まない入力は即通過する（`Bash(git -C *)` で起動された `git -C <dir> status` 等）。
[[ "$input" == *push* ]] || exit 0

setup_toolchain

cmd="$(jq -r '.tool_input.command // ""' <<< "$input")"
cwd_given="$(jq -r '.cwd // ""' <<< "$input")"
base_dir="${cwd_given:-$PWD}"

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# command を語と制御演算子に分割する。結果は tok_val（クォートを外した値）/ tok_op（演算子なら 1）/
# tok_dyn（変数・コマンド置換・~・glob など実行時に値が変わる語なら 1）の並列配列。
tok_val=()
tok_op=()
tok_dyn=()
_tk_cur=""
_tk_has=0
_tk_dyn=0

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

# 戻り値 0: push 先を特定した（push_root に作業ツリーのルートを設定）
#        1: push を含まない（通過させる）
#        2: push を含むが push 先を特定できない（unresolved に理由を設定）
resolve_push_target() {
  local dir="$base_dir" n i w a gdir env_reason cd_reason git_reason reason root
  local cd_seen=0 grouped=0 found=0
  push_root=""
  unresolved=""
  cd_reason=""
  tokenize "$cmd"
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
            push)
              w="push"
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
        if [ "$w" = "push" ]; then
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
          if [ -n "$reason" ]; then
            unresolved="$reason"
            return 2
          fi
          if [ "$found" -eq 1 ] && [ "$root" != "$push_root" ]; then
            unresolved="1 つの command に異なる作業ツリーへの push が含まれる"
            return 2
          fi
          found=1
          push_root="$root"
        fi
        ;;
    esac

    # 次の演算子まで読み飛ばす
    while [ "$i" -lt "$n" ] && [ "${tok_op[i]}" -eq 0 ]; do
      i=$((i + 1))
    done
  done

  if [ "$found" -eq 1 ]; then
    return 0
  fi
  return 1
}

# 作業ツリー DIR の共有 git ディレクトリ（物理パス）。worktree 同士は同じ値になる。
git_common_dir_of() {
  (
    cd -P "$1" 2>/dev/null || exit 0
    common="$(git rev-parse --git-common-dir 2>/dev/null)" || exit 0
    cd -P "$common" 2>/dev/null && pwd -P
  ) || true
}

if resolve_push_target; then
  :
else
  rc=$?
  if [ "$rc" -eq 1 ]; then
    exit 0
  fi
  deny "[pre-push] push 先の作業ツリーを静的に特定できないため push を中止しました（${unresolved}）。cd / git -C の引数に変数・コマンド置換・~・glob を使わず、対象の作業ツリーの中で \`git push\` を単独で実行してください。"
fi

# 別 repository への push は本 project の検査対象外（push 元と共有 git ディレクトリが異なる）。
base_common="$(git_common_dir_of "$base_dir")"
root_common="$(git_common_dir_of "$push_root")"
if [ -n "$base_common" ] && [ -n "$root_common" ] && [ "$base_common" != "$root_common" ]; then
  exit 0
fi

# 以降の検査はすべて push 先の作業ツリーのルートで行う。
if [ "$(pwd -P)" != "$push_root" ]; then
  builtin cd "$push_root"
  setup_toolchain
fi

# シークレット誤コミット検知（gitleaks）。pnpm / node_modules に依存しないため、
# それらが無いと skip される後続チェックより前に実行する。
# 誤検知の除外は .gitleaks.toml の値ベース regexes で行う（値ベースの除外は commit や行が
# 変わっても漏れない）。
# gitleaks が PATH に無い worktree（mise install 未済）では skip して通過する。
# 秘密検知は CI では担保されないため、skip された push は検知なしで remote に出る。
#
# スキャン範囲は `--all --not --remotes`（= ローカルの全 ref のうち、remote-tracking ref の
# いずれからも到達できない commit）に限定する。これは「まだ remote に出ていない＝この push で
# 公開されうる commit」に一致する。
#
# 範囲指定なしの `gitleaks git` は fetch 済みの全 ref を走査するため、**自分が push しない
# 他 branch の commit** まで検査対象になり、そこに誤検知が 1 件あるだけで当該 checkout の
# 全 push が止まる（他 branch のテスト fixture や docs 内のサンプル値だけで起きうる）。
# 値ベース allowlist を都度追記して回避すると、push しない commit のために除外が増え続け
# 検知力が落ちる。
#
# HEAD や branch/tag に絞らず `--all` を使うのは、送信元 ref が checkout 中の HEAD とは
# 限らないため。`git push origin secret-branch:secret-branch` は別 branch を、
# `git push origin refs/changes/x:refs/heads/x` は refs/heads・refs/tags 以外の名前空間を
# 送れる。push コマンドの refspec を解析して送信対象だけを厳密に特定する案もあるが、
# `git push` の引数形態（省略時の push.default / src:dst / --all / --mirror 等）を
# 取りこぼすとそのまま検知漏れになるため、解析はせず ref 名前空間を広く取る。
# `--all` は refs/stash も含むため、stash 内の値でも push が止まりうる。
#
# 既に remote 上にある commit を除外しても検知力は落ちない: それらは push 時点で本 hook を
# 通過済みである。全履歴を走査する backstop が要る場合は定期検査として足す（追加時は
# docs/harness/scheduled-operations.md の設計ガイドに従う）。remote が 1 つも無い repo では
# `--remotes` が空集合になりローカル ref 全体が対象（fail closed）になる。
#
# 限界: 本 hook は Claude Code の PreToolUse hook であり、**意図的な回避を防ぐ
# セキュリティ境界ではない**。どの ref 名前空間まで広げても、ref を作らず
# `git push origin <sha>:refs/heads/x` と raw SHA を送れば範囲外になる。Claude Code を
# 経由しない端末からの push や --no-verify も同様に素通りする。あくまで「事故による
# 秘密の push」を手前で止める best-effort ガードであり、CI は PR / push の全経路に効くが
# 秘密検知を持たない（基礎 CI は format:check / test / build のみ）。
#
# 残るトレードオフ: 未 push のローカル ref（stash 含む）に誤検知があると、無関係な branch の
# push も止まる。ただし対象は「自分の手元にしか無い commit」に限られ、fetch 済み全 ref を
# 走査する場合に比べて影響範囲は小さい。
#
# gitleaks コマンドの注入 seam: PROJ_GITLEAKS_CMD が設定されていればそれを使う（テスト用 stub 注入）。
# 未設定なら本番デフォルトの PATH 上 gitleaks を使う。
if [[ -n "${PROJ_GITLEAKS_CMD:-}" ]]; then
  gitleaks_cmd=("${PROJ_GITLEAKS_CMD}")
elif command -v gitleaks >/dev/null 2>&1; then
  gitleaks_cmd=(gitleaks)
else
  gitleaks_cmd=()
fi

if [[ ${#gitleaks_cmd[@]} -gt 0 ]]; then
  # gitleaks は既定で「leak 検出」時に exit 1 を返すが、設定不正等の「実行エラー」も
  # 同じく exit 1（不明フラグは 126）となり衝突する。--exit-code 99 で leak 検出時のみ
  # 99 を返させることで、実行エラー（1 / 126 等）と区別可能にする。set -e 下で
  # コマンド置換の非ゼロ exit を殺さないよう if/else で rc を捕捉する。
  # .gitleaks.toml があれば値ベース allowlist として尊重し、無ければ既定ルールで走る。
  gitleaks_args=(git --no-banner --redact --exit-code 99 "--log-opts=--all --not --remotes")
  if [[ -f ".gitleaks.toml" ]]; then
    gitleaks_args+=(--config .gitleaks.toml)
  fi
  if gl_out="$("${gitleaks_cmd[@]}" "${gitleaks_args[@]}" 2>&1)"; then
    gl_rc=0
  else
    gl_rc=$?
  fi
  if [[ "$gl_rc" -eq 99 ]]; then
    deny "[gitleaks] シークレットの可能性がある値を検出したため push を中止しました。検出対象は **まだ remote に出ていないローカル commit のみ**（--all --not --remotes）です。実シークレットなら履歴から除去・ローテーションし、誤検知なら .gitleaks.toml の [allowlist] regexes に値ベース（\\b 厳密一致）で追記してください。"$'\n\n'"$gl_out"
  elif [[ "$gl_rc" -ne 0 ]]; then
    # rc が 0/99 以外は実行エラー（mise shim 未 pin・config 不正・不明フラグ等）。
    # leak 検出と区別し、gitleaks 不在時 skip と同じく無出力で後続チェックへ継続する
    # （fail-open。この push の秘密検知は行われない）。stdout は hook JSON プロトコル用のため、
    # デバッグログは stderr へ 1 行だけ出す。
    printf '[pre-push] gitleaks skipped (execution error rc=%s); secret scan was not run\n' "$gl_rc" >&2
  fi
fi

## --- 共通ユーティリティ読み込み ---
# pnpm / node_modules 非依存の検査でも run_step を使えるよう、skip ガードより前に読み込む。
# hook_dir は cd する前に確定した絶対パス。
HOOK_UTILS="$hook_dir/../bin/hook-utils.sh"
export HOOK_LOG_PREFIX="pre-push"
# shellcheck source=../bin/hook-utils.sh
source "$HOOK_UTILS"

run_step() {
  local label="$1"
  shift
  local output
  if ! output="$("$@" 2>&1)"; then
    local compacted
    compacted="$(compact_output "$label" "$output" 200)"
    deny "[$label] failed before git push."$'\n\n'"$compacted"
  fi
}

# --- PJ 固有の pnpm 非依存検査をここに追加 -------------------------------------
# bash / 標準ツールのみで動く高速・決定論的な検査は、下の pnpm / node_modules
# skip ガードより **前** に置く（install 未済の worktree でも違反を止められる）。
#   例: run_step "<check-name>" bash scripts/<check-script>.sh
# 検査スクリプトの実体が無ければ run_step が deny する（fail-closed。検査の消失を
# 沈黙させない）。追加時は tests/test-pre-push-ci-check.sh を同時更新する。
# -------------------------------------------------------------------------------

# pnpm コマンドの注入 seam: PROJ_PNPM_CMD が設定されていればそれを使う（テスト用 stub 注入）。
# 未設定なら PATH 上の pnpm を使う。
if [[ -n "${PROJ_PNPM_CMD:-}" ]]; then
  pnpm_cmd=("${PROJ_PNPM_CMD}")
else
  pnpm_cmd=(pnpm)
fi

# pnpm が解決できない（mise activate 失敗等）場合は skip して通過する（fail-open）。
# skip した検査のうち format:check / build は CI が担保するが、lint / typecheck は担保されない。
if ! command -v "${pnpm_cmd[0]}" >/dev/null 2>&1; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: "pre-push CI check skipped (pnpm not on PATH; run `mise install` and push again to run lint / typecheck / build locally)"
    }
  }'
  exit 0
fi

# node_modules が無い（worktree 等で install 未済）場合は skip して通過する。
# 手動で `pnpm install --frozen-lockfile` を実行してから push し直すと完全検証になる。
if [ ! -d "node_modules" ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: "pre-push CI check skipped (node_modules not installed; run `pnpm install --frozen-lockfile` and push again to run lint / typecheck / build locally)"
    }
  }'
  exit 0
fi

# 各チェックを順に実行し、失敗した最初のステップで stop して deny を返す。
for step in "${CI_CHECK_STEPS[@]}"; do
  run_step "$step" "${pnpm_cmd[@]}" "$step"
done

# --- PJ 固有の追加 step をここに追加 -------------------------------------------
# root package.json に script を追加したうえで、冒頭の CI_CHECK_STEPS へ足す
# （または個別に run_step "<step-name>" pnpm <step-name> を書く）。
# 追加時は docs/harness/skills/shared/verification-gates.md と
# tests/test-pre-push-ci-check.sh を同時更新する。
# -------------------------------------------------------------------------------

# 全パスしたら additionalContext で通過記録を残す
jq -n --arg steps "${CI_CHECK_STEPS[*]}" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: ("pre-push CI check passed (" + $steps + ")")
  }
}'
