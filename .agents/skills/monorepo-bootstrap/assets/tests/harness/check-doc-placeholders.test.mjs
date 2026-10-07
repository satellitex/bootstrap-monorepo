// 未置換 token・未解決プレースホルダの残存 gate。
//
// ここでいうプレースホルダは、波括弧 2 つで名前を囲んだ記法（以下「二重波括弧」）を指す。
// 恒久検査の対象は docs/ 配下の markdown（ADR を含む）の散文に限る。既存資産にはテンプレート
// 構文（二重波括弧を使うツールの設定例など）が含まれうるため、コードブロックとインラインコードの
// 中は対象にしない。置換対象外の記入欄（support/repo-files.mjs の TEMPLATE_FORM_PATHS）も
// 対象にしない。
//
// モード:
//   - bootstrap 先（既定）: 散文中の二重波括弧はすべて未解決として失敗する。bootstrap 時の
//     明示 token（EXPLICIT_TOKENS）が docs/ のどこかに残っている場合は、コードブロックと
//     インラインコードの中も含めて失敗する。
//   - テンプレート資産（ルートが MANIFEST.md を持つ）: 明示 token は置換前の状態として
//     許容し、それ以外の二重波括弧だけを失敗にする。
//
// TODO は `TODO(取得方法: …)` と `TODO(記入方法: …)` の 2 記法だけを使う。記入欄として書かれた
// 記法外の TODO（`TODO(…` の別の種別、`TODO:`、表のセルや HTML コメントの単独の TODO）は失敗にする。
// 散文中の「TODO」という語の言及（コメントのマーカーの説明など）は対象にしない。走査範囲は docs/ と
// ハーネス文書（.claude/ 配下・ルート直下の *.md）で、件数は完了報告の残 TODO 一覧と突合できるよう
// 診断に出す。
//
// 空 owner の症状（`github.com//` など）は、owner / repo の取得コマンドが空応答でも置換が
// 成功扱いになる経路の後段防御として、どちらのモードでも失敗にする。
//
// このファイルは二重波括弧の実例を持つ固定入力を使う。bootstrap 時の一括置換で書き換わらない
// よう、実例は実行時に組み立てる（T 関数）。

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  EXPLICIT_TOKENS,
  IS_TEMPLATE_ROOT,
  REPO_SCAN_TEST_TIMEOUT_MS,
  assertNoViolations,
  isTemplateFormPath,
  linesOutsideFences,
  listHarnessFiles,
  listMarkdownFiles,
  proseLines,
  readRepoFile,
  stripInlineCode,
} from "./support/repo-files.mjs";

const OPEN = "{" + "{";
const CLOSE = "}" + "}";

/** 二重波括弧のプレースホルダ文字列を作る（固定入力用）。 */
const T = (name) => `${OPEN}${name}${CLOSE}`;

/** GitHub Actions の式（ドル記号で始まるもの）を除く二重波括弧。 */
const PLACEHOLDER_RE = /(?<!\$)\{\{([^{}\n]*)\}\}/g;

/** 散文（コードブロックとインラインコードの外）にある二重波括弧の位置と中身。 */
function findBarePlaceholders(text, allowedNames = []) {
  const out = [];
  for (const { n, text: line } of proseLines(text)) {
    for (const m of line.matchAll(PLACEHOLDER_RE)) {
      const name = m[1].trim();
      if (!allowedNames.includes(name)) out.push({ n, token: m[0] });
    }
  }
  return out;
}

/** 明示 token を、コードブロックとインラインコードの中も含めて探す。 */
function findExplicitTokens(text) {
  const out = [];
  text.split("\n").forEach((line, i) => {
    for (const m of line.matchAll(PLACEHOLDER_RE)) {
      if (EXPLICIT_TOKENS.includes(m[1].trim())) {
        out.push({ n: i + 1, token: m[0] });
      }
    }
  });
  return out;
}

/**
 * 空 owner / 空 repo の症状。`github.com//`・`repos//` は取得値が空のまま埋め込まれた形。
 * owner の位置に未置換 token が残った形は、テンプレート資産では置換前の状態として許容する。
 */
function findEmptyOwnerSymptoms(text, { allowTokenOwner }) {
  const out = [];
  text.split("\n").forEach((line, i) => {
    if (/github\.com\/\/(?!\/)/.test(line) || /\brepos\/\/(?!\/)/.test(line)) {
      out.push({
        n: i + 1,
        message: "owner / repo が空のまま埋め込まれている",
      });
    }
    if (!allowTokenOwner && line.includes(`github.com/${OPEN}`)) {
      out.push({ n: i + 1, message: "owner が未置換 token のまま残っている" });
    }
  });
  return out;
}

/** 記入欄として書かれた、2 記法（取得方法 / 記入方法）に当てはまらない TODO。 */
const BARE_TODO_RE =
  /(?<![\w`])TODO(?:\((?!(?:取得方法|記入方法):)|[:：]|\s*\||\s*-->)/;

function scanTargets() {
  return listMarkdownFiles("docs").filter((rel) => !isTemplateFormPath(rel));
}

/** TODO の検査と件数報告の対象: docs/ とハーネス文書の和集合。 */
function todoScanTargets() {
  return [...new Set([...scanTargets(), ...listHarnessFiles()])].sort();
}

describe("placeholder residue gate: docs/ の未置換 token・空 owner", () => {
  it(
    "走査対象の docs/**/*.md が 0 件ではない（退化ガード）",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      assert.ok(scanTargets().length > 0, "docs/ 配下の走査対象が 0 件");
    },
  );

  it(
    "散文に未解決の二重波括弧プレースホルダが残っていない",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const allowed = IS_TEMPLATE_ROOT ? EXPLICIT_TOKENS : [];
      const violations = [];
      for (const file of scanTargets()) {
        for (const { n, token } of findBarePlaceholders(
          readRepoFile(file),
          allowed,
        )) {
          violations.push({
            file,
            line: n,
            message: `未解決のプレースホルダ ${token}`,
          });
        }
      }
      assertNoViolations(assert, "未解決プレースホルダ", violations);
    },
  );

  it(
    "bootstrap の明示 token が docs/ に残っていない（bootstrap 先のみ）",
    {
      timeout: REPO_SCAN_TEST_TIMEOUT_MS,
      skip: IS_TEMPLATE_ROOT
        ? "テンプレート資産では置換前の明示 token が正"
        : false,
    },
    () => {
      const violations = [];
      for (const file of scanTargets()) {
        for (const { n, token } of findExplicitTokens(readRepoFile(file))) {
          violations.push({
            file,
            line: n,
            message: `未置換の明示 token ${token}`,
          });
        }
      }
      assertNoViolations(assert, "未置換の明示 token", violations);
    },
  );

  it(
    "空 owner / 空 repo の症状が docs/ に無い",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const violations = [];
      for (const file of scanTargets()) {
        for (const s of findEmptyOwnerSymptoms(readRepoFile(file), {
          allowTokenOwner: IS_TEMPLATE_ROOT,
        })) {
          violations.push({ file, line: s.n, message: s.message });
        }
      }
      assertNoViolations(assert, "空 owner の症状", violations);
    },
  );

  it(
    "裸の TODO が無い（TODO は取得方法 / 記入方法の 2 記法だけ）",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const violations = [];
      for (const file of todoScanTargets()) {
        for (const { n, text } of proseLines(readRepoFile(file))) {
          if (BARE_TODO_RE.test(text)) {
            violations.push({ file, line: n, message: "記法外の TODO" });
          }
        }
      }
      assertNoViolations(assert, "記法外の TODO", violations);
    },
  );

  it(
    "TODO の件数を報告する（完了報告の TODO 一覧との突合に使う）",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    (t) => {
      let total = 0;
      for (const file of todoScanTargets()) {
        const count = [
          ...readRepoFile(file).matchAll(/TODO\((?:取得方法|記入方法):/g),
        ].length;
        if (count > 0) {
          total += count;
          t.diagnostic(`${file}: TODO ${count} 件`);
        }
      }
      t.diagnostic(`docs/ とハーネス文書の TODO 合計: ${total} 件`);
      assert.ok(todoScanTargets().length > 0);
    },
  );
});

describe("placeholder residue gate: 自己テスト", () => {
  it("散文のプレースホルダを検出し、コードブロック・インラインコード・式は除く", () => {
    const text = [
      `本文に ${T("ORPHAN")} が残る。`,
      `\`${T("IN_CODE")}\` はインラインコード。`,
      "$" + `${OPEN} github.token ${CLOSE} は式。`,
      "```yaml",
      `image: ${T("IN_FENCE")}`,
      "```",
      `末尾 ${T("TAIL")}`,
    ].join("\n");
    assert.deepEqual(
      findBarePlaceholders(text).map((p) => [p.n, p.token]),
      [
        [1, T("ORPHAN")],
        [7, T("TAIL")],
      ],
    );
  });

  it("許容した明示 token は検出しない", () => {
    const text = `${T("PRODUCT_NAME")} と ${T("OTHER")}`;
    assert.deepEqual(
      findBarePlaceholders(text, ["PRODUCT_NAME"]).map((p) => p.token),
      [T("OTHER")],
    );
  });

  it("明示 token はコードブロックとインラインコードの中も検出する", () => {
    const text = [
      `\`${T("REPO_NAME")}\``,
      "```",
      T("GITHUB_ORG"),
      "```",
      T("FREE_FORM"),
    ].join("\n");
    assert.deepEqual(
      findExplicitTokens(text).map((p) => p.token),
      [T("REPO_NAME"), T("GITHUB_ORG")],
    );
  });

  it("空 owner の症状を検出する", () => {
    const text = [
      "https://github.com//repo/issues/1",
      "gh api repos//x/issues",
      `https://github.com/${T("GITHUB_ORG")}/${T("REPO_NAME")}`,
      "https://github.com/acme/repo",
    ].join("\n");
    assert.deepEqual(
      findEmptyOwnerSymptoms(text, { allowTokenOwner: false }).map((s) => s.n),
      [1, 2, 3],
    );
    assert.deepEqual(
      findEmptyOwnerSymptoms(text, { allowTokenOwner: true }).map((s) => s.n),
      [1, 2],
    );
  });

  it("2 記法に当てはまらない TODO を検出する", () => {
    assert.ok(BARE_TODO_RE.test("TODO: あとで書く"));
    assert.ok(BARE_TODO_RE.test("TODO(bootstrap 時: 書く)"));
    assert.ok(BARE_TODO_RE.test("| TODO(取得方法: 確認する) | TODO |"));
    assert.ok(BARE_TODO_RE.test("<!-- TODO -->"));
    assert.ok(!BARE_TODO_RE.test("TODO(取得方法: 版を確認する)"));
    assert.ok(!BARE_TODO_RE.test("TODO(記入方法: 判断基準を書く)"));
    assert.ok(!BARE_TODO_RE.test("TODO 記法と TODO / FIXME の説明"));
    assert.ok(!BARE_TODO_RE.test("TODOS は別の語"));
  });

  it("インラインコードの除去は桁位置を保つ", () => {
    assert.equal(stripInlineCode("a `bc` d"), "a      d");
    assert.equal(linesOutsideFences("x\n```\ny\n```\nz").length, 2);
  });
});
