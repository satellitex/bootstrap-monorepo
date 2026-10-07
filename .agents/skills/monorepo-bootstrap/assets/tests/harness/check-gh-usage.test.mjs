// gh コマンドの使い方 gate: 規約文書（docs/harness/skills/shared/gh-query-fail-closed.md）の
// 機械検査可能な部分を検査する。
//
//   1. list 系の照会に取得上限（--limit / -L）を明示する。省略時の既定件数を超えた分は無言に
//      切り捨てられ、絞り込み前の集合が欠けたまま「0 件」と解釈されるため。
//   2. `gh issue list` / `gh pr list` に search 系フィルタ（--search / --label / --milestone
//      とその短縮形）を付けない。search 経路はリポジトリの移管・リネームを追わず、エラーにも
//      ならず空配列を返すため。plain list + `--json` + ローカル絞り込みで書く。
//   3. `--repo <owner>/<repo>` と `repos/<owner>/<repo>` に owner を直書きしない。移管のたびに
//      全箇所の手当てが必要になり、漏れが 2 の無言故障に化けるため。
//
// 走査対象: ハーネス文書、.claude/、.github/、scripts/。markdown ではフェンス付きコードブロックの
// 全行と、フラグを伴うインラインコードを「コマンド」として扱う。コマンド名だけのインラインコード
// （`gh pr list` など）は名前の言及であり、検査しない。
//
// 限界: シェルの構文は解析しない。変数に入れたコマンド名や、複数行にまたがる引用文字列は判定できない。

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  IS_TEMPLATE_ROOT,
  REPO_SCAN_TEST_TIMEOUT_MS,
  ROOT,
  assertNoViolations,
  fencedLines,
  inlineCodeSpans,
  linesOutsideFences,
  listFiles,
  listHarnessFiles,
  readRepoFile,
} from "./support/repo-files.mjs";

/** 取得上限を要求する list 系コマンド。 */
const LIST_COMMAND_RE =
  /\bgh\s+(?:(issue|pr|label|release|run|repo)\s+list|project\s+(list|item-list|field-list)|search\s+(issues|prs|repos|code|commits))\b/g;

/** search 経路に落ちるフィルタを禁止するコマンド。 */
const SEARCH_FLAG_COMMANDS = new Set(["gh issue list", "gh pr list"]);

const LIMIT_FLAG_RE = /(?:^|\s)(?:--limit|-L)(?:[\s=\d]|$)/;
const SEARCH_FLAG_RE =
  /(?:^|\s)(?:--search|--label|--milestone)(?:[\s=]|$)|(?:^|\s)-[Slm](?=\s|=|$|["'\w])/;

// ---- 純関数 -----------------------------------------------------------------

/** 行末のバックスラッシュで継続する行を 1 行に連結する。 */
function joinContinuations(entries) {
  const out = [];
  let cur = null;
  for (const e of entries) {
    if (cur === null) cur = { n: e.n, text: e.text };
    else cur.text += ` ${e.text.trim()}`;
    if (/\\\s*$/.test(cur.text)) {
      cur.text = cur.text.replace(/\\\s*$/, "");
    } else {
      out.push(cur);
      cur = null;
    }
  }
  if (cur !== null) out.push(cur);
  return out;
}

/**
 * ファイルからコマンドとして検査する単位を取り出す。
 * markdown: フェンス内の全行（継続行は連結）と、フラグを伴うインラインコード。
 * それ以外: コメント行を除く全行（継続行は連結）。
 */
function commandUnits(rel, text) {
  if (rel.endsWith(".md")) {
    const units = joinContinuations(fencedLines(text)).map((u) => ({
      ...u,
      inline: false,
    }));
    for (const { n, text: line } of linesOutsideFences(text)) {
      for (const span of inlineCodeSpans(line)) {
        if (/\bgh\s/.test(span.text)) {
          units.push({ n, text: span.text, inline: true });
        }
      }
    }
    return units;
  }
  const entries = [];
  text.split("\n").forEach((line, i) => {
    if (!/^\s*(#|\/\/)/.test(line)) entries.push({ n: i + 1, text: line });
  });
  return joinContinuations(entries).map((u) => ({ ...u, inline: false }));
}

/** 引用符の外にある最初のシェル演算子（| ; &）で文字列を切る。 */
function cutAtShellOperator(region) {
  let quote = null;
  for (let i = 0; i < region.length; i += 1) {
    const c = region[i];
    if (quote !== null) {
      if (c === quote) quote = null;
    } else if (c === "'" || c === '"') {
      quote = c;
    } else if (c === "|" || c === ";" || c === "&") {
      return region.slice(0, i);
    }
  }
  return region;
}

/** 引用符で囲まれた部分（jq の式など）を空白に置き換える。 */
function stripQuoted(region) {
  return region.replace(/'[^']*'|"[^"]*"/g, " ");
}

function isPlaceholderOwner(owner) {
  return /^\.+$/.test(owner) || /^(owner|org|user)$/i.test(owner);
}

/** 1 つの検査単位の違反を返す（limit / search フラグ / owner 直書き）。 */
function findGhViolations(unit) {
  const out = [];
  const text = unit.text;
  const ghStarts = [...text.matchAll(/\bgh\s+[a-z]/g)].map((m) => m.index);
  for (const m of text.matchAll(LIST_COMMAND_RE)) {
    const name = m[0].replace(/\s+/g, " ");
    const end = m.index + m[0].length;
    const next = ghStarts.find((s) => s >= end);
    const region = cutAtShellOperator(text.slice(end, next ?? text.length));
    if (unit.inline && !/(?:^|\s)-{1,2}[A-Za-z]/.test(region)) continue;
    if (!LIMIT_FLAG_RE.test(region)) {
      out.push(`${name} に --limit が無い。取得上限を明示する`);
    }
    if (
      SEARCH_FLAG_COMMANDS.has(name) &&
      SEARCH_FLAG_RE.test(stripQuoted(region))
    ) {
      out.push(
        `${name} に search 系フィルタ（--search / --label / --milestone）がある。plain list + --json + ローカル絞り込みにする`,
      );
    }
  }
  if (!/\bgh\s/.test(text)) return out;
  for (const m of text.matchAll(
    /(?:--repo|-R)(?:\s+|=)["']?([\w.-]+)\/([\w.-]+)/g,
  )) {
    if (!isPlaceholderOwner(m[1])) {
      out.push(`--repo ${m[1]}/${m[2]} に owner を直書きしている`);
    }
  }
  for (const m of text.matchAll(
    /\brepos\/([^/\s'"`{}$<>]+)\/([^/\s'"`{}$<>]+)/g,
  )) {
    if (!isPlaceholderOwner(m[1])) {
      out.push(
        `repos/${m[1]}/${m[2]} に owner を直書きしている。{owner}/{repo} を使う`,
      );
    }
  }
  return out;
}

/** `owner/repo` 形式の文字列から owner を取り出す。取れなければ null。 */
function ownerFromSlug(slug) {
  const m = /^([\w.-]+)\/([\w.-]+?)(?:\.git)?$/.exec(slug.trim());
  return m ? m[1] : null;
}

/** git remote の URL（https / ssh）から owner を取り出す。取れなければ null。 */
function ownerFromRemoteUrl(url) {
  const m = /[:/]([\w.-]+)\/([\w.-]+?)(?:\.git)?\/?$/.exec(url.trim());
  return m ? m[1] : null;
}

/** テキストの中で、期待 owner のリテラルが `owner/<name>` の形で現れる行を返す。 */
function findLiteralOwner(text, owner) {
  const escaped = owner.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const re = new RegExp(`(?<![\\w.-])${escaped}/[\\w.-]+`, "i");
  const out = [];
  text.split("\n").forEach((line, i) => {
    if (re.test(line)) out.push(i + 1);
  });
  return out;
}

// ---- 実リポジトリ -----------------------------------------------------------------

function ghTargetFiles() {
  return [
    ...new Set([
      ...listHarnessFiles(),
      ...listFiles(".claude", (p) => /\.(sh|json|md|ya?ml)$/.test(p)),
      ...listFiles(".github", (p) => /\.(ya?ml|md|sh)$/.test(p)),
      ...listFiles("scripts", (p) => /\.(sh|bash|mjs|js|ts|ya?ml|md)$/.test(p)),
    ]),
  ].sort();
}

function resolveExpectedOwner() {
  const fromEnv = process.env.GITHUB_REPOSITORY;
  if (fromEnv) {
    const owner = ownerFromSlug(fromEnv);
    if (owner) return owner;
  }
  const r = spawnSync("git", ["-C", ROOT, "remote", "get-url", "origin"], {
    encoding: "utf8",
  });
  if (r.status === 0) return ownerFromRemoteUrl(r.stdout);
  return null;
}

describe("gh 使用 gate: list の limit・search フィルタ・owner 直書き", () => {
  it(
    "走査対象のファイルと gh コマンドの検査単位が 0 件ではない（退化ガード）",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const files = ghTargetFiles();
      assert.ok(files.length > 0, "走査対象が 0 件");
      let units = 0;
      for (const rel of files) {
        units += commandUnits(rel, readRepoFile(rel)).filter((u) =>
          /\bgh\s/.test(u.text),
        ).length;
      }
      assert.ok(units > 0, "gh コマンドを含む検査単位が 0 件");
    },
  );

  it(
    "list 系の照会に --limit があり、search 系フィルタが無く、owner を直書きしていない",
    { timeout: REPO_SCAN_TEST_TIMEOUT_MS },
    () => {
      const violations = [];
      for (const rel of ghTargetFiles()) {
        for (const unit of commandUnits(rel, readRepoFile(rel))) {
          for (const message of findGhViolations(unit)) {
            violations.push({ file: rel, line: unit.n, message });
          }
        }
      }
      assertNoViolations(assert, "gh 使用規約の違反", violations);
    },
  );

  it(
    "リポジトリ owner のリテラルがハーネス文書・設定・workflow に無い（bootstrap 先のみ）",
    {
      timeout: REPO_SCAN_TEST_TIMEOUT_MS,
      skip: IS_TEMPLATE_ROOT
        ? "テンプレート資産には owner の実値が無い（token で表現する）"
        : false,
    },
    (t) => {
      const owner = resolveExpectedOwner();
      if (owner === null) {
        t.skip(
          "期待 owner を解決できない（GITHUB_REPOSITORY 未設定かつ origin remote が無い）",
        );
        return;
      }
      const violations = [];
      for (const rel of ghTargetFiles()) {
        for (const n of findLiteralOwner(readRepoFile(rel), owner)) {
          violations.push({
            file: rel,
            line: n,
            message: `リポジトリ owner のリテラルがある。remote から解決する値を使う`,
          });
        }
      }
      assertNoViolations(assert, "owner のリテラル", violations);
    },
  );
});

describe("gh 使用 gate: 自己テスト", () => {
  const md = (body) => commandUnits("x.md", body);
  const violationsOf = (rel, body) =>
    commandUnits(rel, body).flatMap((u) => findGhViolations(u));

  it("--limit が無い list を検出し、-L / --limit は通す", () => {
    assert.equal(
      violationsOf("a.sh", "gh pr list --state open --json number").length,
      1,
    );
    assert.equal(
      violationsOf("a.sh", "gh pr list --limit 1000 --json number").length,
      0,
    );
    assert.equal(violationsOf("a.sh", "gh issue list -L 5").length, 0);
    assert.equal(violationsOf("a.sh", "gh label list --json name").length, 1);
    assert.equal(violationsOf("a.sh", "gh search issues foo").length, 1);
    assert.equal(
      violationsOf("a.sh", "gh project item-list 1 --limit 200").length,
      0,
    );
  });

  it("継続行は連結して判定する", () => {
    const body = [
      "gh issue list --state open \\",
      "  --limit 1000 --json number",
    ].join("\n");
    assert.equal(violationsOf("a.sh", body).length, 0);
    const missing = ["gh issue list --state open \\", "  --json number"].join(
      "\n",
    );
    assert.equal(violationsOf("a.sh", missing).length, 1);
  });

  it("パイプの後ろのフラグは gh の引数に数えない", () => {
    assert.equal(
      violationsOf("a.sh", "gh pr list --json number | jq --limit 3 .").length,
      1,
    );
  });

  it("search 系フィルタを検出する（jq の引用式は除く）", () => {
    assert.equal(
      violationsOf("a.sh", "gh pr list --limit 100 --label bug --json number")
        .length,
      1,
    );
    assert.equal(
      violationsOf("a.sh", "gh issue list --limit 100 -S foo").length,
      1,
    );
    assert.equal(
      violationsOf(
        "a.sh",
        `gh issue list --limit 100 --json labels --jq 'map(select(.labels | any(.name == "-l")))'`,
      ).length,
      0,
    );
    assert.equal(
      violationsOf("a.sh", "gh label list --limit 5 --search x").length,
      0,
    );
  });

  it("markdown: フェンス内は全行、インラインコードはフラグを伴うものだけを検査する", () => {
    const body = [
      "`gh pr list` は名前の言及。",
      "`gh pr list --state all` はコマンド。",
      "```bash",
      "gh issue list --json number",
      "```",
    ].join("\n");
    const found = md(body).flatMap((u) => findGhViolations(u));
    assert.equal(found.length, 2);
  });

  it("owner の直書きを検出し、プレースホルダ・変数は許す", () => {
    assert.equal(
      violationsOf("a.sh", "gh issue view 1 --repo acme/app").length,
      1,
    );
    assert.equal(
      violationsOf("a.sh", "gh api repos/acme/app/issues").length,
      1,
    );
    assert.equal(
      violationsOf("a.sh", "gh api 'repos/{owner}/{repo}/milestones'").length,
      0,
    );
    assert.equal(
      violationsOf("a.sh", 'gh issue view 1 --repo "$REPO"').length,
      0,
    );
    assert.equal(
      violationsOf("a.sh", "gh issue create --repo ... --title x").length,
      0,
    );
    assert.equal(violationsOf("a.sh", "gh api repos/.../issues/1").length, 0);
  });

  it("コメント行と gh 以外のコマンドは検査しない", () => {
    assert.equal(violationsOf("a.sh", "# gh pr list --state open").length, 0);
    assert.equal(violationsOf("a.sh", "grep -R src/app .").length, 0);
    assert.equal(violationsOf("a.sh", "ls repos/team/app").length, 0);
  });

  it("owner の取り出しとリテラル検出", () => {
    assert.equal(ownerFromSlug("acme/app"), "acme");
    assert.equal(ownerFromSlug("app"), null);
    assert.equal(ownerFromRemoteUrl("git@github.com:acme/app.git"), "acme");
    assert.equal(ownerFromRemoteUrl("https://github.com/acme/app"), "acme");
    assert.deepEqual(
      findLiteralOwner("a\nsee acme/app here\nxacme/app", "acme"),
      [2],
    );
  });
});
