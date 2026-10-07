#!/usr/bin/env bash
set -uo pipefail

# .claude/hooks/tests/ 配下の全 test-*.sh を列挙・並列実行し、1 つでも fail なら exit 1 する。
# CI の test job（.github/workflows/ci.yml）はこのスクリプトを呼ぶ。
#
# 各 test-*.sh は互いに独立（mktemp の隔離 repo で動く）ため並列に実行する。出力は一時ファイルへ
# 向け、全部の完了を待ってから test-*.sh の名前順に表示する（出力が混ざらない）。
# lib.sh は各テストが source する共通ヘルパで、test-*.sh ではないため実行対象にならない。
#
# 実行の前に、hooks/*.sh のそれぞれに対応する tests/test-<hook ファイル名> が存在することを
# 検査する（hook を追加してテストを書き忘れると fail する）。テストから hook への向きは
# tests/test-*.sh の自動列挙で担保されるため、配線の追加は要らない。
# hook を追加・削除・変更する場合は tests/test-<hook 名>.sh も同一 PR で追加・削除・更新する
# （詳細は ../README.md「hook を増減する時の規約」を参照）。
#
# opt-in hook（opt-in:submodule / opt-in:public-site）のテストも hermetic なため、
# hook 自体が settings.json に配線されているかどうかに関わらず、ファイルが存在すれば常時実行する。
# opt-in グループを採用しない場合は、hook 本体とそのテストを一緒に削除する。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# テスト対応を要求しない hook（hook ファイル名）。除外は理由を併記して最小に保つ。
#   session-start.sh: 主処理が mise / pnpm install などネットワーク副作用で、hermetic に
#     検証できる範囲が限られ、stub の整備コストに見合わないため。
EXEMPT_HOOKS=(session-start.sh)

missing=0
hook_count=0
for hook_file in "$HOOKS_DIR"/*.sh; do
  [[ -f "$hook_file" ]] || continue
  hook_name="$(basename "$hook_file")"
  exempt=0
  for e in "${EXEMPT_HOOKS[@]}"; do
    if [[ "$hook_name" == "$e" ]]; then
      exempt=1
      break
    fi
  done
  [[ "$exempt" -eq 1 ]] && continue
  hook_count=$((hook_count + 1))
  if [[ ! -f "$SCRIPT_DIR/test-$hook_name" ]]; then
    echo "run-all: hook $hook_name has no test (expected tests/test-$hook_name)" >&2
    missing=$((missing + 1))
  fi
done

if [[ "$hook_count" -eq 0 ]]; then
  echo "run-all: no hooks found under $HOOKS_DIR (nothing to check the tests against)" >&2
  exit 1
fi

if [[ "$missing" -gt 0 ]]; then
  echo "run-all: $missing hook(s) without a test file" >&2
  exit 1
fi

out_dir="$(mktemp -d)"
trap 'rm -rf "$out_dir"' EXIT

names=()
pids=()
for test_file in "$SCRIPT_DIR"/test-*.sh; do
  [[ -f "$test_file" ]] || continue
  name="$(basename "$test_file")"
  bash "$test_file" > "$out_dir/$name.out" 2>&1 &
  names+=("$name")
  pids+=("$!")
done

total="${#names[@]}"
if [[ "$total" -eq 0 ]]; then
  echo "run-all: no test-*.sh files found under $SCRIPT_DIR" >&2
  exit 1
fi

failures=0
for i in "${!names[@]}"; do
  name="${names[$i]}"
  echo "=== running $name ==="
  if wait "${pids[$i]}"; then
    status="OK"
  else
    status="FAILED"
    failures=$((failures + 1))
  fi
  cat "$out_dir/$name.out"
  echo "=== $name: $status ==="
  echo
done

if [[ "$failures" -gt 0 ]]; then
  echo "run-all: $failures / $total test file(s) FAILED"
  exit 1
fi

echo "run-all: all $total test file(s) PASSED"
