#!/usr/bin/env node
// opt-in:persona-test
// ペルソナ用のブラウザのサーバー（browser-server.mjs）に、1 操作を送る。
// 操作の一覧は docs/harness/skills/persona-test/tester-brief.md が正本である。
//
// 使い方:
//   node scripts/persona-test/browser.mjs <run のディレクトリ> <context> <command> [args...]
//   node scripts/persona-test/browser.mjs <run のディレクトリ> shutdown

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const [runDir, contextOrCommand, command, ...args] = process.argv.slice(2);
const stopping = contextOrCommand === "shutdown";
if (!runDir || !contextOrCommand || (!stopping && !command)) {
  console.error(
    "usage: node scripts/persona-test/browser.mjs <run-dir> <context> <command> [args...]",
  );
  process.exit(2);
}
const serverFile = join(resolve(runDir), "server.json");
if (!existsSync(serverFile)) {
  console.error(
    `サーバーが起動していない（server.json が無い）: ${serverFile}`,
  );
  process.exit(1);
}
const { port } = JSON.parse(readFileSync(serverFile, "utf8"));

const response = await fetch(`http://127.0.0.1:${port}/`, {
  method: "POST",
  body: JSON.stringify(
    stopping
      ? { command: "shutdown" }
      : { context: contextOrCommand, command, args },
  ),
}).catch(() => null);
if (response === null) {
  console.error(
    `サーバーに届かない（127.0.0.1:${port}）。browser-server.mjs が起動しているか確かめる`,
  );
  process.exit(1);
}
if (!response.ok) {
  console.error(`server error ${response.status}: ${await response.text()}`);
  process.exit(1);
}
if (stopping) {
  console.log("stopped");
  process.exit(0);
}

const out = await response.json();
const lines = [
  `[${out.time}] ${command} (${out.ms} ms)`,
  `url: ${out.url}`,
  `title: ${out.title}`,
];
if (out.body) lines.push(out.body);
for (const note of out.notes ?? []) lines.push(`note: ${note}`);
if (out.shot) {
  lines.push(
    `screenshot: ${out.shot}`,
    `viewport: ${out.viewport?.width}x${out.viewport?.height} CSS px（画像は ${out.shotScale} 倍。click の座標は CSS px = 画像の px ÷ ${out.shotScale}）`,
  );
}
console.log(lines.join("\n"));
