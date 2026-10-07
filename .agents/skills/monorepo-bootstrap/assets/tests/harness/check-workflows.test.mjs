// workflow 構造 gate: .github/workflows/ の各 workflow が、空でなく、jobs を持つことを検査する。
//
// 空ファイルや jobs を持たない workflow は、push のたびに job 0 件の失敗 run を記録し続ける一方、
// PR の CI は緑のままになる。個別の workflow を対象にする検査では、対象にならない workflow の
// 空・破損を拾えないため、全 workflow を列挙して検査する。
//
// 限界: YAML のパーサを使わない簡易判定（トップレベルの `jobs:` と、その配下にインデントされた
// job キーが 1 つ以上あること）。インデントの崩れやタブの混入などのパース不能は検出できない。
// 構文・式まで検査する場合は actionlint などの専用 linter を追加する。

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  REPO_SCAN_TEST_TIMEOUT_MS,
  assertNoViolations,
  listWorkflowFiles,
  readRepoFile,
} from "./support/repo-files.mjs";

/** コメントと空行を除いた行。 */
function significantLines(text) {
  return text
    .split("\n")
    .map((line) => line.replace(/(^|\s)#.*$/, "").replace(/\s+$/, ""))
    .filter((line) => line.trim() !== "");
}

/** workflow 本文の問題を返す（空配列なら正常）。 */
function workflowProblems(text) {
  const lines = significantLines(text);
  if (lines.length === 0) return ["空（コメントと空行だけ）"];
  const jobsIndex = lines.findIndex((l) => /^jobs:\s*$/.test(l));
  if (jobsIndex === -1) {
    return [
      lines.some((l) => /^jobs:/.test(l))
        ? "トップレベルの jobs が空（block 形式で job を書く）"
        : "トップレベルの jobs が無い",
    ];
  }
  const rest = lines.slice(jobsIndex + 1);
  const nextTopLevel = rest.findIndex((l) => /^\S/.test(l));
  const body = nextTopLevel === -1 ? rest : rest.slice(0, nextTopLevel);
  const hasJob = body.some((l) => /^\s+[A-Za-z_][\w-]*:/.test(l));
  return hasJob ? [] : ["jobs の配下に job が 1 つも無い"];
}

describe("workflow 構造 gate: .github/workflows/", () => {
  it(
    "workflow が 1 件以上ある（退化ガード）",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      assert.ok(
        listWorkflowFiles().length > 0,
        ".github/workflows/ に workflow が 0 件",
      );
    },
  );

  it(
    "各 workflow が空でなく、jobs を持つ",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const violations = [];
      for (const rel of listWorkflowFiles()) {
        for (const problem of workflowProblems(readRepoFile(rel))) {
          violations.push({ file: rel, line: 1, message: problem });
        }
      }
      assertNoViolations(assert, "workflow の構造違反", violations);
    },
  );
});

describe("workflow 構造 gate: 自己テスト", () => {
  it("空・コメントだけの workflow を検出する", () => {
    assert.deepEqual(workflowProblems(""), ["空（コメントと空行だけ）"]);
    assert.deepEqual(workflowProblems("# メモだけ\n\n"), [
      "空（コメントと空行だけ）",
    ]);
  });

  it("jobs が無い・空の workflow を検出する", () => {
    assert.deepEqual(workflowProblems("name: CI\non: push\n"), [
      "トップレベルの jobs が無い",
    ]);
    assert.deepEqual(workflowProblems("name: CI\njobs: {}\n"), [
      "トップレベルの jobs が空（block 形式で job を書く）",
    ]);
    assert.deepEqual(workflowProblems("name: CI\njobs:\non: push\n"), [
      "jobs の配下に job が 1 つも無い",
    ]);
  });

  it("job を持つ workflow は通す（コメント内の jobs: は数えない）", () => {
    const ok = [
      "# jobs: はコメント",
      "name: CI",
      "on:",
      "  pull_request:",
      "jobs:",
      "  test:",
      "    runs-on: ubuntu-latest",
      "    steps:",
      "      - run: echo hi",
      "",
    ].join("\n");
    assert.deepEqual(workflowProblems(ok), []);
    assert.deepEqual(workflowProblems("# jobs:\nname: CI\n"), [
      "トップレベルの jobs が無い",
    ]);
  });

  it("jobs の後ろに別のトップレベルキーがあっても job の有無を判定する", () => {
    const ok = "jobs:\n  a:\n    runs-on: x\nenv:\n  K: v\n";
    assert.deepEqual(workflowProblems(ok), []);
    const none = "jobs:\nenv:\n  K: v\n";
    assert.deepEqual(workflowProblems(none), [
      "jobs の配下に job が 1 つも無い",
    ]);
  });
});
