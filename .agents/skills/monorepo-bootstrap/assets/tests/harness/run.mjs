// ハーネス検査ランナー。`tests/harness/` 配下の `*.test.mjs` を列挙して node:test で実行する。
//
//   node tests/harness/run.mjs
//
// `node --test tests/harness/` と書かずにこのランナーを経由する理由は 2 つある。
//   1. Node 21 以降はディレクトリ引数をファイルとして解決し、検査を 1 件も実行せずに失敗する。
//   2. 検査ファイルが 0 件、または実行されたテストが 0 件でも `node --test` は成功終了する。
//      何も検査していないのに green になる状態を避けるため、0 件は失敗にする。
//
// 検査対象のルートは環境変数 HARNESS_ROOT で差し替えられる（support/repo-files.mjs を参照）。
// 出力は組み込みの reporter を使わず、テストの結果イベントだけから組み立てる（Node の版による
// reporter の差を受けないため）。

import { existsSync, readdirSync, statSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { run } from "node:test";

const here = dirname(fileURLToPath(import.meta.url));

function collectTestFiles(dir) {
  const out = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const abs = join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== "node_modules") out.push(...collectTestFiles(abs));
    } else if (entry.isFile() && entry.name.endsWith(".test.mjs")) {
      out.push(abs);
    }
  }
  return out.sort();
}

const files = collectTestFiles(here);
if (files.length === 0) {
  console.error(`harness:test: 検査ファイル (*.test.mjs) が ${here} に 0 件`);
  process.exit(1);
}

const rootEnv = process.env.HARNESS_ROOT;
if (rootEnv !== undefined && rootEnv !== "") {
  const abs = resolve(rootEnv);
  if (!existsSync(abs) || !statSync(abs).isDirectory()) {
    console.error(`harness:test: HARNESS_ROOT がディレクトリではない: ${abs}`);
    process.exit(1);
  }
}

let executed = 0;
let passed = 0;
let failed = 0;
let skipped = 0;
const failures = [];

const label = (event) =>
  `${event.file ? basename(event.file) : "-"}  ${event.name}`;

function errorMessage(event) {
  const error = event.details?.error;
  if (!error) return "(エラー情報なし)";
  const real = error.cause instanceof Error ? error.cause : error;
  // 検査の違反は表明の失敗として一覧が message に入っている。想定外の例外だけ、位置が分かるよう
  // stack の先頭を出す。
  if (real.code === "ERR_ASSERTION") return real.message;
  return String(real.stack ?? real.message ?? real)
    .split("\n")
    .slice(0, 6)
    .join("\n");
}

const stream = run({ files, concurrency: true });

stream.on("test:pass", (event) => {
  if (event.details?.type === "suite") return;
  if (event.skip || event.todo) {
    skipped += 1;
    console.log(`  - ${label(event)}  (skip)`);
    return;
  }
  executed += 1;
  passed += 1;
  console.log(`  ✔ ${label(event)}`);
});

stream.on("test:fail", (event) => {
  // 子テストが失敗した suite は、子の失敗で報告済みのため数えない。
  if (event.details?.type === "suite") return;
  executed += 1;
  failed += 1;
  console.log(`  ✖ ${label(event)}`);
  failures.push({ title: label(event), message: errorMessage(event) });
});

stream.on("test:diagnostic", (event) => {
  // 検査が出す補足情報（TODO の件数など）。ランナー全体の集計行は自前で出す。
  if (event.nesting > 0) console.log(`    ℹ ${event.message}`);
});

stream.on("test:stdout", (event) => process.stdout.write(event.message));
stream.on("test:stderr", (event) => process.stderr.write(event.message));

stream.on("end", () => {
  if (failures.length > 0) {
    console.log("\n失敗した検査:");
    for (const f of failures) {
      console.log(`\n✖ ${f.title}`);
      console.log(
        f.message
          .split("\n")
          .map((line) => `    ${line}`)
          .join("\n"),
      );
    }
  }
  console.log(
    `\nharness:test: 実行 ${executed} 件（成功 ${passed} / 失敗 ${failed}）、skip ${skipped} 件、検査ファイル ${files.length} 本`,
  );
  if (executed === 0) {
    console.error("harness:test: 実行されたテストが 0 件");
    process.exitCode = 1;
  } else {
    process.exitCode = failed > 0 ? 1 : 0;
  }
});

// `run()` は失敗したテストがあってもプロセスを終了させない。ストリームの終端まで待つため、
// データの消費を始める。
stream.resume();
