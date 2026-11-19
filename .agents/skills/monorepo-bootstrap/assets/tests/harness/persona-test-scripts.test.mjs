// opt-in:persona-test
// ペルソナによる利用テストの道具（scripts/persona-test/lib.mjs）の振る舞いの検査。
//
// 対象は、判断を誤ると実害が出る部分だけである。
//   - 公開しない資格情報を、操作の出力から伏せる（出力は subagent の文脈と報告書に残る）
//   - サーバーを起動し直しても、スクリーンショットの番号を続きから振る（0 から振ると、根拠の画像を上書きする）
//   - 保存できない値を持つ記録を、ブラウザの状態の復元の前に除く（壊れた鍵でデータを開けなくなる）
//   - 字数の上限を超えた本文と、無い画像を付けた項目を、送る前に止める
// ブラウザは使わない。外部への通信もしない。
//
// これはルートを走査する gate（check-*.test.mjs）ではなく、script の自己テストである。
// 実行は run.mjs（pnpm harness:test）が検査ファイルの列挙で拾う。

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  FEEDBACK_LIMITS,
  buildPost,
  credentialValues,
  dropIndexedDbRecords,
  lastShotIndex,
  newCredentials,
  redact,
  secretValues,
  validateFeedback,
  validateRunConfig,
} from "../../scripts/persona-test/lib.mjs";

const item = (overrides = {}) => ({
  n: 1,
  heading: "見出し",
  place: "場所",
  issue: "何が起きたか",
  why: "なぜ困るか",
  ideal: "どうなっていればよいか",
  shots: [],
  ...overrides,
});
const feedback = (items) => ({ persona: "P01 A", intro: "人物の紹介", items });

describe("資格情報", () => {
  const spec = {
    email: { template: "t.{id}.{rand}@example.com", public: true },
    password: { random: "password" },
    pin: { random: "digits", length: 6 },
    code: { fixed: "123456", public: true },
  };

  it("公開しない値だけを、出力のどこにあっても伏せる", () => {
    const values = credentialValues(spec, newCredentials("P01", spec));
    const secrets = secretValues(spec, values);
    assert.deepEqual(
      secrets.toSorted(),
      [values.password, values.pin].toSorted(),
    );
    const output = `入力した: ${values.password} / @3 input "${values.pin}" / ${values.email}`;
    const shown = redact(output, secrets);
    assert.ok(!shown.includes(values.password));
    assert.ok(!shown.includes(values.pin));
    assert.ok(shown.includes(values.email));
  });

  it("作る値はペルソナごと・run ごとに別で、固定の値は設定から読む", () => {
    const first = newCredentials("P01", spec);
    assert.match(first.email, /^t\.p01\.[0-9a-f]{6}@example\.com$/);
    assert.notEqual(first.email, newCredentials("P01", spec).email);
    assert.match(first.pin, /^[0-9]{6}$/);
    assert.equal(first.code, undefined);
    assert.equal(credentialValues(spec, first).code, "123456");
  });
});

describe("スクリーンショットの番号", () => {
  it("既にある画像の続きから振る", () => {
    assert.equal(lastShotIndex(["001.png", "158.png", "020.png"]), 158);
    assert.equal(lastShotIndex([]), 0);
    assert.equal(lastShotIndex(["notes.txt"]), 0);
  });
});

describe("ブラウザの状態の復元", () => {
  it("指定した key の記録だけを除く", () => {
    const saved = {
      cookies: [{ name: "session" }],
      origins: [
        {
          origin: "https://app.example",
          localStorage: [],
          indexedDB: [
            {
              name: "app",
              stores: [
                {
                  name: "records",
                  records: [{ key: "cryptokey:acc" }, { key: "settings:acc" }],
                },
              ],
            },
          ],
        },
      ],
    };
    const state = dropIndexedDbRecords(saved, ["cryptokey:"]);
    assert.deepEqual(state.origins[0].indexedDB[0].stores[0].records, [
      { key: "settings:acc" },
    ]);
    assert.deepEqual(state.cookies, saved.cookies);
  });
});

describe("feedback の検査", () => {
  it("上限に収まる feedback は通す", () => {
    assert.deepEqual(validateFeedback(feedback([item()])), []);
  });

  it("上限を超えた欄、空の欄、改行を止める", () => {
    const long = "あ".repeat(FEEDBACK_LIMITS.issue + 1);
    const problems = validateFeedback(
      feedback([item({ issue: long, why: "", ideal: "1 行目\n2 行目" })]),
    );
    assert.equal(problems.length, 3);
  });

  it("無い画像を付けた項目を止める", () => {
    const withShot = item({
      shots: [{ path: "/no/such.png", caption: "説明" }],
    });
    const problems = validateFeedback(feedback([withShot]), {
      fileExists: () => false,
    });
    assert.equal(problems.length, 1);
    assert.deepEqual(
      validateFeedback(feedback([withShot]), { fileExists: () => true }),
      [],
    );
  });
});

describe("投稿の組み立て", () => {
  it("欄の名前と但し書きは、渡された文言だけを使う", () => {
    const post = {
      title: "T",
      disclosure: "D",
      labels: { place: "L1", issue: "L2", why: "L3", ideal: "L4", image: "L5" },
    };
    const shots = [
      { path: "/a.png", caption: "左" },
      { path: "/b.png", caption: "右" },
    ];
    const built = buildPost(feedback([item({ shots })]), post);
    assert.equal(built.parent, "T｜P01 A\n\n人物の紹介\n\nD\n\n1. 見出し");
    assert.equal(
      built.items[0].text,
      "P01 A｜1. 見出し\nL1: 場所\nL2: 何が起きたか\nL3: なぜ困るか\nL4: どうなっていればよいか\nL5: (1) 左 (2) 右",
    );
  });
});

describe("run.json の検査", () => {
  const base = { contexts: { P01: { device: "mac", locale: "ja-JP" } } };

  it("知らない端末の種類、作り方の無い資格情報、欠けた文言を止める", () => {
    assert.deepEqual(validateRunConfig(base), []);
    assert.equal(
      validateRunConfig({
        contexts: { P01: { device: "tv", locale: "ja-JP" } },
      }).length,
      1,
    );
    assert.equal(
      validateRunConfig({ ...base, credentials: { pin: { length: 6 } } })
        .length,
      1,
    );
    assert.equal(
      validateRunConfig({ ...base, post: { title: "T", disclosure: "D" } })
        .length,
      5,
    );
  });
});
