// Discord の応答を fixture とし、実際の bot やチャンネルを使わず契約を検証する。
import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { createDiscord } from "../../scripts/feedback/discord.mjs";

const channel = "10";
const parent = "30";
const message = "40";
const text = "[起票案 1] @everyone <@11>";
const rootPath = `/channels/${channel}/messages/${parent}`;
const threadPath = `/channels/${parent}/messages`;
const readPerms = (1n << 10n) | (1n << 16n);
function msg(id, channelId, other = {}) {
  return {
    id,
    channel_id: channelId,
    author: { id: "12" },
    type: 0,
    flags: 0,
    content: "確認",
    timestamp: "2020-02-01T12:00:00Z",
    attachments: [],
    ...other,
  };
}

function fixture(handle, setup = {}) {
  const calls = [];
  const waits = [];
  const defaults = {
    "/users/@me": { id: "11", bot: true },
    "/channels/10": { id: channel, guild_id: "9", type: 0 },
    "/applications/@me": { flags: 1 << 19 },
    "/channels/10/permissions/member/11": { permissions: String(readPerms) },
    ...setup,
  };
  const client = createDiscord({
    channel,
    token: "test",
    sleep: (ms) => waits.push(ms),
    async fetch(input, init) {
      const url = new URL(input);
      const path =
        decodeURIComponent(url.pathname.replace(/^\/api\/v10/, "")) +
        url.search;
      const call = {
        url,
        path,
        ...init,
        body: init.body && JSON.parse(init.body),
      };
      calls.push(call);
      const data = Object.hasOwn(defaults, path)
        ? defaults[path]
        : handle(call);
      if (data instanceof Response) return data;
      if (data === undefined) throw new Error("unhandled request");
      return Response.json(data);
    },
  });
  return { client, calls, waits };
}

test("Discord の history は全ページを古い順に返し、最古時刻で打ち切る", async () => {
  const start = 1n << 56n;
  const firstPage = Array.from({ length: 100 }, (_, i) =>
    msg(String(start - BigInt(i)), channel),
  );
  const oldestId = firstPage.at(-1).id;
  const next = msg(String(start - 100n), channel, { webhook_id: "13" });
  const belowWindow = msg(String(start - 101n), channel, {
    timestamp: "2020-01-01T00:00:00Z",
  });
  const { client, calls } = fixture(({ path }) => {
    if (path === "/channels/10/messages?limit=100") return firstPage;
    if (path === `/channels/10/messages?limit=100&before=${oldestId}`)
      return [next, belowWindow];
  });
  const rows = await client.history({
    oldest: String(Date.parse("2020-02-01") / 1000),
  });
  assert.equal(rows.length, 101);
  assert.equal(rows[0].id, next.id);
  assert.equal(rows[0].isBot, true);
  assert.equal(rows.at(-1).id, String(start));
  assert.equal(rows.at(-1).createdAt, "2020-02-01T12:00:00.000Z");
  assert.deepEqual(await client.whoami(), { userId: "11" });
  assert.ok(
    calls.every(
      (call) =>
        call.url.hostname === "discord.com" &&
        call.headers.Authorization === "Bot test",
    ),
  );
});

test("本文の intent・履歴権限・チャンネル種別を確認できなければ読み取りに失敗する", async () => {
  for (const [setup, error] of [
    [{ "/applications/@me": { flags: 0 } }, /message_content_required/],
    [
      { "/channels/10/permissions/member/11": { permissions: "1024" } },
      /history_permission_required/,
    ],
    [
      { "/channels/10": { id: channel, guild_id: "9", type: 15 } },
      /guild_text_channel_required/,
    ],
  ]) {
    const { client, calls } = fixture(() => [], setup);
    await assert.rejects(client.history({ oldest: "0" }), error);
    assert.ok(calls.every((call) => !call.path.includes("/messages")));
  }
});

test("Discord の replies は疑似親を除き、通常・バーストの各反応をユーザーIDまで読む", async () => {
  const reactionPath = `${threadPath}/${message}/reactions/✅`;
  const { client } = fixture(({ path }) => {
    if (path === rootPath) return msg(parent, channel, { flags: 32 });
    if (path === `${threadPath}?limit=100`)
      return [
        msg(message, parent, {
          author: { id: "11", bot: true },
          reactions: [
            {
              emoji: { name: "✅", id: null },
              count: 102,
              count_details: { normal: 101, burst: 1 },
            },
            { emoji: { name: "❌", id: "13" }, count: 1 },
          ],
        }),
        msg("31", parent, { type: 21 }),
      ];
    if (path === `${reactionPath}?limit=100&type=0&after=0`)
      return Array.from({ length: 100 }, (_, i) => ({ id: String(i + 1) }));
    if (path === `${reactionPath}?limit=100&type=0&after=100`)
      return [{ id: "101" }];
    if (path === `${reactionPath}?limit=100&type=1&after=0`)
      return [{ id: "101" }];
  });
  const rows = await client.replies({ parent });
  assert.equal(rows.length, 1);
  assert.equal(rows[0].isBot, true);
  assert.deepEqual(rows[0].reactions, [
    {
      name: "white_check_mark",
      users: Array.from({ length: 101 }, (_, i) => String(i + 1)),
    },
  ]);
});

test("Discord は親投稿にスレッドがない間は返信を作らずに読める", async () => {
  const { client, calls } = fixture(
    ({ path }) => path === rootPath && msg(parent, channel),
  );
  assert.deepEqual(await client.replies({ parent }), []);
  await assert.rejects(
    client.react({ parent, message, name: "eyes" }),
    /thread_missing/,
  );
  assert.ok(calls.every((call) => call.method === "GET"));
});

test("Discord は親のスレッドを作成または再利用し、メンションを無効にして投稿する", async () => {
  for (const scenario of ["new", "existing", "concurrent"]) {
    const { client, calls } = fixture(({ path }) => {
      if (path === rootPath)
        return msg(parent, channel, {
          flags: scenario === "existing" ? 32 : 0,
        });
      if (path === `${rootPath}/threads`)
        return scenario === "concurrent"
          ? Response.json({ code: 160004 }, { status: 400 })
          : { id: parent };
      if (path === threadPath) return { id: message };
    });
    assert.deepEqual(await client.post({ parent, text }), { id: message });
    const writes = calls.filter((call) => call.method === "POST");
    assert.deepEqual(
      writes.map((c) => c.path),
      scenario === "existing"
        ? [threadPath]
        : [`${rootPath}/threads`, threadPath],
    );
    assert.deepEqual(writes.at(-1).body, {
      content: text,
      allowed_mentions: { parse: [] },
    });
  }
});

test("Discord は 429 の待機時間を守り、通信結果が不明な書き込みを再送しない", async () => {
  let reads = 0;
  const { client, waits, calls } = fixture(({ path }) => {
    if (path === rootPath && reads++ === 0)
      return Response.json({ retry_after: 0.5 }, { status: 429 });
    if (path === rootPath) return msg(parent, channel, { flags: 32 });
    if (path === threadPath) throw new Error("sample private message body");
  });
  await assert.rejects(client.post({ parent, text }), {
    message: "discord: network_error",
  });
  assert.deepEqual(waits, [500]);
  assert.equal(calls.filter((call) => call.method === "POST").length, 1);
});

test("Discord は親と返信でリアクションの送信先を切り替え、承認の代行を拒む", async () => {
  const { client, calls } = fixture(({ path, method }) => {
    if (path === rootPath) return msg(parent, channel, { flags: 32 });
    if (path === `${threadPath}/${message}`) return msg(message, parent);
    if (method === "PUT") return new Response(null, { status: 204 });
  });
  await assert.rejects(
    client.react({ parent, message, name: "white_check_mark" }),
    /invalid_feedback_reaction/,
  );
  await assert.rejects(
    client.post({ parent, text: "長".repeat(2001) }),
    /invalid_discord_reply_text/,
  );
  await assert.rejects(
    client.post({ parent: "../50", text }),
    /invalid_discord_id/,
  );
  await client.react({ parent, message: parent, name: "checkered_flag" });
  await client.react({ parent, message, name: "eyes" });
  assert.deepEqual(
    calls.filter((call) => call.method === "PUT").map((call) => call.path),
    [
      `${rootPath}/reactions/🏁/@me`,
      `${threadPath}/${message}/reactions/👀/@me`,
    ],
  );
});

test("Discord は指定した投稿の添付を確認し、認証情報なしで Discord CDN から保存する", async (t) => {
  const out = await mkdtemp(join(tmpdir(), "feedback-discord-"));
  t.after(() => rm(out, { recursive: true, force: true }));
  const attachment = {
    id: "50",
    filename: "note.txt",
    content_type: "text/plain",
    size: 2,
    url: "https://cdn.discordapp.com/attachments/sample/note.txt",
  };
  const { client, calls } = fixture(({ path, url }) => {
    if (path === rootPath) return msg(parent, channel, { flags: 32 });
    if (path === `${threadPath}/${message}`)
      return msg(message, parent, { attachments: [attachment] });
    if (url.host === "cdn.discordapp.com") return new Response("OK");
  });
  await assert.rejects(
    client.file({ parent, message, id: "51", out }),
    /attachment_not_in_message/,
  );
  const result = await client.file({ parent, message, id: "50", out });
  assert.ok(result.downloaded);
  assert.equal(await readFile(result.path, "utf8"), "OK");
  assert.equal(calls.at(-1).headers.Authorization, undefined);
});
