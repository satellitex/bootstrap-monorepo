#!/usr/bin/env node
// opt-in:persona-test
// ペルソナによる利用テスト（/persona-test）で、ペルソナごとに独立したブラウザ（context）を持ち、
// HTTP で 1 操作ずつ受けるサーバー。操作は browser.mjs から送る。
// 設定（run.json）と run のディレクトリの形は docs/harness/skills/persona-test/tools.md、
// 操作の一覧は docs/harness/skills/persona-test/tester-brief.md が正本である。
//
// 使い方: node scripts/persona-test/browser-server.mjs --run-dir <ディレクトリ> [--port <番号>]
//
// 資格情報（HTTP 認証のパスワード、検証用のアカウントの公開しない値）は、操作の出力の出口で
// 伏せ字にし、操作のログには引数を残さない。受け口は 127.0.0.1 だけに開く。

import {
  appendFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { createServer } from "node:http";
import { join, resolve } from "node:path";
import { parseArgs } from "node:util";
import {
  credentialValues,
  dropIndexedDbRecords,
  expandHome,
  lastShotIndex,
  newCredentials,
  redact,
  secretValues,
  validateRunConfig,
} from "./lib.mjs";
import { deviceProfile, launchBrowser } from "./playwright.mjs";

const DEFAULT_PORT = 47800;
const MAX_WAIT_MS = 60_000;
const SETTLE_MS = 900;
const SETTLE_AFTER_LOAD_MS = 1500;
const TEXT_PAGE_CHARS = 7000;
const MAX_LISTED_ELEMENTS = 120;
const MAX_NOTES = 20;
/** 引数をログに残してよい操作。打った文字や式は残さないので、明示したものだけを残す */
const LOGGED_ARGS = new Set([
  "goto",
  "click",
  "scroll",
  "press",
  "wait",
  "tab",
  "text",
]);

const { values } = parseArgs({
  options: { "run-dir": { type: "string" }, port: { type: "string" } },
});
if (!values["run-dir"]) {
  console.error(
    "usage: node scripts/persona-test/browser-server.mjs --run-dir <dir> [--port <n>]",
  );
  process.exit(2);
}
const RUN_DIR = resolve(values["run-dir"]);
const CONFIG_FILE = join(RUN_DIR, "run.json");
if (!existsSync(CONFIG_FILE)) {
  console.error(`run.json が無い: ${CONFIG_FILE}`);
  process.exit(2);
}
const config = JSON.parse(readFileSync(CONFIG_FILE, "utf8"));
const configProblems = validateRunConfig(config);
if (configProblems.length > 0) {
  console.error(`run.json の誤り:\n  ${configProblems.join("\n  ")}`);
  process.exit(2);
}

const SHOTS = join(RUN_DIR, "shots");
const STATE = join(RUN_DIR, "state");
const LOGS = join(RUN_DIR, "logs");
const CREDS_FILE = join(RUN_DIR, "creds.json");
const SERVER_FILE = join(RUN_DIR, "server.json");
for (const dir of [STATE, LOGS]) mkdirSync(dir, { recursive: true });

/** HTTP 認証。パスワードは置き場のファイルから読み、設定にもログにも書かない */
const httpCredentials = (config.httpAuth ?? []).map((auth) => {
  const file = expandHome(auth.passwordFile);
  const password = existsSync(file) ? readFileSync(file, "utf8").trim() : "";
  if (password === "") {
    console.error(`HTTP 認証のパスワードのファイルが無いか空: ${file}`);
    process.exit(2);
  }
  return { origin: auth.origin, username: auth.username, password };
});

const savedCredentials = () =>
  existsSync(CREDS_FILE) ? JSON.parse(readFileSync(CREDS_FILE, "utf8")) : {};

/** context が属するペルソナ。同じ人が端末を使い分けるときは、context の persona で束ねる */
const personaOf = (contextId) =>
  config.contexts[contextId].persona ?? contextId;

/** ペルソナの検証用の資格情報。無ければ作って保存する（保存先は run のディレクトリの中だけ） */
function credentialsOf(contextId) {
  if (!config.credentials) throw new Error("run.json に credentials が無い");
  const persona = personaOf(contextId);
  const all = savedCredentials();
  if (!all[persona]) {
    all[persona] = newCredentials(persona, config.credentials);
    writeFileSync(CREDS_FILE, JSON.stringify(all, null, 2), { mode: 0o600 });
  }
  return credentialValues(config.credentials, all[persona]);
}

/** 出力から伏せる値。HTTP 認証のパスワードと、そのペルソナの公開しない資格情報 */
function secretsOf(contextId) {
  const generated = savedCredentials()[personaOf(contextId)];
  const own = generated
    ? secretValues(
        config.credentials,
        credentialValues(config.credentials, generated),
      )
    : [];
  return [...httpCredentials.map((auth) => auth.password), ...own];
}

/** 保存した状態を、復元できない記録を除いて読む */
function restoredState(stateFile) {
  if (!existsSync(stateFile)) return undefined;
  const saved = JSON.parse(readFileSync(stateFile, "utf8"));
  return dropIndexedDbRecords(
    saved,
    config.state?.dropIndexedDbKeyPrefixes ?? [],
  );
}

let launching;
const live = new Map();
const chains = new Map();

async function open(contextId) {
  const existing = live.get(contextId);
  if (existing) return existing;
  const def = config.contexts[contextId];
  if (!def)
    throw new Error(
      `unknown context: ${contextId}（run.json の contexts に無い）`,
    );
  // 最初の操作が重なっても、ブラウザは 1 つだけ起動する
  launching ??= launchBrowser();
  const browser = await launching;
  const profile = deviceProfile(def.device, browser.version().split(".")[0]);
  const stateFile = join(STATE, `${contextId}.json`);
  const shotDir = join(SHOTS, contextId);
  mkdirSync(shotDir, { recursive: true });
  // Service Worker は止めない。結果の表示に Service Worker を使うアプリでは、止めると何も表示されない。
  // HTTP 認証は origin ごとにブラウザへ渡す。ヘッダーの付け足しでは、ページを経由しない要求
  // （Service Worker の取得など）が 401 になる
  const context = await browser.newContext({
    ...profile,
    locale: def.locale,
    timezoneId: def.timezone,
    httpCredentials,
    storageState: restoredState(stateFile),
  });
  await context
    .grantPermissions(["clipboard-read", "clipboard-write"])
    .catch(() => {});
  const state = {
    id: contextId,
    context,
    page: await context.newPage(),
    mobile: Boolean(profile.isMobile),
    scale: profile.deviceScaleFactor,
    elements: [],
    shotDir,
    shots: lastShotIndex(readdirSync(shotDir)),
    notes: [],
    droppedNotes: 0,
    stateFile,
    dirty: false,
  };
  // 開いたままのページが例外を出し続けても、次の操作の出力が膨らまないように件数を切る
  const note = (text) => {
    if (state.notes.length < MAX_NOTES) state.notes.push(text);
    else state.droppedNotes += 1;
  };
  const watch = (page) => {
    page.on("dialog", (dialog) => {
      note(`dialog(${dialog.type()}): ${dialog.message().slice(0, 200)}`);
      dialog.accept().catch(() => {});
    });
    page.on("download", (download) => {
      note(
        `download が始まった: ${download.suggestedFilename()}（保存はせず取り消した）`,
      );
      download.cancel().catch(() => {});
    });
    page.on("pageerror", (error) => {
      note(`pageerror: ${String(error.message).slice(0, 200)}`);
    });
  };
  watch(state.page);
  context.on("page", (page) => {
    watch(page);
    state.page = page;
    note("新しいタブが開き、そのタブに切り替えた");
  });
  live.set(contextId, state);
  return state;
}

// ページの中で実行する。値の伏せ字は、出力の出口（handle）で行う
const LIST_ELEMENTS = () => {
  const selector =
    "a[href],button,input,textarea,select,summary,[role=button],[role=link],[role=tab],[role=menuitem],[role=option],[role=checkbox],[role=radio],[role=switch],[role=combobox],[contenteditable=true],label[for]";
  const width = globalThis.innerWidth;
  const height = globalThis.innerHeight;
  const found = [];
  for (const el of globalThis.document.querySelectorAll(selector)) {
    const rect = el.getBoundingClientRect();
    if (rect.width < 2 || rect.height < 2) continue;
    if (
      rect.bottom <= 0 ||
      rect.top >= height ||
      rect.right <= 0 ||
      rect.left >= width
    )
      continue;
    const style = globalThis.getComputedStyle(el);
    if (style.visibility === "hidden" || style.display === "none") continue;
    const x = Math.min(Math.max(rect.left + rect.width / 2, 1), width - 1);
    const y = Math.min(Math.max(rect.top + rect.height / 2, 1), height - 1);
    const top = globalThis.document.elementFromPoint(x, y);
    const covered =
      Boolean(top) && !(el === top || el.contains(top) || top.contains(el));
    const name = (
      el.getAttribute("aria-label") ||
      el.innerText ||
      el.value ||
      el.getAttribute("placeholder") ||
      el.getAttribute("title") ||
      el.querySelector("img")?.getAttribute("alt") ||
      ""
    )
      .trim()
      .replace(/\s+/g, " ")
      .slice(0, 70);
    found.push({
      kind: el.getAttribute("role") || el.tagName.toLowerCase(),
      type: el.getAttribute("type") || "",
      name,
      x: Math.round(x),
      y: Math.round(y),
      w: Math.round(rect.width),
      h: Math.round(rect.height),
      covered,
      disabled:
        Boolean(el.disabled) || el.getAttribute("aria-disabled") === "true",
    });
  }
  return found;
};

function pointOf(state, args) {
  if (args[0]?.startsWith("@")) {
    const el = state.elements[Number(args[0].slice(1))];
    if (!el) throw new Error(`${args[0]} が無い。先に els を実行する`);
    return [el.x, el.y];
  }
  const [x, y] = [Number(args[0]), Number(args[1])];
  if (!Number.isFinite(x) || !Number.isFinite(y)) {
    throw new Error("click は @番号 か x y を渡す（CSS ピクセル）");
  }
  return [x, y];
}

async function shot(state, fullPage = false) {
  state.shots += 1;
  const path = join(
    state.shotDir,
    `${String(state.shots).padStart(3, "0")}.png`,
  );
  await state.page.screenshot({
    path,
    fullPage,
    scale: "device",
    timeout: 20_000,
  });
  return path;
}

/**
 * 1 操作を実行する。読むだけの操作は本文だけを返し、画面を変える操作は、落ち着くのを待ってから
 * スクリーンショットを撮って返す。
 */
async function run(state, command, args) {
  const { page } = state;
  let body = "";
  let settleMs = SETTLE_MS;
  switch (command) {
    case "find": {
      const matches = page.getByText(args.join(" "), { exact: false });
      const count = await matches.count();
      const lines = [];
      for (let index = 0; index < Math.min(count, 8); index += 1) {
        const match = matches.nth(index);
        const box = await match.boundingBox().catch(() => null);
        const text = ((await match.innerText().catch(() => "")) || "").replace(
          /\s+/g,
          " ",
        );
        const where = box
          ? `(${Math.round(box.x + box.width / 2)},${Math.round(box.y + box.height / 2)})`
          : "(画面外か非表示)";
        lines.push(`${where} ${text.slice(0, 90)}`);
      }
      return { body: `${count} 件\n${lines.join("\n")}` };
    }
    case "text": {
      const text = await page.evaluate(
        () => globalThis.document.body.innerText,
      );
      const from = Number(args[0] ?? 0);
      const rest =
        text.length > from + TEXT_PAGE_CHARS
          ? `\n…（全 ${text.length} 文字。続きは text ${from + TEXT_PAGE_CHARS}）`
          : "";
      return { body: text.slice(from, from + TEXT_PAGE_CHARS) + rest };
    }
    case "els": {
      state.elements = await page.evaluate(LIST_ELEMENTS);
      const lines = state.elements
        .slice(0, MAX_LISTED_ELEMENTS)
        .map((el, index) => {
          const marks = `${el.disabled ? " [disabled]" : ""}${el.covered ? " [ほかの要素の下]" : ""}`;
          const type = el.type ? `[${el.type}]` : "";
          return `@${index} ${el.kind}${type} "${el.name}" (${el.x},${el.y}) ${el.w}x${el.h}${marks}`;
        });
      return { body: lines.join("\n") };
    }
    case "whoami": {
      const shown = Object.entries(credentialsOf(state.id))
        .filter(([name]) => config.credentials[name]?.public === true)
        .map(([name, value]) => `${name}: ${value}`);
      return { body: shown.join("\n") };
    }
    case "tabs": {
      const tabs = state.context.pages();
      return {
        body: tabs
          .map(
            (tab, index) =>
              `${index}${tab === state.page ? " *" : ""} ${tab.url()}`,
          )
          .join("\n"),
      };
    }
    // 確認のために、ページの状態を読むだけに使う。画面を変える操作には使わない
    case "eval":
      return {
        body:
          JSON.stringify(await page.evaluate(args.join(" ")), null, 1) ?? "",
      };
    case "fullshot":
      return {
        body: "ページ全体のスクリーンショット",
        shot: await shot(state, true),
      };
    case "open":
    case "shot":
      settleMs = 0;
      break;
    case "wait":
      await page.waitForTimeout(Math.min(Number(args[0] ?? 2000), MAX_WAIT_MS));
      settleMs = 0;
      break;
    case "goto":
      await page.goto(args[0], {
        waitUntil: "domcontentloaded",
        timeout: 45_000,
      });
      settleMs = SETTLE_AFTER_LOAD_MS;
      break;
    case "reload":
      await page.reload({ waitUntil: "domcontentloaded", timeout: 45_000 });
      settleMs = SETTLE_AFTER_LOAD_MS;
      break;
    case "back":
      await page.goBack({ timeout: 30_000 }).catch(() => {});
      break;
    case "click": {
      const [x, y] = pointOf(state, args);
      if (state.mobile) await page.touchscreen.tap(x, y);
      else await page.mouse.click(x, y);
      break;
    }
    case "clicktext": {
      const target = page.getByText(args.join(" "), { exact: false }).first();
      await target.scrollIntoViewIfNeeded({ timeout: 8000 });
      if (state.mobile) await target.tap({ timeout: 8000 });
      else await target.click({ timeout: 8000 });
      break;
    }
    case "type": {
      const text = args.join(" ");
      if (text.length > 60) await page.keyboard.insertText(text);
      else await page.keyboard.type(text, { delay: 12 });
      break;
    }
    case "cred": {
      const value = credentialsOf(state.id)[args[0]];
      if (!value) {
        throw new Error(
          `cred の名前は ${Object.keys(config.credentials).join(" / ")} のどれか`,
        );
      }
      await page.keyboard.type(value, { delay: 15 });
      // 公開しない値は、出力の出口で伏せ字になる
      body = `入力した: ${args[0]} = ${value}`;
      break;
    }
    case "press":
      await page.keyboard.press(args[0]);
      break;
    case "clear":
      await page.keyboard.press("ControlOrMeta+A");
      await page.keyboard.press("Backspace");
      break;
    case "scroll": {
      const size = page.viewportSize();
      await page.mouse.move(
        Number(args[1] ?? size.width / 2),
        Number(args[2] ?? size.height / 2),
      );
      await page.mouse.wheel(0, Number(args[0] ?? 600));
      break;
    }
    case "upload":
      await page
        .locator("input[type=file]")
        .nth(Number(args[1] ?? 0))
        .setInputFiles(args[0]);
      break;
    case "tab":
      state.page = state.context.pages()[Number(args[0])] ?? state.page;
      await state.page.bringToFront();
      break;
    case "closetab":
      if (state.context.pages().length > 1) {
        await state.page.close();
        state.page = state.context.pages().at(-1);
      }
      break;
    default:
      throw new Error(`unknown command: ${command}`);
  }
  // 画面を変えた操作。状態の保存は、応答を返した後に行う（saveIfDirty）
  state.dirty = true;
  if (settleMs > 0) {
    await state.page
      .waitForLoadState("domcontentloaded", { timeout: 15_000 })
      .catch(() => {});
    await state.page.waitForTimeout(settleMs);
  }
  return { body, shot: await shot(state) };
}

async function handle(contextId, command, args) {
  const started = Date.now();
  const state = await open(contextId);
  let result;
  try {
    result = await run(state, command, args);
  } catch (error) {
    result = {
      body: `ERROR: ${String(error.message ?? error).split("\n")[0]}`,
      shot: await shot(state).catch(() => null),
    };
  }
  const { page } = state;
  const notes = state.notes.splice(0);
  if (state.droppedNotes > 0) notes.push(`ほか ${state.droppedNotes} 件`);
  state.droppedNotes = 0;
  // 出力の出口。ここを通るすべての文字列から、秘密を伏せる
  const secrets = secretsOf(contextId);
  const out = {
    time: new Date().toISOString(),
    ms: Date.now() - started,
    url: redact(page.url(), secrets),
    title: redact(await page.title().catch(() => ""), secrets),
    viewport: page.viewportSize(),
    shotScale: state.scale,
    body: redact(result.body ?? "", secrets),
    shot: result.shot,
    notes: notes.map((text) => redact(text, secrets)),
  };
  const logged = {
    time: out.time,
    ms: out.ms,
    command,
    url: out.url,
    shot: out.shot,
  };
  if (LOGGED_ARGS.has(command)) logged.args = args;
  appendFileSync(
    join(LOGS, `${contextId}.jsonl`),
    `${JSON.stringify(logged)}\n`,
  );
  return out;
}

/** 画面を変えた操作の後に、ブラウザの状態を保存する。全量を書き出すため、応答の経路には置かない */
async function saveIfDirty(contextId) {
  const state = live.get(contextId);
  if (!state?.dirty) return;
  state.dirty = false;
  await state.context
    .storageState({ path: state.stateFile, indexedDB: true })
    .catch(() => {});
}

async function shutdown() {
  await Promise.all(
    [...live.keys()].map((contextId) => saveIfDirty(contextId)),
  );
  const browser = await launching?.catch(() => null);
  await browser?.close().catch(() => {});
  rmSync(SERVER_FILE, { force: true });
  process.exit(0);
}

const server = createServer((request, response) => {
  let raw = "";
  request.on("data", (chunk) => {
    raw += chunk;
  });
  request.on("end", () => {
    let input;
    try {
      input = JSON.parse(raw);
    } catch {
      response.writeHead(400).end("bad json");
      return;
    }
    if (input.command === "shutdown") {
      response.writeHead(200, { "content-type": "application/json" }).end("{}");
      void shutdown();
      return;
    }
    const { context, command, args = [] } = input;
    // 同じ context への操作は、届いた順に 1 つずつ実行する。保存は応答の後、次の操作の前に行う
    const done = (chains.get(context) ?? Promise.resolve()).then(() =>
      handle(context, command, args),
    );
    chains.set(
      context,
      done.then(
        () => saveIfDirty(context),
        () => {},
      ),
    );
    done
      .then((out) => {
        response
          .writeHead(200, { "content-type": "application/json" })
          .end(JSON.stringify(out));
      })
      .catch((error) => {
        response.writeHead(500).end(String(error.message ?? error));
      });
  });
});

// ブラウザを閉じてから終わる。閉じずに受け口だけが残ると、次の起動が同じポートで失敗する
for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, () => {
    void shutdown();
  });
}

const port = Number(values.port ?? DEFAULT_PORT);
server.listen(port, "127.0.0.1", () => {
  writeFileSync(SERVER_FILE, JSON.stringify({ port }));
  console.log(`persona browser server on 127.0.0.1:${port}`);
});
