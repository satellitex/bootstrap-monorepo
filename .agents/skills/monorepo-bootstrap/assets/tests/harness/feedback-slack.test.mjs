import assert from "node:assert/strict";
import { test } from "node:test";
import { checkDecision } from "../../scripts/feedback/decision.mjs";
import { createSlack } from "../../scripts/feedback/slack.mjs";

const channel = "CTEST";
const parent = "1700000000.123456";
const reply = "1700000001.123456";
const user = "UWRITER";
const bot = "UBOT";
const botIdentity = { user_id: bot, bot_id: "BAPP" };

function message(ts, fields = {}) {
  return { type: "message", user, ts, text: "投稿", ...fields };
}

function simulate(responses, options = {}) {
  const calls = [];
  const sleeps = [];
  const slack = createSlack({
    channel,
    token: "bot-credential",
    ...options,
    fetch: async (url, init) => {
      const request = new URL(url);
      calls.push({
        method: request.pathname.split("/").at(-1),
        verb: init.method ?? "GET",
        token: new Headers(init.headers).get("Authorization"),
        params: Object.fromEntries(init.body ?? request.searchParams),
      });
      const next = responses[calls.length - 1];
      if (!next) throw new Error("unexpected request");
      if (next instanceof Error) throw next;
      if (next instanceof Response) return next;
      return Response.json({ ok: true, ...next });
    },
    sleep: async (ms) => sleeps.push(ms),
  });
  return { slack, calls, sleeps };
}

test("Slack 履歴をページ末尾まで収集し、重複とチャンネルへ転送されたスレッド返信を除く", async () => {
  const root = message(parent, { reply_count: 1, thread_ts: parent });
  const file = {
    id: "FIMAGE",
    name: "screen.png",
    mimetype: "image/png",
    size: 1024,
  };
  const event = message("1700000003.100000", { subtype: "channel_join" });
  const human = message("1700000002.100000", {
    subtype: "file_share",
    files: [file],
  });
  const { slack, calls } = simulate([
    {
      messages: [event, human, message(reply, { thread_ts: parent })],
      response_metadata: { next_cursor: "next" },
    },
    { messages: [human, root] },
  ]);
  const result = await slack.history({ oldest: "1699999999" });
  assert.deepEqual(
    result.map((m) => m.id),
    [parent, human.ts, event.ts],
  );
  assert.deepEqual(result[0], {
    id: parent,
    authorId: user,
    isBot: false,
    isSystem: false,
    text: root.text,
    createdAt: "2023-11-14T22:13:20.123Z",
    hasReplies: true,
    files: [],
    reactions: [],
  });
  assert.deepEqual(result[1].files, [file]);
  assert.equal(result[1].isSystem, false);
  assert.equal(result[2].isSystem, true);
  assert.equal(calls[1].params.cursor, "next");
  assert.ok(
    calls.every(
      (c) => c.params.channel === channel && c.params.oldest === "1699999999",
    ),
  );
});

test("Slack は省略された承認者・否決者を問い合わせ、同じ親の返信だけを返す", async () => {
  const proposal = message(reply, {
    thread_ts: parent,
    user: bot,
    bot_id: "BAPP",
    reactions: [{ name: "x", users: [user], count: 2 }],
  });
  const { slack, calls } = simulate(
    [
      { messages: [message(parent), proposal] },
      {
        channel,
        message: {
          ...proposal,
          reactions: [{ name: "x", users: [user, "UOWNER"], count: 2 }],
        },
      },
      botIdentity,
    ],
    { readToken: "read-credential" },
  );
  const rows = await slack.replies({ parent });
  assert.equal(rows.length, 1);
  assert.equal(rows[0].isBot, true);
  assert.equal(rows[0].authorId, bot);
  assert.deepEqual(rows[0].reactions, [{ name: "x", users: [user, "UOWNER"] }]);
  assert.deepEqual(await slack.whoami(), { userId: bot });
  assert.deepEqual(
    calls.map((c) => [c.method, c.verb, c.token]),
    [
      ["conversations.replies", "GET", "Bearer read-credential"],
      ["reactions.get", "GET", "Bearer bot-credential"],
      ["auth.test", "POST", "Bearer bot-credential"],
    ],
  );
  assert.equal(calls[1].params.full, "true");
});

test("Slack が反応者または履歴の一部しか返さなければ結果を返さない", async () => {
  const msg = message(reply, {
    thread_ts: parent,
    reactions: [{ name: "x", users: [], count: 1 }],
  });
  const { slack } = simulate([{ messages: [msg] }, { channel, message: msg }]);
  await assert.rejects(slack.replies({ parent }), /incomplete_reaction_users/);
  await assert.rejects(
    simulate([{ messages: [], has_more: true }]).slack.history({ oldest: "1" }),
    /incomplete_history/,
  );
  const page = { messages: [], response_metadata: { next_cursor: "same" } };
  await assert.rejects(
    simulate([page, page]).slack.history({ oldest: "1" }),
    /repeated_cursor/,
  );
});

test("Slack の返信は指定スレッド内に送り、投稿中のメンションを展開しない", async () => {
  const { slack, calls } = simulate(
    [botIdentity, { channel, message: message(parent) }, { ts: reply }],
    {
      readToken: "read-credential",
    },
  );
  assert.deepEqual(await slack.post({ parent, text: "<!channel> A&B" }), {
    id: reply,
  });
  const [auth, lookup, call] = calls;
  assert.equal(auth.method, "auth.test");
  assert.equal(auth.token, "Bearer bot-credential");
  assert.equal(lookup.method, "reactions.get");
  assert.equal(lookup.params.timestamp, parent);
  assert.equal(call.method, "chat.postMessage");
  assert.equal(call.token, "Bearer bot-credential");
  assert.deepEqual(call.params, {
    channel,
    thread_ts: parent,
    text: "&lt;!channel&gt; A&amp;B",
    reply_broadcast: "false",
    link_names: "false",
    unfurl_links: "false",
    unfurl_media: "false",
  });
  await assert.rejects(slack.post({ text: "本文" }), /invalid_timestamp/);
  await assert.rejects(slack.post({ parent, text: " " }), /invalid_reply_text/);
  assert.equal(calls.length, 3);
});

test("Slack の routine は承認リアクションを付けず、付与済みの印を成功として扱う", async () => {
  const { slack, calls } = simulate([
    botIdentity,
    { channel, message: message(reply, { thread_ts: parent }) },
    { ok: false, error: "already_reacted" },
  ]);
  for (const name of ["x", "white_check_mark"]) {
    await assert.rejects(
      slack.react({ parent, message: reply, name }),
      /invalid_routine_reaction/,
    );
  }
  assert.deepEqual(
    await slack.react({ parent, message: reply, name: "eyes" }),
    { id: reply, name: "eyes" },
  );
  assert.deepEqual(calls[2].params, {
    channel,
    timestamp: reply,
    name: "eyes",
  });
});

test("Slack は別のスレッドへのリアクションと別の投稿の添付取得を拒む", async () => {
  const { slack, calls } = simulate([
    botIdentity,
    { channel, message: message(reply) },
    { channel, message: message(parent, { files: [{ id: "FOTHER" }] }) },
  ]);
  await assert.rejects(
    slack.react({ parent, message: reply, name: "eyes" }),
    /message_outside_thread/,
  );
  await assert.rejects(
    slack.file({ parent, message: parent, id: "FFILE", out: "." }),
    /attachment_not_on_message/,
  );
  assert.deepEqual(
    calls.map((c) => c.method),
    ["auth.test", "reactions.get", "reactions.get"],
  );
});

test("Slack は 429 の待ち時間に従い、結果不明の返信は再送しない", async () => {
  const { slack, calls, sleeps } = simulate([
    botIdentity,
    { channel, message: message(parent) },
    new Response(null, { status: 429, headers: { "Retry-After": "2" } }),
    new Error("private request body"),
  ]);
  await assert.rejects(slack.post({ parent, text: "投稿案" }), {
    message: "slack: chat.postMessage: network_error",
  });
  assert.deepEqual(sleeps, [2000]);
  assert.equal(calls.length, 4);
});

test("Slack のファイル ID が一致しても外部ホストへ token を送らない", async () => {
  const file = {
    id: "FIMAGE",
    name: "screen.png",
    mimetype: "image/png",
    size: 1024,
    url_private: "https://example.org/image.png",
  };
  const { slack, calls } = simulate([
    { channel, message: message(parent, { files: [file] }) },
    { file },
  ]);
  const result = await slack.file({
    parent,
    message: parent,
    id: file.id,
    out: ".",
  });
  assert.equal(result.downloaded, false);
  assert.deepEqual(
    calls.map((call) => call.method),
    ["reactions.get", "files.info"],
  );
});

test("Slack は返信先に別の返信の ID を指定されたら送信しない", async () => {
  const { slack, calls } = simulate([
    botIdentity,
    { channel, message: message(reply, { thread_ts: parent }) },
  ]);
  await assert.rejects(
    slack.post({ parent: reply, text: "更新" }),
    /message_outside_thread/,
  );
  assert.deepEqual(
    calls.map((c) => c.method),
    ["auth.test", "reactions.get"],
  );
});

test("Slack は user token での投稿とリアクションを本人確認で止める", async () => {
  for (const write of [
    (slack) => slack.post({ parent, text: "返信" }),
    (slack) => slack.react({ parent, message: parent, name: "eyes" }),
  ]) {
    const { slack, calls } = simulate([{ user_id: user }]);
    await assert.rejects(write(slack), /slack_bot_identity_required/);
    assert.deepEqual(
      calls.map((call) => call.method),
      ["auth.test"],
    );
  }
});

test("Slack の bot_id だけの返信は担当 bot のものだけを承認判定に使う", async () => {
  const approved = {
    type: "message",
    subtype: "bot_message",
    bot_id: "BAPP",
    ts: reply,
    thread_ts: parent,
    text: "[起票案 1] 案",
    reactions: [{ name: "white_check_mark", users: [user], count: 1 }],
  };
  const foreign = {
    ...approved,
    ts: "1700000002.123456",
    bot_id: "BOTHER",
    text: "[取り下げ 1] 別 bot の返信",
  };
  const { slack, calls } = simulate([
    botIdentity,
    { messages: [message(parent), approved, foreign] },
  ]);
  assert.deepEqual(
    await checkDecision(slack, {
      parent,
      item: "1",
      proposal: reply,
      approver: [user],
    }),
    { state: "approved", proposalId: reply },
  );
  assert.deepEqual(
    calls.map((call) => call.method),
    ["auth.test", "conversations.replies"],
  );
});
