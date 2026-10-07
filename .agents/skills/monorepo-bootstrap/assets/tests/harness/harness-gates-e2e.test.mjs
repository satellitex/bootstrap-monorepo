// 走査系の gate を、実際のルートに依存しない最小のルートに対して実行する結合テスト。
//
//   - 違反の無い最小のルート（bootstrap 先と同じく MANIFEST.md を持たない）では全 gate が通る。
//   - gate ごとに違反を 1 つ注入すると、その gate が失敗する（死んだ gate を作らないための確認）。
//
// gate は子プロセスの node:test として HARNESS_ROOT を差し替えて実行する。

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = fileURLToPath(new URL(".", import.meta.url));

const OPEN = "{" + "{";
const CLOSE = "}" + "}";

const GUIDE = [
  "# guide",
  "",
  "| ファイル種別 | 上限 | 根拠 |",
  "| --- | --- | --- |",
  "| OPERATING_MODEL.md / CLAUDE.md / AGENTS.md | ≤30 行 | a |",
  "| skill 正本（`docs/harness/skills/<name>.md`） | ≤40 行 | b |",
  "| thin adapter（`.claude/skills/<name>/SKILL.md`） | ≤12 行 | c |",
  "| Agent 定義（`.claude/agents/*.md`） | ≤40 行 | d |",
  "| Skill description（frontmatter） | ≤80 文字 | e |",
  "",
].join("\n");

const GATES_DOC = [
  "# gates",
  "",
  "| コマンド | 役割 |",
  "| --- | --- |",
  "| `pnpm run format:check` | 差分検査 |",
  "| `pnpm run test` | テスト |",
  "",
  "| 名前 | 内容 |",
  "| --- | --- |",
  "| `gate:commit` | 全部 |",
  "",
].join("\n");

/** 違反の無い最小のルートのファイル一式（パス → 本文）。 */
function baseFiles() {
  return {
    "package.json": JSON.stringify({
      scripts: { "format:check": "x", test: "x", "harness:test": "x" },
    }),
    ".gitignore": ".claude/state/\n",
    "AGENTS.md": "# AGENTS\n\n`docs/harness/OPERATING_MODEL.md` を参照する。\n",
    "CLAUDE.md": "# CLAUDE\n\n`docs/harness/OPERATING_MODEL.md` を参照する。\n",
    "docs/harness/OPERATING_MODEL.md": "# OM\n",
    "docs/harness/harness_authoring_guide.md": GUIDE,
    "docs/harness/skills/shared/verification-gates.md": GATES_DOC,
    "docs/harness/skills/demo.md": [
      "# demo",
      "",
      "Agent tool で `subagent_type: worker` を起動する。",
      "検証は `gate:commit` を通す。",
      "",
      "```bash",
      "gh pr list --state open --limit 100 --json number",
      "```",
      "",
    ].join("\n"),
    ".claude/skills/demo/SKILL.md": [
      "---",
      "name: demo",
      "description: 動作確認の場合に使う。",
      "---",
      "",
      "正本は `docs/harness/skills/demo.md`。",
      "",
    ].join("\n"),
    ".claude/agents/worker.md": [
      "---",
      "name: worker",
      "description: 作業役",
      "---",
      "",
      "> 役割: 作業を行う。",
      "",
    ].join("\n"),
    ".github/workflows/ci.yml": [
      "name: CI",
      "on: push",
      "jobs:",
      "  test:",
      "    runs-on: ubuntu-latest",
      "    steps:",
      "      - run: pnpm test",
      "",
    ].join("\n"),
    "docs/note.md": [
      "# note",
      "",
      "`docs/harness/OPERATING_MODEL.md` と `.claude/state/x.json` を参照する。",
      "",
    ].join("\n"),
  };
}

function buildRoot(overrides = {}) {
  const root = mkdtempSync(join(tmpdir(), "harness-e2e-"));
  const files = { ...baseFiles(), ...overrides };
  for (const [rel, content] of Object.entries(files)) {
    if (content === null) continue;
    const abs = join(root, rel);
    mkdirSync(dirname(abs), { recursive: true });
    writeFileSync(abs, content);
  }
  return root;
}

function runGate(gateFile, root) {
  const env = { ...process.env, HARNESS_ROOT: root };
  delete env.NODE_TEST_CONTEXT;
  delete env.GITHUB_REPOSITORY;
  return spawnSync(process.execPath, ["--test", join(HERE, gateFile)], {
    encoding: "utf8",
    env,
  });
}

const GATE_FILES = [
  "check-harness-structure.test.mjs",
  "check-doc-placeholders.test.mjs",
  "check-harness-refs.test.mjs",
  "check-gh-usage.test.mjs",
  "check-workflows.test.mjs",
  "check-agent-launch-paths.test.mjs",
];

/** gate ごとの違反の注入。`overrides` を最小のルートに重ねる。 */
const INJECTIONS = [
  {
    gate: "check-harness-structure.test.mjs",
    name: "adapter の行数が上限を超える",
    overrides: {
      ".claude/skills/demo/SKILL.md": `${baseFiles()[".claude/skills/demo/SKILL.md"]}${"行\n".repeat(20)}`,
    },
  },
  {
    gate: "check-harness-structure.test.mjs",
    name: "正本に対応する adapter が無い",
    overrides: { "docs/harness/skills/orphan.md": "# orphan\n" },
  },
  {
    gate: "check-harness-structure.test.mjs",
    name: "組合せを名前で参照せず直書きする",
    overrides: {
      "docs/harness/skills/demo.md": `${baseFiles()["docs/harness/skills/demo.md"]}\`pnpm run format:check\` と \`pnpm run test\`\n`,
    },
  },
  {
    gate: "check-doc-placeholders.test.mjs",
    name: "散文に未解決のプレースホルダが残る",
    overrides: { "docs/note.md": `# note\n\n本文 ${OPEN}LEFTOVER${CLOSE}\n` },
  },
  {
    gate: "check-doc-placeholders.test.mjs",
    name: "明示 token が残る",
    overrides: {
      "docs/note.md": `# note\n\n\`${OPEN}PRODUCT_NAME${CLOSE}\`\n`,
    },
  },
  {
    gate: "check-doc-placeholders.test.mjs",
    name: "空 owner の症状がある",
    overrides: { "docs/note.md": "# note\n\nhttps://github.com//repo\n" },
  },
  {
    gate: "check-harness-refs.test.mjs",
    name: "実在しないパスを参照する",
    overrides: {
      "docs/harness/skills/demo.md": `${baseFiles()["docs/harness/skills/demo.md"]}\`docs/missing.md\` を読む。\n`,
    },
  },
  {
    gate: "check-gh-usage.test.mjs",
    name: "list に --limit が無い",
    overrides: {
      "docs/harness/skills/demo.md": `${baseFiles()["docs/harness/skills/demo.md"]}\n\`\`\`bash\ngh issue list --json number\n\`\`\`\n`,
    },
  },
  {
    gate: "check-gh-usage.test.mjs",
    name: "--repo に owner を直書きする",
    overrides: {
      "docs/harness/skills/demo.md": `${baseFiles()["docs/harness/skills/demo.md"]}\n\`\`\`bash\ngh issue view 1 --repo acme/app\n\`\`\`\n`,
    },
  },
  {
    gate: "check-workflows.test.mjs",
    name: "workflow が空",
    overrides: { ".github/workflows/ci.yml": "" },
  },
  {
    gate: "check-agent-launch-paths.test.mjs",
    name: "agent の起動経路が無い",
    overrides: {
      "docs/harness/skills/demo.md": baseFiles()[
        "docs/harness/skills/demo.md"
      ].replace("subagent_type: worker", "worker"),
    },
  },
];

describe("gate の結合テスト（最小のルート）", () => {
  it("違反の無い最小のルートでは全 gate が通る", () => {
    const root = buildRoot();
    try {
      for (const gate of GATE_FILES) {
        const r = runGate(gate, root);
        assert.equal(r.status, 0, `${gate} が失敗\n${r.stdout}\n${r.stderr}`);
      }
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  for (const { gate, name, overrides } of INJECTIONS) {
    it(`${gate}: ${name}と失敗する`, () => {
      const root = buildRoot(overrides);
      try {
        const r = runGate(gate, root);
        assert.notEqual(r.status, 0, `違反を注入しても ${gate} が通った`);
      } finally {
        rmSync(root, { recursive: true, force: true });
      }
    });
  }

  it("注入ケースが走査系の gate をすべて覆う", () => {
    const covered = new Set(INJECTIONS.map((i) => i.gate));
    assert.deepEqual(
      GATE_FILES.filter((g) => !covered.has(g)),
      [],
    );
  });
});
