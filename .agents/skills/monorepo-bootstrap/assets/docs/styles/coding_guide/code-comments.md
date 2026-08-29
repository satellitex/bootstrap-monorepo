# ソースコメント規約

> この文書はソースコメントに **何を書いてはいけないか** を定義する規約である。
> `/code-sync` は本ガイドを検出基準の正本として参照する（skill の操作仕様は `docs/harness/skills/code-sync.md` 側に書き、本書には書かない）。
> doc-style コメントの **タグの書き方**（必須項目等）は各言語規約（`docs/styles/coding_guide/` に追加する言語別ガイド）が担当し、本書と相補的に機能する。

## 適用範囲

### 対象拡張子

対象拡張子はプロジェクトの採用スタックに応じて定義する。既定は TypeScript（`.ts`, `.tsx`）。
採用言語を追加したら本表へ拡張子とコメントマーカーを追記する（`/code-sync` はこの表を走査対象とする）。

| 言語 | 拡張子 |
|------|--------|
| TypeScript | `.ts`, `.tsx` |
| <additional-language> | 採用時に追記 |

### 非対象

以下は本規約の検査対象外:

- 自動生成ファイル（generated ヘッダ・自動生成ディレクトリ配下）
- `node_modules/` / `dist/` / ビルド成果物 / `.git/` / `.claude/worktrees/`
- シェバン行（`#!/usr/bin/env ...`）
- license header（SPDX-License-Identifier / Copyright を含む先頭コメント）
- コメントアウトされたコード（disabled code）

## コメント種別の分類

検査の適用範囲は種別で分かれるため、最初に分類する。

| 種別 | マーカーの例 |
|------|---------------|
| `doc-style` | JSDoc（`/** */`）/ docstring（`"""..."""`）/ IaC の `description = "..."` 等、ドキュメント生成ツールが extract する形式 |
| `regular` | line コメント（`//`, `#`）/ block コメント（`/* */`） |

`doc-style` はドキュメント生成ツール・API 仕様・SDK 型情報として **公開ドキュメントに extract される** ため、後述の検査 2 が追加適用される。

## 検査 1: 「現状の事実のみ」原則（全コメント対象）

> 本検査の判定基準は [`docs.md`](docs.md) を SSOT として **そのまま流用** する。重複定義は禁止。詳細は `docs.md` の各節を参照すること。

### `docs.md` から流用する要素

- **4 層モデル**（現状層 / 決定層 / 調査層 / 実装計画層）
- **現状層の 3 原則**:
  - **原則 1: No-Time** — 過去形・経緯・将来形・時系列マーカーの禁止
  - **原則 2: No-Ticket-In-Prose** — Issue / PR 番号を散文中に埋め込まない
  - **原則 3: No-Counterfactual** — 不採用・否定形比較の禁止
- **シグナル語 lexicon**（regex 検出パターン）
- **例外規定**（バージョン番号、要件 ID 等の保持してよい項目）
- **退避先の判定基準**（ADR / research / requirements / runbook）

ソースコメントに対しても、現状層 Markdown と同一の判定基準を適用する。

### ソースコメント特有の例外

以下は `docs.md` の例外規定に加えて、ソースコメント特有の理由で検査 1 から除外する:

1. **コメントアウトされたコード**（disabled code）— コメントマーカーの後がコード構文（記号・キーワード・括弧等）の場合
2. **TODO / FIXME / NOTE / HACK マーカー** を含むコメント — 経緯記録・将来実装メモ・既知の課題としての性格があるため、削除提案はしない（緩和的判定）
3. **シェバン行・license header** — 検査対象外

#### 書き手向けルール: 将来実装メモは必ずマーカーを付ける

「現状の事実」ではないが残したい記述（将来実装予定・既知の課題・暫定対処の経緯・後続タスクへの申し送り等）は、**必ず次のいずれかのマーカーを行頭に付与する**:

| マーカー | 用途 |
|---------|------|
| `TODO:` | 将来実装予定・追加すべき機能 |
| `FIXME:` | 既知の不具合・修正必要箇所 |
| `NOTE:` | 注意喚起・補足説明（経緯・背景の最小記述含む） |
| `HACK:` | 暫定対処・回避策（恒久対応が必要） |

マーカーが付いていない**将来タスクの申し送り**は、`/code-sync` が削除せず言語別の regular line コメントの `TODO:` へ自動変換する（doc-style 内にある場合は将来タスク句のみを分離し、`TODO:` を doc-style ブロックの直前に置く）。経緯・否定形比較など、その他の 3 原則違反は `/code-sync` により削除提案される。書き手は自動変換に依存せず、最初からマーカー付きで意図を明示すること。

```typescript
// BAD（マーカーなし — /code-sync が `// TODO:` へ自動変換する。書き手が最初から付けるべき）
// 将来的に外部キャッシュに置き換える予定
const cache = new Map<string, Value>();

// GOOD（最初から TODO マーカー付き — そのまま保持される）
// TODO: スループット要件が確定したら外部キャッシュに置き換える
const cache = new Map<string, Value>();
```

### 違反例とリファクタ例

```typescript
// BAD（原則 1 違反: 経緯記述）
/**
 * @deprecated 旧 API。以前は別ストレージを使用していたが、現在の構成に移行済み。
 */
export function legacyQuery() { ... }

// GOOD
/**
 * @deprecated 後継 API は `query()` を使用すること。
 */
export function legacyQuery() { ... }
```

```typescript
// BAD（原則 2 違反: チケット参照）
// Issue #123 で追加された exclusion filter
if (excluded.has(id)) throw new ForbiddenError();

// GOOD（理由を直接書く）
// 除外リストに登録された ID はリクエストを拒否する
if (excluded.has(id)) throw new ForbiddenError();
```

```typescript
// BAD（原則 3 違反: 比較・否定）
// ライブラリ A は不採用。ライブラリ B に統一
import { parse } from "lib-b";

// GOOD（採用事実のみ書く）
// ライブラリ B でペイロードを parse する
import { parse } from "lib-b";
```

## 検査 2: 公開ドキュメント生成対象コメントの内部参照排除（doc-style のみ）

### モチベーション

`doc-style` コメントは **API 利用者・SDK 利用者・運用者** が直接読む。
利用者は内部 ADR / 要件 ID / Issue にアクセスできないため、これらへの参照は **リンク切れ・意味不明な参照** となり公開ドキュメントのノイズになる。
利用者向けには「**現状の動作・入出力・制約**」を自己完結した文章で記述する。

### 検出すべき内部参照

| カテゴリ | regex 風パターン |
|---------|----------------|
| 内部ドキュメントパス | `docs/notes/`, `docs/adr/`, `docs/requirements/`, `docs/issues/`, `docs/customer/`, `docs/runbooks/` |
| 内部要件 ID | `BR-\d+(-FIX)?`, `IF-\d+(-FIX)?`, `DATA-\d+(-FIX)?`, `FR-\d+(-FIX)?`, `NFR-\d+(-FIX)?`, `SEC-\d+(-FIX)?` |
| User Story / Acceptance Criteria ID | `US-\d+(-\d+)?`, `AC-\d+(-[\d*]+)*(-FIX)?`（例: `US-001`, `AC-001-01`） |
| ADR ファイル名 | `ADR-\d{8}_[a-z0-9-]+` |
| Issue / PR 番号 | `(Issue\|PR)\s*#\d+`, `\(#\d+\)` |

いずれも内部実装者向けに「設計判断の根拠を辿る」ためのトレーサビリティ ID であり、外部利用者は当該ドキュメントにアクセスできない。doc-style コメント内では **ID を書かず、その ID が指す動作・契約・制約を自己完結した文章で直接記述する**。

### 自動編集ポリシー

`doc-style` コメント内の検出箇所は **自動編集しない**。
利用者向け要約への書き換えは文脈判断が必要なため、PR body に `fix_action: needs_user_facing_rewrite` として記録し、**人間判断** で「利用者向けに自己完結した要約」へ書き換える。

### 検査 2 の例外

| 例外 | 理由 |
|------|------|
| `regular` コメント内の内部参照 | 内部実装者向け参照は許容（公開ドキュメントには extract されない） |
| テストファイル（`*.test.ts` 等、採用言語のテスト命名規則に従うファイル）の doc-style コメント | 公開 API ではない |

### 違反例とリファクタ例

```typescript
// BAD（要件 ID + 内部パス参照）
/**
 * SEC-0012 で定義された署名検証を実行する。
 * 詳細は docs/adr/ 配下の該当 ADR を参照。
 */
export function verifySignature(payload: Payload, signature: string) { ... }

// GOOD（動作・入出力・制約を自己完結で記述）
/**
 * リクエストペイロードの署名を検証する。
 * 署名対象は payload hash / 発行者 / nonce / 有効期限を含む。
 * 戻り値: 署名者の識別子。検証失敗時は InvalidSignatureError を throw する。
 */
export function verifySignature(payload: Payload, signature: string) { ... }
```

```typescript
// BAD（Issue 番号参照）
/**
 * リソースを発行する。
 * Issue #123 で追加された rate limit が適用される。
 */
export async function issueResource(...) { ... }

// GOOD（仕様を直接書く）
/**
 * リソースを発行する。
 * rate limit: 10 req/min per API key。超過時は 429 を返す。
 */
export async function issueResource(...) { ... }
```

```typescript
// BAD（US / AC 参照）
/** US-001 / AC-001-03 を満たす作成 API。AC-001-01〜11 で検証される。 */
export async function createRecord(...) { ... }

// GOOD（契約・前提条件・失敗条件を直接書く）
/**
 * 管理者ロールがレコードを作成する。
 * 入力の重複・権限不足・有効期限切れのいずれかの場合はエラーを返す。
 */
export async function createRecord(...) { ... }
```

## 書き手向けクイックチェック

ソースコメントを書くときに毎回確認する:

- [ ] 書こうとしている記述は「今こうなっている」事実か？（過去・将来・移行の話なら ADR / 削除 / TODO・FIXME・NOTE・HACK マーカー付与）
- [ ] 将来実装メモ・既知の課題・暫定対処メモを残す場合、`TODO:` / `FIXME:` / `NOTE:` / `HACK:` マーカーを必ず付与しているか？
- [ ] 文中に Issue / PR 番号を埋め込んでいないか？（仕様を直接書く）
- [ ] 「X は不採用」「Y ではなく Z」と書いていないか？（採用事実のみ書く）
- [ ] `doc-style` の場合、内部 ADR / 要件 ID / US・AC ID / 内部パス / Issue 番号を含んでいないか？
- [ ] `doc-style` の場合、利用者がコメントだけで動作・入出力・制約を理解できるか？

## 参考

- [`docs.md`](docs.md) — 検査 1 の SSOT（4 層モデル、3 原則、signal lexicon、退避先判定）
- `docs/harness/skills/code-sync.md` — 本ガイドを検出基準として実行する skill の操作仕様
