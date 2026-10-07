// 参照実在 gate: ハーネス文書のインラインコードに書かれたリポジトリ相対パスが実在するか検査する。
//
// 走査対象はハーネス文書（support/repo-files.mjs の listHarnessFiles）。対象のパスは
// PATH_PREFIXES で始まるトークンで、インラインコード（バッククォート 1 組）の中にあるものだけを
// 見る。フェンス付きコードブロックは例示として扱い、検査しない。
//
// 実在判定から外すもの:
//   - ワイルドカード・プレースホルダ・変数展開などのメタ文字を含むトークン
//   - .gitignore で無視される実行時の生成物
//   - MISSING_PATH_EXCLUSIONS に理由付きで登録したトークン
//
// 限界: ファイル名だけの参照（`README.md` など接頭辞の無いもの）は判定しない。
// 節名や見出しの参照も判定しない。

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  IS_TEMPLATE_ROOT,
  REPO_SCAN_TEST_TIMEOUT_MS,
  assertNoViolations,
  existsExactCase,
  findStaleExclusions,
  inlineCodeSpans,
  linesOutsideFences,
  listHarnessFiles,
  loadGitignoreMatcher,
  readRepoFile,
  validateExclusions,
} from "./support/repo-files.mjs";

/** 実在確認の対象にするパスの接頭辞。 */
const PATH_PREFIXES = [
  ".agents/",
  ".claude/",
  ".github/",
  "apps/",
  "docs/",
  "infra/",
  "packages/",
  "scripts/",
  "tests/",
];

/**
 * 実在しないが、参照として正しいトークン。`{ candidate, reason, optional? }`。
 * `candidate` は末尾の `/` を除いたトークン全体、または末尾 `/**` を持つ接頭辞。
 * 本文に出現しない除外は stale として失敗にする。`optional: true` の除外は、導入先の文書構成に
 * よって現れないことがあるため、テンプレート資産でだけ stale を検査する。導入先で除外を足す
 * ときは `optional` を付けず、対象が消えたら除外も削除する。
 */
const MISSING_PATH_EXCLUSIONS = [
  {
    candidate: "apps",
    reason:
      "ワークスペースのパッケージ置き場。実装を始めるまで存在しないため、ディレクトリ単体の言及は実在を求めない",
    optional: true,
  },
  {
    candidate: "packages",
    reason:
      "ワークスペースのパッケージ置き場。実装を始めるまで存在しないため、ディレクトリ単体の言及は実在を求めない",
    optional: true,
  },
  {
    candidate: "infra",
    reason:
      "IaC を採用したときに作るディレクトリ。不採用の導入先では infra 向けの rule ごと削除する",
    optional: true,
  },
  {
    candidate: ".github/renovate.json",
    reason:
      "Renovate が探索する設定ファイルの候補パスの 1 つ。採用先は候補のうち 1 か所にだけ置く",
    optional: true,
  },
];

const META_CHARS = /[*?<>{}$|()[\]~^!&;"'\\=,]|\.{3}|…/;
const PLACEHOLDER_WORDS = /YYYY|MM-DD|\bXXX|\bNNN/;

/** インラインコードの中から、接頭辞で始まるパス候補トークンを集める。 */
function extractPathCandidates(text) {
  const out = [];
  for (const { n, text: line } of linesOutsideFences(text)) {
    for (const span of inlineCodeSpans(line)) {
      for (const raw of span.text.split(/\s+/)) {
        const token = normalizeToken(raw);
        if (token !== null) out.push({ n, token });
      }
    }
  }
  return out;
}

/** トークンを実在確認用のパスに正規化する。対象外なら null。 */
function normalizeToken(raw) {
  let t = raw;
  if (!PATH_PREFIXES.some((p) => t.startsWith(p))) return null;
  t = t.replace(/[.,;:)]+$/, "");
  t = t.replace(/#.*$/, "");
  t = t.replace(/:(?:L?\d+)(?:-L?\d+)?$/, "");
  t = t.replace(/\/+$/, "");
  if (t === "" || META_CHARS.test(t) || PLACEHOLDER_WORDS.test(t)) return null;
  return t;
}

function matchesExclusion(token, exclusion) {
  return exclusion.candidate.endsWith("/**")
    ? token.startsWith(exclusion.candidate.slice(0, -2))
    : token === exclusion.candidate;
}

function isExcluded(token) {
  return MISSING_PATH_EXCLUSIONS.some((e) => matchesExclusion(token, e));
}

function collectCandidates() {
  const out = [];
  for (const file of listHarnessFiles()) {
    for (const c of extractPathCandidates(readRepoFile(file))) {
      out.push({ file, ...c });
    }
  }
  return out;
}

describe("参照実在 gate: ハーネス文書のパス参照", () => {
  it(
    "走査対象のハーネス文書とパス候補が 0 件ではない（退化ガード）",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      assert.ok(listHarnessFiles().length > 0, "ハーネス文書が 0 件");
      assert.ok(collectCandidates().length > 0, "パス候補が 0 件");
    },
  );

  it(
    "インラインコードのパス参照が実在する",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const ignored = loadGitignoreMatcher();
      const violations = [];
      for (const { file, n, token } of collectCandidates()) {
        if (isExcluded(token) || ignored(token) || ignored(`${token}/`))
          continue;
        if (!existsExactCase(token)) {
          violations.push({ file, line: n, message: `${token} が実在しない` });
        }
      }
      assertNoViolations(assert, "実在しないパス参照", violations);
    },
  );

  it(
    "除外定数が理由付きで、本文に出現する（stale を含まない）",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      assert.deepEqual(
        validateExclusions(MISSING_PATH_EXCLUSIONS, "candidate"),
        [],
      );
      const tokens = collectCandidates().map((c) => c.token);
      const stale = findStaleExclusions(
        MISSING_PATH_EXCLUSIONS.filter((e) => IS_TEMPLATE_ROOT || !e.optional),
        (e) => tokens.some((t) => matchesExclusion(t, e)),
      );
      assert.deepEqual(
        stale.map((e) => e.candidate),
        [],
        "本文に出現しない除外が残っている。除外を削除する",
      );
    },
  );
});

describe("参照実在 gate: 自己テスト", () => {
  it("接頭辞で始まるトークンを、行番号・アンカー・末尾の句読点を落として抽出する", () => {
    const text = [
      "`docs/adr/README.md` を読む。",
      "`docs/styles/refactoring_guide.md#検出観点` と `.claude/hooks/x.sh:42,`",
      "`bash tests/harness/run.mjs` を実行する。",
    ].join("\n");
    assert.deepEqual(
      extractPathCandidates(text).map((c) => c.token),
      [
        "docs/adr/README.md",
        "docs/styles/refactoring_guide.md",
        ".claude/hooks/x.sh",
        "tests/harness/run.mjs",
      ],
    );
  });

  it("末尾のスラッシュを落とし、ディレクトリ参照も同じ形にそろえる", () => {
    assert.deepEqual(
      extractPathCandidates("`apps/` と `docs/adr/`").map((c) => c.token),
      ["apps", "docs/adr"],
    );
  });

  it("除外は完全一致と接頭辞（/**）で判定する", () => {
    assert.equal(matchesExclusion("apps", { candidate: "apps" }), true);
    assert.equal(matchesExclusion("apps/api", { candidate: "apps" }), false);
    assert.equal(matchesExclusion("tmp/a/b", { candidate: "tmp/**" }), true);
  });

  it("メタ文字・プレースホルダ・フェンス内・接頭辞なしは対象外", () => {
    const text = [
      "`docs/**/*.md` `docs/adr/ADR-<id>.md` `docs/${name}.md`",
      "`docs/YYYY-MM-DD.md` `docs/x/XXX.md` `README.md` `src/a.ts`",
      "```",
      "docs/in-fence.md",
      "```",
      "`https://example.com/docs/a.md`",
    ].join("\n");
    assert.deepEqual(extractPathCandidates(text), []);
  });
});
