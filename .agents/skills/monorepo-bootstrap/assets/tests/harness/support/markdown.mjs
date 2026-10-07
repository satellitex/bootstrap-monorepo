// ROOT に依存しない純粋なテキストヘルパ。markdown の簡易解析、frontmatter、計測、パス接頭辞、
// 正規表現のエスケープを持つ。検査対象のルート（HARNESS_ROOT）を解決しないため、ルートが不正でも
// import でき、単体で動く CLI（check-adr-compression-lossless.mjs）がここから import する。
// 検査ファイルは repo-files.mjs が re-export するものを使う。
//
// markdown の解析は CommonMark の完全準拠ではなく、検査に必要な範囲（フェンス付きコードブロックと
// インラインコード）だけを扱う。限界: 複数行にまたがるインラインコード、HTML ブロック、
// インデントによるコードブロックは判定しない。

/** 実在確認の対象にするリポジトリ相対パスの接頭辞。 */
export const PATH_PREFIXES = [
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

/** 正規表現の特殊文字をエスケープして、文字列をそのままの一致パターンにする。 */
export function escapeRegExp(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// ---- markdown ------------------------------------------------------------

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
