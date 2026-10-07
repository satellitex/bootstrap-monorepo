// 構造 gate: ハーネス文書のサイズ上限、skill 正本と adapter の 1:1、adapter の薄さ、
// 検証ゲート名の整合、文書間の名前の整合（skill 表・rule 表・routine カタログ・pnpm の版）を
// 検査する。
//
// 上限値は docs/harness/harness_authoring_guide.md のサイズ表を正本として読む（この
// ファイルに数値を持たない）。表は次の 5 種別を持つ前提で、行頭セルのパス表記
// （OPERATING_MODEL.md / docs/harness/skills/ / .claude/skills/…/SKILL.md /
// .claude/agents/ / description）で種別を判定する。
//
// 検証ゲート名の整合は 3 点を見る。
//   - 文書中の `gate:<name>` の参照が、verification-gates.md の表に定義されている。
//   - verification-gates.md の定義表が挙げる script が、package.json の scripts に実在する。
//   - pre-push hook の CI_CHECK_STEPS が、verification-gates.md の `gate:push` の定義と一致する。
//
// 文書間の名前の整合は、表から読んだ名前の集合を実ファイルの集合と突き合わせる。
//   - OPERATING_MODEL の skill 表の名前 = .claude/skills/*/
//   - scheduled-operations の routine カタログの名前 ⊂ .claude/skills/*/
//   - OPERATING_MODEL の領域別 rule 表の名前 = .claude/rules/*.md
//   - package.json の packageManager の pnpm の版 = .mise.toml の "npm:pnpm" の版
// どの検査も、表や pin から名前・版を 1 件も読めなければ失敗する（読み取りが壊れて何も検査して
// いないのに green になることを避ける）。
//
// 検査範囲の外:
//   - docs/harness/skills/shared/ と docs/harness/skills/<name>/ は、表が上限を定めて
//     いない種別のため対象にしない。
//   - .claude/agents/references/ と .claude/skills/<name>/references/ も同じ理由で対象外。

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  REPO_SCAN_TEST_TIMEOUT_MS,
  assertNoViolations,
  countCodePoints,
  countLines,
  existsInRepo,
  findStaleExclusions,
  isDirInRepo,
  linesOutsideFences,
  listAgentFiles,
  listDir,
  listFiles,
  listHarnessFiles,
  once,
  packageScriptNames,
  parseFrontmatter,
  readRepoFile,
  readRequiredFile,
  validateExclusions,
} from "./support/repo-files.mjs";

const GUIDE = "docs/harness/harness_authoring_guide.md";
const GATES_DOC = "docs/harness/skills/shared/verification-gates.md";
const OPERATING_MODEL = "docs/harness/OPERATING_MODEL.md";
const SCHEDULED_OPERATIONS = "docs/harness/scheduled-operations.md";
const PRE_PUSH_HOOK = ".claude/hooks/pre-push-ci-check.sh";
const MISE_TOML = ".mise.toml";

/** 入口の薄い adapter。いずれも OPERATING_MODEL を参照する。 */
const ENTRY_ADAPTERS = ["AGENTS.md", "CLAUDE.md", ".claude/CLAUDE.md"];

/**
 * 導入先の既存違反を一時的に許容するサイズ超過の除外。`{ path, reason }`。
 * 既定は空。許容した path が上限内に収まったら stale として失敗にするため、
 * 違反を解消したら同じ PR で除外も削除する。
 */
const SIZE_ALLOWLIST = [];

// ---- 純関数 -----------------------------------------------------------------

/**
 * markdown の表の各行を、前後の空白を除いたセルの配列にする。フェンス内の行と、区切り行
 * （`---`）は含めない。
 */
function tableRows(text) {
  return linesOutsideFences(text)
    .map(({ text: line }) => line.trim())
    .filter((line) => line.startsWith("|"))
    .map((line) =>
      line
        .replace(/^\||\|$/g, "")
        .split("|")
        .map((cell) => cell.trim()),
    )
    .filter((cells) => !cells.every((cell) => /^:?-{3,}:?$/.test(cell)));
}

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
  for (const cells of tableRows(guideText)) {
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

/**
 * verification-gates.md の表から、script の定義（行頭セルが `pnpm run <name>`）と、名前付き
 * 組合せの定義（行頭セルが `gate:<name>`）を読む。返り値の `combos` は、組合せの名前から、
 * 第 2 セルが挙げる定義済み script 名の配列への Map。第 2 セルの括弧書きは補足（他の組合せが
 * 実行するゲートへの言及など）として構成に数えない。
 */
function parseGateDefinitions(text) {
  const rows = tableRows(text);
  const scripts = [
    ...new Set(
      rows
        .map((cells) => /^`pnpm(?: run)? ([\w:-]+)`$/.exec(cells[0])?.[1])
        .filter(Boolean),
    ),
  ];
  const combos = new Map();
  for (const [first, second = ""] of rows) {
    const name = /^`(gate:[a-z][a-z0-9-]*)`$/.exec(first)?.[1];
    if (!name) continue;
    const body = second.replace(/（[^）]*）|\([^)]*\)/g, "");
    combos.set(
      name,
      [...body.matchAll(/`([^`]+)`/g)]
        .map((m) => m[1])
        .filter((n) => scripts.includes(n)),
    );
  }
  return { scripts, combos };
}

/** hook の `CI_CHECK_STEPS=(a b c)` から step 名を読む。無ければ null。 */
function parseCiCheckSteps(hookText) {
  const m = /^CI_CHECK_STEPS=\(([^)]*)\)/m.exec(hookText);
  return m ? m[1].split(/\s+/).filter(Boolean) : null;
}

/** 表のセルが単独のインラインコードで `/<name>`（引数は任意）の形のとき、その `<name>`。 */
function slashCommandName(cell) {
  return /^`\/([a-z][a-z0-9-]*)(?:\s[^`]*)?`$/.exec(cell)?.[1] ?? null;
}

/** 文書中の表のセルに書かれた skill コマンド名（`/<name>` の `<name>`）。重複なし、昇順。 */
function slashCommandNames(text) {
  const names = tableRows(text).flatMap((cells) =>
    cells.map(slashCommandName).filter((name) => name !== null),
  );
  return [...new Set(names)].sort();
}

/** 文書中の表の行頭セルに書かれた rule ファイル名（`.claude/rules/<file>.md`）。重複なし、昇順。 */
function ruleFileNames(text) {
  const names = tableRows(text)
    .map((cells) => /^`\.claude\/rules\/([^`/]+\.md)`$/.exec(cells[0])?.[1])
    .filter(Boolean);
  return [...new Set(names)].sort();
}

/** package.json の `packageManager`（`pnpm@<版>`、`+<hash>` は除く）から pnpm の版を読む。 */
function pnpmVersionFromPackageManager(value) {
  return /^pnpm@([^+\s]+)/.exec(value ?? "")?.[1] ?? null;
}

/** .mise.toml の `"npm:pnpm" = "<版>"` から pnpm の版を読む。 */
function pnpmVersionFromMise(text) {
  return /^\s*["']npm:pnpm["']\s*=\s*["']([^"']+)["']/m.exec(text)?.[1] ?? null;
}

/** `a` にあって `b` に無い要素。 */
const without = (a, b) => a.filter((x) => !b.includes(x));

// ---- 実リポジトリの列挙 --------------------------------------------------------

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

function skillDirNames() {
  return listDir(".claude/skills").filter((name) =>
    isDirInRepo(`.claude/skills/${name}`),
  );
}

function skillNameFromCanon(rel) {
  return rel.slice("docs/harness/skills/".length, -".md".length);
}

function skillNameFromAdapter(rel) {
  return rel.split("/")[2];
}

const measureSizes = once(() => {
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
      files: [OPERATING_MODEL, ...ENTRY_ADAPTERS].filter(existsInRepo),
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
      files: listAgentFiles(),
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
});

/** 上限を超えたファイル（許容リストを適用する前）。`{ file, value, k }`。 */
const oversized = once(() =>
  measureSizes().flatMap((k) =>
    k.rows.filter((r) => r.value > k.limit).map((r) => ({ ...r, k })),
  ),
);

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
    const allowed = new Set(SIZE_ALLOWLIST.map((e) => e.path));
    const violations = oversized()
      .filter(({ file }) => !allowed.has(file))
      .map(
        ({ file, value, k }) =>
          `${file}  ${k.label}が上限 ${k.limit} ${k.unit} を超過（${value} ${k.unit}）`,
      );
    assertNoViolations(assert, "サイズ上限の超過", violations);
  });

  it(
    "サイズ超過の許容リストが理由付きで、stale を含まない",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      assert.deepEqual(validateExclusions(SIZE_ALLOWLIST, "path"), []);
      const over = new Set(oversized().map(({ file }) => file));
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
      for (const dir of skillDirNames()) {
        if (!existsInRepo(`.claude/skills/${dir}/SKILL.md`)) {
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
      const files = ENTRY_ADAPTERS.filter(existsInRepo);
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
        defs.combos.size > 0,
        "名前付き組合せ（gate:<name>）が定義されていない",
      );
    },
  );

  it(
    "定義表の script 名が package.json の scripts に存在する",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const scripts = packageScriptNames();
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
    "文書中の gate:* の参照がすべて verification-gates.md に定義されている",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const defs = parseGateDefinitions(readRequiredFile(GATES_DOC));
      const violations = [];
      for (const file of gateReferenceFiles()) {
        if (file === GATES_DOC) continue;
        const names = new Set(
          readRepoFile(file).match(/\bgate:[a-z][a-z0-9-]*/g) ?? [],
        );
        for (const name of names) {
          if (!defs.combos.has(name)) {
            violations.push(`${file}  ${name} は ${GATES_DOC} に定義が無い`);
          }
        }
      }
      assertNoViolations(assert, "未定義の組合せの参照", violations);
    },
  );

  it(
    "pre-push hook の CI_CHECK_STEPS が gate:push の定義と一致する",
    {
      timeout: REPO_SCAN_TEST_TIMEOUT_MS,
      skip: existsInRepo(PRE_PUSH_HOOK) ? false : "pre-push hook が無い",
    },
    () => {
      const steps = parseCiCheckSteps(readRepoFile(PRE_PUSH_HOOK));
      assert.ok(
        steps !== null && steps.length > 0,
        "CI_CHECK_STEPS を読めない",
      );
      const defined = parseGateDefinitions(
        readRequiredFile(GATES_DOC),
      ).combos.get("gate:push");
      assert.ok(
        defined !== undefined && defined.length > 0,
        `${GATES_DOC} から gate:push の定義を読めない`,
      );
      assert.deepEqual(
        [...steps].sort(),
        [...defined].sort(),
        `hook の CI_CHECK_STEPS が ${GATES_DOC} の gate:push の定義と異なる。hook と定義を同一 PR で揃える`,
      );
    },
  );
});

// ---- 文書間の名前の整合 -------------------------------------------------------------

describe("構造 gate: 文書間の名前の整合", () => {
  it(
    "OPERATING_MODEL の skill 表が .claude/skills/ の skill と同じ集合",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const listed = slashCommandNames(readRequiredFile(OPERATING_MODEL));
      assert.ok(
        listed.length > 0,
        `${OPERATING_MODEL} の表から skill コマンド（\`/<name>\`）を読めない`,
      );
      const actual = skillDirNames();
      assert.ok(actual.length > 0, ".claude/skills/ に skill が 0 件");
      assertNoViolations(assert, "skill 表と .claude/skills/ の不一致", [
        ...without(listed, actual).map(
          (n) =>
            `${OPERATING_MODEL}  表の /${n} に対応する .claude/skills/${n}/ が無い`,
        ),
        ...without(actual, listed).map(
          (n) =>
            `.claude/skills/${n}/  ${OPERATING_MODEL} の skill 表に行が無い`,
        ),
      ]);
    },
  );

  it(
    "routine カタログの skill がすべて .claude/skills/ に存在する",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const listed = slashCommandNames(readRequiredFile(SCHEDULED_OPERATIONS));
      assert.ok(
        listed.length > 0,
        `${SCHEDULED_OPERATIONS} の表から routine のエントリポイント（\`/<name>\`）を読めない`,
      );
      const actual = skillDirNames();
      assertNoViolations(
        assert,
        "routine カタログの不整合",
        without(listed, actual).map(
          (n) =>
            `${SCHEDULED_OPERATIONS}  routine /${n} に対応する .claude/skills/${n}/ が無い`,
        ),
      );
    },
  );

  it(
    "OPERATING_MODEL の領域別 rule 表が .claude/rules/*.md と同じ集合",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const listed = ruleFileNames(readRequiredFile(OPERATING_MODEL));
      assert.ok(
        listed.length > 0,
        `${OPERATING_MODEL} の表から rule（\`.claude/rules/<file>.md\`）を読めない`,
      );
      const actual = listDir(".claude/rules").filter((n) => n.endsWith(".md"));
      assert.ok(actual.length > 0, ".claude/rules/ に rule が 0 件");
      assertNoViolations(assert, "rule 表と .claude/rules/ の不一致", [
        ...without(listed, actual).map(
          (n) =>
            `${OPERATING_MODEL}  表の .claude/rules/${n} に対応するファイルが無い`,
        ),
        ...without(actual, listed).map(
          (n) => `.claude/rules/${n}  ${OPERATING_MODEL} の rule 表に行が無い`,
        ),
      ]);
    },
  );

  it(
    "pnpm の版が package.json の packageManager と .mise.toml で一致する（dual-pin）",
    {
      timeout: REPO_SCAN_TEST_TIMEOUT_MS,
      skip: existsInRepo(MISE_TOML)
        ? false
        : `${MISE_TOML} が無い（mise を使わない導入先）`,
    },
    () => {
      const fromPackage = pnpmVersionFromPackageManager(
        JSON.parse(readRequiredFile("package.json")).packageManager,
      );
      const fromMise = pnpmVersionFromMise(readRepoFile(MISE_TOML));
      assert.ok(
        fromPackage !== null,
        "package.json の packageManager から pnpm の版を読めない",
      );
      assert.ok(fromMise !== null, `${MISE_TOML} の "npm:pnpm" の版を読めない`);
      assert.equal(
        fromMise,
        fromPackage,
        `pnpm の版が package.json の packageManager（${fromPackage}）と ${MISE_TOML}（${fromMise}）で異なる。2 か所を同時に更新する`,
      );
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

  it("tableRows: セルを trim し、区切り行とフェンス内の行を除く", () => {
    const text = [
      "| a | b |",
      "| :--- | ---: |",
      "|  `x`  |y|",
      "```",
      "| z | w |",
      "```",
      "本文 | 表ではない",
    ].join("\n");
    assert.deepEqual(tableRows(text), [
      ["a", "b"],
      ["`x`", "y"],
    ]);
  });

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

  it("parseGateDefinitions: script 名と組合せの構成を表から読み、括弧書きと本文の言及は数えない", () => {
    const text = [
      "| コマンド | 役割 |",
      "|---|---|",
      "| `pnpm run lint` | 静的解析 |",
      "| `pnpm run format:check` | 差分検査 |",
      "| `pnpm run test` | テスト |",
      "",
      "| 名前 | 内容 |",
      "|---|---|",
      "| `gate:commit` | `lint` + `format:check` + `test` |",
      "| `gate:push` | `lint` + `format:check`（`test` は `gate:ci` が実行） |",
      "本文で `gate:docs` を参照する。",
    ].join("\n");
    const defs = parseGateDefinitions(text);
    assert.deepEqual(defs.scripts, ["lint", "format:check", "test"]);
    assert.deepEqual([...defs.combos.keys()], ["gate:commit", "gate:push"]);
    assert.deepEqual(defs.combos.get("gate:commit"), [
      "lint",
      "format:check",
      "test",
    ]);
    assert.deepEqual(defs.combos.get("gate:push"), ["lint", "format:check"]);
  });

  it("parseCiCheckSteps: 配列を読む / 無ければ null", () => {
    assert.deepEqual(parseCiCheckSteps("CI_CHECK_STEPS=(a b:c d)\n"), [
      "a",
      "b:c",
      "d",
    ]);
    assert.equal(parseCiCheckSteps("echo hi\n"), null);
  });

  it("slashCommandNames: 単独のインラインコードの `/<name>` だけを読む（引数は落とす）", () => {
    const text = [
      "| コマンド | 用途 |",
      "|---|---|",
      "| `/multi-issue #N ...` | 実装 |",
      "| `/docs-sync` | 突合 |",
      "| `/<name>` で `.claude/skills/<name>/SKILL.md` が起動する | 読み替え |",
      "| 週次 | `/docs-sync` | 重複は 1 件にまとまる |",
      "| `docs/harness/x.md` | 別のセル |",
    ].join("\n");
    assert.deepEqual(slashCommandNames(text), ["docs-sync", "multi-issue"]);
  });

  it("ruleFileNames: 行頭セルの `.claude/rules/<file>.md` だけを読む", () => {
    const text = [
      "| rule | スコープ |",
      "|---|---|",
      "| `.claude/rules/team-policy.md` | 全領域 |",
      "| `.claude/rules/product-development.md` | `apps/**/*` |",
      "| 本文の `.claude/rules/other.md` の言及 | x |",
    ].join("\n");
    assert.deepEqual(ruleFileNames(text), [
      "product-development.md",
      "team-policy.md",
    ]);
  });

  it("pnpm の版の読み取り: packageManager の hash 接尾辞を除き、.mise.toml の pin を読む", () => {
    assert.equal(pnpmVersionFromPackageManager("pnpm@11.24.0"), "11.24.0");
    assert.equal(
      pnpmVersionFromPackageManager("pnpm@11.24.0+sha512.abc"),
      "11.24.0",
    );
    assert.equal(pnpmVersionFromPackageManager("yarn@4.0.0"), null);
    assert.equal(pnpmVersionFromPackageManager(undefined), null);
    assert.equal(
      pnpmVersionFromMise('[tools]\nnode = "22"\n"npm:pnpm" = "11.24.0"\n'),
      "11.24.0",
    );
    assert.equal(pnpmVersionFromMise('[tools]\nnode = "22"\n'), null);
  });
});
