// 走査系の gate（check-*.test.mjs）を子プロセスで実行するヘルパ。ROOT を解決しないため、
// 検査対象のルートが不正でも import できる。
//
// 結合テスト（harness-gates-e2e.test.mjs）と足場の自己テスト（harness-support.test.mjs）が、
// gate を実際のルートから切り離した最小のルートや空のルートに対して実行するときに使う。

import { spawn } from "node:child_process";
import { readdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HARNESS_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "..");

/** ルートの内容に依存しない check-*.test.mjs。空のルートで失敗することを求めない。 */
const ROOT_INDEPENDENT = new Set(["check-adr-compression-lossless.test.mjs"]);

/** ルートを走査する gate のファイル名（check-*.test.mjs からルート非依存のものを除く）。 */
export function listScanGateFiles() {
  return readdirSync(HARNESS_DIR)
    .filter((name) => /^check-.+\.test\.mjs$/.test(name))
    .filter((name) => !ROOT_INDEPENDENT.has(name))
    .sort();
}

// 実行中のテストの外側の状態を子へ引き継がない。
//   - NODE_TEST_CONTEXT: 残すと子の node:test が入れ子の実行と判断して何も実行しない。
//   - HARNESS_TEMPLATE_ROOT: 子が検査するルートは、呼び出し側が指定しない限り bootstrap 先として扱う。
//   - GITHUB_REPOSITORY: 子が検査する owner の解決を、実行環境の repo から切り離す。
const ISOLATED_ENV_KEYS = [
  "NODE_TEST_CONTEXT",
  "HARNESS_TEMPLATE_ROOT",
  "GITHUB_REPOSITORY",
];

/**
 * 子プロセス用の環境変数。上記を取り除き、`extra` を重ねる。`extra` の値が undefined のキーは
 * 取り除く。
 */
export function childEnv(extra = {}) {
  const env = { ...process.env };
  for (const key of ISOLATED_ENV_KEYS) delete env[key];
  for (const [key, value] of Object.entries(extra)) {
    if (value === undefined) delete env[key];
    else env[key] = value;
  }
  return env;
}

/**
 * gate を `HARNESS_ROOT=<root>` で実行する。`file` は tests/harness/ 内のファイル名（絶対パスも可）。
 * テストファイルを直接実行するため、失敗したテストがあれば子は非ゼロで終了する。
 * 返り値は `{ status, stdout, stderr }` の Promise。
 */
export function spawnGate(file, { root, env = {} }) {
  return new Promise((resolvePromise, reject) => {
    const child = spawn(process.execPath, [resolve(HARNESS_DIR, file)], {
      env: childEnv({ ...env, HARNESS_ROOT: root }),
    });
    let stdout = "";
    let stderr = "";
    child.stdout.setEncoding("utf8").on("data", (chunk) => (stdout += chunk));
    child.stderr.setEncoding("utf8").on("data", (chunk) => (stderr += chunk));
    child.on("error", reject);
    child.on("close", (status) => resolvePromise({ status, stdout, stderr }));
  });
}
