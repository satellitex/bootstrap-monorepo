#!/usr/bin/env node
// ADR 本文の要約圧縮（adr-compress のカテゴリ IV）が、決定内容を落としていないことを検証する CLI。
//
//   node tests/harness/check-adr-compression-lossless.mjs <before> <after> [options]
//
//   <before>   要約を始める直前の ADR（ファイルパス）
//   <after>    要約後の ADR（ファイルパス）
//   --decision-heading <text>   決定節の見出し（既定: Decision）
//   --related-heading <text>    関連 Issue 節の見出し（既定: Related Issues）
//
// 判定（1 つでも満たさなければ終了コード 1）:
//   1. 決定節が空白を正規化したうえで前後で逐語一致する（見出しは前後ともちょうど 1 つ）
//   2. 関連 Issue 節が要約前にあれば、前後で逐語一致する
//   3. 要約前に現れた相互参照（ADR id・リポジトリ内パス・Issue / PR 番号・要件 ID）が後にも残る
//   4. Status の値が前後で変わらない（読み取れない場合は証明できないとして失敗）
//   5. 要約後のサイズ（バイト数）が要約前より小さい
//
// 終了コード: 0 = 全判定を通過 / 1 = 判定に失敗（証明できない場合を含む）/ 2 = 引数・読み込みエラー。
// 無人実行では前後を読み比べる人がいないため、無損失を証明できない要約は失敗として扱う。
//
// node:test からも `verifyCompression()` を import して呼べる。依存は Node 標準と support/markdown.mjs
// （検査対象のルートを解決しない純粋なヘルパ）だけ。

import { readFileSync, realpathSync } from "node:fs";
import { fileURLToPath } from "node:url";
import {
  PATH_PREFIXES,
  countLines,
  escapeRegExp,
  fenceMask,
} from "./support/markdown.mjs";

/** 要約済みを示す注記行の marker。この marker を含む行は比較から除く。 */
export const SUMMARIZED_MARKER = "adr-compress:summarized";

export const DEFAULT_DECISION_HEADING = "Decision";
export const DEFAULT_RELATED_HEADING = "Related Issues";

/**
 * 相互参照として保全する識別子の抽出規則。プロジェクトの ID 体系に合わせて差し替える。
 * 各規則は `{ name, re, normalize }`。`re` はグローバルフラグ付き。
 */
export const REFERENCE_RULES = [
  {
    name: "adr-id",
    re: /ADR-\d{8}[A-Za-z0-9_-]*(?:\.[A-Za-z0-9_-]+)*/g,
    normalize: (s) => s.replace(/\.md$/, "").replace(/\.+$/, ""),
  },
  {
    name: "issue-or-pr",
    re: /(?<![\w&#/])#\d+(?!\w)/g,
    normalize: (s) => s,
  },
  {
    name: "requirement-id",
    re: /\b[A-Z]{2,5}-\d{4}(?:-FIX)?\b/g,
    normalize: (s) => s,
  },
  {
    name: "repo-path",
    re: new RegExp(
      `(?<![\\w./-])(?:${PATH_PREFIXES.map((p) => escapeRegExp(p)).join("|")})[^\\s\`)\\]"'<>|,;]+`,
      "g",
    ),
    normalize: (s) =>
      s
        .replace(/#.*$/, "")
        .replace(/:(?:L?\d+)(?:-L?\d+)?$/, "")
        .replace(/[.,;:]+$/, ""),
  },
];

const STATUS_KEYWORDS = ["proposed", "accepted", "deprecated", "superseded"];

// ---- 節と Status の読み取り -----------------------------------------------------

function normalizeSpace(s) {
  return s.replace(/\s+/g, " ").trim();
}

/** 注記行（marker を含む行）を除いた本文。 */
function stripSummaryNote(text) {
  return text
    .split("\n")
    .filter((line) => !line.includes(SUMMARIZED_MARKER))
    .join("\n");
}

/**
 * `## <heading>` の節を探す。返り値は `{ count, body }`。count は同名見出し（レベル 2）の数、
 * body は最初の節の本文（次のレベル 1〜2 の見出しまで）を空白正規化した文字列。
 */
export function findSection(text, heading) {
  const lines = text.split("\n");
  const mask = fenceMask(lines);
  const isHeading = (i) => !mask[i] && /^#{1,2}\s+\S/.test(lines[i]);
  let count = 0;
  let body = null;
  for (let i = 0; i < lines.length; i += 1) {
    if (mask[i]) continue;
    const m = /^##\s+(.*?)\s*$/.exec(lines[i]);
    if (!m || m[1] !== heading) continue;
    count += 1;
    if (body !== null) continue;
    let j = i + 1;
    while (j < lines.length && !isHeading(j)) j += 1;
    body = normalizeSpace(lines.slice(i + 1, j).join("\n"));
  }
  return { count, body };
}

// ---- Status -------------------------------------------------------------------

function normalizeStatusValue(raw) {
  return normalizeSpace(
    raw.replace(/\[([^\]]*)\]\([^)]*\)/g, "$1").replace(/\*+|`/g, ""),
  );
}

/**
 * Status 値を読む。4 形を上から順に探し、最初に見つかったものを使う:
 * 表の Status 行 / `## Status` 節の最初の非空行 / `- Status:` の箇条書き / 太字の Status 行。
 * 読めなければ null。
 */
export function extractStatus(text) {
  const lines = text.split("\n");
  const mask = fenceMask(lines);
  const live = (i) => !mask[i];

  for (let i = 0; i < lines.length; i += 1) {
    if (!live(i) || !lines[i].trim().startsWith("|")) continue;
    const cells = lines[i]
      .split("|")
      .slice(1)
      .map((c) => c.trim());
    if (
      cells.length >= 2 &&
      /^\**Status\**$/i.test(cells[0]) &&
      cells[1] !== ""
    ) {
      return normalizeStatusValue(cells[1]);
    }
  }
  for (let i = 0; i < lines.length; i += 1) {
    if (live(i) && /^##\s+Status\s*$/i.test(lines[i])) {
      for (let j = i + 1; j < lines.length; j += 1) {
        if (/^#{1,6}\s/.test(lines[j])) break;
        if (lines[j].trim() !== "") return normalizeStatusValue(lines[j]);
      }
    }
  }
  for (let i = 0; i < lines.length; i += 1) {
    if (!live(i)) continue;
    const m = /^\s*[-*]\s+\**Status\**\s*:\s*\**\s*(.+)$/i.exec(lines[i]);
    if (m) return normalizeStatusValue(m[1]);
  }
  for (let i = 0; i < lines.length; i += 1) {
    if (!live(i)) continue;
    const m = /^\s*\*\*Status(?::\*\*|\*\*\s*:)\s*(.+)$/i.exec(lines[i]);
    if (m) return normalizeStatusValue(m[1]);
  }
  return null;
}

/** Status 値が 4 キーワードのどれか 1 つで始まるか。付記（by …・括弧書き）は判定に含めない。 */
export function classifyStatus(value) {
  if (value === null) return null;
  const head = value.split(/\s+by\s+|[（(]/i)[0];
  const found = STATUS_KEYWORDS.filter((k) =>
    new RegExp(`\\b${k}\\b`, "i").test(head),
  );
  if (found.length !== 1) return null;
  return new RegExp(`^${found[0]}\\b`, "i").test(head.trim()) ? found[0] : null;
}

// ---- 相互参照 -----------------------------------------------------------------

/**
 * 本文から相互参照を集める。返り値は `<規則名>\0<参照>` をキーとする `{ rule, ref }` の Map
 * （同じ参照は 1 つにまとまる）。
 */
export function collectReferences(text, rules = REFERENCE_RULES) {
  const out = new Map();
  for (const rule of rules) {
    for (const m of text.matchAll(rule.re)) {
      const ref = rule.normalize(m[0]);
      if (ref !== "")
        out.set(`${rule.name}\u0000${ref}`, { rule: rule.name, ref });
    }
  }
  return out;
}

// ---- 検証 ---------------------------------------------------------------------

function byteLength(text) {
  return Buffer.byteLength(text, "utf8");
}

/**
 * 要約前後の ADR 本文を検証する。
 * 返り値: `{ ok, checks: [{ id, ok, detail }], stats: { before, after } }`。
 */
export function verifyCompression(beforeRaw, afterRaw, options = {}) {
  const decisionHeading = options.decisionHeading ?? DEFAULT_DECISION_HEADING;
  const relatedHeading = options.relatedHeading ?? DEFAULT_RELATED_HEADING;
  const rules = options.referenceRules ?? REFERENCE_RULES;
  const before = stripSummaryNote(beforeRaw);
  const after = stripSummaryNote(afterRaw);
  const checks = [];
  const add = (id, ok, detail) => checks.push({ id, ok, detail });

  // 節の逐語一致。`optional` の節は、要約前に無ければ対象外とする。
  const compareSection = (id, heading, { optional = false } = {}) => {
    const b = findSection(before, heading);
    if (optional && b.count === 0) {
      return add(id, true, `要約前に ## ${heading} 節が無いため対象外`);
    }
    if (b.count !== 1) {
      return add(
        id,
        false,
        `要約前の ## ${heading} 節が ${b.count} 個。ちょうど 1 個でないと無損失を証明できない`,
      );
    }
    const a = findSection(after, heading);
    if (a.count !== 1) {
      return add(id, false, `要約後の ## ${heading} 節が ${a.count} 個`);
    }
    if (b.body !== a.body) {
      return add(id, false, `## ${heading} 節が要約前後で一致しない`);
    }
    return add(id, true, `## ${heading} 節が一致（${b.body.length} 文字）`);
  };

  // 1. 決定節の逐語一致
  compareSection("decision", decisionHeading);

  // 2. 関連 Issue 節（要約前にあれば）
  compareSection("related-issues", relatedHeading, { optional: true });

  // 3. 相互参照の保存
  const refsBefore = collectReferences(before, rules);
  const refsAfter = collectReferences(after, rules);
  const lost = [...refsBefore]
    .filter(([key]) => !refsAfter.has(key))
    .map(([, r]) => r);
  if (lost.length > 0) {
    add(
      "references",
      false,
      `要約後に残っていない相互参照 ${lost.length} 件: ${lost
        .slice(0, 10)
        .map((r) => r.ref)
        .join(", ")}${lost.length > 10 ? " ほか" : ""}`,
    );
  } else {
    add("references", true, `相互参照 ${refsBefore.size} 件がすべて残っている`);
  }

  // 4. Status の不変
  const sBefore = extractStatus(before);
  const sAfter = extractStatus(after);
  if (classifyStatus(sBefore) === null) {
    add(
      "status",
      false,
      `status-unparseable: 要約前の Status を 1 つのキーワードに分類できない（${sBefore ?? "読み取れない"}）`,
    );
  } else if (sBefore !== sAfter) {
    add(
      "status",
      false,
      `Status が変わった（${sBefore} → ${sAfter ?? "読み取れない"}）`,
    );
  } else {
    add("status", true, `Status が不変（${sBefore}）`);
  }

  // 5. サイズの純減
  const stats = {
    before: { lines: countLines(before), bytes: byteLength(before) },
    after: { lines: countLines(after), bytes: byteLength(after) },
  };
  if (stats.after.bytes < stats.before.bytes) {
    add(
      "size",
      true,
      `${stats.before.bytes} → ${stats.after.bytes} バイト（${stats.before.lines} → ${stats.after.lines} 行）`,
    );
  } else {
    add(
      "size",
      false,
      `サイズが減っていない（${stats.before.bytes} → ${stats.after.bytes} バイト）`,
    );
  }

  return { ok: checks.every((c) => c.ok), checks, stats };
}

// ---- CLI ----------------------------------------------------------------------

function parseArgs(argv) {
  const positional = [];
  const options = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--decision-heading" || arg === "--related-heading") {
      const value = argv[i + 1];
      if (value === undefined) throw new Error(`${arg} に値が必要`);
      options[
        arg === "--decision-heading" ? "decisionHeading" : "relatedHeading"
      ] = value;
      i += 1;
    } else if (arg.startsWith("--")) {
      throw new Error(`未知のオプション: ${arg}`);
    } else {
      positional.push(arg);
    }
  }
  if (positional.length !== 2) {
    throw new Error("引数は <before> <after> の 2 つ");
  }
  return { before: positional[0], after: positional[1], options };
}

export function main(argv, io = { out: console.log, err: console.error }) {
  let parsed;
  let beforeText;
  let afterText;
  try {
    parsed = parseArgs(argv);
    beforeText = readFileSync(parsed.before, "utf8");
    afterText = readFileSync(parsed.after, "utf8");
  } catch (error) {
    io.err(`check-adr-compression-lossless: ${error.message}`);
    io.err(
      "usage: node tests/harness/check-adr-compression-lossless.mjs <before> <after> [--decision-heading <text>] [--related-heading <text>]",
    );
    return 2;
  }
  const result = verifyCompression(beforeText, afterText, parsed.options);
  for (const c of result.checks) {
    io.out(`${c.ok ? "ok  " : "FAIL"} ${c.id}: ${c.detail}`);
  }
  io.out(
    `${result.ok ? "PASS" : "FAIL"} ${parsed.after}  before=${result.stats.before.lines} lines / ${result.stats.before.bytes} bytes  after=${result.stats.after.lines} lines / ${result.stats.after.bytes} bytes`,
  );
  return result.ok ? 0 : 1;
}

function isMain() {
  if (process.argv[1] === undefined) return false;
  try {
    return (
      realpathSync(process.argv[1]) ===
      realpathSync(fileURLToPath(import.meta.url))
    );
  } catch {
    return false;
  }
}

if (isMain()) process.exit(main(process.argv.slice(2)));
