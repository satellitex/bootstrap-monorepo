#!/usr/bin/env node
// opt-in:persona-test
// ペルソナ 1 人分の feedback（<run>/reports/<ID>-feedback.json）から、送る本文と画像を組み立てる。
// feedback と run.json の post の形は docs/harness/skills/persona-test/tools.md が正本である。
//
// 使い方: node scripts/persona-test/assemble-posts.mjs <run のディレクトリ> <ID>
// 出力:   <run>/reports/<ID>-post.json（親の投稿の本文、項目ごとの本文と画像）、<run>/post/<ID>/item<n>.png
//
// 字数の上限を超えた欄や、無い画像があれば、何も書かずに終了コード 1 で終わる。
// 画像が 2 枚の項目は、番号と説明を付けて横に並べた 1 枚にする（そのときだけブラウザを起動する）。

import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { buildPost, validateFeedback, validateRunConfig } from "./lib.mjs";
import { launchBrowser } from "./playwright.mjs";

const SIDE_BY_SIDE_WIDTH = 1440;
const SIDE_BY_SIDE_STYLE =
  "body{margin:0;background:#fff;font:15px/1.5 system-ui,sans-serif;display:flex;gap:16px;padding:16px;align-items:flex-start}figure{margin:0;flex:1;min-width:0}img{width:100%;border:1px solid #ccc}figcaption{padding:6px 2px;color:#333}";

const [runDirArg, id] = process.argv.slice(2);
if (!runDirArg || !id) {
  console.error(
    "usage: node scripts/persona-test/assemble-posts.mjs <run-dir> <ID>",
  );
  process.exit(2);
}
const runDir = resolve(runDirArg);
const config = JSON.parse(readFileSync(join(runDir, "run.json"), "utf8"));
const feedback = JSON.parse(
  readFileSync(join(runDir, "reports", `${id}-feedback.json`), "utf8"),
);

const problems = [
  ...validateRunConfig(config),
  ...(config.post ? [] : ["run.json に post が無い"]),
  ...validateFeedback(feedback, {
    fileExists: (path) => existsSync(path ?? ""),
  }),
];
if (problems.length > 0) {
  console.error(`${id}: 直す点\n  ${problems.join("\n  ")}`);
  process.exit(1);
}

const escapeHtml = (text) =>
  text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/"/g, "&quot;");

const outDir = join(runDir, "post", id);
mkdirSync(outDir, { recursive: true });

let browser;

/** 2 枚の画像を横に並べ、番号と説明を付けた 1 枚にする */
async function sideBySide(image, shots) {
  browser ??= await launchBrowser();
  const page = await browser.newPage({
    viewport: { width: SIDE_BY_SIDE_WIDTH, height: 900 },
  });
  const figures = shots.map(
    (shot, index) =>
      `<figure><img src="${pathToFileURL(shot.path).href}"><figcaption>(${index + 1}) ${escapeHtml(shot.caption)}</figcaption></figure>`,
  );
  // 手元の画像を読むので、file: のページとして開く（about:blank からは file: の画像を読めない）
  const html = join(outDir, "side-by-side.html");
  writeFileSync(
    html,
    `<!doctype html><meta charset="utf-8"><style>${SIDE_BY_SIDE_STYLE}</style>${figures.join("")}`,
  );
  await page.goto(pathToFileURL(html).href, { waitUntil: "load" });
  await page.screenshot({ path: image, fullPage: true });
  await page.close();
  rmSync(html);
}

const built = buildPost(feedback, config.post);
const items = [];
for (const item of built.items) {
  const image =
    item.shots.length > 0 ? join(outDir, `item${item.n}.png`) : null;
  if (item.shots.length === 1) copyFileSync(item.shots[0].path, image);
  if (item.shots.length > 1) await sideBySide(image, item.shots);
  items.push({
    n: item.n,
    heading: item.heading,
    text: item.text,
    image,
    size: image ? statSync(image).size : 0,
  });
}
await browser?.close();

writeFileSync(
  join(runDir, "reports", `${id}-post.json`),
  JSON.stringify({ id, parent: built.parent, items }, null, 2),
);
const withImage = items.filter((item) => item.image).length;
console.log(
  `${id}: 項目 ${items.length}、画像 ${withImage}、親の本文 ${[...built.parent].length} 字`,
);
