// 構造 gate: ハーネス文書のサイズ上限、skill 正本と adapter の 1:1、adapter の薄さ、
// 検証ゲート名の整合を検査する。
//
// 上限値は docs/harness/harness_authoring_guide.md のサイズ表を正本として読む（この
// ファイルに数値を持たない）。表は次の 5 種別を持つ前提で、行頭セルのパス表記
// （OPERATING_MODEL.md / docs/harness/skills/ / .claude/skills/…/SKILL.md /
// .claude/agents/ / description）で種別を判定する。
//
// 検査範囲の外:
//   - docs/harness/skills/shared/ と docs/harness/skills/<name>/ は、表が上限を定めて
//     いない種別のため対象にしない。
//   - .claude/agents/references/ と .claude/skills/<name>/references/ も同じ理由で対象外。

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  IS_TEMPLATE_ROOT,
  REPO_SCAN_TEST_TIMEOUT_MS,
  assertNoViolations,
  countCodePoints,
  countLines,
  existsInRepo,
  findStaleExclusions,
  inlineCodeSpans,
  isDirInRepo,
  linesOutsideFences,
  fencedLines,
  listDir,
  listFiles,
  listHarnessFiles,
  parseFrontmatter,
  readRepoFile,
  readRequiredFile,
  validateExclusions,
} from "./support/repo-files.mjs";

const GUIDE = "docs/harness/harness_authoring_guide.md";
const GATES_DOC = "docs/harness/skills/shared/verification-gates.md";
const OPERATING_MODEL = "docs/harness/OPERATING_MODEL.md";

/**
 * 導入先の既存違反を一時的に許容するサイズ超過の除外。`{ path, reason }`。
 * 既定は空。許容した path が上限内に収まったら stale として失敗にするため、
 * 違反を解消したら同じ PR で除外も削除する。
 */
const SIZE_ALLOWLIST = [];

/**
 * ゲートのコマンド名（`pnpm run <name>`）を直接書いてよい文書。`{ path, reason }`。
 * 末尾 `/` はディレクトリ配下全体。許可箇所は verification-gates.md の記述と揃える。
 * これ以外の文書は組合せを `gate:<name>` で参照する。
 */
const DIRECT_COMMAND_ALLOWED = [
  {
    path: GATES_DOC,
    reason: "ゲートのコマンド定義と組合せの正本",
  },
  {
    path: ".claude/hooks/",
    reason: "hook が実行するゲートの実装と説明",
  },
];

function isAllowedDirectCommand(rel) {
  return DIRECT_COMMAND_ALLOWED.some((e) =>
    e.path.endsWith("/") ? rel.startsWith(e.path) : rel === e.path,
  );
}

/** `pnpm <name>` の `<name>` に現れても package.json の script ではないサブコマンド。 */
const PNPM_BUILTINS = new Set([
  "add",
  "approve-builds",
  "audit",
  "bin",
  "config",
  "create",
  "dedupe",
  "deploy",
  "dlx",
  "doctor",
  "env",
  "exec",
  "fetch",
  "i",
  "import",
  "init",
  "install",
  "licenses",
  "link",
  "list",
  "ln",
  "ls",
  "outdated",
  "pack",
  "patch",
  "prune",
  "publish",
  "rebuild",
  "remove",
  "rm",
  "root",
  "run",
  "self-update",
  "setup",
  "store",
  "un",
  "uninstall",
  "unlink",
  "up",
  "update",
  "upgrade",
  "why",
]);

// ---- 純関数 -----------------------------------------------------------------

const LIMIT_KINDS = [
  {
    key: "description",
    match: (cell) => /description/i.test(cell) && !cell.includes("/"),
  },
  {
    key: "adapter",
    match: (cell) => /\.claude\/skills\//.test(cell) && /SKILL\.md/.test(cell),
  },
  {
    key: "skill",
    match: (cell) => /docs\/harness\/skills\//.test(cell),
  },
  {
    key: "agent",
    match: (cell) => /\.claude\/agents\//.test(cell),
  },
  {
    key: "entry",
    match: (cell) => /OPERATING_MODEL\.md/.test(cell),
  },
];

/**
 * authoring guide のサイズ表から 5 種別の上限を読む。種別は行頭セルのパス表記で、上限は
 * 第 2 セルの `≤<数値>` で判定する（単位の語は読まない。description は文字数、それ以外は
 * 行数として扱う）。読めない種別があれば例外を投げる（表の書式が変わって検査が黙って外れる
 * ことを防ぐ）。
 */
function parseSizeLimits(guideText) {
  const limits = {};
  for (const raw of guideText.split("\n")) {
    const line = raw.trim();
    if (!line.startsWith("|")) continue;
    const cells = line
      .split("|")
      .slice(1, -1)
      .map((c) => c.trim());
    if (cells.length < 2) continue;
    const m = /(?:≤|<=)\s*(\d+)/.exec(cells[1]);
    if (!m) continue;
    const kind = LIMIT_KINDS.find((k) => k.match(cells[0]));
    if (!kind || limits[kind.key]) continue;
    limits[kind.key] = Number(m[1]);
  }
  const missing = LIMIT_KINDS.filter((k) => limits[k.key] === undefined).map(
    (k) => k.key,
  );
  if (missing.length > 0) {
    throw new Error(`サイズ表から上限を読めない種別: ${missing.join(", ")}`);
  }
  return limits;
}

/** verification-gates.md から script 名の定義表と名前付き組合せ（gate:*）を読む。 */
function parseGateDefinitions(text) {
  const scripts = [
    ...text.matchAll(/^\|\s*`pnpm(?: run)? ([\w:-]+)`\s*\|/gm),
  ].map((m) => m[1]);
  const combos = [
    ...new Set([...text.matchAll(/\bgate:[a-z][a-z0-9-]*/g)].map((m) => m[0])),
  ];
  return { scripts: [...new Set(scripts)], combos };
}

/**
 * 1 行に、定義済み script 名のコマンド表記が複数あるか（組合せの直書き）。
 * コマンド表記は 2 種類ある。
 *   - `pnpm run <name>` / `pnpm <name>`（フェンス内は行のどこでも、散文ではインラインコードの中）:
 *     2 種類以上で直書きとみなす。
 *   - インラインコードが `<name>` だけのもの: `test` や `build` は普通の語でもあるため、
 *     3 種類以上、または名前に `:` を含む script（`format:check` など）と `typecheck` を
 *     含む 2 種類以上で直書きとみなす。
 */
function listsGateCommands(lineText, inFence, scriptNames) {
  if (scriptNames.length === 0) return false;
  const alt = scriptNames
    .map((n) => n.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
    .join("|");
  const pnpmForm = new RegExp(`\\bpnpm(?: run)? (${alt})(?![\\w:-])`, "g");
  const viaPnpm = new Set();
  const viaBare = new Set();
  if (inFence) {
    for (const m of lineText.matchAll(pnpmForm)) viaPnpm.add(m[1]);
  } else {
    for (const span of inlineCodeSpans(lineText)) {
      const text = span.text.trim();
      const bare = new RegExp(`^(${alt})$`).exec(text);
      if (bare) viaBare.add(bare[1]);
      for (const m of text.matchAll(pnpmForm)) viaPnpm.add(m[1]);
    }
  }
  const all = new Set([...viaPnpm, ...viaBare]);
  if (viaPnpm.size >= 2) return true;
  const distinctive = [...all].some(
    (n) => n.includes(":") || n === "typecheck",
  );
  return all.size >= 3 || (all.size >= 2 && distinctive);
}

/** workflow 本文（コメントを除く）から `pnpm run <name>` / `pnpm <name>` の script 名を集める。 */
function pnpmScriptCalls(workflowText) {
  const names = new Set();
  for (const raw of workflowText.split("\n")) {
    const line = raw.replace(/(^|\s)#.*$/, "");
    for (const m of line.matchAll(/\bpnpm (?:run )?([a-z][\w:-]*)/g)) {
      if (!PNPM_BUILTINS.has(m[1])) names.add(m[1]);
    }
  }
  return [...names];
}

/** hook の `CI_CHECK_STEPS=(a b c)` から step 名を読む。無ければ null。 */
function parseCiCheckSteps(hookText) {
  const m = /^CI_CHECK_STEPS=\(([^)]*)\)/m.exec(hookText);
  return m ? m[1].split(/\s+/).filter(Boolean) : null;
}

// ---- 実リポジトリの列挙 --------------------------------------------------------

function entryFiles() {
  return [
    OPERATING_MODEL,
    "CLAUDE.md",
    "AGENTS.md",
    ".claude/CLAUDE.md",
  ].filter(existsInRepo);
}

function skillCanonFiles() {
  return listFiles(
    "docs/harness/skills",
    (p) => p.endsWith(".md") && p.split("/").length === 4,
  );
}

function adapterFiles() {
  return listFiles(
    ".claude/skills",
    (p) => p.endsWith("/SKILL.md") && p.split("/").length === 4,
  );
}

function agentFiles() {
  return listFiles(
    ".claude/agents",
    (p) => p.endsWith(".md") && p.split("/").length === 3,
  );
}

function skillNameFromCanon(rel) {
  return rel.slice("docs/harness/skills/".length, -".md".length);
}

function skillNameFromAdapter(rel) {
  return rel.split("/")[2];
}

function measureSizes() {
  const limits = parseSizeLimits(readRequiredFile(GUIDE));
  const lines = (rel) => countLines(readRepoFile(rel));
  const descriptionLength = (rel) => {
    const fm = parseFrontmatter(readRepoFile(rel));
    const d = fm ? (fm.fields.get("description") ?? "") : "";
    return countCodePoints(d);
  };
  return [
    {
      kind: "entry",
      label: "入口文書（OPERATING_MODEL / CLAUDE / AGENTS）",
      unit: "行",
      limit: limits.entry,
      files: entryFiles(),
      measure: lines,
    },
    {
      kind: "skill",
      label: "skill 正本",
      unit: "行",
      limit: limits.skill,
      files: skillCanonFiles(),
      measure: lines,
    },
    {
      kind: "adapter",
      label: "thin adapter",
      unit: "行",
      limit: limits.adapter,
      files: adapterFiles(),
      measure: lines,
    },
    {
      kind: "agent",
      label: "agent 定義",
      unit: "行",
      limit: limits.agent,
      files: agentFiles(),
      measure: lines,
    },
    {
      kind: "description",
      label: "skill description",
      unit: "文字",
      limit: limits.description,
      files: adapterFiles(),
      measure: descriptionLength,
    },
  ].map((k) => ({
    ...k,
    rows: k.files.map((file) => ({ file, value: k.measure(file) })),
  }));
}

// ---- サイズ上限 ------------------------------------------------------------------

describe("構造 gate: サイズ上限（authoring guide の表から読む）", () => {
  it(
    "表から 5 種別の上限を読める",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const limits = parseSizeLimits(readRequiredFile(GUIDE));
      for (const [key, value] of Object.entries(limits)) {
        assert.ok(Number.isInteger(value) && value > 0, `${key} の上限が不正`);
      }
    },
  );

  it(
    "走査対象が各種別で 0 件ではない（退化ガード）",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      assert.ok(existsInRepo(OPERATING_MODEL), `${OPERATING_MODEL} が無い`);
      for (const k of measureSizes()) {
        assert.ok(k.rows.length > 0, `${k.label} の走査対象が 0 件`);
      }
    },
  );

  it("各ファイルが表の上限以内", { timeout: REPO_SCAN_TEST_TIMEOUT_MS }, () => {
    const allowed = new Map(SIZE_ALLOWLIST.map((e) => [e.path, e.reason]));
    const violations = [];
    for (const k of measureSizes()) {
      for (const { file, value } of k.rows) {
        if (value > k.limit && !allowed.has(file)) {
          violations.push(
            `${file}  ${k.label}が上限 ${k.limit} ${k.unit} を超過（${value} ${k.unit}）`,
          );
        }
      }
    }
    assertNoViolations(assert, "サイズ上限の超過", violations);
  });

  it(
    "サイズ超過の許容リストが理由付きで、stale を含まない",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      assert.deepEqual(validateExclusions(SIZE_ALLOWLIST, "path"), []);
      const over = new Set();
      for (const k of measureSizes()) {
        for (const { file, value } of k.rows) {
          if (value > k.limit) over.add(file);
        }
      }
      const stale = findStaleExclusions(SIZE_ALLOWLIST, (e) =>
        over.has(e.path),
      );
      assert.deepEqual(
        stale.map((e) => e.path),
        [],
        "上限内に収まった path が許容リストに残っている。除外を削除する",
      );
    },
  );
});

// ---- skill 正本と adapter ---------------------------------------------------------

describe("構造 gate: skill 正本と adapter の 1:1・薄さ", () => {
  it(
    "docs/harness/skills/*.md と .claude/skills/*/SKILL.md が同名で 1:1",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const canon = skillCanonFiles().map(skillNameFromCanon);
      const adapters = adapterFiles().map(skillNameFromAdapter);
      assert.ok(canon.length > 0, "skill 正本が 0 件");
      assert.ok(adapters.length > 0, "adapter が 0 件");
      const violations = [];
      for (const name of canon) {
        if (!adapters.includes(name)) {
          violations.push(
            `docs/harness/skills/${name}.md  対応する .claude/skills/${name}/SKILL.md が無い`,
          );
        }
      }
      for (const name of adapters) {
        if (!canon.includes(name)) {
          violations.push(
            `.claude/skills/${name}/SKILL.md  対応する docs/harness/skills/${name}.md が無い`,
          );
        }
      }
      for (const dir of listDir("docs/harness/skills")) {
        if (
          dir !== "shared" &&
          isDirInRepo(`docs/harness/skills/${dir}`) &&
          !canon.includes(dir)
        ) {
          violations.push(
            `docs/harness/skills/${dir}/  同名の正本 docs/harness/skills/${dir}.md が無い（skill 固有の詳細は正本と同名のディレクトリに置く）`,
          );
        }
      }
      for (const dir of listDir(".claude/skills")) {
        if (
          isDirInRepo(`.claude/skills/${dir}`) &&
          !existsInRepo(`.claude/skills/${dir}/SKILL.md`)
        ) {
          violations.push(`.claude/skills/${dir}/  SKILL.md が無い`);
        }
      }
      assertNoViolations(assert, "skill 正本と adapter の不整合", violations);
    },
  );

  it(
    "adapter は frontmatter（name = ディレクトリ名・単一行の description）と正本への参照だけを持つ",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const files = adapterFiles();
      assert.ok(files.length > 0, "adapter が 0 件");
      const violations = [];
      for (const file of files) {
        const name = skillNameFromAdapter(file);
        const text = readRepoFile(file);
        const fm = parseFrontmatter(text);
        if (!fm) {
          violations.push(`${file}  frontmatter が無い`);
          continue;
        }
        if (fm.fields.get("name") !== name) {
          violations.push(
            `${file}  name がディレクトリ名 ${name} と一致しない（${fm.fields.get("name") ?? "未定義"}）`,
          );
        }
        if (fm.multiline.has("description")) {
          violations.push(
            `${file}  description が複数行。単一行にする（長さを検査できない）`,
          );
        } else if ((fm.fields.get("description") ?? "") === "") {
          violations.push(`${file}  description が空`);
        }
        if (!text.includes(`docs/harness/skills/${name}.md`)) {
          violations.push(
            `${file}  正本 docs/harness/skills/${name}.md への参照が無い`,
          );
        }
      }
      assertNoViolations(assert, "adapter の構造違反", violations);
    },
  );

  it(
    "入口 adapter（AGENTS.md / CLAUDE.md）は OPERATING_MODEL を参照する",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const files = ["AGENTS.md", "CLAUDE.md", ".claude/CLAUDE.md"].filter(
        existsInRepo,
      );
      assert.ok(files.length > 0, "入口 adapter が 0 件");
      const violations = [];
      for (const file of files) {
        if (!readRepoFile(file).includes(OPERATING_MODEL)) {
          violations.push(`${file}  ${OPERATING_MODEL} への参照が無い`);
        }
      }
      assertNoViolations(assert, "入口 adapter の参照欠落", violations);
    },
  );
});

// ---- 検証ゲート名 -----------------------------------------------------------------

function gateReferenceFiles() {
  return [
    ...new Set([
      ...listHarnessFiles(),
      ...listFiles(".claude", (p) => /\.(sh|json)$/.test(p)),
      ...listFiles(".github", (p) => /\.(ya?ml|md)$/.test(p)),
      ...listFiles("docs", (p) => p.endsWith(".md")),
    ]),
  ].sort();
}

describe("構造 gate: 検証ゲート名の整合", () => {
  it(
    "verification-gates.md が script 名と名前付き組合せ（gate:*）を定義している",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const defs = parseGateDefinitions(readRequiredFile(GATES_DOC));
      assert.ok(
        defs.scripts.length > 0,
        "コマンド定義表から script 名を読めない",
      );
      assert.ok(
        defs.combos.length > 0,
        "名前付き組合せ（gate:<name>）が定義されていない",
      );
    },
  );

  it(
    "定義表の script 名が package.json の scripts に存在する",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const scripts = Object.keys(
        JSON.parse(readRequiredFile("package.json")).scripts ?? {},
      );
      const defs = parseGateDefinitions(readRequiredFile(GATES_DOC));
      const missing = defs.scripts.filter((n) => !scripts.includes(n));
      assert.deepEqual(
        missing,
        [],
        "package.json に無い script を定義表が持つ",
      );
    },
  );

  it(
    "workflow の pnpm 呼び出しが package.json の scripts に存在する",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const workflows = listFiles(".github/workflows", (p) =>
        /\.ya?ml$/.test(p),
      );
      assert.ok(workflows.length > 0, "workflow が 0 件");
      const scripts = Object.keys(
        JSON.parse(readRequiredFile("package.json")).scripts ?? {},
      );
      const violations = [];
      for (const file of workflows) {
        for (const name of pnpmScriptCalls(readRepoFile(file))) {
          if (!scripts.includes(name)) {
            violations.push(
              `${file}  pnpm ${name} は package.json の scripts に無い`,
            );
          }
        }
      }
      assertNoViolations(assert, "workflow が呼ぶ script の欠落", violations);
    },
  );

  it(
    "pre-push hook の CI_CHECK_STEPS が package.json の scripts に存在する",
    {
      timeout: REPO_SCAN_TEST_TIMEOUT_MS,
      skip: existsInRepo(".claude/hooks/pre-push-ci-check.sh")
        ? false
        : "pre-push hook が無い",
    },
    () => {
      const steps = parseCiCheckSteps(
        readRepoFile(".claude/hooks/pre-push-ci-check.sh"),
      );
      assert.ok(
        steps !== null && steps.length > 0,
        "CI_CHECK_STEPS を読めない",
      );
      const scripts = Object.keys(
        JSON.parse(readRequiredFile("package.json")).scripts ?? {},
      );
      const missing = steps.filter((n) => !scripts.includes(n));
      assert.deepEqual(missing, [], "package.json に無い step を hook が呼ぶ");
    },
  );

  it(
    "gate:* の参照がすべて定義済みで、定義済みの組合せがどこかで参照されている",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const defs = parseGateDefinitions(readRequiredFile(GATES_DOC));
      const referenced = new Map();
      for (const file of gateReferenceFiles()) {
        if (file === GATES_DOC) continue;
        const text = readRepoFile(file);
        for (const m of text.matchAll(/\bgate:[a-z][a-z0-9-]*/g)) {
          if (!referenced.has(m[0])) referenced.set(m[0], file);
        }
      }
      const violations = [];
      for (const [name, file] of referenced) {
        if (!defs.combos.includes(name)) {
          violations.push(`${file}  ${name} は ${GATES_DOC} に定義が無い`);
        }
      }
      for (const name of defs.combos) {
        if (!referenced.has(name)) {
          violations.push(
            `${GATES_DOC}  ${name} をどの文書も参照していない。参照するか定義を削除する`,
          );
        }
      }
      assertNoViolations(assert, "名前付き組合せの不整合", violations);
    },
  );

  it(
    "組合せは名前で参照し、ゲートのコマンド列を直書きしない",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const defs = parseGateDefinitions(readRequiredFile(GATES_DOC));
      const reasonProblems = validateExclusions(DIRECT_COMMAND_ALLOWED, "path");
      assert.deepEqual(reasonProblems, []);
      const violations = [];
      for (const file of listHarnessFiles()) {
        if (isAllowedDirectCommand(file)) continue;
        const text = readRepoFile(file);
        const prose = linesOutsideFences(text);
        const fenced = fencedLines(text);
        for (const { n, text: t } of prose) {
          if (listsGateCommands(t, false, defs.scripts)) {
            violations.push({
              file,
              line: n,
              message:
                "ゲートのコマンド列を直書きしている。gate:<name> で参照する",
            });
          }
        }
        for (const { n, text: t } of fenced) {
          if (listsGateCommands(t, true, defs.scripts)) {
            violations.push({
              file,
              line: n,
              message:
                "ゲートのコマンド列を直書きしている。gate:<name> で参照する",
            });
          }
        }
      }
      assertNoViolations(assert, "ゲートのコマンド列の直書き", violations);
    },
  );
});

// ---- 自己テスト（固定入力の純関数。timeout を付けない） --------------------------------

describe("構造 gate: 自己テスト", () => {
  const goodTable = [
    "| ファイル種別 | 上限 | 根拠 |",
    "|---|---|---|",
    "| OPERATING_MODEL.md / CLAUDE.md / AGENTS.md | ≤200 行 | a |",
    "| skill 正本（`docs/harness/skills/<name>.md`） | ≤500 行 | b |",
    "| thin adapter（`.claude/skills/<name>/SKILL.md`） | ≤20 行 | c |",
    "| Agent 定義（`.claude/agents/*.md`） | ≤250 行 | d |",
    "| Skill description（frontmatter） | ≤250 文字 | e |",
  ].join("\n");

  it("parseSizeLimits: 5 種別を読む", () => {
    assert.deepEqual(parseSizeLimits(goodTable), {
      entry: 200,
      skill: 500,
      adapter: 20,
      agent: 250,
      description: 250,
    });
  });

  it("parseSizeLimits: 種別が欠けたら例外", () => {
    const missing = goodTable.split("\n").slice(0, -1).join("\n");
    assert.throws(() => parseSizeLimits(missing), /description/);
  });

  it("parseSizeLimits: 単位の語に依存しない", () => {
    const translated = goodTable
      .replaceAll("行", "lines")
      .replace("文字", "chars");
    assert.equal(parseSizeLimits(translated).description, 250);
    assert.equal(parseSizeLimits(translated).entry, 200);
  });

  it("parseGateDefinitions: script 名と gate:* を読む", () => {
    const text = [
      "| コマンド | 役割 |",
      "|---|---|",
      "| `pnpm run lint` | 静的解析 |",
      "| `pnpm run format:check` | 差分検査 |",
      "| `gate:commit` | lint |",
      "本文で `gate:push` と `gate:commit` を使う。",
    ].join("\n");
    const defs = parseGateDefinitions(text);
    assert.deepEqual(defs.scripts, ["lint", "format:check"]);
    assert.deepEqual(defs.combos.sort(), ["gate:commit", "gate:push"]);
  });

  it("listsGateCommands: 散文の列挙とフェンス内の列挙を検出する", () => {
    const names = ["format:check", "lint", "typecheck", "test", "build"];
    assert.equal(
      listsGateCommands(
        "`format:check` + `lint` + `build` を通す",
        false,
        names,
      ),
      true,
    );
    assert.equal(
      listsGateCommands("pnpm run lint && pnpm run test", true, names),
      true,
    );
    assert.equal(
      listsGateCommands("`pnpm run lint` を通す", false, names),
      false,
    );
    assert.equal(listsGateCommands("lint と test を通す", false, names), false);
    assert.equal(listsGateCommands("pnpm run lint", true, names), false);
  });

  it("pnpmScriptCalls: コメントと組み込みサブコマンドを除く", () => {
    const yml = [
      "      - run: pnpm install --frozen-lockfile",
      "      - run: pnpm test",
      "      - run: pnpm run format:check",
      "      # pnpm lint はここでは実行しない",
      "      - run: pnpm exec prettier --check .",
    ].join("\n");
    assert.deepEqual(pnpmScriptCalls(yml).sort(), ["format:check", "test"]);
  });

  it("parseCiCheckSteps: 配列を読む / 無ければ null", () => {
    assert.deepEqual(parseCiCheckSteps("CI_CHECK_STEPS=(a b:c d)\n"), [
      "a",
      "b:c",
      "d",
    ]);
    assert.equal(parseCiCheckSteps("echo hi\n"), null);
  });

  it("許容リストの形: IS_TEMPLATE_ROOT は真偽値", () => {
    assert.equal(typeof IS_TEMPLATE_ROOT, "boolean");
  });
});
