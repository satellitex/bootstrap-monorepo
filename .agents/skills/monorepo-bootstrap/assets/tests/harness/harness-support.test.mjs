// 検査の足場（support ヘルパとランナー）の自己テスト。
//
// 次の 2 つを固定する:
//   - ヘルパの挙動（markdown の簡易解析・frontmatter・計測・除外定数・.gitignore・パス仕様・
//     ルート配下の列挙・gate の子プロセス実行）
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
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  CLOSE,
  OPEN,
  REPO_SCAN_TEST_TIMEOUT_MS,
  countCodePoints,
  countLines,
  createGitignoreMatcher,
  escapeRegExp,
  fenceMask,
  fencedLines,
  findStaleExclusions,
  inlineCodeSpans,
  linesOutsideFences,
  matchesPathSpec,
  once,
  parseFrontmatter,
  proseLines,
  stripInlineCode,
  validateExclusions,
} from "./support/repo-files.mjs";
import { childEnv, listScanGateFiles, spawnGate } from "./support/gates.mjs";

const HERE = fileURLToPath(new URL(".", import.meta.url));
const RUNNER = join(HERE, "run.mjs");
const REPO_FILES_URL = new URL("./support/repo-files.mjs", import.meta.url)
  .href;
const MARKDOWN_URL = new URL("./support/markdown.mjs", import.meta.url).href;
const GATES_URL = new URL("./support/gates.mjs", import.meta.url).href;

/** `HARNESS_ROOT=<root>` の子プロセスで ES module のコードを実行する。 */
function runModuleCode(root, code) {
  return spawnSync(process.execPath, ["--input-type=module", "-e", code], {
    encoding: "utf8",
    env: childEnv({ HARNESS_ROOT: root }),
  });
}

/**
 * `vars` の環境変数を設定して `fn` を実行し、終わったら元に戻す（undefined は未設定）。`fn` が環境変数を
 * 読むのは同期的な実行の間だけである前提（Promise が解決するまで待たない）。
 */
function withEnv(vars, fn) {
  const saved = Object.fromEntries(
    Object.keys(vars).map((key) => [key, process.env[key]]),
  );
  const apply = (values) => {
    for (const [key, value] of Object.entries(values)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  };
  apply(vars);
  try {
    return fn();
  } finally {
    apply(saved);
  }
}

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

describe("support: パス仕様・正規表現・二重波括弧のヘルパ", () => {
  it("matchesPathSpec: 末尾 / は配下全体、それ以外は完全一致", () => {
    assert.equal(matchesPathSpec("docs/a.md", "docs/a.md"), true);
    assert.equal(matchesPathSpec("docs/a.md.bak", "docs/a.md"), false);
    assert.equal(matchesPathSpec("docs/a/b.md", "docs/"), true);
    assert.equal(matchesPathSpec("docs2/a.md", "docs/"), false);
    assert.equal(matchesPathSpec("docs", "docs/"), false);
  });

  it("escapeRegExp: 特殊文字をそのままの一致パターンにする", () => {
    const raw = "a.b*c+d?(e)[f]{g}|h^i$j\\k";
    assert.equal(new RegExp(`^${escapeRegExp(raw)}$`).test(raw), true);
    assert.equal(new RegExp(escapeRegExp("a.c")).test("abc"), false);
  });

  it("OPEN / CLOSE: 二重波括弧の開きと閉じ", () => {
    assert.equal(OPEN, "{".repeat(2));
    assert.equal(CLOSE, "}".repeat(2));
  });

  it("once: 最初の呼び出しの結果を使い回す", () => {
    let calls = 0;
    const get = once(() => {
      calls += 1;
      return { calls };
    });
    assert.equal(get(), get());
    assert.equal(calls, 1);
  });
});

describe("support: ルート配下の列挙", () => {
  it("列挙ヘルパは HARNESS_ROOT の配下だけを返し、台帳・配下の参照ディレクトリ・非 workflow を含めない", () => {
    const root = mkdtempSync(join(tmpdir(), "harness-root-"));
    try {
      const files = {
        ".claude/agents/a.md": "# a\n",
        ".claude/agents/references/r.md": "# r\n",
        ".github/workflows/ci.yml": "name: CI\n",
        ".github/workflows/x.yaml": "name: X\n",
        ".github/workflows/notes.md": "# notes\n",
        "package.json": JSON.stringify({ scripts: { build: "x", test: "x" } }),
        "docs/a.md": "# a\n",
        "README.md": "# readme\n",
        "MANIFEST.md": "# manifest\n",
      };
      for (const [rel, content] of Object.entries(files)) {
        mkdirSync(join(root, rel, ".."), { recursive: true });
        writeFileSync(join(root, rel), content);
      }
      const r = runModuleCode(
        root,
        `const m = await import(${JSON.stringify(REPO_FILES_URL)});
         console.log(JSON.stringify({
           agents: m.listAgentFiles(),
           workflows: m.listWorkflowFiles(),
           scripts: m.packageScriptNames(),
           exact: [m.existsExactCase("docs/a.md"), m.existsExactCase("docs/A.md")],
           dir: [m.listDir("docs"), m.listDir("missing")],
           harness: m.listHarnessFiles(),
         }));`,
      );
      assert.equal(r.status, 0, r.stderr);
      assert.deepEqual(JSON.parse(r.stdout), {
        agents: [".claude/agents/a.md"],
        workflows: [".github/workflows/ci.yml", ".github/workflows/x.yaml"],
        scripts: ["build", "test"],
        exact: [true, false],
        dir: [["a.md"], []],
        harness: [
          ".claude/agents/a.md",
          ".claude/agents/references/r.md",
          "README.md",
        ],
      });
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  it("markdown.mjs と gates.mjs はルートを解決せず、repo-files.mjs は不正なルートで失敗する", () => {
    const bad = "/nonexistent/harness-root";
    for (const url of [MARKDOWN_URL, GATES_URL]) {
      const r = runModuleCode(bad, `await import(${JSON.stringify(url)});`);
      assert.equal(r.status, 0, r.stderr);
    }
    const r = runModuleCode(
      bad,
      `await import(${JSON.stringify(REPO_FILES_URL)});`,
    );
    assert.notEqual(r.status, 0);
    assert.match(r.stderr, /HARNESS_ROOT/);
  });
});

describe("support: gate の子プロセス実行", () => {
  it("listScanGateFiles: ルートを走査する gate だけを返す", () => {
    const gates = listScanGateFiles();
    assert.ok(gates.includes("check-harness-structure.test.mjs"));
    assert.ok(gates.every((name) => /^check-.+\.test\.mjs$/.test(name)));
    assert.ok(!gates.includes("check-adr-compression-lossless.test.mjs"));
  });

  it("childEnv: 実行中のテストの状態を引き継がず、指定した値を重ねる", () => {
    withEnv(
      {
        NODE_TEST_CONTEXT: "child-v8",
        HARNESS_TEMPLATE_ROOT: "1",
        GITHUB_REPOSITORY: "acme/widgets",
        KEEP_ME: "keep",
        DROP_ME: "drop",
      },
      () => {
        const env = childEnv({ HARNESS_ROOT: "/r", DROP_ME: undefined });
        assert.equal(env.NODE_TEST_CONTEXT, undefined);
        assert.equal(env.HARNESS_TEMPLATE_ROOT, undefined);
        assert.equal(env.GITHUB_REPOSITORY, undefined);
        assert.equal(env.KEEP_ME, "keep");
        assert.equal(env.DROP_ME, undefined);
        assert.equal(env.HARNESS_ROOT, "/r");
        assert.equal(
          childEnv({ HARNESS_TEMPLATE_ROOT: "1" }).HARNESS_TEMPLATE_ROOT,
          "1",
        );
      },
    );
  });

  it("spawnGate: 子の終了コードと出力を返し、環境を切り離す", async () => {
    const dir = mkdtempSync(join(tmpdir(), "harness-gate-"));
    try {
      const script = join(dir, "probe.mjs");
      writeFileSync(
        script,
        `console.log(JSON.stringify([process.env.HARNESS_ROOT, process.env.GITHUB_REPOSITORY ?? null, process.env.EXTRA ?? null]));
         console.error("err");
         process.exit(3);`,
      );
      const r = await withEnv({ GITHUB_REPOSITORY: "acme/widgets" }, () =>
        spawnGate(script, { root: "/some/root", env: { EXTRA: "x" } }),
      );
      assert.equal(r.status, 3);
      assert.deepEqual(JSON.parse(r.stdout), ["/some/root", null, "x"]);
      assert.equal(r.stderr.trim(), "err");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
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
          env: childEnv({ HARNESS_ROOT: undefined }),
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
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    async () => {
      const gates = listScanGateFiles();
      assert.ok(gates.length > 0, "走査系の gate が 0 件");
      const empty = mkdtempSync(join(tmpdir(), "harness-empty-"));
      try {
        const results = await Promise.all(
          gates.map(async (name) => ({
            name,
            ...(await spawnGate(name, { root: empty })),
          })),
        );
        assert.deepEqual(
          results.filter((r) => r.status === 0).map((r) => r.name),
          [],
          "空のルートで成功した gate がある。走査対象が 0 件のときに失敗する退化ガードを足す",
        );
      } finally {
        rmSync(empty, { recursive: true, force: true });
      }
    },
  );
});
