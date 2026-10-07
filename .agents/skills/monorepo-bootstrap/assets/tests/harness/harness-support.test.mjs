// 検査の足場（support ヘルパとランナー）の自己テスト。
//
// 次の 2 つを固定する:
//   - ヘルパの挙動（markdown の簡易解析・frontmatter・計測・除外定数・.gitignore）
//   - 退化ガード: 検査対象が空のルートでは、走査系の gate がすべて失敗する。ランナーは検査
//     ファイルが 0 件、または実行されたテストが 0 件のとき失敗する。何も検査していないのに
//     green になる状態を作らないための検査である。

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  REPO_SCAN_TEST_TIMEOUT_MS,
  countCodePoints,
  countLines,
  createGitignoreMatcher,
  fenceMask,
  fencedLines,
  findStaleExclusions,
  inlineCodeSpans,
  linesOutsideFences,
  parseFrontmatter,
  proseLines,
  stripInlineCode,
  validateExclusions,
} from "./support/repo-files.mjs";

const HERE = fileURLToPath(new URL(".", import.meta.url));
const RUNNER = join(HERE, "run.mjs");

/**
 * 子プロセス用の環境変数。テスト実行中の node は NODE_TEST_CONTEXT を子プロセスへ引き継ぎ、
 * 子の node:test が「入れ子の実行」と判断して何も実行しなくなるため、取り除く。
 */
function childEnv(extra = {}) {
  const env = { ...process.env, ...extra };
  delete env.NODE_TEST_CONTEXT;
  return env;
}

/** ルートの内容に依存しない検査ファイル。空のルートで失敗することを求めない。 */
const ROOT_INDEPENDENT = new Set([
  "check-adr-compression-lossless.test.mjs",
  "harness-support.test.mjs",
]);

describe("support: markdown の簡易解析", () => {
  it("フェンス付きコードブロックの内外を分ける（~~~・長いフェンス・未閉鎖）", () => {
    const text = ["a", "```js", "b", "```", "c", "~~~", "d", "~~~", "e"].join(
      "\n",
    );
    assert.deepEqual(
      linesOutsideFences(text).map((l) => l.text),
      ["a", "c", "e"],
    );
    assert.deepEqual(
      fencedLines(text).map((l) => l.text),
      ["b", "d"],
    );
    const longer = ["````", "```", "x", "````", "y"].join("\n");
    assert.deepEqual(
      linesOutsideFences(longer).map((l) => l.text),
      ["y"],
    );
    assert.deepEqual(fenceMask(["```", "x"]), [true, true]);
  });

  it("インラインコードは同じ長さのバッククォート列で閉じ、閉じが無ければ文字として扱う", () => {
    assert.deepEqual(
      inlineCodeSpans("a `b` c ``d ` e`` f").map((s) => s.text),
      ["b", "d ` e"],
    );
    assert.deepEqual(inlineCodeSpans("閉じない ` だけ"), []);
    assert.equal(stripInlineCode("x `ab` y"), "x      y");
  });

  it("proseLines はフェンスとインラインコードを除く", () => {
    const text = ["`a` b", "```", "c", "```", "d"].join("\n");
    assert.deepEqual(
      proseLines(text).map((l) => [l.n, l.text.trim()]),
      [
        [1, "b"],
        [5, "d"],
      ],
    );
  });
});

describe("support: frontmatter と計測", () => {
  it("単一行の値を読み、引用符を外し、複数行の値を記録する", () => {
    const text = [
      "---",
      "name: demo",
      'description: "引用符付き"',
      "long: >",
      "  折り返し",
      "---",
      "本文",
    ].join("\n");
    const fm = parseFrontmatter(text);
    assert.equal(fm.fields.get("name"), "demo");
    assert.equal(fm.fields.get("description"), "引用符付き");
    assert.equal(fm.multiline.has("long"), true);
    assert.equal(fm.body, "本文");
    assert.equal(parseFrontmatter("本文だけ"), null);
    assert.equal(parseFrontmatter("---\nname: x\n"), null);
  });

  it("行数は末尾の改行を数えず、文字数はコードポイントで数える", () => {
    assert.equal(countLines(""), 0);
    assert.equal(countLines("a\nb\n"), 2);
    assert.equal(countLines("a\nb"), 2);
    assert.equal(countCodePoints("ab"), 2);
    assert.equal(countCodePoints("𠮷a"), 2);
  });
});

describe("support: 除外定数と .gitignore", () => {
  it("理由の無い除外を検出し、生きた出現の無い除外を stale とする", () => {
    assert.deepEqual(
      validateExclusions(
        [
          { path: "a", reason: "r" },
          { path: "b", reason: " " },
        ],
        "path",
      ),
      ['除外 "b" に reason が無い'],
    );
    const stale = findStaleExclusions(
      [{ id: 1 }, { id: 2 }],
      (e) => e.id === 1,
    );
    assert.deepEqual(stale, [{ id: 2 }]);
  });

  it("gitignore の簡易マッチャー: 末尾スラッシュ・アンカー・ワイルドカード・祖先", () => {
    const m = createGitignoreMatcher(
      [
        "# コメント",
        "node_modules/",
        "/dist",
        "*.log",
        ".claude/state/",
        "!keep.log",
      ].join("\n"),
    );
    assert.equal(m("node_modules/x/y.js"), true);
    assert.equal(m("dist"), true);
    assert.equal(m("src/dist"), false);
    assert.equal(m("a/b.log"), true);
    assert.equal(m(".claude/state/"), true);
    assert.equal(m(".claude/state/x.json"), true);
    assert.equal(m(".claude/state"), false);
    assert.equal(m("docs/a.md"), false);
  });
});

describe("足場: ランナーの退化ガード", () => {
  function withTempRunner(setup, fn) {
    const dir = mkdtempSync(join(tmpdir(), "harness-runner-"));
    try {
      copyFileSync(RUNNER, join(dir, "run.mjs"));
      setup(dir);
      return fn(
        spawnSync(process.execPath, [join(dir, "run.mjs")], {
          encoding: "utf8",
          env: childEnv(),
        }),
      );
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  }
  const passing = 'import { it } from "node:test";\nit("ok", () => {});\n';
  const failing =
    'import { it } from "node:test";\nit("ng", () => { throw new Error("x"); });\n';
  const skipped = 'import { it } from "node:test";\nit.skip("s", () => {});\n';

  it("検査ファイルが 0 件なら失敗する", () => {
    withTempRunner(
      () => {},
      (r) => {
        assert.equal(r.status, 1);
        assert.match(r.stderr, /0 件/);
      },
    );
  });

  it("実行されたテストが 0 件（全件 skip）なら失敗する", () => {
    withTempRunner(
      (dir) => writeFileSync(join(dir, "a.test.mjs"), skipped),
      (r) => {
        assert.equal(r.status, 1);
        assert.match(r.stderr, /0 件/);
      },
    );
  });

  it("全件成功なら 0、1 件でも失敗すれば 1", () => {
    withTempRunner(
      (dir) => writeFileSync(join(dir, "a.test.mjs"), passing),
      (r) => assert.equal(r.status, 0, r.stdout + r.stderr),
    );
    withTempRunner(
      (dir) => {
        writeFileSync(join(dir, "a.test.mjs"), passing);
        mkdirSync(join(dir, "sub"));
        writeFileSync(join(dir, "sub", "b.test.mjs"), failing);
      },
      (r) => assert.equal(r.status, 1),
    );
  });

  it("HARNESS_ROOT がディレクトリでなければ失敗する", () => {
    const r = spawnSync(process.execPath, [RUNNER], {
      encoding: "utf8",
      env: childEnv({ HARNESS_ROOT: "/nonexistent/harness-root" }),
    });
    assert.equal(r.status, 1);
    assert.match(r.stderr, /HARNESS_ROOT/);
  });
});

describe("足場: 空のルートでは走査系の gate がすべて失敗する", () => {
  it(
    "check-*.test.mjs（ルート非依存のものを除く）が空ルートで成功しない",
    { timeout: 4 * REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const gates = readdirSync(HERE).filter(
        (name) =>
          /^check-.+\.test\.mjs$/.test(name) && !ROOT_INDEPENDENT.has(name),
      );
      assert.ok(gates.length > 0, "走査系の gate が 0 件");
      const empty = mkdtempSync(join(tmpdir(), "harness-empty-"));
      try {
        const succeeded = [];
        for (const name of gates) {
          const r = spawnSync(process.execPath, ["--test", join(HERE, name)], {
            encoding: "utf8",
            env: childEnv({ HARNESS_ROOT: empty }),
          });
          if (r.status === 0) succeeded.push(basename(name));
        }
        assert.deepEqual(
          succeeded,
          [],
          "空のルートで成功した gate がある。走査対象が 0 件のときに失敗する退化ガードを足す",
        );
      } finally {
        rmSync(empty, { recursive: true, force: true });
      }
    },
  );
});
