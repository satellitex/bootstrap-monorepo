import { mkdir, mkdtemp, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { FeedbackError } from "./error.mjs";

const MAX_BYTES = 10 * 1024 * 1024;
const MEDIA_TYPE = /^(audio|video)\//i;

export async function downloadAttachment({
  file,
  url,
  allowedHost,
  headers,
  out,
  fetch,
}) {
  const skipped = (reason) => ({ downloaded: false, reason });
  if (MEDIA_TYPE.test(file.mimetype)) return skipped("video_or_audio");
  if (file.size > MAX_BYTES) return skipped("too_large");
  const source = URL.canParse(url) ? new URL(url) : undefined;
  if (
    !source ||
    source.protocol !== "https:" ||
    source.host !== allowedHost ||
    source.username ||
    source.password
  ) {
    return skipped("unexpected_url");
  }
  let response;
  try {
    response = await fetch(source.href, {
      headers,
      redirect: "error",
      signal: AbortSignal.timeout(30_000),
    });
  } catch {
    throw new FeedbackError("attachment: download_failed");
  }
  if (!response.ok)
    throw new FeedbackError(`attachment: http_${response.status}`);
  const mime = response.headers
    .get("content-type")
    ?.split(";")[0]
    .trim()
    .toLowerCase();
  if (MEDIA_TYPE.test(mime)) {
    await response.body?.cancel();
    return skipped("video_or_audio");
  }
  if (mime === "text/html" && file.mimetype !== "text/html") {
    await response.body?.cancel();
    throw new FeedbackError("attachment: unexpected_html");
  }
  if (Number(response.headers.get("content-length")) > MAX_BYTES) {
    await response.body?.cancel();
    return skipped("too_large");
  }
  const chunks = [];
  let size = 0;
  if (!response.body) throw new FeedbackError("attachment: missing_body");
  for await (const chunk of response.body) {
    size += chunk.length;
    if (size > MAX_BYTES) return skipped("too_large");
    chunks.push(chunk);
  }
  // 添付名は表示用。run ごとに独立した場所に保存し、同名ファイルを上書きしない。
  const name = String(file.name || "file")
    .replace(/[^a-z0-9._-]/gi, "_")
    .slice(0, 100);
  await mkdir(out, { recursive: true, mode: 0o700 });
  const directory = await mkdtemp(join(out, "feedback-"));
  const path = join(directory, "attachment-" + name);
  await writeFile(path, Buffer.concat(chunks, size), {
    flag: "wx",
    mode: 0o600,
  });
  return { downloaded: true, path };
}
