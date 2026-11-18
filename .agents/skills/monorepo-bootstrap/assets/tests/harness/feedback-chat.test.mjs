import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  cp,
  mkdtemp,
  readFile,
  readdir,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { run } from "../../scripts/feedback/chat.mjs";
import { downloadAttachment } from "../../scripts/feedback/attachment.mjs";

const slack = {
  FEEDBACK_PROVIDER: "slack",
  FEEDBACK_CHANNEL_ID: "CTEST",
  SLACK_FEEDBACK_BOT_TOKEN: "test-only",
};
const discord = {
  FEEDBACK_PROVIDER: "discord",
  FEEDBACK_CHANNEL_ID: "123",
  DISCORD_FEEDBACK_BOT_TOKEN: "test-only",
};

async function tempDir(t) {
  const dir = await mkdtemp(join(tmpdir(), "feedback-test-"));
  t.after(() => rm(dir, { recursive: true, force: true }));
  return dir;
}

test("symlink 経由の CLI も起動し、環境変数をルートの .env より優先する", async (t) => {
  const dir = await tempDir(t);
  const root = join(dir, "project");
  const alias = join(dir, "checkout");
  await cp(
    new URL("../../scripts/feedback", import.meta.url),
    join(root, "scripts", "feedback"),
    { recursive: true },
  );
  await symlink(root, alias, "junction");
  await writeFile(
    join(root, ".env"),
    "FEEDBACK_CHANNEL_ID=CTEST\nFEEDBACK_PROVIDER=slack\n",
  );
  for (const [env, diagnostic] of [
    [{}, /SLACK_FEEDBACK_BOT_TOKEN/],
    [{ FEEDBACK_PROVIDER: "discord" }, /DISCORD_FEEDBACK_BOT_TOKEN/],
  ]) {
    const result = spawnSync(
      process.execPath,
      [join(alias, "scripts", "feedback", "chat.mjs"), "whoami"],
      { env, encoding: "utf8" },
    );
    assert.equal(result.status, 1);
    assert.equal(result.stdout, "");
    assert.match(result.stderr, diagnostic);
  }
});

test("CLI は設定したサービスと受付先を使い、API に他方の資格情報を渡さない", async () => {
  const result = await run(
    ["history", "--oldest", "10"],
    { ...discord, ...slack },
    async (url, options) => {
      assert.equal(url.origin, "https://slack.com");
      assert.equal(url.pathname, "/api/conversations.history");
      assert.equal(url.searchParams.get("channel"), "CTEST");
      assert.equal(options.headers.Authorization, "Bearer test-only");
      return Response.json({ ok: true, messages: [] });
    },
  );
  assert.deepEqual(result, []);
});

test("設定不備、受付先の上書き、承認リアクションの付与を通信前に拒む", async () => {
  const offline = assert.fail;
  for (const [args, config, message] of [
    [["whoami"], { FEEDBACK_CHANNEL_ID: "123" }, /FEEDBACK_PROVIDER/],
    [
      ["whoami"],
      { ...discord, DISCORD_FEEDBACK_BOT_TOKEN: "" },
      /DISCORD_FEEDBACK_BOT_TOKEN/,
    ],
    [["history", "--oldest", "0", "--channel", "other"], slack, /引数/],
    [["replies"], discord, /--parent/],
    [
      [
        "react",
        "--parent",
        "123",
        "--message",
        "124",
        "--name",
        "white_check_mark",
      ],
      discord,
      /リアクション/,
    ],
  ]) {
    await assert.rejects(run(args, config, offline), message);
  }
});

test("Slack と Discord のどちらも同じ長さの境界で送信を止める", async (t) => {
  const file = join(await tempDir(t), "reply");
  await writeFile(file, "😀".repeat(1001));
  for (const config of [slack, discord]) {
    await assert.rejects(
      run(
        ["post", "--parent", "123", "--text-file", file],
        config,
        assert.fail,
      ),
      /2,000/,
    );
  }
});

function attachment(out, fetch, overrides = {}) {
  return downloadAttachment({
    file: {
      id: "123",
      name: "../../picture.png",
      mimetype: "image/png",
      size: 3,
    },
    url: "https://files.example.test/picture",
    allowedHost: "files.example.test",
    headers: {},
    fetch,
    out,
    ...overrides,
  });
}

test("添付の URL と MIME を検査し、実際に受信したバイト数にも上限を適用する", async (t) => {
  const dir = await tempDir(t);
  assert.equal(
    (
      await attachment(dir, assert.fail, {
        url: "https://files.example.test.invalid/picture",
      })
    ).reason,
    "unexpected_url",
  );
  assert.equal(
    (await attachment(dir, assert.fail, { file: { mimetype: "audio/mpeg" } }))
      .reason,
    "video_or_audio",
  );
  await assert.rejects(
    attachment(
      dir,
      async () =>
        new Response("sign in", { headers: { "content-type": "text/html" } }),
    ),
    /unexpected_html/,
  );
  const stream = new ReadableStream({
    pull(controller) {
      controller.enqueue(new Uint8Array(1024 * 1024));
    },
  });
  assert.equal(
    (await attachment(dir, async () => new Response(stream))).reason,
    "too_large",
  );
  assert.deepEqual(await readdir(dir), []);
});

test("同名の添付は出力先の内側に別々に保存する", async (t) => {
  const dir = await tempDir(t);
  const fetch = async (_url, options) => {
    assert.equal(options.redirect, "error");
    return new Response("abc");
  };
  const [a, b] = await Promise.all([
    attachment(dir, fetch),
    attachment(dir, fetch),
  ]);
  assert.equal(a.downloaded, true);
  assert.ok(a.path.startsWith(dir + "/"));
  assert.notEqual(a.path, b.path);
  assert.equal(await readFile(a.path, "utf8"), "abc");
});

test("decision CLI は両サービスで承認者の複数指定・否決優先・改訂による失効を同じように扱う", async () => {
  const slackThread = {
    type: "message",
    thread_ts: "1.000",
    user: "UBOT",
    bot_id: "BAPP",
  };
  const slackRoutes = [
    ["POST /api/auth.test", { ok: true, user_id: "UBOT", bot_id: "BAPP" }],
    [
      "GET /api/conversations.replies?ts=1.000&channel=CTEST&limit=100",
      {
        ok: true,
        messages: [
          { ...slackThread, ts: "2.000", text: "[起票案 1] 初案" },
          {
            ...slackThread,
            ts: "3.000",
            text: "[起票案 1] 改訂",
            reactions: [
              { name: "white_check_mark", users: ["11"], count: 1 },
              { name: "x", users: ["12"], count: 1 },
            ],
          },
        ],
      },
    ],
  ];
  const discordThread = {
    channel_id: "100",
    type: 0,
    author: { id: "99", bot: true },
    timestamp: "2020-01-01T00:00:00Z",
  };
  const discordRoutes = [
    ["GET /api/v10/users/@me", { id: "99", bot: true }],
    ["GET /api/v10/channels/123", { id: "123", guild_id: "1", type: 0 }],
    ["GET /api/v10/applications/@me", { flags: 1 << 19 }],
    [
      "GET /api/v10/channels/123/permissions/member/99",
      { permissions: String((1 << 10) | (1 << 16)) },
    ],
    [
      "GET /api/v10/channels/123/messages/100",
      { id: "100", channel_id: "123", flags: 32 },
    ],
    [
      "GET /api/v10/channels/100/messages?limit=100",
      [
        {
          ...discordThread,
          id: "102",
          content: "[起票案 1] 改訂",
          reactions: [
            { emoji: { name: "✅" }, count: 1 },
            { emoji: { name: "❌" }, count: 1 },
          ],
        },
        { ...discordThread, id: "101", content: "[起票案 1] 初案" },
      ],
    ],
    [
      "GET /api/v10/channels/100/messages/102/reactions/✅?limit=100&type=0&after=0",
      [{ id: "11" }],
    ],
    [
      "GET /api/v10/channels/100/messages/102/reactions/❌?limit=100&type=0&after=0",
      [{ id: "12" }],
    ],
  ];

  for (const [config, parent, latest, stale, routes] of [
    [slack, "1.000", "3.000", "2.000", slackRoutes],
    [discord, "100", "102", "101", discordRoutes],
  ]) {
    for (const [proposal, voters, state] of [
      [latest, ["13", "11"], "approved"],
      [latest, ["12", "11"], "rejected"],
      [stale, ["13", "11"], "superseded"],
    ]) {
      const calls = [];
      const fetch = async (input, options) => {
        const url = new URL(input);
        calls.push(
          `${options.method ?? "GET"} ${decodeURIComponent(url.pathname)}${url.search}`,
        );
        return Response.json(routes[calls.length - 1][1]);
      };
      const result = await run(
        [
          "decision",
          "--parent",
          parent,
          "--item",
          "1",
          "--proposal",
          proposal,
          "--approver",
          voters[0],
          "--approver",
          voters[1],
        ],
        config,
        fetch,
      );
      assert.deepEqual(
        calls,
        routes.map(([route]) => route),
      );
      assert.deepEqual(result, { state, proposalId: proposal });
    }
  }
});
