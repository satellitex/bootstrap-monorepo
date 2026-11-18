// Discord REST API v10。親投稿を固定チャンネルで引いてから、その投稿のスレッドを扱う。
import { setTimeout as wait } from "node:timers/promises";
import { downloadAttachment } from "./attachment.mjs";
import { FeedbackError } from "./error.mjs";

const API = "https://discord.com/api/v10";
const PAGE_SIZE = 100;
const HAS_THREAD = 1 << 5;
const MESSAGE_CONTENT = (1 << 18) | (1 << 19);
const READ_PERMISSIONS = (1n << 10n) | (1n << 16n); // VIEW_CHANNEL, READ_MESSAGE_HISTORY
const REACTIONS = new Map([
  ["👀", "eyes"],
  ["🏁", "checkered_flag"],
  ["✅", "white_check_mark"],
  ["❌", "x"],
]);
const BOT_REACTIONS = new Map([
  ["eyes", "👀"],
  ["checkered_flag", "🏁"],
]);

function snowflake(value) {
  if (
    typeof value !== "string" ||
    !/^[1-9]\d{0,19}$/.test(value) ||
    BigInt(value) >= 1n << 64n
  ) {
    throw new FeedbackError("discord: invalid_discord_id");
  }
  return value;
}

function hasThread(msg) {
  return (msg.flags & HAS_THREAD) !== 0 || msg.thread?.id === msg.id;
}

function fileInfo(file) {
  return {
    id: snowflake(file.id),
    name: file.filename,
    mimetype: file.content_type ?? "",
    size: file.size,
  };
}

export function createDiscord({
  channel,
  token,
  fetch = globalThis.fetch,
  sleep = wait,
}) {
  const base = `/channels/${snowflake(channel)}`;
  const headers = {
    "User-Agent": `DiscordBot (https://nodejs.org/, ${process.versions.node})`,
    ...(token ? { Authorization: `Bot ${token}` } : {}),
  };

  async function api(path, method = "GET", body) {
    for (let attempt = 0; ; attempt++) {
      let res;
      try {
        res = await fetch(API + path, {
          method,
          headers: body
            ? { ...headers, "Content-Type": "application/json" }
            : headers,
          body: body ? JSON.stringify(body) : undefined,
          redirect: "error",
          signal: AbortSignal.timeout(30_000),
        });
      } catch {
        throw new FeedbackError("discord: network_error");
      }
      if (res.status === 204) return;
      const data = await res.json().catch(() => null);
      if (res.status === 429 && attempt < 3) {
        const seconds = Number(
          data?.retry_after ?? res.headers.get("retry-after") ?? 1,
        );
        if (Number.isFinite(seconds) && seconds >= 0 && seconds <= 60) {
          await sleep(Math.ceil(seconds * 1000));
          continue;
        }
      }
      if (!res.ok) {
        const code = Number.isSafeInteger(data?.code) ? data.code : undefined;
        throw Object.assign(
          new FeedbackError(
            `discord: http_${res.status}${code ? "_" + code : ""}`,
          ),
          { code },
        );
      }
      if (!data) throw new FeedbackError("discord: invalid_discord_response");
      return data;
    }
  }

  let access;
  async function checkAccess() {
    const user = await api("/users/@me");
    if (!user.bot) throw new FeedbackError("discord: bot_required");
    const userId = snowflake(user.id);
    const source = await api(base);
    if (source.id !== channel || source.type !== 0 || !source.guild_id)
      throw new FeedbackError("discord: guild_text_channel_required");
    // この 2 条件を欠くと、HTTP 200 でも本文または履歴が空になる。
    const application = await api("/applications/@me");
    if (!(application.flags & MESSAGE_CONTENT))
      throw new FeedbackError("discord: message_content_required");
    const member = await api(`${base}/permissions/member/${userId}`);
    const perms = BigInt(member.permissions);
    if (!(perms & 8n) && (perms & READ_PERMISSIONS) !== READ_PERMISSIONS) {
      throw new FeedbackError("discord: history_permission_required");
    }
    return { userId };
  }

  function whoami() {
    return (access ??= checkAccess());
  }

  // 集合読み取りは全ページ成功時だけ返す。cursor は API 上の文字列のまま渡す。
  async function reactionUsers(path, type) {
    const users = [];
    let after = "0";
    for (;;) {
      const page = await api(
        `${path}?limit=${PAGE_SIZE}&type=${type}&after=${after}`,
      );
      if (!Array.isArray(page))
        throw new FeedbackError("discord: invalid_discord_reactions");
      const ids = page.map((user) => snowflake(user.id));
      if (ids.some((id) => BigInt(id) <= BigInt(after)))
        throw new FeedbackError("discord: invalid_discord_reaction_cursor");
      users.push(...ids);
      if (ids.length < PAGE_SIZE) return users;
      after = ids.reduce((max, id) => (BigInt(id) > BigInt(max) ? id : max));
    }
  }

  async function summarize(msg) {
    const reactions = [];
    for (const reaction of msg.reactions ?? []) {
      const name = REACTIONS.get(reaction.emoji.name);
      if (!name || reaction.emoji.id) continue;
      const url = `/channels/${msg.channel_id}/messages/${msg.id}/reactions/${encodeURIComponent(reaction.emoji.name)}`;
      const users = await reactionUsers(url, 0);
      if (reaction.count_details?.burst > 0)
        users.push(...(await reactionUsers(url, 1)));
      if (users.length !== reaction.count)
        throw new FeedbackError("discord: reactions_changed");
      reactions.push({ name, users: [...new Set(users)] });
    }
    return {
      id: snowflake(msg.id),
      authorId: snowflake(msg.author.id),
      isBot: Boolean(msg.author.bot || msg.webhook_id),
      isSystem: msg.type !== 0 && msg.type !== 19,
      text: msg.content ?? "",
      createdAt: new Date(msg.timestamp).toISOString(),
      hasReplies: hasThread(msg),
      reactions,
      files: (msg.attachments ?? []).map(fileInfo),
    };
  }

  async function listMessages(target, oldestMs, insideThread = false) {
    const messages = [];
    let before;
    for (;;) {
      const page = await api(
        `/channels/${target}/messages?limit=${PAGE_SIZE}${before ? "&before=" + before : ""}`,
      );
      if (!Array.isArray(page))
        throw new FeedbackError("discord: invalid_discord_history");
      for (const msg of page) {
        if (msg.channel_id !== target)
          throw new FeedbackError("discord: invalid_discord_channel");
        const id = snowflake(msg.id);
        if (before && BigInt(id) >= BigInt(before))
          throw new FeedbackError("discord: invalid_discord_message_cursor");
        before = id;
        if (Date.parse(msg.timestamp) < oldestMs) return messages.reverse();
        // スレッドの先頭に Discord が挿入する親投稿の参照（THREAD_STARTER_MESSAGE）を除く。
        if (insideThread && (id === target || msg.type === 21)) continue;
        messages.push(await summarize(msg));
      }
      if (page.length < PAGE_SIZE) return messages.reverse();
    }
  }

  async function getMessage(target, id) {
    const msg = await api(`/channels/${target}/messages/${snowflake(id)}`);
    if (msg.id !== id || msg.channel_id !== target)
      throw new FeedbackError("discord: invalid_discord_message");
    return msg;
  }

  async function locate(parent, message) {
    snowflake(message);
    await whoami();
    const root = await getMessage(channel, parent);
    if (parent === message) return root;
    if (!hasThread(root)) throw new FeedbackError("discord: thread_missing");
    return getMessage(parent, message);
  }

  return {
    whoami,
    async history({ oldest }) {
      if (
        typeof oldest !== "string" ||
        !/^\d+(\.\d+)?$/.test(oldest) ||
        !Number.isFinite(Number(oldest) * 1000)
      ) {
        throw new FeedbackError("discord: invalid_oldest");
      }
      await whoami();
      return listMessages(channel, Number(oldest) * 1000);
    },
    async replies({ parent }) {
      const root = await locate(parent, parent);
      return hasThread(root) ? listMessages(parent, 0, true) : [];
    },
    async post({ parent, text }) {
      if (typeof text !== "string" || !text.trim() || text.length > 2000)
        throw new FeedbackError("discord: invalid_discord_reply_text");
      const root = await locate(parent, parent);
      if (!hasThread(root)) {
        try {
          await api(`${base}/messages/${parent}/threads`, "POST", {
            name: "フィードバック",
          });
        } catch (error) {
          // 並行して別の利用者がスレッドを作った場合も、親 ID が同じスレッドを使う。
          if (error.code !== 160004) throw error;
        }
      }
      const msg = await api(`/channels/${parent}/messages`, "POST", {
        content: text,
        allowed_mentions: { parse: [] },
      });
      return { id: snowflake(msg.id) };
    },
    async react({ parent, message, name }) {
      const emoji = BOT_REACTIONS.get(name);
      if (!emoji) throw new FeedbackError("discord: invalid_feedback_reaction");
      const msg = await locate(parent, message);
      await api(
        `/channels/${msg.channel_id}/messages/${message}/reactions/${encodeURIComponent(emoji)}/@me`,
        "PUT",
      );
      return { ok: true };
    },
    async file({ parent, message, id, out }) {
      snowflake(id);
      const msg = await locate(parent, message);
      const attachment = (msg.attachments ?? []).find(
        (entry) => entry.id === id,
      );
      if (!attachment)
        throw new FeedbackError("discord: attachment_not_in_message");
      return downloadAttachment({
        file: fileInfo(attachment),
        url: attachment.url,
        allowedHost: "cdn.discordapp.com",
        headers: {},
        out,
        fetch,
      });
    },
  };
}
