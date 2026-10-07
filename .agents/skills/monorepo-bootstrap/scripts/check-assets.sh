#!/usr/bin/env bash
# テンプレート資産（assets/）の整合検査。テンプレート repo の保守専用で、bootstrap 先へは配布しない。
#
#   bash .agents/skills/monorepo-bootstrap/scripts/check-assets.sh
#
# 検査:
#   1. assets/MANIFEST.md の「資産一覧」節の表（第 1 列 = 資産パス）と assets/ の実ファイルが 1:1
#      （`<name>` や `*` を含む行はパターンとして展開し、末尾 `/` の行はディレクトリ配下全体）
#   2. 未置換 token: assets 内の二重波括弧 token が明示 token 4 種だけで、MANIFEST が列挙している
#      （対象外: 記入欄（冒頭 5 行以内に `<!-- harness:form -->` を持つファイル）、台帳 MANIFEST.md 自身、
#      GitHub Actions の式、波括弧 3 つの外部ツールのテンプレート構文）
#   3. 固有語 denylist: 環境変数 TEMPLATE_DENYLIST_FILE が指すファイル（1 行 1 パターンの拡張正規表現、
#      `#` 始まりはコメント）を、assets / references / SKILL.md / ルートの入口文書に対して照合する。
#      denylist を repo に置くと固有語そのものが混入するため、ファイルは repo 外に置く。未設定なら skip
#   4. HARNESS_ROOT=assets、HARNESS_TEMPLATE_ROOT=1（テンプレートモード）で tests/harness/run.mjs
#      （配布版の機械検査）を実行
#   5. assets を複製して MANIFEST.md を除き、明示 token を置換した状態（bootstrap 直後の配布先と同じ形）で
#      tests/harness/run.mjs を実行する。置換後にだけ現れる違反（owner の直書きなど）を検出する
#   6. opt-in グループの除去シミュレーション: MANIFEST の区分（資産一覧の区分列と、節見出しの
#      `opt-in:<group>`）からグループごとの資産を導出し、5 の複製からそのグループの資産を除いた状態で
#      tests/harness/run.mjs を実行する。削除済み資産へのパス参照が残って検査が失敗する場合、失敗する
#      ファイルが、除去資産のパス・名前（skill は `/<name>` と `routine:<name>`、空になったディレクトリを含む）
#      の grep で見つかること、つまり MANIFEST のグループ除去手順で処理できることを確かめる（見つからない
#      失敗は、手順の取りこぼしとして失敗にする）。除去資産の名前（README.md など汎用の名前はパス）が残る
#      ファイルは、残存箇所として報告する
#
# skill 正本と adapter の 1:1 は、4 と 5 の tests/harness（check-harness-structure）が検査する。
# 4 から 6 は並列に実行し、結果は上の順に表示する。
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
HARNESS_RUN="$ASSETS/tests/harness/run.mjs"

# 明示 token（bootstrap 時に置換される二重波括弧の名前）と、bootstrap 直後の状態を作るときの置換値
# （NAME=値）。名前の集合は MANIFEST と tests/harness/support/repo-files.mjs の EXPLICIT_TOKENS と
# 同じに保つ。
TOKEN_SAMPLES="PRODUCT_NAME=Acme GITHUB_ORG=acme REPO_NAME=widgets PROJECT_LANGUAGE=日本語"

ALLOWED_TOKENS=""
SED_RULES=()
for kv in $TOKEN_SAMPLES; do
  ALLOWED_TOKENS="$ALLOWED_TOKENS ${kv%%=*}"
  SED_RULES+=(-e "s/{{${kv%%=*}}}/${kv#*=}/g")
done

# token_sample NAME: TOKEN_SAMPLES の置換値を返す。
token_sample() {
  local kv
  for kv in $TOKEN_SAMPLES; do
    [ "${kv%%=*}" = "$1" ] && echo "${kv#*=}"
  done
}

# 置換対象外の記入欄（コピーして埋める様式）がファイル冒頭 5 行以内に置く自己宣言のマーカー。
# tests/harness/check-doc-placeholders.test.mjs の FORM_MARKER と同じ値を保つ。
FORM_MARKER='<!-- harness:form -->'

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP:?}"' EXIT

FAILS=0
ok() { echo "ok:   $*"; }
skip() { echo "skip: $*"; }
fail() {
  echo "FAIL: $*"
  FAILS=$((FAILS + 1))
}
detail() { sed 's/^/        /'; }

# is_form_file PATH: 記入欄（冒頭 5 行以内に FORM_MARKER だけの行がある）か。
is_form_file() {
  head -n 5 "$1" 2>/dev/null | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -qxF -- "$FORM_MARKER"
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

# ---- 2. 未置換 token の網羅 -----------------------------------------------------------------
check_tokens() {
  : >"$TMP/stray.txt"
  : >"$TMP/used_tokens.txt"
  # 二重波括弧を含むファイルだけを走査する。
  (cd "$ASSETS" && grep -rlF --exclude=.DS_Store '{{' . 2>/dev/null | sed 's|^\./||' | LC_ALL=C sort) >"$TMP/token_files.txt"
  local scanned=0 rel file token name allowed t
  while IFS= read -r rel; do
    [ "$rel" = "MANIFEST.md" ] && continue
    file="$ASSETS/$rel"
    is_form_file "$file" && continue
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
        echo "$name" >>"$TMP/used_tokens.txt"
      else
        echo "$rel  $token" >>"$TMP/stray.txt"
      fi
    done <"$TMP/file_tokens.txt"
  done <"$TMP/token_files.txt"

  if [ "$scanned" -eq 0 ]; then
    fail "未置換 token の走査対象（二重波括弧を含むファイル）が 0 件"
    return
  fi

  local problems=0
  if [ -s "$TMP/stray.txt" ]; then
    fail "明示 token 4 種以外の二重波括弧 token（記入欄は冒頭 5 行以内に ${FORM_MARKER} を置く）"
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
  [ "$problems" -eq 0 ] && ok "二重波括弧 token は明示 token 4 種だけで、MANIFEST が列挙している（二重波括弧を含む ${scanned} ファイルを走査）"
}

# ---- 3. 固有語 denylist ---------------------------------------------------------------------
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
    # ファイル名・ディレクトリ名も照合する
    find "$target" -print 2>/dev/null | sed "s|^$repo_root/||" | grep -iE -f "$TMP/deny.txt" | sed 's|^|(path) |' >>"$TMP/deny_hits.txt" || true
  done
  if [ -s "$TMP/deny_hits.txt" ]; then
    fail "固有語 denylist に一致する箇所（$(wc -l <"$TMP/deny_hits.txt" | tr -d ' ') 件。先頭 40 件を表示）"
    head -40 "$TMP/deny_hits.txt" | sed "s|$repo_root/||" | detail
  else
    ok "固有語 denylist に一致する箇所なし"
  fi
}

# ---- 4〜6. tests/harness の実行 ----------------------------------------------------------------

# harness_exec ROOT OUTFILE [VAR=val…]: ROOT を HARNESS_ROOT として tests/harness/run.mjs を実行し、
# 出力を OUTFILE に書く。run.mjs の終了コードを返す。
harness_exec() {
  local root="$1" out="$2"
  shift 2
  env HARNESS_ROOT="$root" "$@" node "$HARNESS_RUN" >"$out" 2>&1
}

# run_harness LABEL ROOT OUTFILE [VAR=val…]: harness_exec の結果を ok / FAIL で報告する。
run_harness() {
  local label="$1" root="$2" out="$3"
  shift 3
  if harness_exec "$root" "$out" "$@"; then
    ok "$label が通過（$(grep -E '^harness:test: 実行' "$out" | tail -1)）"
  else
    fail "$label が失敗"
    if grep -q '^失敗した検査:' "$out"; then
      sed -n '/^失敗した検査:/,$p' "$out" | head -60 | detail
    else
      tail -30 "$out" | detail
    fi
  fi
}

# run_parallel TASK…: TASK（`関数名` または `関数名:引数`）をバックグラウンドで実行し、すべて終わってから
# 引数の順に出力を表示する。サブシェルの FAILS は親に届かないため、失敗の件数は出力の FAIL 行から数える。
run_parallel() {
  local task fn arg report
  for task in "$@"; do
    fn="${task%%:*}"
    arg=""
    case "$task" in *:*) arg="${task#*:}" ;; esac
    report="$TMP/report_$(echo "$task" | tr -c 'A-Za-z0-9\n' '_')"
    "$fn" "$arg" >"$report" 2>&1 &
  done
  wait
  for task in "$@"; do
    report="$TMP/report_$(echo "$task" | tr -c 'A-Za-z0-9\n' '_')"
    cat "$report"
    FAILS=$((FAILS + $(grep -c '^FAIL:' "$report")))
  done
}

BOOTSTRAPPED="$TMP/bootstrapped"

# prepare_bootstrapped: assets を複製して MANIFEST.md を除き、記入欄を除いて明示 token を置換する
# （bootstrap 直後の配布先と同じ形）。
prepare_bootstrapped() {
  mkdir -p "$BOOTSTRAPPED"
  cp -R "$ASSETS/." "$BOOTSTRAPPED/"
  rm -f "${BOOTSTRAPPED:?}/MANIFEST.md"
  local f
  grep -rlF --null --exclude=.DS_Store '{{' "$BOOTSTRAPPED" 2>/dev/null |
    while IFS= read -r -d '' f; do
      is_form_file "$f" || printf '%s\0' "$f"
    done >"$TMP/replace_list"
  if [ -s "$TMP/replace_list" ]; then
    xargs -0 sed -i.bak "${SED_RULES[@]}" <"$TMP/replace_list"
  fi
  find "$BOOTSTRAPPED" -name '*.bak' -delete
}

# ---- 4. 配布版の機械検査（HARNESS_ROOT=assets、テンプレートモード） ---------------------------
check_harness_tests() {
  run_harness "HARNESS_ROOT=assets で tests/harness" "$ASSETS" "$TMP/harness.out" HARNESS_TEMPLATE_ROOT=1
}

# ---- 5. token 置換後の配布先モードでの機械検査 -------------------------------------------------
check_bootstrapped_harness() {
  run_harness "token 置換後の配布先モードで tests/harness" "$BOOTSTRAPPED" "$TMP/bootstrapped.out" \
    GITHUB_REPOSITORY="$(token_sample GITHUB_ORG)/$(token_sample REPO_NAME)"
}

# ---- 6. opt-in グループの除去シミュレーション ---------------------------------------------------

# derive_groups: MANIFEST から opt-in グループの一覧（$TMP/groups.txt）と、グループごとの資産
# （$TMP/group_assets.tsv の `グループ<TAB>パス`）を導出する。資産は、資産一覧の区分列の
# `opt-in:<group>` と、節見出しの `opt-in:<group>` から読む。パターン行（`<name>` を含む行）は
# 読まない。skill 正本の adapter は「正本と同区分」の行で、check_group_removal が正本から導く。
derive_groups() {
  awk '
    /^## / { insec = ($0 ~ /^## opt-in グループ[[:space:]]*$/); next }
    insec && /^\| `opt-in:/ { g = $0; sub(/^\| `/, "", g); sub(/`.*$/, "", g); print g }' "$MANIFEST" |
    LC_ALL=C sort -u >"$TMP/groups.txt"
  awk '
    /^## / { insec = ($0 ~ /^## 資産一覧[[:space:]]*$/); sg = ""; next }
    insec && /^### / { sg = ""; if (match($0, /opt-in:[a-z-]+/)) sg = substr($0, RSTART, RLENGTH); next }
    insec && /^\|/ {
      n = split($0, c, "|")
      p = c[2]; gsub(/^[ \t]+|[ \t]+$/, "", p); gsub(/`/, "", p)
      if (p !~ /^[A-Za-z0-9._\/-]+$/ || p !~ /[.\/]/) next
      g = sg
      last = c[n - 1]; gsub(/^[ \t]+|[ \t]+$/, "", last)
      if (last ~ /^opt-in:[a-z-]+$/) g = last
      if (g != "") print g "\t" p
    }' "$MANIFEST" >"$TMP/group_assets.tsv"
}

# unlisted_lines LISTED_FILE: 標準入力の各行のうち、先頭の語（パス）が LISTED_FILE のパスにもその配下にも
# 当たらない行を出す。
unlisted_lines() {
  awk '
    FILENAME == ARGV[1] { listed[$0] = 1; next }
    { f = $1; ok = 0; for (l in listed) if (f == l || index(f, l "/") == 1) ok = 1; if (!ok) print }' "$1" -
}

# check_group_removal GROUP: GROUP の資産を除いた状態で tests/harness を実行する。
check_group_removal() {
  local group="$1" name dst removed needles hits out p base needle count
  name="${group#opt-in:}"
  dst="$TMP/removed_$name"
  removed="$TMP/removed_$name.txt"
  needles="$TMP/needles_$name.txt"
  hits="$TMP/hits_$name.txt"

  awk -F'\t' -v g="$group" '$1 == g { print $2 }' "$TMP/group_assets.tsv" >"$removed.base"
  if [ ! -s "$removed.base" ]; then
    fail "$group の資産を MANIFEST の区分から 1 件も導出できない"
    return
  fi
  # skill 正本の adapter（.claude/skills/<name>/SKILL.md）は正本と同じ区分で、正本と一緒に除く。
  # skill の名前（/<name> と routine:<name>）は、除去後に残る参照を探す語に加える。
  cp "$removed.base" "$removed"
  : >"$needles"
  while IFS= read -r p; do
    case "$p" in
      docs/harness/skills/*.md)
        base="${p#docs/harness/skills/}"
        case "$base" in
          */*) ;;
          *)
            echo ".claude/skills/${base%.md}/SKILL.md" >>"$removed"
            printf '%s\n' "/${base%.md}" "routine:${base%.md}" >>"$needles"
            ;;
        esac
        ;;
    esac
  done <"$removed.base"

  mkdir -p "$dst"
  cp -R "$BOOTSTRAPPED/." "$dst/"
  while IFS= read -r p; do rm -f "${dst:?}/${p:?}"; done <"$removed"
  # 空になったディレクトリも除く（git は空のディレクトリを持たない）。その名前も探す語に加える。
  find "$dst" -type d -empty -print -delete | sed "s|^$dst/||" >>"$needles"
  # 除去資産の名前（README.md など汎用の名前はパス）も探す語に加える。
  while IFS= read -r p; do
    base="$(basename "$p")"
    case "$base" in README.md | INDEX.md | SKILL.md) base="$p" ;; esac
    echo "$base" >>"$needles"
  done <"$removed"

  # 除去資産のパス・名前を残りのファイルで grep する（MANIFEST のグループ除去手順の検索）。
  # tests/harness/ の除外定数は、現れない参照を許す設計のため対象にしない。
  LC_ALL=C sort -u "$needles" | while IFS= read -r needle; do
    [ -n "$needle" ] || continue
    (cd "$dst" && grep -rlF --exclude=.DS_Store -- "$needle" . 2>/dev/null) |
      sed 's|^\./||' | grep -v '^tests/harness/' | awk -v n="$needle" '{ print $0 "\t" n }'
  done >"$hits.all"
  cut -f1 "$hits.all" | LC_ALL=C sort -u >"$hits"
  count="$(wc -l <"$hits" | tr -d ' ')"

  out="$TMP/removed_$name.out"
  if harness_exec "$dst" "$out" GITHUB_REPOSITORY="$(token_sample GITHUB_ORG)/$(token_sample REPO_NAME)"; then
    ok "$group を除去した状態で tests/harness が通過（除去資産の名前が残るファイル ${count} 件）"
  else
    # 失敗した検査が指すファイルを集める。ファイルを指さない失敗は「帰属不明」として扱う。
    awk '
      /^失敗した検査:/ { insec = 1; next }
      !insec { next }
      /^✖ / { if (open && !got) print "(帰属不明) " title; open = 1; got = 0; title = $0; next }
      $0 ~ "^      [A-Za-z0-9._][A-Za-z0-9._/-]*(:[0-9]+)?  " { got = 1; p = $1; sub(/:[0-9]+$/, "", p); print p; next }
      END { if (open && !got) print "(帰属不明) " title }' "$out" | LC_ALL=C sort -u >"$TMP/flagged_$name.txt"
    unlisted_lines "$hits" <"$TMP/flagged_$name.txt" >"$TMP/unfound_$name.txt"
    if [ -s "$TMP/unfound_$name.txt" ]; then
      fail "$group を除去した状態の tests/harness が、除去資産のパス・名前の grep で見つからない箇所で失敗する（MANIFEST のグループ除去手順の取りこぼし）"
      detail <"$TMP/unfound_$name.txt"
      sed -n '/^失敗した検査:/,$p' "$out" | head -30 | detail
    else
      ok "$group を除去した状態で tests/harness が失敗する箇所は、すべて除去資産のパス・名前の grep で見つかる（失敗 $(wc -l <"$TMP/flagged_$name.txt" | tr -d ' ') ファイル、残存 ${count} ファイル）"
    fi
  fi
  if [ -s "$hits.all" ]; then
    LC_ALL=C sort -u "$hits.all" | awk -F'\t' '
      { if ($1 == prev) acc = acc ", " $2; else { if (prev != "") print prev "  <- " acc; prev = $1; acc = $2 } }
      END { if (prev != "") print prev "  <- " acc }' | detail
  fi
}

check_group_removals() {
  derive_groups
  if [ ! -s "$TMP/groups.txt" ]; then
    fail "MANIFEST の「opt-in グループ」節の表から、グループを 1 件も読めない"
    return
  fi
  # 資産一覧に現れるグループは、グループ表にも載っていること
  cut -f1 "$TMP/group_assets.tsv" | LC_ALL=C sort -u | comm -23 - "$TMP/groups.txt" >"$TMP/unknown_groups.txt"
  if [ -s "$TMP/unknown_groups.txt" ]; then
    fail "資産一覧が使っているが、MANIFEST の opt-in グループ表に無いグループ"
    detail <"$TMP/unknown_groups.txt"
    return
  fi
  local tasks=() g
  while IFS= read -r g; do tasks+=("check_group_removal:$g"); done <"$TMP/groups.txt"
  run_parallel "${tasks[@]}"
}

echo "assets: $ASSETS"
check_manifest
check_tokens
check_denylist

if ! command -v node >/dev/null 2>&1 || [ ! -f "$HARNESS_RUN" ]; then
  fail "tests/harness の実行に必要な node または tests/harness/run.mjs が無い"
else
  prepare_bootstrapped
  run_parallel check_harness_tests check_bootstrapped_harness
  check_group_removals
fi

echo
if [ "$FAILS" -eq 0 ]; then
  echo "check-assets: 全検査を通過"
  exit 0
fi
echo "check-assets: $FAILS 件の検査が失敗"
exit 1
