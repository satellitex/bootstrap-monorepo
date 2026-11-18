import assert from "node:assert/strict";
import test from "node:test";
import { checkDecision } from "../../scripts/feedback/decision.mjs";

const request = {
  parent: "parent",
  item: "1",
  proposal: "proposal",
  approver: ["reviewer"],
};
function reply(id, text, reactions = [], authorId = "bot") {
  return { id, text, authorId, isSystem: false, reactions };
}
const accept = { name: "white_check_mark", users: ["reviewer"] };
const reject = { name: "x", users: ["reviewer"] };
function adapter(replies) {
  return {
    whoami: async () => ({ userId: "bot" }),
    async replies({ parent }) {
      assert.equal(parent, request.parent);
      return replies;
    },
  };
}

test("承認・否決は最新の案に付けた登録済み user ID だけを数え、両方なら否決する", async () => {
  for (const [reactions, state] of [
    [[], "pending"],
    [[{ name: "white_check_mark", users: ["bot", "reporter"] }], "pending"],
    [[{ name: "eyes", users: ["reviewer"] }], "pending"],
    [[accept], "approved"],
    [[reject], "rejected"],
    [[reject, accept], "rejected"],
  ]) {
    const run = adapter([reply("proposal", "[修正案 1] 訂正", reactions)]);
    assert.deepEqual(await checkDecision(run, request), {
      state,
      proposalId: "proposal",
    });
  }
});

test("同じ項目の後続の案と状態遷移はそれ以前の案への票を無効にする", async () => {
  for (const label of [
    "起票案",
    "修正案",
    "起票済み",
    "更新済み",
    "取り下げ",
    "PR作成",
    "マージ済み",
    "実装見送り",
    "本番反映",
    "配布完了",
  ]) {
    const current = `[${label} 1]`;
    const run = adapter([
      reply("proposal", "[起票案 1]", [accept]),
      reply("newer", current),
    ]);
    assert.equal((await checkDecision(run, request)).state, "superseded");
    if (label !== "起票案" && label !== "修正案") {
      assert.equal(
        (await checkDecision(run, { ...request, proposal: "newer" })).state,
        "superseded",
      );
    }
  }
  assert.deepEqual(await checkDecision(adapter([]), request), {
    state: "superseded",
    proposalId: "proposal",
  });
});

test("他人・別 bot・別項目・本文の引用による区分表記で判定を変えない", async () => {
  const rows = [
    reply("proposal", "[起票案 1] 要望", [accept]),
    reply("next", "[起票案 2]", [reject]),
    reply("human", "[取り下げ 1]", [], "reporter"),
    reply("otherbot", "[起票済み 1]", [], "another-bot"),
    reply("quoted", "前回の案\n[取り下げ 1]"),
    { ...reply("system", "[取り下げ 1]"), isSystem: true },
  ];
  assert.equal((await checkDecision(adapter(rows), request)).state, "approved");
  const forged = adapter([
    reply("proposal", "[起票案 1]", [accept], "another-bot"),
  ]);
  assert.equal((await checkDecision(forged, request)).state, "superseded");
});

test("設定不備、未検証の票、読み取り失敗では承認を返さない", async () => {
  for (const invalid of [
    { item: 0 },
    { item: "1.1" },
    { item: "1e2" },
    { item: "01" },
    { item: Number.MAX_SAFE_INTEGER + 1 },
    { parent: "" },
    { proposal: " " },
    { approver: [] },
    { approver: "reviewer" },
    { approver: [""] },
    { approver: ["reviewer", "bot"] },
  ]) {
    await assert.rejects(
      checkDecision(adapter([]), { ...request, ...invalid }),
      /decision: invalid/,
    );
  }
  for (const invalid of [
    null,
    [{ name: "x" }],
    [accept, { name: "x", users: [null] }],
  ]) {
    const run = adapter([reply("proposal", "[起票案 1]", invalid)]);
    await assert.rejects(checkDecision(run, request), /decision: incomplete/);
  }
  const run = adapter([]);
  run.replies = async () => {
    throw new Error("history unavailable");
  };
  await assert.rejects(checkDecision(run, request), /history unavailable/);
});
