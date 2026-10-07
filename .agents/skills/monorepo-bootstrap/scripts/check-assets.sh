#!/usr/bin/env bash
# テンプレート資産（assets/）の整合検査。テンプレート repo の保守専用で、bootstrap 先へは配布しない。
#
#   bash .agents/skills/monorepo-bootstrap/scripts/check-assets.sh
#
# 検査:
#   1. assets/MANIFEST.md の「資産一覧」節の表（第 1 列 = 資産パス）と assets/ の実ファイルが 1:1
#      （`<name>` や `*` を含む行はパターンとして展開し、末尾 `/` の行はディレクトリ配下全体）
#   2. skill 正本（docs/harness/skills/*.md）と adapter（.claude/skills/*/SKILL.md）が同名で 1:1
#   3. 未置換 token: assets 内の二重波括弧 token が明示 token 4 種だけで、MANIFEST が列挙している
#      （対象外: 置換対象外の記入欄 docs/adr/template.md と docs/templates/、台帳 MANIFEST.md 自身、
#      GitHub Actions の式、波括弧 3 つの外部ツールのテンプレート構文）
#   4. 固有語 denylist: 環境変数 TEMPLATE_DENYLIST_FILE が指すファイル（1 行 1 パターンの拡張正規表現、
#      `#` 始まりはコメント）を、assets / references / SKILL.md / ルートの入口文書に対して照合する。
#      denylist を repo に置くと固有語そのものが混入するため、ファイルは repo 外に置く。未設定なら skip
#   5. HARNESS_ROOT=assets で tests/harness/run.mjs（配布版の機械検査）を実行
#
# 終了コード: 0 = すべて通過（skip を含む）/ 1 = 1 つ以上失敗。
# bash 3.2（macOS 標準）でも動くよう、連想配列・mapfile は使わない。

set -uo pipefail

# sort / comm / grep の照合順序を固定する（ロケール差による不一致を避ける）。
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ASSETS="$SKILL_DIR/assets"
MANIFEST="$ASSETS/MANIFEST.md"

# 明示 token（bootstrap 時に置換される二重波括弧の名前）。MANIFEST と tests/harness/support/
# repo-files.mjs の EXPLICIT_TOKENS と同じ集合を保つ。
ALLOWED_TOKENS="PRODUCT_NAME GITHUB_ORG REPO_NAME PROJECT_LANGUAGE"

# 置換対象外の記入欄（コピーして埋める様式）。tests/harness/support/repo-files.mjs の
# TEMPLATE_FORM_PATHS と同じ集合を保つ。
FORM_PATHS="docs/adr/template.md docs/templates/"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAILS=0
ok() { echo "ok:   $*"; }
skip() { echo "skip: $*"; }
fail() {
  echo "FAIL: $*"
  FAILS=$((FAILS + 1))
}
detail() { sed 's/^/        /'; }

is_form_path() {
  local rel="$1" p
  for p in $FORM_PATHS; do
    case "$p" in
      */) case "$rel" in "$p"*) return 0 ;; esac ;;
      *) [ "$rel" = "$p" ] && return 0 ;;
    esac
  done
  return 1
}

# ---- 1. MANIFEST と実ファイルの 1:1 -------------------------------------------------------
check_manifest() {
  if [ ! -f "$MANIFEST" ]; then
    fail "MANIFEST.md が無い: $MANIFEST"
    return
  fi

  (cd "$ASSETS" && find . -type f ! -name '.DS_Store' | sed 's|^\./||' | LC_ALL=C sort) >"$TMP/actual.txt"

  # 「資産一覧」節（## 見出し）の表から、第 1 列がパスらしいセルだけを取り出す。
  awk '
    /^## / { insec = ($0 ~ /^## 資産一覧[[:space:]]*$/); next }
    insec && /^\|/ {
      n = split($0, c, "|")
      cell = c[2]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", cell)
      gsub(/`/, "", cell)
      print cell
    }' "$MANIFEST" |
    sed 's/&lt;/</g; s/&gt;/>/g' |
    grep -E '^[A-Za-z0-9._<>*/-]+$' |
    grep -E '[./]' >"$TMP/manifest_cells.txt" || true

  if [ ! -s "$TMP/manifest_cells.txt" ]; then
    fail "MANIFEST.md の「資産一覧」節（## 見出し）から資産パスを 1 件も読めない"
    return
  fi

  : >"$TMP/m_exact.txt"
  : >"$TMP/m_regex.txt"
  : >"$TMP/m_dirs.txt"
  while IFS= read -r cell; do
    case "$cell" in
      */) echo "$cell" >>"$TMP/m_dirs.txt" ;;
      *'<'* | *'*'*)
        # <name> → 1 セグメント、** → 任意、* → セグメント内の任意
        echo "$cell" |
          sed -e 's/\./\\./g' \
            -e 's/<[^>]*>/[^\/]+/g' \
            -e 's/\*\*/@@DOUBLESTAR@@/g' \
            -e 's/\*/[^\/]*/g' \
            -e 's/@@DOUBLESTAR@@/.*/g' >>"$TMP/m_regex.txt"
        ;;
      *) echo "$cell" >>"$TMP/m_exact.txt" ;;
    esac
  done <"$TMP/manifest_cells.txt"
  LC_ALL=C sort -u "$TMP/m_exact.txt" -o "$TMP/m_exact.txt"

  local problems=0

  # MANIFEST に載っているが実在しない
  grep -Fxv -f "$TMP/actual.txt" "$TMP/m_exact.txt" >"$TMP/missing.txt" || true
  while IFS= read -r re; do
    [ -n "$re" ] || continue
    grep -Eq "^${re}\$" "$TMP/actual.txt" || echo "(パターン) $re" >>"$TMP/missing.txt"
  done <"$TMP/m_regex.txt"
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    grep -q "^${dir}" "$TMP/actual.txt" || echo "$dir" >>"$TMP/missing.txt"
  done <"$TMP/m_dirs.txt"
  if [ -s "$TMP/missing.txt" ]; then
    fail "MANIFEST に載っているが実在しない資産"
    detail <"$TMP/missing.txt"
    problems=1
  fi

  # 実在するが MANIFEST に載っていない
  grep -Fxv -f "$TMP/m_exact.txt" "$TMP/actual.txt" >"$TMP/uncovered.txt" || true
  while IFS= read -r re; do
    [ -n "$re" ] || continue
    grep -Ev "^${re}\$" "$TMP/uncovered.txt" >"$TMP/uncovered.next" || true
    mv "$TMP/uncovered.next" "$TMP/uncovered.txt"
  done <"$TMP/m_regex.txt"
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    grep -v "^${dir}" "$TMP/uncovered.txt" >"$TMP/uncovered.next" || true
    mv "$TMP/uncovered.next" "$TMP/uncovered.txt"
  done <"$TMP/m_dirs.txt"
  if [ -s "$TMP/uncovered.txt" ]; then
    fail "実在するが MANIFEST に載っていない資産"
    detail <"$TMP/uncovered.txt"
    problems=1
  fi

  [ "$problems" -eq 0 ] && ok "MANIFEST と assets/ の実ファイルが 1:1（$(wc -l <"$TMP/actual.txt" | tr -d ' ') ファイル）"
}

# ---- 2. skill 正本と adapter の 1:1 ---------------------------------------------------------
check_skill_pairs() {
  local canon_dir="$ASSETS/docs/harness/skills" adapter_dir="$ASSETS/.claude/skills"
  (cd "$canon_dir" 2>/dev/null && ls -1 | grep -E '\.md$' | sed 's/\.md$//' | LC_ALL=C sort) >"$TMP/canon.txt" || : >"$TMP/canon.txt"
  : >"$TMP/adapters.txt"
  : >"$TMP/adapter_dirs.txt"
  if [ -d "$adapter_dir" ]; then
    local d name
    for d in "$adapter_dir"/*/; do
      [ -d "$d" ] || continue
      name="$(basename "$d")"
      echo "$name" >>"$TMP/adapter_dirs.txt"
      [ -f "$d/SKILL.md" ] && echo "$name" >>"$TMP/adapters.txt"
    done
    LC_ALL=C sort -o "$TMP/adapters.txt" "$TMP/adapters.txt"
  fi

  if [ ! -s "$TMP/canon.txt" ] || [ ! -s "$TMP/adapters.txt" ]; then
    fail "skill 正本または adapter が 0 件（docs/harness/skills/*.md と .claude/skills/*/SKILL.md）"
    return
  fi

  local problems=0
  comm -23 "$TMP/canon.txt" "$TMP/adapters.txt" >"$TMP/only_canon.txt"
  comm -13 "$TMP/canon.txt" "$TMP/adapters.txt" >"$TMP/only_adapter.txt"
  LC_ALL=C sort "$TMP/adapter_dirs.txt" | comm -23 - "$TMP/adapters.txt" >"$TMP/no_skill_md.txt"
  if [ -s "$TMP/only_canon.txt" ]; then
    fail "adapter（.claude/skills/<name>/SKILL.md）が無い skill 正本"
    detail <"$TMP/only_canon.txt"
    problems=1
  fi
  if [ -s "$TMP/only_adapter.txt" ]; then
    fail "正本（docs/harness/skills/<name>.md）が無い adapter"
    detail <"$TMP/only_adapter.txt"
    problems=1
  fi
  if [ -s "$TMP/no_skill_md.txt" ]; then
    fail "SKILL.md が無い skill ディレクトリ"
    detail <"$TMP/no_skill_md.txt"
    problems=1
  fi
  [ "$problems" -eq 0 ] && ok "skill 正本と adapter が同名で 1:1（$(wc -l <"$TMP/canon.txt" | tr -d ' ') 本）"
}

# ---- 3. 未置換 token の網羅 -----------------------------------------------------------------
check_tokens() {
  : >"$TMP/stray.txt"
  : >"$TMP/used_tokens.txt"
  local scanned=0 rel file token name allowed
  while IFS= read -r rel; do
    file="$ASSETS/$rel"
    is_form_path "$rel" && continue
    scanned=$((scanned + 1))
    # GitHub Actions の式（ドル記号 + 二重波括弧）と、波括弧 3 つの外部ツールのテンプレート構文を
    # 除いてから token を取り出す。
    sed -E -e 's/\$\{\{[^}]*\}\}//g' -e 's/\{\{\{[^}]*\}\}\}//g' "$file" 2>/dev/null |
      grep -oE '\{\{[^}]*\}\}' 2>/dev/null |
      sort -u >"$TMP/file_tokens.txt" || true
    while IFS= read -r token; do
      [ -n "$token" ] || continue
      name="$(echo "$token" | sed -E 's/^\{\{[[:space:]]*//; s/[[:space:]]*\}\}$//')"
      allowed=0
      for t in $ALLOWED_TOKENS; do [ "$t" = "$name" ] && allowed=1; done
      if [ "$allowed" -eq 1 ]; then
        [ "$rel" = "MANIFEST.md" ] || echo "$name" >>"$TMP/used_tokens.txt"
      elif [ "$rel" != "MANIFEST.md" ]; then
        echo "$rel  $token" >>"$TMP/stray.txt"
      fi
    done <"$TMP/file_tokens.txt"
  done <"$TMP/actual.txt"

  if [ "$scanned" -eq 0 ]; then
    fail "未置換 token の走査対象が 0 件"
    return
  fi

  local problems=0
  if [ -s "$TMP/stray.txt" ]; then
    fail "明示 token 4 種以外の二重波括弧 token（記入欄は docs/adr/template.md と docs/templates/ に置く）"
    detail <"$TMP/stray.txt"
    problems=1
  fi
  # 使用している token が MANIFEST の列挙に含まれること
  LC_ALL=C sort -u "$TMP/used_tokens.txt" | while IFS= read -r name; do
    [ -n "$name" ] || continue
    grep -qF "{{${name}}}" "$MANIFEST" || echo "$name"
  done >"$TMP/unlisted.txt"
  if [ -s "$TMP/unlisted.txt" ]; then
    fail "資産が使っているが MANIFEST が列挙していない token"
    detail <"$TMP/unlisted.txt"
    problems=1
  fi
  [ "$problems" -eq 0 ] && ok "二重波括弧 token は明示 token 4 種だけで、MANIFEST が列挙している（${scanned} ファイルを走査）"
}

# ---- 4. 固有語 denylist ---------------------------------------------------------------------
check_denylist() {
  if [ -z "${TEMPLATE_DENYLIST_FILE:-}" ]; then
    skip "固有語 denylist（TEMPLATE_DENYLIST_FILE が未設定）"
    return
  fi
  if [ ! -f "$TEMPLATE_DENYLIST_FILE" ]; then
    fail "TEMPLATE_DENYLIST_FILE が指すファイルが無い: $TEMPLATE_DENYLIST_FILE"
    return
  fi
  grep -vE '^[[:space:]]*(#|$)' "$TEMPLATE_DENYLIST_FILE" >"$TMP/deny.txt" || true
  if [ ! -s "$TMP/deny.txt" ]; then
    fail "denylist にパターンが 1 件も無い: $TEMPLATE_DENYLIST_FILE"
    return
  fi

  local repo_root target
  repo_root="$(cd "$SKILL_DIR/../../.." && pwd)"
  : >"$TMP/deny_hits.txt"
  for target in \
    "$ASSETS" \
    "$SKILL_DIR/references" \
    "$SKILL_DIR/SKILL.md" \
    "$SKILL_DIR/../harness-adopt/SKILL.md" \
    "$repo_root/AGENTS.md" \
    "$repo_root/CLAUDE.md" \
    "$repo_root/README.md"; do
    [ -e "$target" ] || continue
    grep -rnIiE -f "$TMP/deny.txt" "$target" >>"$TMP/deny_hits.txt" 2>/dev/null || true
  done
  if [ -s "$TMP/deny_hits.txt" ]; then
    fail "固有語 denylist に一致する箇所（$(wc -l <"$TMP/deny_hits.txt" | tr -d ' ') 件。先頭 40 件を表示）"
    head -40 "$TMP/deny_hits.txt" | sed "s|$repo_root/||" | detail
  else
    ok "固有語 denylist に一致する箇所なし"
  fi
}

# ---- 5. 配布版の機械検査（HARNESS_ROOT=assets） -----------------------------------------------
check_harness_tests() {
  if ! command -v node >/dev/null 2>&1; then
    fail "node が PATH に無い（tests/harness の実行に必要）"
    return
  fi
  if [ ! -f "$ASSETS/tests/harness/run.mjs" ]; then
    fail "tests/harness/run.mjs が無い"
    return
  fi
  if HARNESS_ROOT="$ASSETS" node "$ASSETS/tests/harness/run.mjs" >"$TMP/harness.out" 2>&1; then
    ok "HARNESS_ROOT=assets で tests/harness が通過（$(grep -E '^harness:test: 実行' "$TMP/harness.out" | tail -1)）"
  else
    fail "HARNESS_ROOT=assets の tests/harness が失敗"
    if grep -q '^失敗した検査:' "$TMP/harness.out"; then
      sed -n '/^失敗した検査:/,$p' "$TMP/harness.out" | head -60 | detail
    else
      tail -30 "$TMP/harness.out" | detail
    fi
  fi
}

echo "assets: $ASSETS"
check_manifest
check_skill_pairs
check_tokens
check_denylist
check_harness_tests

echo
if [ "$FAILS" -eq 0 ]; then
  echo "check-assets: 全検査を通過"
  exit 0
fi
echo "check-assets: $FAILS 件の検査が失敗"
exit 1
