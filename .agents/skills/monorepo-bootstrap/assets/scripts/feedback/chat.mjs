import { readFile, realpath } from "node:fs/promises";
import { setTimeout as sleep } from "node:timers/promises";
import { fileURLToPath } from "node:url";
import { parseArgs, parseEnv } from "node:util";
import { createSlack } from "./slack.mjs";
import { createDiscord } from "./discord.mjs";
import { checkDecision } from "./decision.mjs";
import { FeedbackError } from "./error.mjs";

// provider と channel は導入時に固定する。コマンド引数では上書きできない。
const argumentsByCommand = {
  whoami: [],
  history: ["oldest"],
  replies: ["parent"],
  decision: ["parent", "item", "proposal", "approver"],
  post: ["parent", "text-file"],
  react: ["parent", "message", "name"],
  file: ["parent", "message", "id", "out"],
};

async function readConfig() {
  try {
    const file = new URL("../../.env", import.meta.url);
    return { ...parseEnv(await readFile(file, "utf8")), ...process.env };
  } catch (error) {
    if (error.code === "ENOENT") return process.env;
    throw new FeedbackError("設定ファイル .env を読み取れません");
  }
}

export async function run(
  [command, ...args],
  config,
  fetch = globalThis.fetch,
) {
  if (!Object.hasOwn(argumentsByCommand, command)) {
    throw new FeedbackError(
      `コマンドは ${Object.keys(argumentsByCommand).join(" / ")} から選びます`,
    );
  }
  const names = argumentsByCommand[command];
  let values;
  try {
    const options = Object.fromEntries(
      names.map((name) => [
        name,
        { type: "string", multiple: name === "approver" },
      ]),
    );
    ({ values } = parseArgs({
      args,
      options,
      strict: true,
      allowPositionals: false,
    }));
  } catch {
    throw new FeedbackError(`${command} の引数を確認してください`);
  }
  for (const name of names) {
    if (
      values[name] === undefined ||
      [values[name]].flat().some((value) => !value.trim())
    ) {
      throw new FeedbackError(`--${name} が必要です`);
    }
  }
  if (command === "history" && !/^\d+(\.\d+)?$/.test(values.oldest)) {
    throw new FeedbackError("--oldest には UNIX 秒を指定してください");
  }
  if (
    command === "react" &&
    !["eyes", "checkered_flag"].includes(values.name)
  ) {
    throw new FeedbackError(
      "bot のリアクションは eyes / checkered_flag に限ります",
    );
  }
  const channel = config.FEEDBACK_CHANNEL_ID;
  if (!channel) throw new FeedbackError("FEEDBACK_CHANNEL_ID が必要です");
  let adapter;
  switch (config.FEEDBACK_PROVIDER) {
    case "slack":
      if (!config.SLACK_FEEDBACK_BOT_TOKEN)
        throw new FeedbackError("SLACK_FEEDBACK_BOT_TOKEN が必要です");
      adapter = createSlack({
        channel,
        token: config.SLACK_FEEDBACK_BOT_TOKEN,
        readToken: config.SLACK_FEEDBACK_READ_TOKEN,
        fetch,
        sleep,
      });
      break;
    case "discord":
      if (!config.DISCORD_FEEDBACK_BOT_TOKEN)
        throw new FeedbackError("DISCORD_FEEDBACK_BOT_TOKEN が必要です");
      adapter = createDiscord({
        channel,
        token: config.DISCORD_FEEDBACK_BOT_TOKEN,
        fetch,
        sleep,
      });
      break;
    default:
      throw new FeedbackError(
        "FEEDBACK_PROVIDER には slack または discord を指定してください",
      );
  }
  if (command === "decision") return checkDecision(adapter, values);
  if (command === "post") {
    const text = await readFile(values["text-file"], "utf8").catch(() => {
      throw new FeedbackError("--text-file を読み取れません");
    });
    if (!text.trim() || text.length > 2000)
      throw new FeedbackError(
        "返信本文は空白以外を含む 2,000 UTF-16 コード単位以内で指定してください",
      );
    return adapter.post({ parent: values.parent, text });
  }
  return adapter[command](values);
}

// Node 22 の初期版でも、symlink 経由で起動した CLI を同じ実体として扱う。
const isMain =
  import.meta.main ??
  (process.argv[1] &&
    (await realpath(process.argv[1]).catch(() => undefined)) ===
      fileURLToPath(import.meta.url));
if (isMain) {
  try {
    const result = await run(process.argv.slice(2), await readConfig());
    console.log(JSON.stringify(result));
  } catch (error) {
    console.error(
      "feedback:",
      error instanceof FeedbackError ? error.message : "操作に失敗しました",
    );
    process.exitCode = 1;
  }
}
