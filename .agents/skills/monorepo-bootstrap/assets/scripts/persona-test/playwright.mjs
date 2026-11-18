// opt-in:persona-test
// Playwright の解決、ブラウザの起動、端末の種類ごとの設定。サーバーと投稿の組み立てが共有する。
//
// Playwright は、既定ではリポジトリのルートの依存から解決する（`@playwright/test` か `playwright`）。
// ブラウザの統合テストを持つ workspace など、別の package の依存から解決するときは、
// PERSONA_PLAYWRIGHT_FROM にその package.json があるディレクトリを渡す。
// 既定のブラウザは Playwright の Chromium の新しい headless（channel: "chromium"）で、別の実行ファイルを
// 使うときは PERSONA_BROWSER_PATH で指す。
// 解決は最初に使うときに行う。画像の横並べが要らない投稿の組み立ては、Playwright が無くても動く。

import { createRequire } from "node:module";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const PACKAGE_NAMES = ["@playwright/test", "playwright"];

let loaded;

function playwright() {
  if (loaded) return loaded;
  const from = resolve(
    process.env.PERSONA_PLAYWRIGHT_FROM ??
      fileURLToPath(new URL("../../", import.meta.url)),
  );
  const require = createRequire(join(from, "package.json"));
  for (const name of PACKAGE_NAMES) {
    try {
      loaded = require(name);
      return loaded;
    } catch (error) {
      if (error?.code !== "MODULE_NOT_FOUND") throw error;
    }
  }
  throw new Error(
    `Playwright が見つからない（解決元: ${from}）。profile の取得の方法で入れるか、` +
      `PERSONA_PLAYWRIGHT_FROM に ${PACKAGE_NAMES.join(" か ")} を依存に持つ package のディレクトリを渡す`,
  );
}

export function launchBrowser() {
  const executablePath = process.env.PERSONA_BROWSER_PATH;
  return playwright().chromium.launch({
    headless: true,
    ...(executablePath ? { executablePath } : { channel: "chromium" }),
  });
}

const desktop = (viewport, platform, chromeMajor) => ({
  viewport,
  deviceScaleFactor: 1,
  userAgent: `Mozilla/5.0 (${platform}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${chromeMajor}.0.0.0 Safari/537.36`,
});

/**
 * 端末の種類 → context の設定。種類の一覧は lib.mjs の検査が持つ。スマホは 2 倍の解像度で撮る。
 * UA の Chrome の版は、起動したブラウザ（desktop）か Playwright の端末の定義（スマホ）に合わせる。
 */
export function deviceProfile(kind, chromeMajor) {
  const { devices } = playwright();
  switch (kind) {
    case "iphone":
      return { ...devices["iPhone 15"], deviceScaleFactor: 2 };
    case "pixel":
      return { ...devices["Pixel 7"], deviceScaleFactor: 2 };
    case "galaxy": {
      const base = devices["Galaxy S24"];
      return {
        ...base,
        deviceScaleFactor: 2,
        userAgent: base.userAgent.replace(
          "Chrome/",
          "SamsungBrowser/26.0 Chrome/",
        ),
      };
    }
    case "win":
      return desktop(
        { width: 1536, height: 864 },
        "Windows NT 10.0; Win64; x64",
        chromeMajor,
      );
    case "mac":
      return desktop(
        { width: 1440, height: 900 },
        "Macintosh; Intel Mac OS X 10_15_7",
        chromeMajor,
      );
    default:
      throw new Error(`unknown device kind: ${kind}`);
  }
}
