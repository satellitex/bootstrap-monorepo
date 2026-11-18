import { setTimeout as wait } from "node:timers/promises";
import { downloadAttachment } from "./attachment.mjs";
import { FeedbackError } from "./error.mjs";

const timestamp = /^\d{1,12}\.\d{1,6}$/;
const routineReactions = new Set(["eyes", "checkered_flag"]);
const trackedReactions = new Set([
  ...routineReactions,
  "white_check_mark",
  "x",
]);
const messageSubtypes = new Set([
  "file_share",
  "me_message",
  "bot_message",
  "thread_broadcast",
]);

function requireTimestamp(value) {
  if (typeof value !== "string" || !timestamp.test(value))
    throw new FeedbackError("slack: invalid_timestamp");
}

function summarizeFile(file) {
  return {
    id: file.id,
    name: file.name,
    mimetype: file.mimetype,
    size: file.size,
  };
}

function relevantReactions(message) {
  return (message.reactions ?? []).filter((r) => trackedReactions.has(r.name));
}

function incomplete(reaction) {
  return (
    !Array.isArray(reaction.users) ||
    reaction.count !== new Set(reaction.users).size
  );
}

export function createSlack({
  channel,
  token,
  readToken,
  fetch = globalThis.fetch,
  sleep = wait,
}) {
  if (!/^[CG][A-Z0-9]+$/.test(channel))
    throw new FeedbackError("slack: invalid_slack_channel");
  if (!token) throw new FeedbackError("slack: missing_slack_token");

  // GET の thread 読み取り用 token を指定しても、書き込みと bot の本人確認は常に bot token。
  async function api(
    method,
    params,
    { post = false, credential = token } = {},
  ) {
    const url = new URL(method, "https://slack.com/api/");
    const form = new URLSearchParams(params);
    const options = {
      headers: { Authorization: `Bearer ${credential}` },
      redirect: "error",
    };
    if (post) {
      options.method = "POST";
      options.body = form;
    } else {
      url.search = form.toString();
    }

    for (let retry = 0; ; retry++) {
      let response;
      try {
        response = await fetch(url, {
          ...options,
          signal: AbortSignal.timeout(30_000),
        });
      } catch {
        throw new FeedbackError(`slack: ${method}: network_error`);
      }
      // 429 は操作前の拒否である。タイムアウトや 5xx の書き込みを再送すると二重投稿になる。
      if (response.status === 429 && retry < 3) {
        const seconds = Number(response.headers.get("retry-after") ?? 1);
        if (Number.isFinite(seconds) && seconds >= 0 && seconds <= 60) {
          await sleep(seconds * 1000);
          continue;
        }
      }
      if (!response.ok)
        throw new FeedbackError(`slack: ${method}: HTTP ${response.status}`);
      const result = await response.json().catch(() => null);
      if (!result?.ok) {
        const code = /^[a-z_]{1,64}$/.test(result?.error ?? "")
          ? result.error
          : "invalid_response";
        throw Object.assign(new FeedbackError(`slack: ${method}: ${code}`), {
          code,
        });
      }
      return result;
    }
  }

  async function getMessage(id) {
    const data = await api("reactions.get", {
      channel,
      timestamp: id,
      full: "true",
    });
    if (data.channel !== channel || data.message?.ts !== id)
      throw new FeedbackError("slack: unexpected_message");
    return data.message;
  }

  async function inThread(parent, id) {
    requireTimestamp(parent);
    requireTimestamp(id);
    const msg = await getMessage(id);
    if ((msg.thread_ts ?? msg.ts) !== parent)
      throw new FeedbackError("slack: message_outside_thread");
    return msg;
  }

  async function summarize(message) {
    let reactions = relevantReactions(message);
    // 履歴の users は一部のみの場合がある。否決した承認者を見落とした状態では先へ進めない。
    if (reactions.some(incomplete)) {
      reactions = relevantReactions(await getMessage(message.ts));
      if (reactions.some(incomplete))
        throw new FeedbackError("slack: incomplete_reaction_users");
    }
    let authorId = message.user ?? message.bot_id ?? null;
    // Slack は bot_message に user を付けず bot_id だけを返す場合がある。
    if (!message.user && message.bot_id) {
      const { botId, userId } = await botIdentity();
      if (message.bot_id === botId) authorId = userId;
    }
    return {
      id: message.ts,
      authorId,
      isBot: Boolean(
        message.bot_id ||
        message.bot_profile ||
        message.app_id ||
        message.subtype === "bot_message",
      ),
      isSystem: Boolean(
        message.type !== "message" ||
        (message.subtype && !messageSubtypes.has(message.subtype)),
      ),
      text: message.text ?? "",
      createdAt: new Date(Math.floor(Number(message.ts) * 1000)).toISOString(),
      hasReplies: (message.reply_count ?? 0) > 0,
      reactions: reactions.map(({ name, users }) => ({ name, users })),
      files: (message.files ?? []).map(summarizeFile),
    };
  }

  async function messages(method, params, credential, keep) {
    const rows = new Map();
    const seen = new Set();
    let cursor = "";
    do {
      const query = { ...params, channel, limit: "100" };
      if (cursor) query.cursor = cursor;
      const page = await api(method, query, { credential });
      if (!Array.isArray(page.messages))
        throw new FeedbackError("slack: invalid_messages");
      for (const message of page.messages) {
        requireTimestamp(message.ts);
        if (keep(message)) rows.set(message.ts, message);
      }
      cursor = page.response_metadata?.next_cursor ?? "";
      if (cursor && seen.has(cursor))
        throw new FeedbackError("slack: repeated_cursor");
      if (!cursor && page.has_more)
        throw new FeedbackError("slack: incomplete_history");
      seen.add(cursor);
    } while (cursor);
    const result = [];
    for (const row of [...rows.values()].sort(
      (a, b) => Number(a.ts) - Number(b.ts),
    )) {
      result.push(await summarize(row));
    }
    return result;
  }

  let identity;
  function botIdentity() {
    return (identity ??= api("auth.test", {}, { post: true }).then((auth) => {
      if (!auth.user_id || !auth.bot_id)
        throw new FeedbackError("slack: slack_bot_identity_required");
      return { userId: auth.user_id, botId: auth.bot_id };
    }));
  }

  return {
    async whoami() {
      const { userId } = await botIdentity();
      return { userId };
    },
    async history({ oldest }) {
      if (!/^\d+(?:\.\d+)?$/.test(oldest))
        throw new FeedbackError("slack: invalid_oldest");
      return messages(
        "conversations.history",
        { oldest, inclusive: "true" },
        token,
        (m) => !m.thread_ts || m.thread_ts === m.ts,
      );
    },
    async replies({ parent }) {
      requireTimestamp(parent);
      return messages(
        "conversations.replies",
        { ts: parent },
        readToken || token,
        (m) => m.thread_ts === parent && m.ts !== parent,
      );
    },
    async post({ parent, text }) {
      requireTimestamp(parent);
      if (!text?.trim() || [...text].length > 4000)
        throw new FeedbackError("slack: invalid_reply_text");
      await botIdentity();
      await inThread(parent, parent);
      const escaped = text
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;");
      const result = await api(
        "chat.postMessage",
        {
          channel,
          thread_ts: parent,
          text: escaped,
          reply_broadcast: "false",
          link_names: "false",
          unfurl_links: "false",
          unfurl_media: "false",
        },
        { post: true },
      );
      requireTimestamp(result.ts);
      return { id: result.ts };
    },
    async react({ parent, message, name }) {
      if (!routineReactions.has(name))
        throw new FeedbackError("slack: invalid_routine_reaction");
      await botIdentity();
      await inThread(parent, message);
      try {
        await api(
          "reactions.add",
          { channel, timestamp: message, name },
          { post: true },
        );
      } catch (error) {
        if (error.code !== "already_reacted") throw error;
      }
      return { id: message, name };
    },
    async file({ parent, message, id, out }) {
      const msg = await inThread(parent, message);
      if (
        !/^F[A-Z0-9]+$/.test(id) ||
        !msg.files?.some((file) => file.id === id)
      ) {
        throw new FeedbackError("slack: attachment_not_on_message");
      }
      const { file } = await api("files.info", { file: id });
      if (file?.id !== id)
        throw new FeedbackError("slack: unexpected_attachment");
      return downloadAttachment({
        file: summarizeFile(file),
        url: file.url_private_download ?? file.url_private,
        allowedHost: "files.slack.com",
        headers: { Authorization: `Bearer ${token}` },
        out,
        fetch,
      });
    },
  };
}
