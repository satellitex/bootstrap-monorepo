# create-adr — ADR の構造的記録

この文書は `/create-adr` の tool-neutral な正本手順である。ADR の運用ポリシー（起票基準・命名・Status 遷移・置換と廃止・INDEX 形式・圧縮運用）は `docs/adr/README.md` が正本であり、ここには手順のみを書く。

## 目的

レビューでの差し戻しや設計方針の変更を含む設計判断が発生したときに、ADR (Architecture Decision Record) を構造的に記録する。既存の ADR を置き換える判断では、元の ADR の Status も同じ PR で更新し、無効になった決定が「現在有効」のまま残らないようにする。

## 起票基準

起票基準（ADR にする判断、ADR にせず PR 本文に書く判断、暫定対策の撤去条件と再評価トリガの書き方）は `docs/adr/README.md`「いつ書くか」に従う。

## 入力

| 項目               | 必須 | 説明                                                               |
| ------------------ | ---- | ------------------------------------------------------------------ |
| 問題の概要         | Yes  | 何が問題だったか（人間の入力、レビュー指摘、実装中の設計判断など） |
| 関連 Issue 番号    | No   | GitHub Issue `#<N>`                                                |
| 関連要件           | No   | `docs/requirements/` 配下の要件 ID への参照                        |
| 置換・廃止する ADR | No   | 新しい判断が置き換える既存 ADR の ID またはファイル名（Step 4）    |

引数例: `/create-adr "リトライ方針の変更判断" #<N>`

引数が不足している場合は、起票文脈（レビューコメント・実装中の判断内容・関連 Issue / PR）から補完する。補完できない必須項目は、対話 run ではユーザに質問する。無人 run では、必須項目（問題の概要）を既定値で埋めず、ADR を生成せずに不足項目を明示して呼び出し元へ返す。扱いは実行モードによる（→ `docs/harness/skills/shared/unattended-contract.md`）。

## フロー

### Step 1: ファイル名の決定

ファイル名は `docs/adr/README.md`「書き方」の命名規則に従う。`{YYYYMMDD}` は実行日、`{branch-slug}` は現在の git ブランチ名、`{topic-slug}` は問題の概要から生成した英語 kebab-case（簡潔に）で埋める。

### Step 2: ADR ファイルの生成

`docs/adr/template.md` を Read し、その構造で `docs/adr/<ファイル名>` を生成する（テンプレートの SSOT は template.md。本文書に複製しない）。

- Status: `Proposed` で起票する。マージ後の `Accepted` への更新は `/adr-compress`（`docs/harness/skills/adr-compress.md`）が追従させるため、手動で更新しない（マージと保留の扱い → `docs/adr/README.md`「書き方」「Status の追従」）。
- Author: 起票元に応じて設定（例: `Agent (Review Comment)`, `Human`, `Agent (Planner)`）
- Context: 問題の背景・制約・前提条件。関連する要件 ID（SEC-NNNN, FR-NNNN 等）があれば言及
- Decision: 選択した方針と根拠。複数案を比較した場合は、退けた案と理由も書く
- Consequences: Positive（メリット）と Negative（トレードオフ・リスク）の両面で記述
- Related Issues: 関連 Issue 番号と要件ドキュメントへのリンク

### Step 3: INDEX.md の扱い

`docs/adr/INDEX.md` の更新主体は `docs/harness/skills/shared/index-writer-policy.md` の割当表に従う。既定の更新主体は routine（`/adr-compress`）であり、実装 PR では INDEX.md を編集しない。並列に走る PR が同じ表の末尾へ追記すると衝突するため。ADR 本文は、冒頭見出しと Status・Date の表だけで一覧の行を起こせる状態にしておく。

同ポリシーが経過措置として同一 PR での更新を許している間は、`docs/adr/INDEX.md` の Proposed 表に、第 1 セルを ADR へのリンク、第 2 セルを 1 行要旨にした行を追記する:

```markdown
| [<id>](./<id>.md) | 1 行要旨 | YYYY-MM-DD |
```

`<id>` は ADR のファイル名から `.md` を除いたものである。

### Step 4: 既存 ADR を置換・廃止する場合

新しい ADR の Decision が既存の ADR を ID またはファイル名で名指しして置換・廃止・撤回する場合は、置換と廃止の規則（`docs/adr/README.md`「置換と廃止」）に従って、元の ADR の Status と冒頭見出しを新しい ADR と同じ PR で更新する。

1. 元の ADR の Status と冒頭の `## Superseded（YYYY-MM-DD）` / `## Deprecated（YYYY-MM-DD）` 見出しを、README の規則どおりに更新する。
2. 新しい ADR の Related Issues（または Context）に、置換・廃止した ADR を挙げる。
3. INDEX.md の元の ADR の行（Superseded / Deprecated 表への移動を含む）は、Step 3 の更新主体の扱いに従う。

既存の ADR が実態と合わなくなった場合は、レビュー指摘への対応で吸収せず、この Step で置換の ADR を起票する。

## 出力

完了後、作成した ADR ファイルのパス、置換・廃止した元の ADR（あれば）、INDEX.md の扱い、ADR の概要（タイトル・Status・Related Issues）をユーザに報告する。

## 関連

- `docs/adr/README.md` — ADR 運用の正本（起票基準・命名・Status 遷移・圧縮）
- `docs/adr/template.md` — 本文テンプレートの SSOT
- `docs/harness/skills/shared/index-writer-policy.md` — INDEX の更新主体
- `docs/harness/skills/shared/unattended-contract.md` — 確認ゲートの扱い（対話 run / 無人 run）
- `docs/harness/skills/adr-compress.md` — Status 追従と圧縮
- `docs/harness/skills/handle-review.md` — レビュー対応時の ADR 記録の呼び出し元
