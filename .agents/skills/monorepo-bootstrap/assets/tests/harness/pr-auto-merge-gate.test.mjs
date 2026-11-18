// opt-in:pr-auto-merge — REST 応答を差し替え、実際に送信する更新を記録する。
import assert from "node:assert/strict";
import test from "node:test";
import { runGate } from "../../scripts/pr-auto-merge/gate.mjs";

const head = "1".repeat(40);
const options = {
  mode: "merge",
  repo: "owner/repository",
  pr: "9",
  base: "dev",
  head,
  holdLabel: [],
  holdPrefix: [],
  allowLabel: [],
};
const repository = { full_name: options.repo };
const root = "repos/" + options.repo;
const pullPath = root + "/pulls/9";
const commit = root + "/commits/" + head;
const pull = {
  number: 9,
  state: "open",
  merged: false,
  draft: false,
  title: "更新",
  body: null,
  labels: [],
  head: { repo: repository, sha: head },
  base: { repo: repository, ref: "dev" },
  mergeable: true,
  mergeable_state: "clean",
};
const success = {
  id: 1,
  head_sha: head,
  status: "completed",
  conclusion: "success",
  name: "test",
};
const noStatuses = { sha: head, state: "pending", total_count: 0 };

function fixture({
  first = pull,
  last = first,
  reviews = [],
  checks = [success],
  total = checks.length,
  statuses = noStatuses,
  mergeResult = { merged: true, sha: "2".repeat(40) },
} = {}) {
  const writes = [];
  let reads = 0;
  const api = (endpoint, fields) => {
    if (fields) {
      writes.push({ endpoint, fields });
      return mergeResult;
    }
    if (endpoint === pullPath) return reads++ ? last : first;
    const url = new URL(endpoint, "https://api.example.invalid");
    assert.equal(url.searchParams.get("per_page"), "100");
    const start = (Number(url.searchParams.get("page")) - 1) * 100;
    if (url.pathname === "/" + commit + "/status")
      return {
        ...statuses,
        statuses: statuses.statuses?.slice(start, start + 100),
      };
    if (url.pathname === "/" + pullPath + "/reviews")
      return reviews.slice(start, start + 100);
    assert.equal(url.pathname, "/" + commit + "/check-runs");
    assert.equal(url.searchParams.get("filter"), "latest");
    return { total_count: total, check_runs: checks.slice(start, start + 100) };
  };
  return { api, writes };
}

test("全ページの CI と直近の人の判断を読み、審査 SHA だけを squash する", () => {
  const reviews = [
    { user: { login: "reviewer" }, state: "CHANGES_REQUESTED" },
    ...Array(99).fill({ user: { login: "other" }, state: "COMMENTED" }),
    { user: { login: "reviewer" }, state: "APPROVED" },
    { user: { login: "bot", type: "Bot" }, state: "CHANGES_REQUESTED" },
  ];
  const checks = Array.from({ length: 117 }, (_, i) => ({
    ...success,
    id: i + 1,
    conclusion: ["neutral", "skipped", "success"][i % 3],
  }));
  const f = fixture({
    reviews,
    checks,
    first: { ...pull, labels: [{ name: "human:none" }] },
  });
  assert.equal(runGate(options, f.api).status, "merged");
  assert.deepEqual(f.writes, [
    {
      endpoint: pullPath + "/merge",
      fields: { sha: head, merge_method: "squash" },
    },
  ]);
});

test("inspect は書き込まず、空 CI・途中ページの失敗・従来形式の status を見落とさない", () => {
  for (const [data, status] of [
    [{}, "ready"],
    [{ checks: [] }, "waiting"],
    [
      { checks: [{ ...success, status: "in_progress", conclusion: null }] },
      "waiting",
    ],
    [
      {
        checks: Array.from({ length: 101 }, (_, i) => ({
          ...success,
          id: i + 1,
          conclusion: i === 100 ? "cancelled" : "success",
        })),
      },
      "blocked",
    ],
    [{ checks: [{ ...success, conclusion: "timed_out" }] }, "blocked"],
    [
      { statuses: { ...noStatuses, total_count: 1, state: "failure" } },
      "blocked",
    ],
    [
      { statuses: { ...noStatuses, total_count: 1, state: "pending" } },
      "waiting",
    ],
  ]) {
    const f = fixture(data);
    assert.equal(
      runGate({ ...options, mode: "inspect" }, f.api).status,
      status,
    );
    assert.deepEqual(f.writes, []);
    if (status !== "ready") {
      assert.equal(runGate(options, f.api).status, status);
      assert.deepEqual(f.writes, []);
    }
  }
});

test("同じ SHA でも対象・保留・競合・保護ルールを更新直前に読み直す", () => {
  for (const [change, status] of [
    [{ state: "closed", merged: true }, "merged"],
    [{ state: "closed" }, "closed"],
    [{ draft: true }, "blocked"],
    [{ head: { repo: repository, sha: "9".repeat(40) } }, "changed"],
    [
      { head: { repo: { full_name: "fork/repository" }, sha: head } },
      "blocked",
    ],
    [{ base: { repo: repository, ref: "release" } }, "blocked"],
    [{ labels: [{ name: "automerge:hold" }] }, "blocked"],
    [{ labels: [{ name: "human:review" }] }, "blocked"],
    [{ labels: [{ name: "Stop" }] }, "blocked"],
    [{ title: "WIP: 更新" }, "blocked"],
    [
      {
        body: "## 人間に判断してほしい点\n- なし\n## その他\n説明\n## 人間に判断してほしい点\n- 日時を指定",
      },
      "blocked",
    ],
    [{ mergeable: null }, "waiting"],
    [{ mergeable: false }, "blocked"],
    [{ mergeable_state: "blocked" }, "blocked"],
    [{ mergeable_state: "unknown" }, "waiting"],
  ]) {
    const f = fixture({ last: { ...pull, ...change } });
    assert.equal(
      runGate({ ...options, holdLabel: ["stop"] }, f.api).status,
      status,
    );
    assert.deepEqual(f.writes, []);
  }
});

test("後からコメントが付いても人の変更要求は残る", () => {
  const user = { login: "person" };
  const reviews = [
    { user, state: "CHANGES_REQUESTED" },
    { user, state: "COMMENTED" },
  ];
  const f = fixture({ reviews });
  assert.equal(runGate(options, f.api).status, "blocked");
  assert.deepEqual(f.writes, []);
});

test("表示される保留だけを読み、インデントした人間判断の見出しも検査する", () => {
  for (const [body, expected] of [
    ["<!-- WIP のときは draft にする -->\n変更を検証済み。", "ready"],
    ["  ## 人間に判断してほしい点\n- 公開日の決定を待つ", "blocked"],
  ]) {
    const f = fixture({ first: { ...pull, body } });
    assert.equal(
      runGate({ ...options, mode: "inspect" }, f.api).status,
      expected,
    );
    assert.deepEqual(f.writes, []);
  }
});

test("従来型 CI の必須名が後続ページにあっても検出する", () => {
  const statuses = Array.from({ length: 101 }, (_, i) => ({
    context: "external-" + i,
    state: "success",
  }));
  const f = fixture({
    statuses: {
      sha: head,
      total_count: statuses.length,
      state: "success",
      statuses,
    },
  });
  assert.equal(
    runGate(
      { ...options, mode: "inspect", requiredChecks: ["external-100"] },
      f.api,
    ).status,
    "ready",
  );
  assert.deepEqual(f.writes, []);
});

test("必須の check は登録を待ち、接頭辞の例外で完全一致の保留を解除しない", () => {
  const missing = fixture();
  const requiredChecks = ["test", "build"];
  assert.deepEqual(runGate({ ...options, requiredChecks }, missing.api), {
    status: "waiting",
    reason: "必須 check 未登録",
    missing: ["build"],
  });
  assert.deepEqual(missing.writes, []);

  const marked = fixture({
    first: { ...pull, labels: [{ name: "review:ok" }] },
  });
  const labelOptions = {
    ...options,
    mode: "inspect",
    holdPrefix: ["review:"],
    allowLabel: ["review:ok"],
  };
  assert.equal(runGate(labelOptions, marked.api).status, "ready");
  assert.equal(
    runGate({ ...labelOptions, holdLabel: ["review:ok"] }, marked.api).status,
    "blocked",
  );
});

test("情報欠落・別 SHA・API エラーでは更新しない", () => {
  for (const data of [
    { total: 2 },
    { checks: [{ ...success, head_sha: "9".repeat(40) }] },
    { statuses: { state: "success" } },
    { reviews: [{ state: "CHANGES_REQUESTED", user: null }] },
  ]) {
    const f = fixture(data);
    assert.throws(() => runGate(options, f.api));
    assert.deepEqual(f.writes, []);
  }
  let writes = 0;
  assert.throws(() =>
    runGate(options, (endpoint, fields) => {
      if (fields) writes++;
      if (endpoint === pullPath) return pull;
      throw new Error("読み取り失敗");
    }),
  );
  assert.equal(writes, 0);
});

test("サーバーの拒否後に更新を送り直さない", () => {
  const f = fixture({ mergeResult: { merged: false } });
  assert.equal(runGate(options, f.api).status, "blocked");
  assert.equal(f.writes.length, 1);
});
