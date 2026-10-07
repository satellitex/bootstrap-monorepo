// ハーネス検査の共通ヘルパ。Node 標準（node:fs / node:path / node:url）だけを使う。
//
// 検査対象のルートは環境変数 HARNESS_ROOT で差し替えられる（既定は tests/harness/support/
// から 3 階層上、つまり bootstrap 先 repo のルート）。テンプレート資産そのものを検査するときは、
// 環境変数 HARNESS_TEMPLATE_ROOT=1 でテンプレートモードにし、置換前の明示 token を許容する
// （IS_TEMPLATE_MODE）。
//
// ROOT に依存しない純粋なテキストヘルパは markdown.mjs にあり、ここから re-export する。

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export {
  PATH_PREFIXES,
  countCodePoints,
  countLines,
  escapeRegExp,
  fenceMask,
  fencedLines,
  inlineCodeSpans,
  linesOutsideFences,
  parseFrontmatter,
  proseLines,
  stripInlineCode,
} from "./markdown.mjs";

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
 * テンプレートモード。テンプレート資産そのもの（置換前の明示 token を持つ状態）を検査する
 * ときだけ、テンプレート repo の整合検査（scripts/check-assets.sh）が環境変数
 * HARNESS_TEMPLATE_ROOT=1 で有効にする。bootstrap 先では設定しない。
 */
export const IS_TEMPLATE_MODE = process.env.HARNESS_TEMPLATE_ROOT === "1";

/** テンプレート資産でだけ存在し、bootstrap 先へ配布されないルート直下のファイル。 */
export const TEMPLATE_ONLY_FILES = ["MANIFEST.md"];

/** bootstrap 時に置換される明示 token の名前（二重波括弧で囲んだ記法の名前部分）。 */
export const EXPLICIT_TOKENS = [
  "PRODUCT_NAME",
  "GITHUB_ORG",
  "REPO_NAME",
  "PROJECT_LANGUAGE",
];

/**
 * 二重波括弧の開きと閉じ。bootstrap 時の一括置換で書き換わらないよう、リテラルを分けて
 * 連結して組み立てる（固定入力に二重波括弧の実例が要る自己テスト用）。
 */
export const OPEN = "{" + "{";
export const CLOSE = "}" + "}";

/**
 * `rel`（ルート相対の POSIX パス）が `spec` に一致するか。`spec` が `/` で終わればその配下全体、
 * それ以外は完全一致。
 */
export function matchesPathSpec(rel, spec) {
  return spec.endsWith("/") ? rel.startsWith(spec) : rel === spec;
}

/** 引数なしの関数の結果を、最初の呼び出しで 1 回だけ計算して使い回す。 */
export function once(fn) {
  let cached;
  let computed = false;
  return () => {
    if (!computed) {
      cached = fn();
      computed = true;
    }
    return cached;
  };
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

// 検査は実行中にルートを書き換えないため、読み取り結果はモジュール内で使い回す。
const fileCache = new Map();
const dirCache = new Map();

export function readRepoFile(rel) {
  let text = fileCache.get(rel);
  if (text === undefined) {
    text = readFileSync(repoPath(rel), "utf8");
    fileCache.set(rel, text);
  }
  return text;
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

/**
 * ディレクトリ直下のエントリ名（ファイル・ディレクトリ）を昇順で返す。存在しなければ空。
 * 返す配列は使い回すため、変更できない。
 */
export function listDir(rel) {
  let names = dirCache.get(rel);
  if (names === undefined) {
    names = Object.freeze(
      isDirInRepo(rel) ? readdirSync(repoPath(rel)).sort() : [],
    );
    dirCache.set(rel, names);
  }
  return names;
}

/**
 * `rel` 配下のファイルを再帰的に列挙する（ルート相対 POSIX パス、昇順）。
 * `.git` と `node_modules` は辿らない。`rel` が空文字ならルート全体。
 */
export function listFiles(rel = "", predicate = () => true) {
  const out = [];
  const walk = (relDir) => {
    if (!isDirInRepo(relDir)) return;
    for (const entry of readdirSync(repoPath(relDir), {
      withFileTypes: true,
    })) {
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

/** `.claude/agents/` 直下の agent 定義（`references/` などの配下は含まない）。 */
export function listAgentFiles() {
  return listFiles(
    ".claude/agents",
    (p) => p.endsWith(".md") && p.split("/").length === 3,
  );
}

/** `.github/workflows/` の workflow ファイル（`*.yml` / `*.yaml`）。 */
export function listWorkflowFiles() {
  return listFiles(".github/workflows", (p) => /\.ya?ml$/.test(p));
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

/** ルートの `package.json` の scripts の名前。`package.json` が無ければ例外を投げる。 */
export function packageScriptNames() {
  return Object.keys(
    JSON.parse(readRequiredFile("package.json")).scripts ?? {},
  );
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
