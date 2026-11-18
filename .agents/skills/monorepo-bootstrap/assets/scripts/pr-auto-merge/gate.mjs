// opt-in:pr-auto-merge
// 審査した head の機械判定を再取得してから、一度だけ squash merge する。
// PUT の sha は head だけを固定する。必須レビュー・必須 CI は導入先のブランチ保護でも強制する。
// https://docs.github.com/en/rest/pulls/pulls#merge-a-pull-request
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { parseArgs } from "node:util";

const pageSize = 100;
const passed = new Set(["success", "skipped", "neutral"]);

function result(status, reason, details = {}) {
  return { status, reason, ...details };
}

function github(endpoint, fields) {
  const args = ["api", endpoint];
  if (fields) {
    args.push("--method", "PUT");
    for (const [key, value] of Object.entries(fields))
      args.push("-f", key + "=" + value);
  }
  return JSON.parse(
    execFileSync("gh", args, { encoding: "utf8", maxBuffer: 32 * 1024 * 1024 }),
  );
}

function validateOptions({
  mode,
  repo,
  pr,
  base,
  head,
  holdLabel = [],
  holdPrefix = [],
  allowLabel = [],
}) {
  if (
    !["inspect", "merge"].includes(mode) ||
    !/^[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+$/.test(repo ?? "") ||
    !/^[1-9][0-9]*$/.test(pr ?? "") ||
    !base ||
    !/^[a-f0-9]{40}$/.test(head ?? "")
  ) {
    throw new Error(
      "inspect|merge --repo OWNER/REPO --pr N --base BRANCH --head SHA が必要です",
    );
  }
  // 完全一致の保留は常に優先し、例外は接頭辞一致にだけ適用する。
  return {
    exact: new Set(
      ["automerge:hold", "needs-human", ...holdLabel].map((s) =>
        s.toLowerCase(),
      ),
    ),
    prefixes: ["human:", ...holdPrefix].map((s) => s.toLowerCase()),
    exceptions: new Set(
      ["human:none", ...allowLabel].map((s) => s.toLowerCase()),
    ),
  };
}

function hasHumanItems(body) {
  let inSection = false;
  for (const line of body.split(/\r?\n/)) {
    if (/^ {0,3}#{1,2}\s/.test(line)) {
      inSection = /^ {0,3}##\s+人間に判断してほしい点\s*#*\s*$/.test(line);
    } else if (
      inSection &&
      line.trim() &&
      !/^\s*(?:[-*+]\s*)?(?:なし|無し|none)[。.]?\s*$/i.test(line)
    ) {
      return true;
    }
  }
  return false;
}

function checkPull(pull, target, labels) {
  if (
    pull.number !== Number(target.pr) ||
    pull.base?.repo?.full_name?.toLowerCase() !== target.repo.toLowerCase()
  ) {
    return result("blocked", "照会先の PR を確認できない");
  }
  if (pull.state === "closed")
    return result(pull.merged === true ? "merged" : "closed", "既に終了");
  if (
    pull.state !== "open" ||
    pull.draft !== false ||
    pull.base.ref !== target.base ||
    pull.head?.repo?.full_name?.toLowerCase() !== target.repo.toLowerCase()
  ) {
    return result("blocked", "対象外の状態・ブランチ・リポジトリ");
  }
  if (pull.head.sha !== target.head) return result("changed", "head の更新");
  if (
    typeof pull.title !== "string" ||
    (pull.body !== null && typeof pull.body !== "string") ||
    !Array.isArray(pull.labels)
  )
    throw new Error("PR 本文またはラベルを確認できません");
  const body = (pull.body ?? "").replace(/<!--[\s\S]*?-->/g, "");
  for (const label of pull.labels) {
    const name = label.name.toLowerCase();
    if (
      labels.exact.has(name) ||
      (!labels.exceptions.has(name) &&
        labels.prefixes.some((prefix) => name.startsWith(prefix)))
    ) {
      return result("blocked", "保留ラベル", { label: name });
    }
  }
  if (
    /\bWIP\b|作業中|\bdo not merge\b/i.test(pull.title + "\n" + body) ||
    hasHumanItems(body)
  ) {
    return result("blocked", "作業中または未決の人間判断");
  }
  if (pull.mergeable === null) return result("waiting", "競合状態を計算中");
  if (pull.mergeable !== true)
    return result("blocked", "競合または競合状態が不明");
  return null;
}

function checkReviews(api, pullPath) {
  const decisions = new Map();
  for (let page = 1; ; page++) {
    const reviews = api(
      pullPath + "/reviews?per_page=" + pageSize + "&page=" + page,
    );
    if (!Array.isArray(reviews)) throw new Error("レビューの一覧が不明です");
    for (const review of reviews) {
      if (review.user?.type === "Bot") continue;
      if (["COMMENTED", "PENDING"].includes(review.state)) continue;
      if (
        !["APPROVED", "CHANGES_REQUESTED", "DISMISSED"].includes(
          review.state,
        ) ||
        !review.user?.login
      ) {
        throw new Error("レビューの判定を確認できません");
      }
      // REST は時系列順。通常コメントでは以前の変更要求を取り消さない。
      decisions.set(review.user.login.toLowerCase(), review.state);
    }
    if (reviews.length < pageSize) break;
  }
  const reviewers = [...decisions]
    .filter(([, state]) => state === "CHANGES_REQUESTED")
    .map(([login]) => login);
  return reviewers.length
    ? result("blocked", "人の変更要求", { reviewers })
    : null;
}

function checkStatuses(api, commitPath, head, missingChecks) {
  let expected;
  for (let page = 1; ; page++) {
    const combined = api(
      commitPath + "/status?per_page=" + pageSize + "&page=" + page,
    );
    if (expected === undefined) expected = combined.total_count;
    if (
      combined.sha !== head ||
      !Number.isSafeInteger(expected) ||
      expected < 0 ||
      combined.total_count !== expected
    ) {
      throw new Error("commit status の件数または対象 SHA が不明です");
    }
    if (expected === 0) return null;
    if (combined.state !== "success") {
      return result(
        combined.state === "pending" ? "waiting" : "blocked",
        "commit status",
        { state: combined.state },
      );
    }
    // combined.state は全 context の集約値。追加の必須名を探す場合だけページをたどる。
    if (!missingChecks.size) return null;
    if (
      !Array.isArray(combined.statuses) ||
      combined.statuses.length !==
        Math.min(pageSize, expected - (page - 1) * pageSize)
    ) {
      throw new Error("commit status の一覧が途中で変化しました");
    }
    for (const status of combined.statuses) {
      if (status.state !== "success" || !status.context)
        throw new Error("commit status の集約結果が一致しません");
      missingChecks.delete(status.context);
    }
    if (!missingChecks.size || page * pageSize >= expected) return null;
  }
}

function checkCI(api, commitPath, head, requiredChecks = []) {
  const seen = new Set();
  const missingChecks = new Set(requiredChecks);
  let expected;
  let waiting;
  for (let page = 1; ; page++) {
    const batch = api(
      commitPath +
        "/check-runs?filter=latest&per_page=" +
        pageSize +
        "&page=" +
        page,
    );
    if (expected === undefined) expected = batch.total_count;
    if (
      !Array.isArray(batch.check_runs) ||
      !Number.isSafeInteger(expected) ||
      expected < 0 ||
      batch.total_count !== expected
    )
      throw new Error("check の件数を確認できません");
    for (const check of batch.check_runs) {
      if (
        !Number.isSafeInteger(check.id) ||
        seen.has(check.id) ||
        check.head_sha !== head
      ) {
        throw new Error("check の一覧または対象 SHA が一致しません");
      }
      seen.add(check.id);
      missingChecks.delete(check.name);
      if (check.status !== "completed") {
        waiting = result("waiting", "未完了の check", {
          check: check.name,
          url: check.html_url,
        });
      } else if (!passed.has(check.conclusion)) {
        return result("blocked", "CI 失敗", {
          check: check.name,
          conclusion: check.conclusion,
          url: check.html_url,
        });
      }
    }
    if (seen.size >= expected || batch.check_runs.length < pageSize) break;
  }
  if (seen.size !== expected)
    throw new Error("check の一覧が途中で変化しました");
  const status = checkStatuses(api, commitPath, head, missingChecks);
  if (status) return status;
  if (!seen.size) return result("waiting", "check 未登録");
  if (missingChecks.size)
    return result("waiting", "必須 check 未登録", {
      missing: [...missingChecks],
    });
  return waiting;
}

export function runGate(target, api = github) {
  const labels = validateOptions(target);
  const root = "repos/" + target.repo;
  const pullPath = root + "/pulls/" + target.pr;
  const first = checkPull(api(pullPath), target, labels);
  if (first) return first;
  const ci = checkCI(
    api,
    root + "/commits/" + target.head,
    target.head,
    target.requiredChecks,
  );
  if (ci) return ci;
  const review = checkReviews(api, pullPath);
  if (review) return review;

  const pull = api(pullPath);
  const last = checkPull(pull, target, labels);
  if (last) return last;
  // 管理権限での保護ルールのバイパスを避ける。未確定なら次の照会で判定する。
  if (pull.mergeable_state === "unknown")
    return result("waiting", "ブランチ保護を計算中");
  if (!["clean", "has_hooks"].includes(pull.mergeable_state)) {
    return result("blocked", "ブランチのマージ条件が未達", {
      state: pull.mergeable_state,
    });
  }
  if (target.mode === "inspect")
    return result("ready", "機械条件を通過", { head: target.head });
  const response = api(pullPath + "/merge", {
    sha: target.head,
    merge_method: "squash",
  });
  if (response.merged !== true || !response.sha)
    return result("blocked", "マージ拒否");
  return result("merged", "squash merge 完了", {
    head: target.head,
    commit: response.sha,
  });
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  try {
    const { values } = parseArgs({
      args: process.argv.slice(3),
      options: {
        repo: { type: "string" },
        pr: { type: "string" },
        base: { type: "string" },
        head: { type: "string" },
        "hold-label": { type: "string", multiple: true, default: [] },
        "hold-prefix": { type: "string", multiple: true, default: [] },
        "allow-label": { type: "string", multiple: true, default: [] },
        "required-check": { type: "string", multiple: true, default: [] },
      },
    });
    const outcome = runGate({
      ...values,
      mode: process.argv[2],
      holdLabel: values["hold-label"],
      holdPrefix: values["hold-prefix"],
      allowLabel: values["allow-label"],
      requiredChecks: values["required-check"],
    });
    console.log(JSON.stringify(outcome));
  } catch (error) {
    console.error(
      JSON.stringify(result("blocked", String(error.message).split("\n")[0])),
    );
    process.exitCode = 1;
  }
}
