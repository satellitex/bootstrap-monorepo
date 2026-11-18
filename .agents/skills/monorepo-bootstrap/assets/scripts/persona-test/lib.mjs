// opt-in:persona-test
// ペルソナによる利用テスト（/persona-test）の道具が共有する、ブラウザを使わない部分。
// 設定（run.json）と feedback の形は docs/harness/skills/persona-test/tools.md が正本である。
// 判定を誤ると実害が出るもの（資格情報を出力に書かない、証拠の画像を上書きしない、長すぎる本文を
// 送らせない）をここに集め、tests/harness/persona-test-scripts.test.mjs で検査する。

import { randomBytes, randomInt } from "node:crypto";
import { homedir } from "node:os";
import { join } from "node:path";

/** context に指定できる端末の種類。中身は playwright.mjs の deviceProfile が持つ。 */
const DEVICE_KINDS = ["iphone", "pixel", "galaxy", "win", "mac"];

/** feedback の欄ごとの上限（文字数）。読む人は全員分を続けて読むため、短く保つ。 */
export const FEEDBACK_LIMITS = Object.freeze({
  intro: 150,
  heading: 40,
  place: 60,
  issue: 220,
  why: 140,
  ideal: 160,
  caption: 60,
});

/** 1 人が出す項目の上限。 */
const MAX_ITEMS = 8;

/** 1 項目に付けられる画像の上限。2 枚は横に並べて 1 枚にする。 */
const MAX_SHOTS_PER_ITEM = 2;

/** 出力の中の秘密を置き換える文字列。 */
const REDACTED = "（伏せ字）";

const length = (text) => [...text].length;
const isText = (value) => typeof value === "string" && value !== "";

/** 先頭の `~/` を home に読み替える。 */
export function expandHome(path) {
  return path.startsWith("~/") ? join(homedir(), path.slice(2)) : path;
}

/** run.json の誤りを文の一覧で返す。空なら使える。 */
export function validateRunConfig(config) {
  const problems = [];
  const contexts = Object.entries(config?.contexts ?? {});
  if (contexts.length === 0) problems.push("contexts が空");
  for (const [id, def] of contexts) {
    if (!DEVICE_KINDS.includes(def?.device)) {
      problems.push(`${id}: device は ${DEVICE_KINDS.join(" / ")} のどれか`);
    }
    if (!isText(def?.locale)) problems.push(`${id}: locale が無い`);
  }
  for (const auth of config?.httpAuth ?? []) {
    for (const key of ["origin", "username", "passwordFile"]) {
      if (!isText(auth?.[key])) problems.push(`httpAuth: ${key} が無い`);
    }
  }
  for (const [name, recipe] of Object.entries(config?.credentials ?? {})) {
    const kinds = ["template", "random", "fixed"].filter(
      (kind) => recipe?.[kind] !== undefined,
    );
    if (kinds.length !== 1) {
      problems.push(
        `credentials.${name}: template / random / fixed のどれか 1 つを書く`,
      );
    } else if (
      kinds[0] === "random" &&
      !["password", "digits"].includes(recipe.random)
    ) {
      problems.push(`credentials.${name}: random は password か digits`);
    }
  }
  if (config?.post) {
    for (const key of ["title", "disclosure"]) {
      if (!isText(config.post[key])) problems.push(`post.${key} が無い`);
    }
    for (const key of ["place", "issue", "why", "ideal", "image"]) {
      if (!isText(config.post.labels?.[key]))
        problems.push(`post.labels.${key} が無い`);
    }
  }
  return problems;
}

/**
 * 検証用のアカウントの資格情報を、設定の表（名前 → 作り方）から作る。固定の値（fixed）は設定から
 * 読むので、ここでは作らない。検証環境でだけ使う値で、利用者の実際の資格情報は扱わない。
 */
export function newCredentials(personaId, spec) {
  const values = {};
  for (const [name, recipe] of Object.entries(spec)) {
    if (recipe.template !== undefined) {
      values[name] = recipe.template
        .replaceAll("{id}", personaId.toLowerCase())
        .replaceAll("{rand}", randomBytes(3).toString("hex"));
    } else if (recipe.random === "password") {
      // 英大文字・小文字・数字・記号を必ず含める（パスワードの要件で弾かれないようにする）
      values[name] = `Pw-${randomBytes(12).toString("base64url")}-9a`;
    } else if (recipe.random === "digits") {
      values[name] = Array.from({ length: recipe.length ?? 6 }, () =>
        randomInt(0, 10),
      ).join("");
    }
  }
  return values;
}

/** 作った値と固定の値を合わせた、名前 → 値の表。 */
export function credentialValues(spec, generated) {
  const fixed = Object.entries(spec)
    .filter(([, recipe]) => recipe.fixed !== undefined)
    .map(([name, recipe]) => [name, String(recipe.fixed)]);
  return { ...generated, ...Object.fromEntries(fixed) };
}

/** 出力に出してはいけない値。設定で public と明示したもの以外のすべて。 */
export function secretValues(spec, values) {
  return Object.entries(values)
    .filter(([name]) => spec[name]?.public !== true)
    .map(([, value]) => value);
}

/**
 * 文字列の中の秘密を伏せ字にする。操作の出力は subagent の文脈と報告書に残るため、サーバーは
 * 出力の出口でこれを通す。入力欄の種類や操作の種類ごとに伏せるのでは、漏れる経路が残る。
 */
export function redact(text, secrets) {
  return secrets.reduce(
    (result, secret) =>
      isText(secret) ? result.replaceAll(secret, REDACTED) : result,
    text,
  );
}

/**
 * 既にあるスクリーンショットの、最後の番号。サーバーを起動し直しても続きから振る。
 * 0 から振り直すと、報告書が根拠に挙げた前の画像を上書きする。
 */
export function lastShotIndex(fileNames) {
  return Math.max(
    0,
    ...fileNames.map((name) => Number.parseInt(name, 10) || 0),
  );
}

/**
 * 保存したブラウザの状態から、IndexedDB の指定した key の記録を除く。
 * 鍵のオブジェクトのように保存できない値を持つ記録は、復元すると壊れた値になるため、復元の前に除く。
 */
export function dropIndexedDbRecords(state, keyPrefixes) {
  const keep = (record) =>
    !keyPrefixes.some((prefix) => String(record.key ?? "").startsWith(prefix));
  return {
    ...state,
    origins: (state.origins ?? []).map((origin) => ({
      ...origin,
      indexedDB: (origin.indexedDB ?? []).map((db) => ({
        ...db,
        stores: db.stores.map((store) => ({
          ...store,
          records: store.records.filter(keep),
        })),
      })),
    })),
  };
}

/** feedback（1 人分）の誤りを文の一覧で返す。空なら送れる。 */
export function validateFeedback(feedback, { fileExists } = {}) {
  const problems = [];
  const within = (label, text, max) => {
    if (typeof text !== "string" || text.trim() === "")
      problems.push(`${label} が空`);
    else if (length(text) > max)
      problems.push(`${label} が ${length(text)} 字（上限 ${max}）`);
    else if (text.includes("\n")) problems.push(`${label} に改行がある`);
  };
  within("persona", feedback?.persona, FEEDBACK_LIMITS.heading);
  within("intro", feedback?.intro, FEEDBACK_LIMITS.intro);
  const items = feedback?.items ?? [];
  if (items.length === 0) problems.push("items が空");
  if (items.length > MAX_ITEMS)
    problems.push(`items が ${items.length} 個（上限 ${MAX_ITEMS}）`);
  for (const item of items) {
    const at = `項目 ${item?.n}`;
    for (const key of ["heading", "place", "issue", "why", "ideal"]) {
      within(`${at}: ${key}`, item?.[key], FEEDBACK_LIMITS[key]);
    }
    const shots = item?.shots ?? [];
    if (shots.length > MAX_SHOTS_PER_ITEM) {
      problems.push(
        `${at}: 画像が ${shots.length} 枚（上限 ${MAX_SHOTS_PER_ITEM}）`,
      );
    }
    for (const shot of shots) {
      within(`${at}: caption`, shot?.caption, FEEDBACK_LIMITS.caption);
      if (fileExists && !fileExists(shot?.path))
        problems.push(`${at}: 画像が無い ${shot?.path}`);
    }
  }
  return problems;
}

/**
 * feedback から、親の投稿の本文と、項目ごとの返信の本文を組み立てる。
 * 文言（題、但し書き、欄の名前）は run.json の post から受け取り、ここには持たない。
 */
export function buildPost(feedback, post) {
  const { labels } = post;
  const parent = [
    `${post.title}｜${feedback.persona}`,
    "",
    feedback.intro,
    "",
    post.disclosure,
    "",
    ...feedback.items.map((item) => `${item.n}. ${item.heading}`),
  ].join("\n");
  const items = feedback.items.map((item) => {
    const shots = item.shots ?? [];
    const lines = [
      `${feedback.persona}｜${item.n}. ${item.heading}`,
      `${labels.place}: ${item.place}`,
      `${labels.issue}: ${item.issue}`,
      `${labels.why}: ${item.why}`,
      `${labels.ideal}: ${item.ideal}`,
    ];
    if (shots.length === 1) lines.push(`${labels.image}: ${shots[0].caption}`);
    if (shots.length > 1) {
      lines.push(
        `${labels.image}: ${shots.map((shot, index) => `(${index + 1}) ${shot.caption}`).join(" ")}`,
      );
    }
    return { n: item.n, heading: item.heading, text: lines.join("\n"), shots };
  });
  return { parent, items };
}
