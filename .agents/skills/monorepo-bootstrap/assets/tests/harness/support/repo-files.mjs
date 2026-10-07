// ハーネス検査の共通ヘルパ。Node 標準（node:fs / node:path / node:url）だけを使う。
//
// 検査対象のルートは環境変数 HARNESS_ROOT で差し替えられる（既定は tests/harness/support/
// から 3 階層上、つまり bootstrap 先 repo のルート）。ルートが MANIFEST.md を持つ場合は
// テンプレート資産そのものとみなし、置換前の明示 token を許容する（IS_TEMPLATE_ROOT）。

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

/**
 * 走査系テストに付ける明示 timeout（ミリ秒）。repo 全体を走査する検査は実行環境の
 * CPU 競合で所要時間が伸びうるため、既定の timeout に頼らず定数で指定する。
 * 固定入力だけを扱う純関数の自己テストには付けない。
 */
export const REPO_SCAN_TEST_TIMEOUT_MS = 30_000;

const here = dirname(fileURLToPath(import.meta.url));
const DEFAULT_ROOT = resolve(here, "..", "..", "..");

function resolveRoot() {
  const fromEnv = process.env.HARNESS_ROOT;
  if (fromEnv === undefined || fromEnv === "") return DEFAULT_ROOT;
  const abs = resolve(fromEnv);
  if (!existsSync(abs) || !statSync(abs).isDirectory()) {
    throw new Error(`HARNESS_ROOT が存在するディレクトリではない: ${abs}`);
  }
  return abs;
}

/** 検査対象ルートの絶対パス。 */
export const ROOT = resolveRoot();

/**
 * ルートがテンプレート資産そのものか。MANIFEST.md は bootstrap 先へ配布されない台帳で、
 * テンプレート資産のルートにだけ存在する。
 */
export const IS_TEMPLATE_ROOT = existsSync(join(ROOT, "MANIFEST.md"));

/** テンプレート資産でだけ存在し、bootstrap 先へ配布されないファイル。 */
export const TEMPLATE_ONLY_FILES = ["MANIFEST.md"];

/** bootstrap 時に置換される明示 token の名前（二重波括弧で囲んだ記法の名前部分）。 */
export const EXPLICIT_TOKENS = [
  "PRODUCT_NAME",
  "GITHUB_ORG",
  "REPO_NAME",
  "PROJECT_LANGUAGE",
];

/**
 * 置換対象外の記入欄（コピーして埋める様式）を置くパス。末尾 `/` はディレクトリ配下全体。
 * これらの中の二重波括弧は未置換 token ではなく記入欄として扱う。
 */
export const TEMPLATE_FORM_PATHS = ["docs/adr/template.md", "docs/templates/"];

export function isTemplateFormPath(rel) {
  return TEMPLATE_FORM_PATHS.some((p) =>
    p.endsWith("/") ? rel.startsWith(p) : rel === p,
  );
}

const SKIP_DIRS = new Set([".git", "node_modules"]);

/** ルート相対の POSIX 区切りパスを絶対パスにする。 */
export function repoPath(rel) {
  return join(ROOT, ...rel.split("/").filter(Boolean));
}

export function existsInRepo(rel) {
  return existsSync(repoPath(rel));
}

export function isDirInRepo(rel) {
  const p = repoPath(rel);
  return existsSync(p) && statSync(p).isDirectory();
}

export function readRepoFile(rel) {
  return readFileSync(repoPath(rel), "utf8");
}

/** gate の前提となるファイルを読む。無ければ、何が無いかが分かる例外を投げる。 */
export function readRequiredFile(rel) {
  if (!existsInRepo(rel)) {
    throw new Error(
      `${rel} が無い（この gate の前提となるファイル。ルート: ${ROOT}）`,
    );
  }
  return readRepoFile(rel);
}

/** ディレクトリ直下のエントリ名（ファイル・ディレクトリ）を昇順で返す。存在しなければ空。 */
export function listDir(rel) {
  if (!isDirInRepo(rel)) return [];
  return readdirSync(repoPath(rel)).sort();
}

/**
 * `rel` 配下のファイルを再帰的に列挙する（ルート相対 POSIX パス、昇順）。
 * `.git` と `node_modules` は辿らない。`rel` が空文字ならルート全体。
 */
export function listFiles(rel = "", predicate = () => true) {
  const out = [];
  const walk = (relDir) => {
    const abs = repoPath(relDir);
    if (!existsSync(abs) || !statSync(abs).isDirectory()) return;
    for (const entry of readdirSync(abs, { withFileTypes: true })) {
      const childRel = relDir === "" ? entry.name : `${relDir}/${entry.name}`;
      if (entry.isDirectory()) {
        if (!SKIP_DIRS.has(entry.name)) walk(childRel);
      } else if (entry.isFile() || entry.isSymbolicLink()) {
        if (predicate(childRel)) out.push(childRel);
      }
    }
  };
  walk(rel);
  return out.sort();
}

export function listMarkdownFiles(rel) {
  return listFiles(rel, (p) => p.endsWith(".md"));
}

/** ルート直下の *.md（テンプレート専用の台帳を除く）。 */
export function listRootMarkdownFiles() {
  return listDir("")
    .filter((name) => name.endsWith(".md"))
    .filter((name) => !TEMPLATE_ONLY_FILES.includes(name))
    .filter((name) => statSync(repoPath(name)).isFile());
}

/**
 * ハーネス文書の走査対象（ルート相対パス、昇順）。
 * `.claude/agents/**`、`.claude/skills/**`、`.claude/rules/**`、`.claude/*.md`、
 * `docs/harness/**`、ルート直下の *.md。
 */
export function listHarnessFiles() {
  const files = new Set([
    ...listMarkdownFiles(".claude/agents"),
    ...listMarkdownFiles(".claude/skills"),
    ...listMarkdownFiles(".claude/rules"),
    ...listDir(".claude")
      .filter((name) => name.endsWith(".md"))
      .map((name) => `.claude/${name}`),
    ...listMarkdownFiles("docs/harness"),
    ...listRootMarkdownFiles(),
  ]);
  return [...files].sort();
}

// ---- markdown の簡易解析 --------------------------------------------------
// CommonMark の完全準拠ではなく、検査に必要な範囲（フェンス付きコードブロックと
// インラインコード）だけを扱う。限界: 複数行にまたがるインラインコード、HTML ブロック、
// インデントによるコードブロックは判定しない。

/** 行配列に対し、フェンス付きコードブロックの内側（区切り行を含む）を true にしたマスク。 */
export function fenceMask(lines) {
  const mask = new Array(lines.length).fill(false);
  let open = null;
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    if (open === null) {
      const m = /^\s*(`{3,}|~{3,})(.*)$/.exec(line);
      if (m && !(m[1][0] === "`" && m[2].includes("`"))) {
        open = { char: m[1][0], len: m[1].length };
        mask[i] = true;
      }
    } else {
      mask[i] = true;
      const m = /^\s*(`{3,}|~{3,})\s*$/.exec(line);
      if (m && m[1][0] === open.char && m[1].length >= open.len) open = null;
    }
  }
  return mask;
}

/** フェンス付きコードブロックの外側の行を `{ n, text }`（n は 1 始まりの行番号）で返す。 */
export function linesOutsideFences(text) {
  const lines = text.split("\n");
  const mask = fenceMask(lines);
  const out = [];
  lines.forEach((line, i) => {
    if (!mask[i]) out.push({ n: i + 1, text: line });
  });
  return out;
}

/** フェンス付きコードブロックの内側の行を `{ n, text }` で返す（区切り行は含まない）。 */
export function fencedLines(text) {
  const lines = text.split("\n");
  const mask = fenceMask(lines);
  const out = [];
  lines.forEach((line, i) => {
    if (mask[i] && !/^\s*(`{3,}|~{3,})/.test(line)) {
      out.push({ n: i + 1, text: line });
    }
  });
  return out;
}

/**
 * 1 行の中のインラインコード範囲を返す。開きと同じ長さのバッククォート列で閉じる。
 * 返り値の `start` / `end` は区切りのバッククォートを含む範囲、`text` は中身。
 */
export function inlineCodeSpans(line) {
  const spans = [];
  let i = 0;
  while (i < line.length) {
    if (line[i] !== "`") {
      i += 1;
      continue;
    }
    let runEnd = i;
    while (runEnd < line.length && line[runEnd] === "`") runEnd += 1;
    const len = runEnd - i;
    let j = runEnd;
    let closeStart = -1;
    while (j < line.length) {
      if (line[j] !== "`") {
        j += 1;
        continue;
      }
      let k = j;
      while (k < line.length && line[k] === "`") k += 1;
      if (k - j === len) {
        closeStart = j;
        break;
      }
      j = k;
    }
    if (closeStart === -1) {
      i = runEnd;
      continue;
    }
    spans.push({
      start: i,
      end: closeStart + len,
      text: line.slice(runEnd, closeStart),
    });
    i = closeStart + len;
  }
  return spans;
}

/** インラインコードを同じ長さの空白に置き換えた行（桁位置を保つ）。 */
export function stripInlineCode(line) {
  let out = line;
  for (const s of inlineCodeSpans(line)) {
    out =
      out.slice(0, s.start) + " ".repeat(s.end - s.start) + out.slice(s.end);
  }
  return out;
}

/** フェンスとインラインコードを除いた散文の行（`{ n, text }`）。 */
export function proseLines(text) {
  return linesOutsideFences(text).map(({ n, text: t }) => ({
    n,
    text: stripInlineCode(t),
  }));
}

// ---- frontmatter ---------------------------------------------------------

/**
 * 先頭の YAML frontmatter を簡易に読む（単一行の `key: value` だけを扱う）。
 * frontmatter が無ければ null。複数行の値（`>` / `|` / 継続行）は `multiline` に記録する。
 */
export function parseFrontmatter(text) {
  const lines = text.split("\n");
  if (lines[0].trim() !== "---") return null;
  let end = -1;
  for (let i = 1; i < lines.length; i += 1) {
    if (lines[i].trim() === "---") {
      end = i;
      break;
    }
  }
  if (end === -1) return null;
  const fields = new Map();
  const multiline = new Set();
  let lastKey = null;
  for (let i = 1; i < end; i += 1) {
    const line = lines[i];
    const m = /^([A-Za-z_][\w-]*):\s*(.*)$/.exec(line);
    if (m) {
      lastKey = m[1];
      let value = m[2].trim();
      if (/^[>|][+-]?$/.test(value)) {
        multiline.add(lastKey);
        value = "";
      }
      if (
        value.length >= 2 &&
        (value[0] === '"' || value[0] === "'") &&
        value[value.length - 1] === value[0]
      ) {
        value = value.slice(1, -1);
      }
      fields.set(lastKey, value);
    } else if (/^\s+\S/.test(line) && lastKey !== null) {
      multiline.add(lastKey);
    }
  }
  return {
    fields,
    multiline,
    bodyStartLine: end + 2,
    body: lines.slice(end + 1).join("\n"),
  };
}

// ---- 計測 ---------------------------------------------------------------

/** `wc -l` ではなく表示上の行数を数える（末尾の改行は行を増やさない）。 */
export function countLines(text) {
  if (text === "") return 0;
  const n = text.split("\n").length;
  return text.endsWith("\n") ? n - 1 : n;
}

/** Unicode コードポイント数（サロゲートペアを 1 と数える）。 */
export function countCodePoints(text) {
  return [...text].length;
}

// ---- 除外定数の検査 ---------------------------------------------------------

/**
 * 除外定数 `{ ..., reason }` の形を検査する。理由が空の除外は許さない。
 * 返り値は問題の説明の配列（空なら正常）。
 */
export function validateExclusions(exclusions, keyName) {
  const problems = [];
  for (const e of exclusions) {
    if (typeof e.reason !== "string" || e.reason.trim() === "") {
      problems.push(`除外 ${JSON.stringify(e[keyName])} に reason が無い`);
    }
  }
  return problems;
}

/**
 * 生きた出現を持たない除外（stale）を返す。`isLive(exclusion)` が false の除外が対象。
 * 対象が消えたのに除外だけが残ると、後で同名の違反が混入しても黙って通るため。
 */
export function findStaleExclusions(exclusions, isLive) {
  return exclusions.filter((e) => !isLive(e));
}

/** 違反の配列を `path:line  message` の複数行文字列にする（テストの失敗メッセージ用）。 */
export function formatViolations(title, violations) {
  const body = violations
    .map((v) =>
      typeof v === "string" ? v : `${v.file}:${v.line ?? 0}  ${v.message}`,
    )
    .join("\n  ");
  return `${title}（${violations.length} 件）\n  ${body}`;
}

/** 配列が空であることを表明する。違反があれば一覧を失敗メッセージに出す。 */
export function assertNoViolations(assert, title, violations) {
  assert.ok(violations.length === 0, formatViolations(title, violations));
}

// ---- .gitignore ----------------------------------------------------------

function globToRegexSource(glob) {
  let out = "";
  for (let i = 0; i < glob.length; i += 1) {
    const c = glob[i];
    if (c === "*") {
      if (glob[i + 1] === "*") {
        out += ".*";
        i += 1;
      } else {
        out += "[^/]*";
      }
    } else if (c === "?") {
      out += "[^/]";
    } else if (/[.+^${}()|[\]\\]/.test(c)) {
      out += `\\${c}`;
    } else {
      out += c;
    }
  }
  return out;
}

/**
 * `.gitignore` の本文から簡易マッチャーを作る。否定パターン（`!`）は扱わない。
 * 返す関数は、ルート相対 POSIX パス（ディレクトリは末尾 `/` 付き）が無視対象かを返す。
 * 自身または祖先ディレクトリが規則に一致すれば無視対象とする。
 */
export function createGitignoreMatcher(gitignoreText) {
  const rules = [];
  for (const raw of gitignoreText.split("\n")) {
    const line = raw.trim();
    if (line === "" || line.startsWith("#") || line.startsWith("!")) continue;
    const dirOnly = line.endsWith("/");
    let body = dirOnly ? line.slice(0, -1) : line;
    const anchored = body.startsWith("/") || body.includes("/");
    if (body.startsWith("/")) body = body.slice(1);
    const src = globToRegexSource(body);
    rules.push({
      dirOnly,
      re: new RegExp(anchored ? `^${src}$` : `(^|/)${src}$`),
    });
  }
  return (rel) => {
    const isDirPath = rel.endsWith("/");
    const parts = rel.split("/").filter(Boolean);
    for (let i = 1; i <= parts.length; i += 1) {
      const prefix = parts.slice(0, i).join("/");
      const isLast = i === parts.length;
      for (const rule of rules) {
        if (rule.dirOnly && isLast && !isDirPath) continue;
        if (rule.re.test(prefix)) return true;
      }
    }
    return false;
  };
}

/** ルートの `.gitignore` から作ったマッチャー。`.gitignore` が無ければ何も無視しない。 */
export function loadGitignoreMatcher() {
  return createGitignoreMatcher(
    existsInRepo(".gitignore") ? readRepoFile(".gitignore") : "",
  );
}

/** 大文字小文字を区別してパスが実在するかを確かめる（大文字小文字を無視する FS 対策）。 */
export function existsExactCase(rel) {
  const parts = rel.split("/").filter(Boolean);
  let cur = "";
  for (const part of parts) {
    if (!listDir(cur).includes(part)) return false;
    cur = cur === "" ? part : `${cur}/${part}`;
  }
  return true;
}
