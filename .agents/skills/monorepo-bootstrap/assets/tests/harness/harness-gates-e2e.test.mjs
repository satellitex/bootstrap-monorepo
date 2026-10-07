// 走査系の gate を、実際のルートに依存しない最小のルートに対して実行する結合テスト。
//
//   - 違反の無い最小のルート（bootstrap 先と同じく、テンプレートモードではない）では全 gate が通る。
//   - gate ごとに違反を 1 つ注入すると、その gate が失敗する（死んだ gate を作らないための確認）。
//
// gate は子プロセスの node:test として HARNESS_ROOT を差し替えて実行する（support/gates.mjs）。
// 対象の gate は check-*.test.mjs から導出するため、gate を足すと、注入ケースが無いことを
// 最後のテストが検出する。

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { CLOSE, OPEN } from "./support/repo-files.mjs";
import { listScanGateFiles, spawnGate } from "./support/gates.mjs";

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
  "| `gate:commit` | `format:check` + `test` |",
  "| `gate:push` | `format:check`（`test` は `gate:ci` が実行） |",
  "",
].join("\n");

const OPERATING_MODEL = [
  "# OM",
  "",
  "| コマンド | 用途 |",
  "| --- | --- |",
  "| `/demo` | 動作確認 |",
  "",
  "| rule | 読む場面 |",
  "| --- | --- |",
  "| `.claude/rules/team-policy.md` | 常時 |",
  "",
].join("\n");

const SCHEDULED_OPERATIONS = [
  "# 定期運用",
  "",
  "| 頻度 | エントリポイント | 目的 |",
  "| --- | --- | --- |",
  "| 週次 | `/demo` | 動作確認 |",
  "",
].join("\n");

/** 違反の無い最小のルートのファイル一式（パス → 本文）。 */
const BASE_FILES = {
  "package.json": JSON.stringify({
    packageManager: "pnpm@10.0.0",
    scripts: { "format:check": "x", test: "x", "harness:test": "x" },
  }),
  ".mise.toml": '[tools]\n"npm:pnpm" = "10.0.0"\n',
  ".gitignore": ".claude/state/\n",
  "AGENTS.md": "# AGENTS\n\n`docs/harness/OPERATING_MODEL.md` を参照する。\n",
  "CLAUDE.md": "# CLAUDE\n\n`docs/harness/OPERATING_MODEL.md` を参照する。\n",
  "docs/harness/OPERATING_MODEL.md": OPERATING_MODEL,
  "docs/harness/scheduled-operations.md": SCHEDULED_OPERATIONS,
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
  ".claude/rules/team-policy.md": "# team policy\n",
  ".claude/hooks/pre-push-ci-check.sh": "CI_CHECK_STEPS=(format:check)\n",
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

const DEMO_DOC = BASE_FILES["docs/harness/skills/demo.md"];

function buildRoot(overrides = {}) {
  const root = mkdtempSync(join(tmpdir(), "harness-e2e-"));
  const files = { ...BASE_FILES, ...overrides };
  for (const [rel, content] of Object.entries(files)) {
    if (content === null) continue;
    const abs = join(root, rel);
    mkdirSync(dirname(abs), { recursive: true });
    writeFileSync(abs, content);
  }
  return root;
}

const GATE_FILES = listScanGateFiles();

/**
 * gate ごとの違反の注入。`overrides` を最小のルートに重ねる。導入先が削除した gate の注入は
 * 除く（存在しない gate は、実行に失敗するだけで、違反を検出したことにならない）。
 */
const INJECTIONS = [
  {
    gate: "check-harness-structure.test.mjs",
    name: "adapter の行数が上限を超える",
    overrides: {
      ".claude/skills/demo/SKILL.md": `${BASE_FILES[".claude/skills/demo/SKILL.md"]}${"行\n".repeat(20)}`,
    },
  },
  {
    gate: "check-harness-structure.test.mjs",
    name: "正本に対応する adapter が無い",
    overrides: { "docs/harness/skills/orphan.md": "# orphan\n" },
  },
  {
    gate: "check-harness-structure.test.mjs",
    name: "定義の無い組合せを参照する",
    overrides: {
      "docs/harness/skills/demo.md": `${DEMO_DOC}\`gate:unknown\` を通す。\n`,
    },
  },
  {
    gate: "check-harness-structure.test.mjs",
    name: "hook の step が gate:push の定義と異なる",
    overrides: {
      ".claude/hooks/pre-push-ci-check.sh":
        "CI_CHECK_STEPS=(format:check test)\n",
    },
  },
  {
    gate: "check-harness-structure.test.mjs",
    name: "skill 表に無い skill がある",
    overrides: {
      "docs/harness/skills/extra.md": "# extra\n",
      ".claude/skills/extra/SKILL.md": BASE_FILES[
        ".claude/skills/demo/SKILL.md"
      ].replaceAll("demo", "extra"),
    },
  },
  {
    gate: "check-harness-structure.test.mjs",
    name: "pnpm の版が package.json と .mise.toml で異なる",
    overrides: { ".mise.toml": '[tools]\n"npm:pnpm" = "10.0.1"\n' },
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
      "docs/harness/skills/demo.md": `${DEMO_DOC}\`docs/missing.md\` を読む。\n`,
    },
  },
  {
    gate: "check-gh-usage.test.mjs",
    name: "list に --limit が無い",
    overrides: {
      "docs/harness/skills/demo.md": `${DEMO_DOC}\n\`\`\`bash\ngh issue list --json number\n\`\`\`\n`,
    },
  },
  {
    gate: "check-gh-usage.test.mjs",
    name: "--repo に owner を直書きする",
    overrides: {
      "docs/harness/skills/demo.md": `${DEMO_DOC}\n\`\`\`bash\ngh issue view 1 --repo acme/app\n\`\`\`\n`,
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
      "docs/harness/skills/demo.md": DEMO_DOC.replace(
        "subagent_type: worker",
        "worker",
      ),
    },
  },
].filter(({ gate }) => GATE_FILES.includes(gate));

/** 最小のルートに `overrides` を重ね、`gates` を並列に実行して結果を返し、ルートを片付ける。 */
async function runGates(gates, overrides = {}) {
  const root = buildRoot(overrides);
  try {
    return await Promise.all(
      gates.map(async (gate) => ({
        gate,
        ...(await spawnGate(gate, { root })),
      })),
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

describe("gate の結合テスト（最小のルート）", { concurrency: true }, () => {
  it("違反の無い最小のルートでは全 gate が通る", async () => {
    for (const r of await runGates(GATE_FILES)) {
      assert.equal(r.status, 0, `${r.gate} が失敗\n${r.stdout}\n${r.stderr}`);
    }
  });

  for (const { gate, name, overrides } of INJECTIONS) {
    it(`${gate}: ${name}と失敗する`, async () => {
      const [r] = await runGates([gate], overrides);
      assert.notEqual(r.status, 0, `違反を注入しても ${gate} が通った`);
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
