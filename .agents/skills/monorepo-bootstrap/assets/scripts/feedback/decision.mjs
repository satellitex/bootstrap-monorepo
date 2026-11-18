import { FeedbackError } from "./error.mjs";

// 区分は bot が書いた返信の先頭行だけから読む。項目番号は親の中で不変。
const control =
  /^\[(起票案|修正案|取り下げ|起票済み|更新済み|PR作成|マージ済み|実装見送り|本番反映|配布完了) ([1-9]\d*)\]/;

function hasId(value) {
  return typeof value === "string" && /^\S+$/.test(value);
}

export async function checkDecision(
  adapter,
  { parent, item, proposal, approver },
) {
  const itemNumber = String(item);
  if (
    !["number", "string"].includes(typeof item) ||
    !/^[1-9]\d*$/.test(itemNumber) ||
    !Number.isSafeInteger(Number(itemNumber))
  ) {
    throw new FeedbackError("decision: invalid_item");
  }
  if (!hasId(parent) || !hasId(proposal))
    throw new FeedbackError("decision: invalid_message_id");
  if (
    !Array.isArray(approver) ||
    approver.length === 0 ||
    !approver.every(hasId)
  ) {
    throw new FeedbackError("decision: invalid_approvers");
  }
  const { userId } = await adapter.whoami();
  const voters = new Set(approver);
  if (!hasId(userId) || voters.has(userId))
    throw new FeedbackError("decision: invalid_bot_or_approvers");

  // 両 adapter の replies は古い順。後続の起票済み・取り下げ等も以前の案を無効にする。
  const replies = await adapter.replies({ parent });
  for (let i = replies.length - 1; i >= 0; i--) {
    const reply = replies[i];
    if (reply.authorId !== userId || reply.isSystem) continue;
    const header = control.exec(reply.text);
    if (header?.[2] !== itemNumber) continue;
    if (reply.id !== proposal || !["起票案", "修正案"].includes(header[1]))
      break;
    if (!Array.isArray(reply.reactions))
      throw new FeedbackError("decision: incomplete_reactions");
    const votes = new Set();
    for (const { name, users } of reply.reactions) {
      if (!Array.isArray(users) || !users.every(hasId))
        throw new FeedbackError("decision: incomplete_reaction_users");
      if (users.some((id) => voters.has(id))) votes.add(name);
    }
    let state = "pending";
    if (votes.has("x")) state = "rejected";
    else if (votes.has("white_check_mark")) state = "approved";
    return { state, proposalId: proposal };
  }
  return { state: "superseded", proposalId: proposal };
}
