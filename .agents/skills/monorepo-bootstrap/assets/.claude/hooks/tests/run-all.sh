#!/usr/bin/env bash
set -uo pipefail

# .claude/hooks/tests/ 配下の全 test-*.sh を列挙・実行し、1 つでも fail なら exit 1 する。
# CI の test job（.github/workflows/ci.yml）はこのスクリプトを呼ぶ。
# hook を追加・削除・変更する場合は tests/test-<hook 名>.sh も同一 PR で追加・削除・更新し、
# 本スクリプトは追随不要（tests/test-*.sh を自動列挙するため配線漏れは起きない。
# 詳細は ../README.md「hook を増減する時の規約」を参照）。
#
# opt-in hook（現状 test-submodule-guard.sh）のテストも hermetic なため、
# hook 自体が settings.json に配線されているかどうかに関わらず常時実行する。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

failures=0
total=0

for test_file in "$SCRIPT_DIR"/test-*.sh; do
  [[ -f "$test_file" ]] || continue
  total=$((total + 1))
  name="$(basename "$test_file")"
  echo "=== running $name ==="
  if bash "$test_file"; then
    echo "=== $name: OK ==="
  else
    echo "=== $name: FAILED ==="
    failures=$((failures + 1))
  fi
  echo
done

if [[ "$total" -eq 0 ]]; then
  echo "run-all: no test-*.sh files found under $SCRIPT_DIR" >&2
  exit 1
fi

if [[ "$failures" -gt 0 ]]; then
  echo "run-all: $failures / $total test file(s) FAILED"
  exit 1
fi

echo "run-all: all $total test file(s) PASSED"
