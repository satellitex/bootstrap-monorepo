#!/usr/bin/env bash
set -euo pipefail

# PreToolUse Hook: git push 前に秘密検知 (gitleaks) + CI 同等の軽量チェックを実行し、
# 失敗があれば push を deny する。test は CI 側で実行する（pre-push 対象外）。
#
# 実行する root script のリスト。名前は root package.json の scripts と
# docs/harness/skills/shared/verification-gates.md の定義に揃える（3 箇所同時更新）。
CI_CHECK_STEPS=(format:check lint typecheck build)

# worktree の .mise.toml を auto-trust（trust 未完だと shim 経由の pnpm 起動が落ちる）
if [ -f ".mise.toml" ]; then
  mise trust --quiet . 2>/dev/null || true
fi
eval "$(mise activate bash 2>/dev/null)" || true
export PATH="$HOME/.local/share/mise/shims:/opt/homebrew/bin:$PATH"

input="$(cat)"

# 防御ガード: git push 以外のコマンドなら即通過（if フィルタの保険）
cmd="$(jq -r '.tool_input.command // ""' <<< "$input")"
if [[ "$cmd" != git\ push* ]]; then
  exit 0
fi

# シークレット誤コミット検知（gitleaks）。pnpm / node_modules に依存しないため、
# それらが無いと skip される後続 CI チェックより前に実行する。
# 誤検知の除外は .gitleaks.toml の値ベース regexes を正とする（fingerprint baseline の
# .gitleaksignore は commit/行が変わると漏れるため不採用）。
# gitleaks が PATH に無い worktree（mise install 未済）では skip し、CI 側の検証に委ねる。
#
# スキャン範囲は `--all --not --remotes`（= ローカルの全 ref のうち、remote-tracking ref の
# いずれからも到達できない commit）に限定する。これは「まだ remote に出ていない＝この push で
# 公開されうる commit」に一致する。
#
# 範囲指定なしの `gitleaks git` は fetch 済みの全 ref を走査するため、**自分が push しない
# 他 branch の commit** まで検査対象になり、そこに誤検知が 1 件あるだけで当該 checkout の
# 全 push が止まる（未マージ branch のテスト fixture や docs 内のサンプル値で全 push が
# 阻害された実績がある）。値ベース allowlist を都度追記して回避すると、push しない commit の
# ために除外が増え続け検知力が落ちる。
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
# 通過済みであり、全履歴の backstop 走査は CI / 定期検査側に置く（追加時は
# docs/harness/scheduled-operations.md の設計ガイドに従う）。remote が 1 つも無い repo では
# `--remotes` が空集合になりローカル ref 全体が対象（fail closed）になる。
#
# 限界（重要）: 本 hook は Claude Code の PreToolUse hook であり、**意図的な回避を防ぐ
# セキュリティ境界ではない**。どの ref 名前空間まで広げても、ref を作らず
# `git push origin <sha>:refs/heads/x` と raw SHA を送れば範囲外になる。Claude Code を
# 経由しない端末からの push や --no-verify も同様に素通りする。あくまで「事故による
# 秘密の push」を手前で止める best-effort ガードであり、権威あるゲートは CI 側に置く。
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
    jq -n --arg reason "[gitleaks] シークレットの可能性がある値を検出したため push を中止しました。検出対象は **まだ remote に出ていないローカル commit のみ**（--all --not --remotes）です。実シークレットなら履歴から除去・ローテーションし、誤検知なら .gitleaks.toml の [allowlist] regexes に値ベース（\\b 厳密一致）で追記してください（.gitleaksignore の fingerprint baseline は不採用）。\n\n$gl_out" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
    exit 0
  elif [[ "$gl_rc" -ne 0 ]]; then
    # rc が 0/99 以外は実行エラー（mise shim 未 pin・config 不正・不明フラグ等）。
    # leak 検出と区別し、gitleaks 不在時 skip と同じく無出力で後続チェックへ継続する
    # （CI 側に検証を委ねる fail-open）。stdout は hook JSON プロトコル用のため、
    # デバッグログは stderr へ 1 行だけ出す。
    printf '[pre-push] gitleaks skipped (execution error rc=%s); CI will validate\n' "$gl_rc" >&2
  fi
fi

## --- 共通ユーティリティ読み込み ---
# pnpm / node_modules 非依存の検査でも run_step を使えるよう、skip ガードより前に読み込む。
HOOK_UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/hook-utils.sh"
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
    jq -n --arg reason "[$label] failed before git push.\n\n$compacted" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
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

# pnpm が解決できない（mise activate 失敗等）場合は skip して通過する。
# CI 同等の検証は GitHub Actions 側に任せる（fail-open）。
if ! command -v pnpm >/dev/null 2>&1; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: "pre-push CI check skipped (pnpm not on PATH; CI will still validate)"
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
      additionalContext: "pre-push CI check skipped (node_modules not installed; run `pnpm install --frozen-lockfile` for local verification; CI will still validate)"
    }
  }'
  exit 0
fi

# 各チェックを順に実行し、失敗した最初のステップで stop して deny を返す。
for step in "${CI_CHECK_STEPS[@]}"; do
  run_step "$step" pnpm "$step"
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
