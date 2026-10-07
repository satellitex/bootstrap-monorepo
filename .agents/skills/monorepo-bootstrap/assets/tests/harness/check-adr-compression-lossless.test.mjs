// check-adr-compression-lossless.mjs の自己テスト。検査対象ルート（HARNESS_ROOT）には依存せず、
// 固定の ADR 文字列と一時ファイルだけを使う。CLI は main() をインプロセスで呼び、子プロセスの
// 起動は、スクリプトとして実行したときの終了コード（isMain と process.exit の経路）を確かめる
// 1 件だけにする。

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  SUMMARIZED_MARKER,
  classifyStatus,
  collectReferences,
  extractStatus,
  findSection,
  main,
  verifyCompression,
} from "./check-adr-compression-lossless.mjs";

const CLI = fileURLToPath(
  new URL("./check-adr-compression-lossless.mjs", import.meta.url),
);

const BEFORE = [
  "# ADR-20260101_branch_topic: タイトル",
  "",
  "| 項目 | 値 |",
  "|------|-----|",
  "| Status | Accepted |",
  "| Date | 2026-01-01 |",
  "",
  "## Context",
  "",
  "長い背景。長い背景。長い背景。長い背景。長い背景。長い背景。",
  "レビューの往復ログ。レビューの往復ログ。レビューの往復ログ。",
  "ADR-20251201_old_topic と #42 と docs/requirements/FR-0001_x.md を参照する。",
  "",
  "## Decision",
  "",
  "方針 A を採用する。",
  "",
  "### 理由",
  "",
  "- 理由 1",
  "",
  "## Consequences",
  "",
  "- 良い点も悪い点も長く書いてある。長く書いてある。長く書いてある。",
  "",
  "## Related Issues",
  "",
  "- #42",
  "- `docs/requirements/FR-0001_x.md`（要件 FR-0001）",
  "",
].join("\n");

const AFTER = [
  "# ADR-20260101_branch_topic: タイトル",
  "",
  "| 項目 | 値 |",
  "|------|-----|",
  "| Status | Accepted |",
  "| Date | 2026-01-01 |",
  "",
  "## Context",
  "",
  "要約した背景。ADR-20251201_old_topic と #42 と docs/requirements/FR-0001_x.md を参照する。",
  "",
  "## Decision",
  "",
  "方針 A を採用する。",
  "",
  "### 理由",
  "",
  "- 理由 1",
  "",
  "## Consequences",
  "",
  "- 要約した帰結。",
  "",
  "## Related Issues",
  "",
  "- #42",
  "- `docs/requirements/FR-0001_x.md`（要件 FR-0001）",
  "",
  `<!-- ${SUMMARIZED_MARKER} --> 詳細は git 履歴を参照する。`,
  "",
].join("\n");

function failedIds(result) {
  return result.checks.filter((c) => !c.ok).map((c) => c.id);
}

describe("check-adr-compression-lossless: 判定", () => {
  it("決定節・関連 Issue 節・参照・Status が保たれ、サイズが減っていれば通る", () => {
    const result = verifyCompression(BEFORE, AFTER);
    assert.deepEqual(failedIds(result), []);
    assert.equal(result.ok, true);
    assert.ok(result.stats.after.bytes < result.stats.before.bytes);
  });

  it("決定節の空白の連続・改行位置だけの差は許し、語句の変更は落とす", () => {
    const spaced = AFTER.replace("- 理由 1", "-   理由\n1");
    assert.deepEqual(failedIds(verifyCompression(BEFORE, spaced)), []);
    const edited = AFTER.replace("方針 A を採用する。", "方針 B を採用する。");
    assert.deepEqual(failedIds(verifyCompression(BEFORE, edited)), [
      "decision",
    ]);
  });

  it("決定節の下位見出し（理由）が落ちたら落とす", () => {
    const dropped = AFTER.replace("### 理由\n\n- 理由 1\n\n", "");
    assert.deepEqual(failedIds(verifyCompression(BEFORE, dropped)), [
      "decision",
    ]);
  });

  it("決定節が 0 個・複数個なら証明できないとして落とす", () => {
    const none = BEFORE.replace("## Decision", "## Choice");
    assert.deepEqual(failedIds(verifyCompression(none, AFTER)), ["decision"]);
    const twice = `${BEFORE}\n## Decision\n\n別の決定。\n`;
    assert.ok(failedIds(verifyCompression(twice, AFTER)).includes("decision"));
  });

  it("関連 Issue 節の変更・欠落を落とす", () => {
    const edited = AFTER.replace("- #42\n", "");
    assert.ok(
      failedIds(verifyCompression(BEFORE, edited)).includes("related-issues"),
    );
    const noSection = BEFORE.slice(0, BEFORE.indexOf("## Related Issues"));
    assert.equal(
      verifyCompression(
        noSection,
        noSection.replace("長い背景。", ""),
      ).checks.find((c) => c.id === "related-issues").ok,
      true,
    );
  });

  it("相互参照（ADR id・Issue 番号・要件 ID・パス）が消えたら落とす", () => {
    for (const target of [
      "ADR-20251201_old_topic",
      "#42",
      "docs/requirements/FR-0001_x.md",
    ]) {
      const lost = AFTER.split(target).join("参照");
      assert.ok(
        failedIds(verifyCompression(BEFORE, lost)).includes("references"),
        `${target} の欠落を検出できない`,
      );
    }
  });

  it("Status が変わった・読めないときは落とす", () => {
    const changed = AFTER.replace(
      "| Status | Accepted |",
      "| Status | Deprecated |",
    );
    assert.ok(failedIds(verifyCompression(BEFORE, changed)).includes("status"));
    const unreadable = BEFORE.replace(
      "| Status | Accepted |",
      "| Status | Proposed / Accepted |",
    );
    assert.ok(
      failedIds(verifyCompression(unreadable, unreadable)).includes("status"),
    );
  });

  it("サイズが減っていなければ落とす", () => {
    assert.ok(failedIds(verifyCompression(BEFORE, BEFORE)).includes("size"));
    assert.ok(
      failedIds(verifyCompression(BEFORE, `${BEFORE}\n追記\n`)).includes(
        "size",
      ),
    );
  });

  it("要約注記（marker を含む行）は比較から除く", () => {
    const noted = `${BEFORE}<!-- ${SUMMARIZED_MARKER} --> 注記\n`;
    const result = verifyCompression(noted, AFTER);
    assert.deepEqual(failedIds(result), []);
  });

  it("コードブロック内の見出しは節として数えない", () => {
    const text = [
      "## Decision",
      "",
      "本文",
      "",
      "```",
      "## Decision",
      "```",
      "",
    ].join("\n");
    assert.equal(findSection(text, "Decision").count, 1);
  });
});

describe("check-adr-compression-lossless: Status の読み取り", () => {
  it("4 形（表・節・箇条書き・太字）を読み、装飾を外して付記を保つ", () => {
    assert.equal(extractStatus("| Status | **Accepted** |"), "Accepted");
    assert.equal(extractStatus("## Status\n\nAccepted\n"), "Accepted");
    assert.equal(
      extractStatus("- Status: Superseded by [ADR-1](./ADR-1.md)"),
      "Superseded by ADR-1",
    );
    assert.equal(extractStatus("**Status**: Accepted"), "Accepted");
    assert.equal(extractStatus("**Status:** Accepted"), "Accepted");
    assert.equal(extractStatus("本文だけ"), null);
  });

  it("キーワードが 1 つに定まらなければ分類しない", () => {
    assert.equal(classifyStatus("Accepted"), "accepted");
    assert.equal(
      classifyStatus("Superseded by ADR-1（部分置換）"),
      "superseded",
    );
    assert.equal(classifyStatus("Proposed / Accepted / Deprecated"), null);
    assert.equal(classifyStatus("Unknown"), null);
    assert.equal(classifyStatus(null), null);
  });
});

describe("check-adr-compression-lossless: 相互参照の抽出", () => {
  it("ADR id は .md と末尾の句点を落とし、パスはアンカーと行番号を落とす", () => {
    const refs = [
      ...collectReferences(
        "[a](ADR-20260101_x_y.md) と ADR-20260101_x_y. と docs/adr/README.md#運用 と tests/a.mjs:10",
      ).values(),
    ].map((r) => `${r.rule}:${r.ref}`);
    assert.deepEqual(refs.sort(), [
      "adr-id:ADR-20260101_x_y",
      "repo-path:docs/adr/README.md",
      "repo-path:tests/a.mjs",
    ]);
  });

  it("Issue 番号は #数字 だけを拾い、見出し記法・アンカーは拾わない", () => {
    const refs = [
      ...collectReferences(
        "# 見出し\n\n#12 と (#34) と page#6 と #abc",
      ).values(),
    ].map((r) => r.ref);
    assert.deepEqual(refs.sort(), ["#12", "#34"]);
  });
});

describe("check-adr-compression-lossless: CLI", () => {
  /** 一時ファイルに before / after を書き、main() をインプロセスで呼ぶ。 */
  function runMain(before, after, extra = []) {
    const dir = mkdtempSync(join(tmpdir(), "adr-lossless-"));
    try {
      const b = join(dir, "before.md");
      const a = join(dir, "after.md");
      writeFileSync(b, before);
      writeFileSync(a, after);
      const out = [];
      const err = [];
      const status = main([b, a, ...extra], {
        out: (line) => out.push(line),
        err: (line) => err.push(line),
      });
      return { status, stdout: out.join("\n"), stderr: err.join("\n") };
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  }

  it("通れば終了コード 0、落ちれば 1", () => {
    const pass = runMain(BEFORE, AFTER);
    assert.equal(pass.status, 0, pass.stdout + pass.stderr);
    assert.match(pass.stdout, /PASS/);
    const fail = runMain(BEFORE, AFTER.replace("方針 A", "方針 B"));
    assert.equal(fail.status, 1);
    assert.match(fail.stdout, /FAIL decision/);
  });

  it("引数不足・未知のオプション・読めないファイルは終了コード 2", () => {
    const quiet = { out: () => {}, err: () => {} };
    assert.equal(main([], quiet), 2);
    assert.equal(main(["--unknown", "a", "b"], quiet), 2);
    assert.equal(main(["--decision-heading"], quiet), 2);
    assert.equal(main(["/nonexistent/a.md", "/nonexistent/b.md"], quiet), 2);
  });

  it("見出し名を差し替えられる", () => {
    const localize = (s) =>
      s
        .replace("## Decision", "## 決定")
        .replace("## Related Issues", "## 関連 Issue");
    const result = runMain(localize(BEFORE), localize(AFTER), [
      "--decision-heading",
      "決定",
      "--related-heading",
      "関連 Issue",
    ]);
    assert.equal(result.status, 0, result.stdout + result.stderr);
  });

  it("スクリプトとして実行すると、判定の終了コードで終了する", () => {
    const dir = mkdtempSync(join(tmpdir(), "adr-lossless-"));
    try {
      const b = join(dir, "before.md");
      const a = join(dir, "after.md");
      writeFileSync(b, BEFORE);
      writeFileSync(a, AFTER.replace("方針 A", "方針 B"));
      const r = spawnSync(process.execPath, [CLI, b, a], { encoding: "utf8" });
      assert.equal(r.status, 1, r.stdout + r.stderr);
      assert.match(r.stdout, /FAIL decision/);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
