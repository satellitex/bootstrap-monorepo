// agent の起動経路 gate: .claude/agents/*.md の各 agent に、起動する側の記述があることを検査する。
//
// 起動経路とみなすもの（agent 名を `subagent_type` の値として書いた記述）:
//   `subagent_type: <name>`（コロンの代わりに `=`、値の引用符は可）
// を、次のファイルのどれかが持つこと。
//   - docs/harness/skills/**/*.md（skill 正本）
//   - .claude/skills/**/*.md（adapter と profile）
//   - .claude/agents/ の他の agent 定義（自分自身は数えない）
//   - .claude/settings.json
//   - .github/workflows/*.yml / *.yaml
//
// 起動経路に数えないもの: 定期実行のカタログ（docs/harness/scheduled-operations.md）や責務分界表への
// 名前の記載。名前が載っているだけでは、誰が起動するかを決めていないため。自然文で「〜を起動する」と
// 書くだけの記述も数えない。起動の指定は `subagent_type: <name>` の形で書く。
//
// 起動経路を持たない agent を意図的に残す場合は、agent 定義の冒頭（frontmatter の直後 15 行以内）に
//   > orphan-allow: <理由>
// の行を置く。理由の妥当性はレビューで判断する。

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  REPO_SCAN_TEST_TIMEOUT_MS,
  assertNoViolations,
  listFiles,
  listMarkdownFiles,
  parseFrontmatter,
  readRepoFile,
} from "./support/repo-files.mjs";

/** 冒頭として扱う、frontmatter 直後の行数。 */
const ORPHAN_ALLOW_WINDOW = 15;

function escapeRegExp(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** `subagent_type: <name>` の形で agent を起動する記述が text にあるか。 */
function launchesAgent(text, name) {
  const re = new RegExp(
    `subagent_type["'\`]?\\s*[:=]\\s*["'\`]?${escapeRegExp(name)}(?![A-Za-z0-9_-])`,
  );
  return re.test(text);
}

/** agent 定義の冒頭に `> orphan-allow: <理由>` があるか。理由が空なら false。 */
function declaresOrphanAllow(text) {
  const fm = parseFrontmatter(text);
  const body = fm ? fm.body : text;
  return body
    .split("\n")
    .slice(0, ORPHAN_ALLOW_WINDOW)
    .some((line) => /^>\s*orphan-allow:\s*\S/.test(line));
}

function agentFiles() {
  return listFiles(
    ".claude/agents",
    (p) => p.endsWith(".md") && p.split("/").length === 3,
  );
}

function launchCorpus() {
  return [
    ...listMarkdownFiles("docs/harness/skills"),
    ...listMarkdownFiles(".claude/skills"),
    ...listMarkdownFiles(".claude/agents"),
    ...listFiles(".claude", (p) => p === ".claude/settings.json"),
    ...listFiles(".github/workflows", (p) => /\.ya?ml$/.test(p)),
  ];
}

describe("agent 起動経路 gate: .claude/agents/", () => {
  it(
    "agent が 1 件以上あり、起動経路の走査対象が 0 件ではない（退化ガード）",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      assert.ok(agentFiles().length > 0, ".claude/agents/ に agent が 0 件");
      assert.ok(launchCorpus().length > 0, "起動経路の走査対象が 0 件");
    },
  );

  it(
    "各 agent が `subagent_type: <name>` で起動されるか、orphan-allow を宣言している",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const corpus = launchCorpus().map((rel) => ({
        rel,
        text: readRepoFile(rel),
      }));
      const violations = [];
      for (const rel of agentFiles()) {
        const name = rel.slice(".claude/agents/".length, -".md".length);
        const launched = corpus.some(
          (f) => f.rel !== rel && launchesAgent(f.text, name),
        );
        if (launched || declaresOrphanAllow(readRepoFile(rel))) continue;
        violations.push({
          file: rel,
          line: 1,
          message: `起動経路が無い。skill 正本などに \`subagent_type: ${name}\` を書くか、冒頭に \`> orphan-allow: <理由>\` を置く`,
        });
      }
      assertNoViolations(assert, "起動経路の無い agent", violations);
    },
  );
});

describe("agent 起動経路 gate: 自己テスト", () => {
  it("launchesAgent: 記法の揺れを許し、前方一致の別名と名前だけの記載は数えない", () => {
    assert.equal(
      launchesAgent(
        "Agent tool で `subagent_type: gc-agent` を起動する",
        "gc-agent",
      ),
      true,
    );
    assert.equal(launchesAgent('subagent_type = "gc-agent"', "gc-agent"), true);
    assert.equal(
      launchesAgent('{"subagent_type": "gc-agent"}', "gc-agent"),
      true,
    );
    assert.equal(
      launchesAgent("subagent_type: gc-agent-v2", "gc-agent"),
      false,
    );
    assert.equal(launchesAgent("gc-agent を起動する", "gc-agent"), false);
    assert.equal(
      launchesAgent("| gc-agent | 責務 | routine |", "gc-agent"),
      false,
    );
  });

  it("declaresOrphanAllow: 冒頭の宣言だけを認め、理由が空なら認めない", () => {
    const head = "---\nname: x\ndescription: d\n---\n\n# X\n\n";
    assert.equal(
      declaresOrphanAllow(`${head}> orphan-allow: 外部から直接読まれる\n`),
      true,
    );
    assert.equal(declaresOrphanAllow(`${head}> orphan-allow:\n`), false);
    assert.equal(
      declaresOrphanAllow(
        `${head}${"本文\n".repeat(20)}> orphan-allow: 遠すぎる\n`,
      ),
      false,
    );
    assert.equal(
      declaresOrphanAllow(`${head}orphan-allow: 引用符号なし\n`),
      false,
    );
  });
});
