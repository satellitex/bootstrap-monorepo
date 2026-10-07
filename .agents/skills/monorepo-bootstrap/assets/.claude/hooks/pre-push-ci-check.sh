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
# 解釈の実装は ../bin/hook-utils.sh の resolve_git_target で、commit 系の hook と共有する。

# hook 自身の位置は cd する前に絶対パスで確定し、共通ユーティリティを読み込む。
hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_UTILS="$hook_dir/../bin/hook-utils.sh"
export HOOK_LOG_PREFIX="pre-push"
# shellcheck source=../bin/hook-utils.sh
source "$HOOK_UTILS"

input="$(cat)"

# push を含まない入力は即通過する（`Bash(git -C *)` で起動された `git -C <dir> status` 等）。
[[ "$input" == *push* ]] || exit 0

# jq 自体も mise の shim で解決され得るため、入力の解析より前に行う。
setup_toolchain

read_bash_input "$input"

# 作業ツリー DIR の共有 git ディレクトリ（物理パス）。worktree 同士は同じ値になる。
git_common_dir_of() {
  (
    cd -P "$1" 2>/dev/null || exit 0
    common="$(git rev-parse --git-common-dir 2>/dev/null)" || exit 0
    cd -P "$common" 2>/dev/null && pwd -P
  ) || true
}

resolve_git_target push "$HOOK_CMD" "$HOOK_BASE_DIR"
if [ -n "$GIT_TARGET_UNRESOLVED" ]; then
  emit_hook_deny "[pre-push] push 先の作業ツリーを静的に特定できないため push を中止しました（${GIT_TARGET_UNRESOLVED}）。cd / git -C の引数に変数・コマンド置換・~・glob を使わず、対象の作業ツリーの中で \`git push\` を単独で実行してください。"
  exit 0
fi
push_root="$GIT_TARGET_ROOT"
[ -n "$push_root" ] || exit 0

# 別 repository への push は本 project の検査対象外（push 元と共有 git ディレクトリが異なる）。
# cd / -C を経ずに push 元の作業ツリーを指す場合は同じ repository なので、比較しない。
if [ "$GIT_TARGET_DIR" != "$HOOK_BASE_DIR" ]; then
  base_common="$(git_common_dir_of "$HOOK_BASE_DIR")"
  root_common="$(git_common_dir_of "$push_root")"
  if [ -n "$base_common" ] && [ -n "$root_common" ] && [ "$base_common" != "$root_common" ]; then
    exit 0
  fi
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
# 未設定なら本番デフォルトの PATH 上 gitleaks を使う（無ければ空で、秘密検知を skip する）。
gitleaks_bin="${PROJ_GITLEAKS_CMD:-$(command -v gitleaks || true)}"

if [[ -n "$gitleaks_bin" ]]; then
  # gitleaks は既定で「leak 検出」時に exit 1 を返すが、設定不正等の「実行エラー」も
  # 同じく exit 1（不明フラグは 126）となり衝突する。--exit-code 99 で leak 検出時のみ
  # 99 を返させることで、実行エラー（1 / 126 等）と区別可能にする。set -e 下で
  # コマンド置換の非ゼロ exit を殺さないよう if/else で rc を捕捉する。
  # .gitleaks.toml があれば値ベース allowlist として尊重し、無ければ既定ルールで走る。
  gitleaks_args=(git --no-banner --redact --exit-code 99 "--log-opts=--all --not --remotes")
  if [[ -f ".gitleaks.toml" ]]; then
    gitleaks_args+=(--config .gitleaks.toml)
  fi
  if gl_out="$("$gitleaks_bin" "${gitleaks_args[@]}" 2>&1)"; then
    gl_rc=0
  else
    gl_rc=$?
  fi
  if [[ "$gl_rc" -eq 99 ]]; then
    emit_hook_deny "[gitleaks] シークレットの可能性がある値を検出したため push を中止しました。検出対象は **まだ remote に出ていないローカル commit のみ**（--all --not --remotes）です。実シークレットなら履歴から除去・ローテーションし、誤検知なら .gitleaks.toml の [allowlist] regexes に値ベース（\\b 厳密一致）で追記してください。"$'\n\n'"$gl_out"
    exit 0
  elif [[ "$gl_rc" -ne 0 ]]; then
    # rc が 0/99 以外は実行エラー（mise shim 未 pin・config 不正・不明フラグ等）。
    # leak 検出と区別し、gitleaks 不在時 skip と同じく無出力で後続チェックへ継続する
    # （fail-open。この push の秘密検知は行われない）。stdout は hook JSON プロトコル用のため、
    # デバッグログは stderr へ 1 行だけ出す。
    printf '[pre-push] gitleaks skipped (execution error rc=%s); secret scan was not run\n' "$gl_rc" >&2
  fi
fi

# run_step LABEL CMD...: 失敗したら compact した出力つきで push を deny する。
# pnpm / node_modules 非依存の検査でも使えるよう、skip ガードより前に定義する。
run_step() {
  local label="$1"
  shift
  local output
  if ! output="$("$@" 2>&1)"; then
    local compacted
    compacted="$(compact_output "$label" "$output" 200)"
    emit_hook_deny "[$label] failed before git push."$'\n\n'"$compacted"
    exit 0
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
pnpm_bin="${PROJ_PNPM_CMD:-pnpm}"

# pnpm が解決できない（mise activate 失敗等）場合は skip して通過する（fail-open）。
# skip した検査のうち format:check / build は CI が担保するが、lint / typecheck は担保されない。
if ! command -v "$pnpm_bin" >/dev/null 2>&1; then
  emit_hook_context PreToolUse "pre-push CI check skipped (pnpm not on PATH; run \`mise install\` and push again to run lint / typecheck / build locally)"
  exit 0
fi

# node_modules が無い（worktree 等で install 未済）場合は skip して通過する。
# 手動で `pnpm install --frozen-lockfile` を実行してから push し直すと完全検証になる。
if [ ! -d "node_modules" ]; then
  emit_hook_context PreToolUse "pre-push CI check skipped (node_modules not installed; run \`pnpm install --frozen-lockfile\` and push again to run lint / typecheck / build locally)"
  exit 0
fi

# 各チェックを順に実行し、失敗した最初のステップで stop して deny を返す。
for step in "${CI_CHECK_STEPS[@]}"; do
  run_step "$step" "$pnpm_bin" "$step"
done

# --- PJ 固有の追加 step をここに追加 -------------------------------------------
# root package.json に script を追加したうえで、冒頭の CI_CHECK_STEPS へ足す
# （または個別に run_step "<step-name>" pnpm <step-name> を書く）。
# 追加時は docs/harness/skills/shared/verification-gates.md と
# tests/test-pre-push-ci-check.sh を同時更新する。
# -------------------------------------------------------------------------------

# 全パスしたら additionalContext で通過記録を残す
emit_hook_context PreToolUse "pre-push CI check passed (${CI_CHECK_STEPS[*]})"
